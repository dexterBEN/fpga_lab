import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpga_register_control/repository/websocket_register_repository.dart';

void main() {
  late HttpServer server;
  late WebSocketRegisterRepository repository;

  const token = 'test-token';

  Future<void> startServer(void Function(WebSocket socket) onConnection) async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      onConnection(socket);
    });

    repository = WebSocketRegisterRepository(
      url: 'ws://127.0.0.1:${server.port}',
      token: token,
    );
  }

  tearDown(() async {
    await repository.dispose();
    await server.close(force: true);
  });

  test('Connects and disconnects successfully', () async {
    await startServer((socket) {});

    expect(repository.isConnected, false);

    await repository.connect();

    expect(repository.isConnected, true);

    await repository.disconnect();

    expect(repository.isConnected, false);
  });

  test('Ping receives pong from server', () async {
    await startServer((socket) {
      socket.listen((message) {
        final request = jsonDecode(message as String);

        socket.add(jsonEncode({'id': request['id'], 'type': 'pong'}));
      });
    });

    await repository.connect();

    final result = await repository.ping();

    expect(result, true);
  });

  test('Ping sends correct JSON and authentication token', () async {
    final received = Completer<Map<String, dynamic>>();

    await startServer((socket) {
      socket.listen((message) {
        final request = jsonDecode(message as String) as Map<String, dynamic>;

        received.complete(request);

        socket.add(jsonEncode({'id': request['id'], 'type': 'pong'}));
      });
    });

    await repository.connect();
    await repository.ping();

    final request = await received.future;

    expect(request['action'], 'ping');
    expect(request['token'], token);
    expect(request['id'], isA<String>());
    expect((request['id'] as String).isNotEmpty, true);
  });

  test('Ping times out if server does not respond', () async {
    await startServer((socket) {
      // Deliberately ignore incoming messages.
      socket.listen((_) {});
    });

    await repository.connect();

    await expectLater(repository.ping(), throwsA(isA<TimeoutException>()));
  });

  test('Detects unexpected WebSocket disconnection', () async {
    final serverSocket = Completer<WebSocket>();

    await startServer((socket) {
      serverSocket.complete(socket);
    });

    await repository.connect();

    expect(repository.isConnected, true);

    final disconnected = repository.connectionChanges.firstWhere(
      (connected) => !connected,
    );

    final socket = await serverSocket.future;
    await socket.close();

    await disconnected.timeout(const Duration(seconds: 3));

    expect(repository.isConnected, false);
  });
}
