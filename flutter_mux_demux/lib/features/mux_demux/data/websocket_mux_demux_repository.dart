import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../model/circuit_state.dart';
import 'mux_demux_repository.dart';

/// JSON protocol implemented by notebooks/mux_demux_bridge.ipynb.
class WebSocketMuxDemuxRepository implements MuxDemuxRepository {
  WebSocketMuxDemuxRepository({
    this.url = 'ws://127.0.0.1:8765',
    this.timeout = const Duration(seconds: 5),
  });

  final String url;
  final Duration timeout;
  WebSocketChannel? _channel;
  StreamIterator<dynamic>? _messages;
  CircuitState _state = CircuitState(dataSource: DataSource.websocket);
  @override
  CircuitState get state => _state;

  @override
  Future<CircuitState> connect() async {
    await disconnect();
    _state = _state.copyWith(
      connectionState: DeviceConnectionState.connecting,
      clearError: true,
    );
    final channel = WebSocketChannel.connect(Uri.parse(url));
    _channel = channel;
    // Subscribe immediately so connection errors are consumed even during ready.
    _messages = StreamIterator(channel.stream);
    try {
      await channel.ready.timeout(timeout);
      return _state = _state.copyWith(
        connectionState: DeviceConnectionState.connected,
      );
    } catch (_) {
      await disconnect();
      rethrow;
    }
  }

  @override
  Future<CircuitState> disconnect() async {
    final messages = _messages;
    final channel = _channel;
    _messages = null;
    _channel = null;
    await messages?.cancel();
    // A failed handshake must not prevent returning to simulation.
    if (channel != null) {
      try {
        await channel.sink.close().timeout(timeout);
      } catch (_) {
        /* Socket already failed or did not finish closing. */
      }
    }
    return _state = _state.copyWith(
      connectionState: DeviceConnectionState.disconnected,
      clearError: true,
    );
  }

  @override
  Future<CircuitState> setMode(CircuitMode mode) =>
      _exchange(_state.copyWith(mode: mode));
  @override
  Future<CircuitState> setSelector(int selector) {
    RangeError.checkValueInInterval(selector, 0, 3, 'selector');
    return _exchange(_state.copyWith(selector: selector));
  }

  @override
  Future<CircuitState> setMuxInput(int index, bool value) {
    RangeError.checkValidIndex(index, _state.muxInputs);
    final inputs = [..._state.muxInputs]..[index] = value;
    return _exchange(_state.copyWith(muxInputs: inputs));
  }

  @override
  Future<CircuitState> setDemuxInput(bool value) =>
      _exchange(_state.copyWith(demuxInput: value));

  Future<CircuitState> _exchange(CircuitState next) async {
    final channel = _channel;
    final messages = _messages;
    if (channel == null || messages == null) {
      throw StateError('WebSocket non connecté');
    }
    final mux = next.mode == CircuitMode.mux;
    channel.sink.add(
      jsonEncode({
        'type': mux ? 'mux' : 'demux',
        'selector': next.selector,
        if (mux) ...{
          for (var i = 0; i < 4; i++) 'd$i': next.muxInputs[i] ? 1 : 0,
        } else
          'd': next.demuxInput ? 1 : 0,
      }),
    );
    try {
      if (!await messages.moveNext().timeout(timeout)) {
        throw StateError('Connexion fermée avant la réponse');
      }
      final raw = messages.current;
      if (raw is! String) throw const FormatException('Réponse texte attendue');
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic> ||
          data['type'] != (mux ? 'mux_state' : 'demux_state')) {
        throw const FormatException('Réponse du serveur inattendue');
      }
      final selector = data['selector'];
      if (selector is! int || selector < 0 || selector > 3) {
        throw const FormatException('Sélecteur invalide');
      }
      bool bit(dynamic value) {
        if (value != 0 && value != 1) {
          throw const FormatException('Bit invalide');
        }
        return value == 1;
      }

      if (mux) {
        _state = next.copyWith(
          selector: selector,
          muxInputs: List.generate(4, (i) => bit(data['d$i'])),
          remoteMuxOutput: bit(data['y']),
          clearError: true,
          connectionState: DeviceConnectionState.connected,
        );
      } else {
        final outputs = data['outputs'];
        if (outputs is! List || outputs.length != 4) {
          throw const FormatException('Quatre sorties attendues');
        }
        _state = next.copyWith(
          selector: selector,
          demuxInput: bit(data['d']),
          demuxOutputs: outputs.map(bit).toList(),
          clearError: true,
          connectionState: DeviceConnectionState.connected,
        );
      }
      return _state;
    } catch (_) {
      // Discard the socket after any protocol error or timeout; a late reply
      // must never be treated as the answer to the next command.
      await disconnect();
      rethrow;
    }
  }
}
