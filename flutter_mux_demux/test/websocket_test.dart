import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mux_demux/features/mux_demux/bloc/mux_demux_cubit.dart';
import 'package:flutter_mux_demux/features/mux_demux/data/mux_demux_repository.dart';
import 'package:flutter_mux_demux/features/mux_demux/data/websocket_mux_demux_repository.dart';
import 'package:flutter_mux_demux/features/mux_demux/model/circuit_state.dart';
import 'package:flutter_mux_demux/features/mux_demux/view/mux_demux_page.dart';

Map<String, Object> physical(int selector, {int d = 1}) => {
  'type': 'physical_inputs',
  'd': d,
  's0': selector & 1,
  's1': (selector >> 1) & 1,
  'selector': selector,
  'outputs': List.generate(4, (i) => i == selector ? d : 0),
};

class _Server {
  late HttpServer http;
  final sockets = <WebSocket>[];
  final commands = <Map<String, dynamic>>[];
  void Function(WebSocket, Map<String, dynamic>)? onCommand;
  void Function(WebSocket)? onConnect;

  Future<void> start() async {
    http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    http.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      onConnect?.call(socket);
      socket.listen((raw) {
        final data = jsonDecode(raw as String) as Map<String, dynamic>;
        commands.add(data);
        if (onCommand != null) {
          onCommand!(socket, data);
        } else {
          reply(socket, data);
        }
      });
    });
  }

  void reply(WebSocket socket, Map<String, dynamic> data) {
    final selector = data['selector'] as int;
    socket.add(
      jsonEncode({
        ...data,
        'type': data['type'] == 'mux' ? 'mux_state' : 'demux_state',
        if (data['type'] == 'mux')
          'y': data['d$selector']
        else
          'outputs': List.generate(4, (i) => i == selector ? data['d'] : 0),
      }),
    );
  }

  void send(Map<String, Object> data) => sockets.last.add(jsonEncode(data));
  Future<void> close() async {
    for (final socket in sockets) {
      await socket.close();
    }
    await http.close(force: true);
  }
}

void main() {
  late _Server server;
  late WebSocketMuxDemuxRepository remote;
  late LocalMuxDemuxRepository local;
  late MuxDemuxCubit cubit;

  setUp(() async {
    server = _Server();
    await server.start();
    remote = WebSocketMuxDemuxRepository(
      url: 'ws://127.0.0.1:${server.http.port}',
      timeout: const Duration(milliseconds: 600),
    );
    local = LocalMuxDemuxRepository();
    cubit = MuxDemuxCubit(local, websocketRepository: remote);
  });
  tearDown(() async {
    await cubit.close();
    await server.close();
  });

  Future<CircuitState> next(bool Function(CircuitState) predicate) =>
      remote.states.firstWhere(predicate).timeout(const Duration(seconds: 3));

  test('Connect is read-only and retains the selected tab', () async {
    await cubit.setMode(CircuitMode.demux);
    await cubit.setDemuxInput(false);
    await cubit.setSelector(3);
    await cubit.connect();
    expect(server.commands, isEmpty);
    expect(cubit.state.mode, CircuitMode.demux);
    expect(cubit.state.connectionState, DeviceConnectionState.connected);
  });

  test(
    'Physical event at rest publishes exactly once, no echo, no MUX tab change',
    () async {
      await cubit.connect();
      await cubit.setMuxInput(2, true);
      final old = cubit.state;
      server.commands.clear();
      final seen = <CircuitState>[];
      final subscription = cubit.stream.listen(seen.add);
      final event = next((s) => s.selector == 2);
      server.send(physical(2));
      await event;
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.demuxInput, true);
      expect(cubit.state.selector, 2);
      expect(cubit.state.demuxOutputs, [false, false, true, false]);
      expect(cubit.state.dataSource, DataSource.websocket);
      expect(cubit.state.connectionState, DeviceConnectionState.connected);
      expect(cubit.state.mode, CircuitMode.mux);
      expect(cubit.state.muxInputs, old.muxInputs);
      expect(cubit.state.remoteMuxOutput, old.remoteMuxOutput);
      expect(seen, hasLength(1));
      expect(server.commands, isEmpty);
      await subscription.cancel();
    },
  );

  test(
    'Physical event during DEMUX command does not acknowledge it or block reception',
    () async {
      await cubit.connect();
      await cubit.setMode(CircuitMode.demux);
      final request = Completer<Map<String, dynamic>>();
      server.onCommand = (socket, data) {
        request.complete(data);
        server.send(physical(2));
      };
      final event = next((s) => s.selector == 2);
      var finished = false;
      final command = cubit.setSelector(3).then((_) => finished = true);
      await event;
      expect(finished, false);
      expect(cubit.state.demuxOutputs, [false, false, true, false]);
      server.reply(server.sockets.last, await request.future);
      await command;
      expect(cubit.state.selector, 3);
      expect(cubit.state.demuxOutputs, [false, false, false, true]);
      expect(cubit.state.connectionState, DeviceConnectionState.connected);
    },
  );

  test(
    'MUX response reduces current state and preserves interleaved DEMUX measurement',
    () async {
      await cubit.connect();
      server.onCommand = (socket, data) {
        server.send(physical(2, d: 0));
        server.reply(socket, data);
      };
      await cubit.setMuxInput(0, true);
      expect(cubit.state.mode, CircuitMode.mux);
      expect(cubit.state.muxInputs[0], true);
      expect(cubit.state.demuxInput, false);
      expect(cubit.state.demuxOutputs, [false, false, false, false]);
    },
  );

  test(
    'Several physical events arrive in wire order without commands',
    () async {
      await cubit.connect();
      final values = <int>[];
      final subscription = cubit.stream.listen((s) => values.add(s.selector));
      final received = next((s) => s.selector == 3);
      for (var i = 0; i < 4; i++) {
        server.send(physical(i));
      }
      await received;
      await Future<void>.delayed(Duration.zero);
      expect(values, [0, 1, 2, 3]);
      expect(server.commands, isEmpty);
      await subscription.cancel();
    },
  );

  for (final entry in <String, Map<String, Object>>{
    'selector outside range': {...physical(2), 'selector': 7},
    'outputs wrong length': {
      ...physical(2),
      'outputs': [0, 0, 1],
    },
    'invalid s0': {...physical(2), 's0': 2},
    'inconsistent selector': {...physical(2), 'selector': 1},
    'invalid d': {...physical(2), 'd': true},
    'invalid output bit': {
      ...physical(2),
      'outputs': [0, 0, 2, 0],
    },
  }.entries) {
    test('Malformed physical event: ${entry.key} closes cleanly', () async {
      await cubit.connect();
      final previous = cubit.state;
      final failed = next(
        (s) => s.connectionState == DeviceConnectionState.error,
      );
      server.send(entry.value);
      await failed;
      expect(cubit.state.lastError, contains('FormatException'));
      expect(cubit.state.selector, previous.selector);
      expect(cubit.state.demuxOutputs, previous.demuxOutputs);
    });
  }

  test(
    'Malformed event also fails pending command without leaving a future open',
    () async {
      await remote.connect();
      server.onCommand = (_, _) => server.send({...physical(2), 's0': 2});
      await expectLater(remote.setSelector(3), throwsFormatException);
      expect(remote.state.connectionState, DeviceConnectionState.error);
    },
  );

  test(
    'Server error retains message, fails command and keeps socket reusable',
    () async {
      await cubit.connect();
      server.onCommand = (_, _) =>
          server.send({'type': 'error', 'message': 'Hardware failure'});
      await expectLater(
        remote.setSelector(2),
        throwsA(
          isA<ServerCommandException>().having(
            (e) => e.message,
            'message',
            'Hardware failure',
          ),
        ),
      );
      expect(cubit.state.lastError, 'Hardware failure');
      expect(cubit.state.connectionState, DeviceConnectionState.connected);
      server.onCommand = null;
      await cubit.setSelector(3);
      expect(cubit.state.lastError, isNull);
      expect(cubit.state.selector, 3);
    },
  );

  test(
    'Server error at rest is visible without an uncaught stream error',
    () async {
      await cubit.connect();
      final event = next((s) => s.lastError == 'Hardware failure');
      server.send({'type': 'error', 'message': 'Hardware failure'});
      await event;
      expect(cubit.state.lastError, 'Hardware failure');
      expect(cubit.state.connectionState, DeviceConnectionState.connected);
    },
  );

  test('Socket closure at rest reaches Cubit', () async {
    await cubit.connect();
    final closed = next(
      (s) => s.connectionState == DeviceConnectionState.disconnected,
    );
    await server.sockets.last.close();
    await closed;
    expect(cubit.state.connectionState, DeviceConnectionState.disconnected);
  });

  test('Disconnect cancels a pending command', () async {
    await remote.connect();
    final received = Completer<void>();
    server.onCommand = (_, _) => received.complete();
    final command = expectLater(remote.setSelector(2), throwsStateError);
    await received.future;
    await remote.disconnect();
    await command;
    expect(remote.state.connectionState, DeviceConnectionState.disconnected);
  });

  test(
    'Return to simulation ignores later remote snapshots and disposes streams',
    () async {
      await cubit.setSelector(0);
      await cubit.connect();
      final event = next((s) => s.selector == 2);
      server.send(physical(2));
      await event;
      await cubit.disconnect();
      expect(cubit.state.dataSource, DataSource.local);
      expect(cubit.state.selector, 0);
      final localSnapshot = cubit.state;
      // Deliberately reopen the inactive repository and simulate a late remote event.
      await remote.connect();
      final late = next((s) => s.selector == 3);
      server.send(physical(3));
      await late;
      expect(identical(cubit.state, localSnapshot), true);
      final done = Completer<void>();
      remote.states.listen((_) {}, onDone: done.complete);
      await cubit.close();
      await done.future;
    },
  );

  test(
    'Existing commands remain serialized with exactly one state per response',
    () async {
      await cubit.connect();
      final seen = <CircuitState>[];
      final subscription = cubit.stream.listen(seen.add);
      await Future.wait([
        cubit.setSelector(0),
        cubit.setMuxInput(0, true),
        cubit.setSelector(3),
      ]);
      expect(server.commands.map((c) => c['selector']), [0, 0, 3]);
      expect(cubit.state.selector, 3);
      expect(cubit.state.muxInputs[0], true);
      expect(seen, hasLength(3));
      await cubit.setMode(CircuitMode.demux);
      await cubit.setSelector(2);
      expect(cubit.state.demuxOutputs, [false, false, true, false]);
      await cubit.setDemuxInput(false);
      expect(cubit.state.demuxOutputs, [false, false, false, false]);
      await subscription.cancel();
    },
  );

  test(
    'Actual server outputs override local truth table assumptions',
    () async {
      await cubit.connect();
      server.onCommand = (_, data) =>
          server.send({...data, 'type': 'mux_state', 'y': 0});
      await cubit.setSelector(1);
      expect(cubit.state.muxInputs[1], true);
      expect(cubit.state.muxOutput, false);
      server.onCommand = (_, data) => server.send({
        ...data,
        'type': 'demux_state',
        'outputs': [1, 1, 0, 0],
      });
      await cubit.setMode(CircuitMode.demux);
      expect(cubit.state.demuxOutputs, [true, true, false, false]);
    },
  );

  test(
    'Timeout invalidates old session; reconnect never accepts its late reply',
    () async {
      await remote.connect();
      final oldSocket = server.sockets.last;
      server.onCommand = (_, _) {};
      await expectLater(
        remote.setSelector(2),
        throwsA(isA<TimeoutException>()),
      );
      expect(remote.state.connectionState, DeviceConnectionState.error);
      await remote.connect();
      expect(server.sockets.last, isNot(same(oldSocket)));
      final requested = Completer<Map<String, dynamic>>();
      server.onCommand = (_, data) => requested.complete(data);
      var completed = false;
      final command = remote.setSelector(3).then((s) {
        completed = true;
        return s;
      });
      final data = await requested.future;
      // Old transport has been closed/cancelled and cannot deliver into the new reader.
      expect(oldSocket.readyState, isNot(WebSocket.open));
      expect(completed, false);
      server.reply(server.sockets.last, data);
      expect((await command).selector, 3);
    },
  );

  test(
    'Direct concurrent repository commands are rejected, not double-read',
    () async {
      await remote.connect();
      final received = Completer<Map<String, dynamic>>();
      server.onCommand = (_, data) => received.complete(data);
      final first = remote.setSelector(2);
      final data = await received.future;
      await expectLater(remote.setSelector(3), throwsStateError);
      server.reply(server.sockets.last, data);
      expect((await first).selector, 2);
    },
  );

  test(
    'Failed handshake is published and reconnect remains possible',
    () async {
      final unused = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = unused.port;
      await unused.close(force: true);
      final unavailable = WebSocketMuxDemuxRepository(
        url: 'ws://127.0.0.1:$port',
        timeout: const Duration(milliseconds: 600),
      );
      final other = MuxDemuxCubit(
        LocalMuxDemuxRepository(),
        websocketRepository: unavailable,
      );
      await other.connect();
      expect(other.state.connectionState, DeviceConnectionState.error);
      expect(other.state.lastError, isNotNull);
      await other.close();
      await cubit.connect();
      expect(cubit.state.connectionState, DeviceConnectionState.connected);
    },
  );

  test(
    'Closing Cubit cancels an in-flight command and disposes once',
    () async {
      await cubit.connect();
      final received = Completer<void>();
      server.onCommand = (_, _) => received.complete();
      final command = cubit.setSelector(2);
      await received.future;
      await cubit.close();
      await command;
      await cubit.close();
      expect(cubit.isClosed, true);
    },
  );

  test(
    'Initial unsolicited snapshot is observed without a command or tab change',
    () async {
      server.onConnect = (socket) => socket.add(jsonEncode(physical(2)));
      final received = next((s) => s.selector == 2);
      await cubit.connect();
      await received;
      expect(cubit.state.mode, CircuitMode.mux);
      expect(cubit.state.connectionState, DeviceConnectionState.connected);
      expect(server.commands, isEmpty);
    },
  );

  test('Remote close also terminates a pending command', () async {
    await remote.connect();
    server.onCommand = (socket, _) {
      unawaited(socket.close());
    };
    await expectLater(remote.setSelector(2), throwsStateError);
    expect(remote.state.connectionState, DeviceConnectionState.disconnected);
  });

  test(
    'Immediate disposal cancels connect before it can leak a new channel',
    () async {
      final connecting = expectLater(remote.connect(), throwsStateError);
      await remote.dispose();
      await connecting;
      expect(server.sockets, isEmpty);
    },
  );

  testWidgets(
    'Physical event refreshes D, selector, destination and measured outputs in UI',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(() => cubit.setMode(CircuitMode.demux));
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: const MaterialApp(home: MuxDemuxPage()),
        ),
      );
      await tester.runAsync(() => cubit.connect());
      await tester.pump();
      await tester.runAsync(() async {
        final updated = next((s) => s.selector == 2);
        server.send(physical(2));
        await updated;
      });
      await tester.pump();
      expect(find.text('D  1'), findsOneWidget);
      expect(find.text('S1  1'), findsOneWidget);
      expect(find.text('S0  0'), findsOneWidget);
      expect(find.text('D → Y2'), findsWidgets);
      expect(find.text('0  0  1  0'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '10'))
            .selected,
        true,
      );
      expect(find.text('Serveur : Connecté'), findsOneWidget);
      expect(server.commands, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => cubit.close());
    },
  );
}
