import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mux_demux/features/mux_demux/bloc/mux_demux_cubit.dart';
import 'package:flutter_mux_demux/features/mux_demux/data/mux_demux_repository.dart';
import 'package:flutter_mux_demux/features/mux_demux/data/websocket_mux_demux_repository.dart';
import 'package:flutter_mux_demux/features/mux_demux/model/circuit_state.dart';

void main() {
  late HttpServer server;
  late WebSocketMuxDemuxRepository remote;
  final sockets = <WebSocket>[];
  var respond = true;
  var overrideMuxOutput = false;

  setUp(() async {
    respond = true;
    overrideMuxOutput = false;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    remote = WebSocketMuxDemuxRepository(
      url: 'ws://127.0.0.1:${server.port}',
      timeout: const Duration(milliseconds: 300),
    );
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((message) {
        if (!respond) return;
        final data = jsonDecode(message as String) as Map<String, dynamic>;
        final selector = data['selector'] as int;
        if (data['type'] == 'mux') {
          socket.add(
            jsonEncode({
              ...data,
              'type': 'mux_state',
              'y': overrideMuxOutput ? 0 : data['d$selector'],
            }),
          );
        } else {
          socket.add(
            jsonEncode({
              ...data,
              'type': 'demux_state',
              'outputs': List.generate(4, (i) => i == selector ? data['d'] : 0),
            }),
          );
        }
      });
    });
  });
  tearDown(() async {
    await remote.disconnect();
    for (final socket in sockets) {
      await socket.close();
    }
    sockets.clear();
    await server.close(force: true);
  });

  test(
    'Cubit connects, routes both modes, serializes changes and returns to simulation',
    () async {
      final cubit = MuxDemuxCubit(
        LocalMuxDemuxRepository(),
        websocketRepository: remote,
      );
      await cubit.connect();
      expect(cubit.state.connectionState, DeviceConnectionState.connected);
      expect(cubit.state.dataSource, DataSource.websocket);
      await Future.wait([
        cubit.setSelector(0),
        cubit.setMuxInput(0, true),
        cubit.setSelector(3),
      ]);
      expect(cubit.state.selector, 3);
      expect(cubit.state.muxInputs[0], true);
      await cubit.setMode(CircuitMode.demux);
      await cubit.setSelector(2);
      expect(cubit.state.demuxOutputs, [false, false, true, false]);
      await cubit.setDemuxInput(false);
      expect(cubit.state.demuxOutputs, [false, false, false, false]);
      await cubit.disconnect();
      expect(cubit.state.dataSource, DataSource.local);
      expect(cubit.state.connectionState, DeviceConnectionState.disconnected);
      await cubit.close();
    },
  );

  test(
    'MUX indicator uses server output instead of a local calculation',
    () async {
      overrideMuxOutput = true;
      await remote.connect();
      final state = await remote.setSelector(1);
      expect(state.muxInputs[1], true);
      expect(state.muxOutput, false);
    },
  );

  test(
    'Failed handshake exposes an error without uncaught socket errors',
    () async {
      final unused = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = unused.port;
      await unused.close(force: true);
      final unavailable = WebSocketMuxDemuxRepository(
        url: 'ws://127.0.0.1:$port',
        timeout: const Duration(milliseconds: 300),
      );
      final cubit = MuxDemuxCubit(
        LocalMuxDemuxRepository(),
        websocketRepository: unavailable,
      );
      await cubit.connect();
      expect(cubit.state.connectionState, DeviceConnectionState.error);
      expect(cubit.state.dataSource, DataSource.local);
      await cubit.close();
    },
  );

  test('No response exposes error and reconnect clears it', () async {
    respond = false;
    final cubit = MuxDemuxCubit(
      LocalMuxDemuxRepository(),
      websocketRepository: remote,
    );
    await cubit.connect();
    expect(cubit.state.connectionState, DeviceConnectionState.error);
    expect(cubit.state.lastError, isNotNull);
    respond = true;
    await cubit.connect();
    expect(cubit.state.connectionState, DeviceConnectionState.connected);
    expect(cubit.state.lastError, isNull);
    await cubit.close();
  });
}
