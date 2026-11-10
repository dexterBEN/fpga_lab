import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpga_register_control/models/register_mode.dart';
import 'package:fpga_register_control/models/register_snapshot.dart';
import 'package:fpga_register_control/repository/register_server_exception.dart';
import 'package:fpga_register_control/repository/websocket_register_repository.dart';

import '../support/register_fixtures.dart';

void main() {
  late _LocalServer server;
  late WebSocketRegisterRepository repository;
  const token = 'test-token';

  setUp(() async {
    server = await _LocalServer.start();
    repository = WebSocketRegisterRepository(
      url: server.url,
      token: token,
      requestTimeout: const Duration(seconds: 2),
    );
  });

  tearDown(() async {
    await repository.dispose();
    await server.close();
  });

  test(
    'all commands share one connection and return server snapshots',
    () async {
      server.onRequest = (request) {
        final state = snapshotJson()
          ..['history'] = [
            // This deliberately differs from the actual hardware value.
            {'action': 'load_parallel', 'value': 3, 'result': 3},
          ];
        server.reply(request, state: state);
      };
      await repository.connect();
      final operations = [
        repository.getState(),
        repository.loadParallel(10),
        repository.shiftBit(1),
        repository.selectMode(RegisterMode.shift),
      ];
      final snapshots = await Future.wait(operations);
      for (final snapshot in snapshots) {
        expect(snapshot.parallel.value, 10);
        expect(snapshot.shift.value, 11);
        // Do not infer state from the requested mode or operation history.
        expect(snapshot.selectedMode, RegisterMode.parallel);
        expect(snapshot.history.single.result, 3);
        expect(snapshot.fclk0Mhz, 50);
        expect(snapshot.softwareResetAvailable, isFalse);
      }
      final commands = server.requests.map((request) {
        final json = Map<String, dynamic>.from(request.json)..remove('id');
        return json;
      }).toList();
      expect(commands, [
        {'token': token, 'action': 'get_state'},
        {'token': token, 'action': 'load_parallel', 'value': 10},
        {'token': token, 'action': 'shift', 'bit': 1},
        {'token': token, 'action': 'select_mode', 'mode': 'shift'},
      ]);
      final ids = server.requests.map((request) => request.json['id']).toList();
      expect(ids, everyElement(matches(r'^flutter-\d+$')));
      expect(ids.toSet(), hasLength(4));
      expect(server.connections, 1);
      expect(await repository.ping(), isTrue);
      expect(server.connections, 1);
    },
  );

  test('accepts boundary values and both modes', () async {
    server.onRequest = server.reply;
    await repository.connect();
    await repository.loadParallel(0);
    await repository.loadParallel(15);
    await repository.shiftBit(0);
    await repository.selectMode(RegisterMode.parallel);
    expect(server.requests.map((request) => request.json['value']), [
      0,
      15,
      null,
      null,
    ]);
    expect(server.requests[2].json['bit'], 0);
    expect(server.requests[3].json['mode'], 'parallel');
  });

  test('rejects invalid values locally without sending commands', () async {
    server.onRequest = server.reply;
    await repository.connect();
    for (final value in [-1, 16]) {
      await expectLater(repository.loadParallel(value), throwsRangeError);
    }
    for (final bit in [-1, 2]) {
      await expectLater(repository.shiftBit(bit), throwsRangeError);
    }
    expect(server.requests, isEmpty);
    await repository.ping();
    expect(server.requests.single.json['action'], 'ping');
  });

  test('rejects every operation without an active connection', () async {
    await expectLater(repository.ping(), throwsStateError);
    await expectLater(repository.getState(), throwsStateError);
    await expectLater(repository.loadParallel(10), throwsStateError);
    await expectLater(repository.shiftBit(1), throwsStateError);
    await expectLater(
      repository.selectMode(RegisterMode.shift),
      throwsStateError,
    );
    expect(server.connections, 0);
  });

  test('getState deserializes the complete state response', () async {
    server.onRequest = server.reply;
    await repository.connect();
    expect(
      await repository.getState(),
      RegisterSnapshot.fromJson(snapshotJson()),
    );
  });

  test(
    'server errors preserve the message and request ID; queue can continue',
    () async {
      server.onRequest = (request) {
        if (request.json['action'] == 'load_parallel') {
          request.socket.add(
            jsonEncode({
              'id': request.json['id'],
              'type': 'error',
              'message': 'MMIO unavailable',
            }),
          );
        } else {
          server.reply(request);
        }
      };
      await repository.connect();
      final failure = expectLater(
        repository.loadParallel(10),
        throwsA(
          isA<RegisterServerException>()
              .having((error) => error.message, 'message', 'MMIO unavailable')
              .having((error) => error.requestId, 'requestId', 'flutter-1'),
        ),
      );
      final next = repository.getState();
      await failure;
      expect(await next, RegisterSnapshot.fromJson(snapshotJson()));
      expect(repository.isConnected, isTrue);
    },
  );

  test(
    'correlates concurrent pings by ID when replies arrive in reverse order',
    () async {
      await repository.connect();
      final first = expectLater(
        repository.ping(),
        throwsA(isA<RegisterServerException>()),
      );
      final second = repository.ping();
      final firstRequest = await server.nextRequest();
      final secondRequest = await server.nextRequest();
      server.reply(secondRequest);
      expect(await second, isTrue);
      firstRequest.socket.add(
        jsonEncode({
          'id': firstRequest.json['id'],
          'type': 'error',
          'message': 'First ping rejected',
        }),
      );
      await first;
      expect(firstRequest.json['id'], isNot(secondRequest.json['id']));
      expect(server.connections, 1);
    },
  );

  test('ping and hardware responses can arrive out of order', () async {
    await repository.connect();
    final state = repository.getState();
    final ping = repository.ping();
    final stateRequest = await server.nextRequest();
    final pingRequest = await server.nextRequest();
    expect(stateRequest.json['action'], 'get_state');
    expect(pingRequest.json['action'], 'ping');
    server.reply(pingRequest);
    expect(await ping, isTrue);
    server.reply(stateRequest);
    expect(await state, RegisterSnapshot.fromJson(snapshotJson()));
  });

  test('serializes all hardware operations, including MUX reads', () async {
    server.onRequest = (request) {
      if (request.json['action'] == 'ping') server.reply(request);
    };
    await repository.connect();
    final results = Future.wait([
      repository.loadParallel(10),
      repository.shiftBit(1),
      repository.selectMode(RegisterMode.shift),
      repository.getState(),
    ]);
    final first = await server.nextRequest();
    await repository.ping(); // A round trip while the first command is held.
    expect(server.requests.map((request) => request.json['action']), [
      'load_parallel',
      'ping',
    ]);
    await server.nextRequest(); // Consume the ping from the helper's queue.
    server.reply(first);
    final second = await server.nextRequest();
    expect(second.json['action'], 'shift');
    expect(server.requests, hasLength(3));
    server.reply(second);
    final third = await server.nextRequest();
    expect(third.json['action'], 'select_mode');
    expect(server.requests, hasLength(4));
    server.reply(third);
    final fourth = await server.nextRequest();
    expect(fourth.json['action'], 'get_state');
    server.reply(fourth);
    expect(await results, hasLength(4));
  });

  test(
    'broadcasts, unknown IDs and duplicate responses do not consume requests',
    () async {
      await repository.connect();
      final result = repository.getState();
      final request = await server.nextRequest();
      for (final type in ['hello', 'state_changed']) {
        request.socket.add(
          jsonEncode({'id': request.json['id'], 'type': type}),
        );
        request.socket.add(jsonEncode({'type': type}));
      }
      request.socket.add(jsonEncode({'id': 'unknown-id', 'type': 'result'}));
      server.reply(request);
      server.reply(request);
      expect(await result, RegisterSnapshot.fromJson(snapshotJson()));
      final next = repository.ping();
      server.reply(await server.nextRequest());
      expect(await next, isTrue);
    },
  );

  test(
    'malformed state fails the command without fabricating a snapshot',
    () async {
      server.onRequest = (request) {
        server.reply(
          request,
          state: {
            'parallel': {'value': 99},
          },
        );
      };
      await repository.connect();
      await expectLater(repository.loadParallel(10), throwsFormatException);
      server.onRequest = server.reply;
      expect(
        await repository.getState(),
        RegisterSnapshot.fromJson(snapshotJson()),
      );
    },
  );

  test('a response of the wrong type fails its matching request', () async {
    server.onRequest = (request) {
      request.socket.add(
        jsonEncode({'id': request.json['id'], 'type': 'pong'}),
      );
    };
    await repository.connect();
    await expectLater(repository.getState(), throwsFormatException);
  });

  for (final packet in ['not JSON', '[]', '{"type":"result"}']) {
    test(
      'malformed protocol packet $packet fails pending and queued work',
      () async {
        await repository.connect();
        final pending = expectLater(
          repository.getState(),
          throwsFormatException,
        );
        final queued = expectLater(
          repository.shiftBit(1),
          throwsFormatException,
        );
        final ping = expectLater(repository.ping(), throwsFormatException);
        final request = await server.nextRequest();
        request.socket.add(packet);
        await Future.wait([pending, queued, ping]);
        expect(repository.isConnected, isFalse);
      },
    );
  }

  test(
    'a server-wide error fails all requests with a meaningful exception',
    () async {
      await repository.connect();
      final pending = expectLater(
        repository.getState(),
        throwsA(isA<RegisterServerException>()),
      );
      final queued = expectLater(
        repository.shiftBit(1),
        throwsA(isA<RegisterServerException>()),
      );
      final request = await server.nextRequest();
      request.socket.add(
        jsonEncode({
          'id': null,
          'type': 'error',
          'message': 'Authentication failed',
        }),
      );
      await Future.wait([pending, queued]);
      expect(repository.isConnected, isFalse);
    },
  );

  test(
    'configurable ping timeout ignores late replies and preserves connection',
    () async {
      await repository.dispose();
      repository = WebSocketRegisterRepository(
        url: server.url,
        token: token,
        requestTimeout: const Duration(milliseconds: 200),
      );
      await repository.connect();
      final timeout = expectLater(
        repository.ping(),
        throwsA(isA<TimeoutException>()),
      );
      final expired = await server.nextRequest();
      await timeout;
      expect(repository.isConnected, isTrue);
      final next = repository.ping();
      final current = await server.nextRequest();
      expired.socket.add(
        jsonEncode({
          'id': expired.json['id'],
          'type': 'error',
          'message': 'Late error',
        }),
      );
      server.reply(current);
      expect(await next, isTrue);
    },
  );

  test(
    'hardware timeout cancels unsent operations instead of replaying them',
    () async {
      await repository.dispose();
      repository = WebSocketRegisterRepository(
        url: server.url,
        token: token,
        requestTimeout: const Duration(milliseconds: 200),
      );
      await repository.connect();
      final timedOut = expectLater(
        repository.loadParallel(10),
        throwsA(isA<TimeoutException>()),
      );
      final cancelled = expectLater(repository.shiftBit(1), throwsStateError);
      await Future.wait([timedOut, cancelled]);
      expect(server.requests.single.json['action'], 'load_parallel');
      expect(repository.isConnected, isFalse);
      server.onRequest = server.reply;
      await repository.connect();
      expect(
        await repository.getState(),
        RegisterSnapshot.fromJson(snapshotJson()),
      );
      expect(server.requests.map((request) => request.json['action']), [
        'load_parallel',
        'get_state',
      ]);
      expect(
        server.requests.map((request) => request.json['id']).toSet(),
        hasLength(2),
      );
    },
  );

  for (final closure in ['server close', 'disconnect', 'dispose']) {
    test('$closure fails in-flight, queued and ping requests', () async {
      await repository.connect();
      final inFlight = expectLater(repository.getState(), throwsStateError);
      final queued = expectLater(repository.shiftBit(1), throwsStateError);
      final ping = expectLater(repository.ping(), throwsStateError);
      final request = await server.nextRequest();
      if (closure == 'server close') {
        await request.socket.close();
      } else if (closure == 'disconnect') {
        await repository.disconnect();
      } else {
        await repository.dispose();
      }
      await Future.wait([inFlight, queued, ping]);
      expect(repository.isConnected, isFalse);
      expect(
        server.requests.where((request) => request.json['action'] == 'shift'),
        isEmpty,
      );
    });
  }

  test('concurrent connect calls open exactly one connection', () async {
    server.onRequest = server.reply;
    await Future.wait(List.generate(5, (_) => repository.connect()));
    await repository.connect();
    await repository.ping();
    expect(server.connections, 1);
    await repository.disconnect();
    await Future.wait([repository.connect(), repository.connect()]);
    await repository.ping();
    expect(server.connections, 2);
    expect(
      server.requests.first.json['id'],
      isNot(server.requests.last.json['id']),
    );
  });

  test('disconnect cancels a connection attempt before it starts', () async {
    final connecting = expectLater(repository.connect(), throwsStateError);
    await repository.disconnect();
    await connecting;
    expect(repository.isConnected, isFalse);
    expect(server.connections, 0);
    server.onRequest = server.reply;
    await repository.connect();
    expect(await repository.ping(), isTrue);
  });

  test(
    'dispose is idempotent, closes notifications and forbids reuse',
    () async {
      await repository.connect();
      final notificationsDone = expectLater(
        repository.connectionChanges,
        emitsInOrder([false, emitsDone]),
      );
      await Future.wait([repository.dispose(), repository.dispose()]);
      await notificationsDone;
      await expectLater(repository.connect(), throwsStateError);
      await expectLater(repository.getState(), throwsStateError);
      await expectLater(repository.ping(), throwsStateError);
      expect(server.connections, 1);
    },
  );

  test('rejects nonpositive timeout settings', () {
    expect(
      () => WebSocketRegisterRepository(
        url: server.url,
        token: token,
        requestTimeout: Duration.zero,
      ),
      throwsArgumentError,
    );
    expect(
      () => WebSocketRegisterRepository(
        url: server.url,
        token: token,
        connectionTimeout: const Duration(seconds: -1),
      ),
      throwsArgumentError,
    );
  });
}

class _ReceivedRequest {
  _ReceivedRequest(this.socket, this.json);
  final WebSocket socket;
  final Map<String, dynamic> json;
}

class _LocalServer {
  _LocalServer(this._server);
  final HttpServer _server;
  final _sockets = <WebSocket>[];
  final requests = <_ReceivedRequest>[];
  final _unread = Queue<_ReceivedRequest>();
  final _waiting = Queue<Completer<_ReceivedRequest>>();
  void Function(_ReceivedRequest)? onRequest;
  int get connections => _sockets.length;
  String get url => 'ws://127.0.0.1:${_server.port}';

  static Future<_LocalServer> start() async {
    final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final server = _LocalServer(http);
    http.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      server._sockets.add(socket);
      socket.add(jsonEncode({'type': 'hello', 'protocol': 'fpga-exo7-v1'}));
      socket.listen((message) {
        final received = _ReceivedRequest(
          socket,
          jsonDecode(message as String) as Map<String, dynamic>,
        );
        server.requests.add(received);
        if (server._waiting.isEmpty) {
          server._unread.add(received);
        } else {
          server._waiting.removeFirst().complete(received);
        }
        server.onRequest?.call(received);
      });
    });
    return server;
  }

  Future<_ReceivedRequest> nextRequest() {
    if (_unread.isNotEmpty) return Future.value(_unread.removeFirst());
    final completer = Completer<_ReceivedRequest>();
    _waiting.add(completer);
    return completer.future.timeout(const Duration(seconds: 3));
  }

  void reply(_ReceivedRequest request, {Map<String, dynamic>? state}) {
    request.socket.add(
      jsonEncode({
        'id': request.json['id'],
        'type': request.json['action'] == 'ping' ? 'pong' : 'result',
        if (request.json['action'] != 'ping') 'state': state ?? snapshotJson(),
      }),
    );
  }

  Future<void> close() async {
    for (final socket in _sockets) {
      await socket.close();
    }
    await _server.close(force: true);
  }
}
