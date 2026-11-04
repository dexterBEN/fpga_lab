import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../model/circuit_state.dart';
import 'mux_demux_repository.dart';
import 'websocket_message.dart';

class ServerCommandException implements Exception {
  const ServerCommandException(this.message);
  final String message;
  @override
  String toString() => 'ServerCommandException: $message';
}

class _PendingCommand {
  _PendingCommand(this.mode);
  final CircuitMode mode;
  final result = Completer<CircuitState>();
}

/// One permanent socket reader, one command in flight. Physical events never
/// acknowledge a command. Snapshots are reduced from the latest state, in wire
/// order; the current server protocol has no request IDs or revision numbers.
class WebSocketMuxDemuxRepository implements MuxDemuxRepository {
  WebSocketMuxDemuxRepository({
    this.url = 'ws://192.168.200.120:8765',
    this.timeout = const Duration(seconds: 5),
  });

  final String url;
  final Duration timeout;
  final _states = StreamController<CircuitState>.broadcast(sync: true);
  CircuitState _state = CircuitState(dataSource: DataSource.websocket);
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _reader;
  _PendingCommand? _pendingCommand;
  final _beforeReady = <Object?>[];
  bool _ready = false;
  bool _opening = false;
  int _session = 0;
  Future<void> _cleanup = Future.value();
  Future<void>? _disposeFuture;

  @override
  CircuitState get state => _state;
  @override
  Stream<CircuitState> get states => _states.stream;

  CircuitState _publish(CircuitState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
    return next;
  }

  @override
  Future<CircuitState> connect({CircuitMode? mode}) async {
    if (_disposeFuture != null) throw StateError('Repository disposed');
    if (_opening) throw StateError('Connexion WebSocket déjà en cours');
    _opening = true;
    try {
      return await _connect(mode);
    } finally {
      _opening = false;
    }
  }

  Future<CircuitState> _connect(CircuitMode? mode) async {
    final cleanup = disconnect();
    final attempt = _session;
    await cleanup;
    if (_disposeFuture != null || attempt != _session) {
      throw StateError('Connexion WebSocket annulée');
    }
    final session = ++_session;
    _publish(
      _state.copyWith(
        mode: mode,
        connectionState: DeviceConnectionState.connecting,
        clearError: true,
        clearRemoteMuxOutput: true,
      ),
    );
    try {
      final channel = WebSocketChannel.connect(Uri.parse(url));
      _channel = channel;
      _reader = channel.stream.listen(
        (raw) {
          if (session != _session) return;
          if (!_ready) {
            _beforeReady.add(raw);
            return;
          }
          _receive(raw, session);
        },
        onError: (Object error, StackTrace stack) =>
            _endSession(session, DeviceConnectionState.error, error, stack),
        onDone: () => _endSession(
          session,
          DeviceConnectionState.disconnected,
          StateError('Connexion WebSocket fermée par le serveur'),
        ),
      );
      await channel.ready.timeout(timeout);
      if (session != _session) {
        throw StateError(_state.lastError ?? 'Connexion annulée');
      }
      _ready = true;
      _publish(
        _state.copyWith(connectionState: DeviceConnectionState.connected),
      );
      final early = List<Object?>.of(_beforeReady);
      _beforeReady.clear();
      for (final raw in early) {
        _receive(raw, session);
      }
      if (session != _session) {
        throw StateError(_state.lastError ?? 'Connexion annulée');
      }
      return _state;
    } catch (error, stack) {
      _endSession(session, DeviceConnectionState.error, error, stack);
      await _cleanup;
      rethrow;
    }
  }

  void _receive(Object? raw, int session) {
    if (session != _session) return;
    try {
      final message = WebSocketMessage.decode(raw);
      if (message is PhysicalInputsMessage) {
        // Do not invoke command setters here, and preserve the visible tab/MUX.
        _publish(
          _state.copyWith(
            selector: message.selector,
            demuxInput: message.input,
            demuxOutputs: message.outputs,
            dataSource: DataSource.websocket,
            connectionState: DeviceConnectionState.connected,
            clearError: true,
          ),
        );
        return;
      }
      if (message is ServerErrorMessage) {
        final pending = _pendingCommand;
        _pendingCommand = null;
        _publish(
          _state.copyWith(
            lastError: message.message,
            connectionState: DeviceConnectionState.connected,
          ),
        );
        // Server errors acknowledge the sole pending command. Keep transport
        // usable; the next valid message/command clears the error.
        pending?.result.completeError(ServerCommandException(message.message));
        return;
      }
      final pending = _pendingCommand;
      if (pending == null) {
        throw const FormatException('Réponse sans commande en attente');
      }
      CircuitState next;
      if (message is MuxStateMessage && pending.mode == CircuitMode.mux) {
        next = _state.copyWith(
          mode: pending.mode,
          selector: message.selector,
          muxInputs: message.inputs,
          remoteMuxOutput: message.output,
          connectionState: DeviceConnectionState.connected,
          clearError: true,
        );
      } else if (message is DemuxStateMessage &&
          pending.mode == CircuitMode.demux) {
        next = _state.copyWith(
          mode: pending.mode,
          selector: message.selector,
          demuxInput: message.input,
          demuxOutputs: message.outputs,
          connectionState: DeviceConnectionState.connected,
          clearError: true,
        );
      } else {
        throw const FormatException(
          'Réponse incompatible avec la commande en attente',
        );
      }
      _pendingCommand = null;
      _publish(next);
      pending.result.complete(next);
    } catch (error, stack) {
      // Malformed/ambiguous frames invalidate this session, including pending
      // commands. No partially validated state is ever applied.
      _endSession(session, DeviceConnectionState.error, error, stack);
    }
  }

  void _endSession(
    int session,
    DeviceConnectionState status,
    Object error, [
    StackTrace? stack,
  ]) {
    if (session != _session) return;
    ++_session; // Late callbacks from the old channel cannot publish anything.
    _ready = false;
    _beforeReady.clear();
    final channel = _channel;
    final reader = _reader;
    final pending = _pendingCommand;
    _channel = null;
    _reader = null;
    _pendingCommand = null;
    _publish(
      _state.copyWith(connectionState: status, lastError: error.toString()),
    );
    pending?.result.completeError(error, stack);
    _cleanup = Future.wait([
      _cleanup,
      _closeTransport(channel, reader),
    ]).then((_) {});
  }

  Future<void> _closeTransport(
    WebSocketChannel? channel,
    StreamSubscription<dynamic>? reader,
  ) async {
    try {
      await reader?.cancel();
    } catch (_) {
      /* Already failed. */
    }
    try {
      await channel?.sink.close().timeout(timeout);
    } catch (_) {
      /* Already failed. */
    }
  }

  @override
  Future<CircuitState> disconnect() async {
    if (_channel != null || _pendingCommand != null) {
      _endSession(
        _session,
        DeviceConnectionState.disconnected,
        StateError('Connexion WebSocket annulée'),
      );
    } else {
      ++_session; // Also cancel a connect waiting for previous cleanup.
    }
    await _cleanup;
    if (_disposeFuture == null) {
      _publish(
        _state.copyWith(
          connectionState: DeviceConnectionState.disconnected,
          clearError: true,
        ),
      );
    }
    return _state;
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

  Future<CircuitState> _exchange(CircuitState command) async {
    final channel = _channel;
    if (_disposeFuture != null || channel == null || !_ready) {
      throw StateError('WebSocket non connecté');
    }
    if (_pendingCommand != null) {
      throw StateError('Une commande WebSocket est déjà en attente');
    }
    final session = _session;
    final pending = _PendingCommand(command.mode);
    _pendingCommand = pending;
    final result = pending.result.future.timeout(
      timeout,
      onTimeout: () {
        final error = TimeoutException(
          'Délai de réponse WebSocket dépassé',
          timeout,
        );
        _endSession(session, DeviceConnectionState.error, error);
        throw error;
      },
    );
    try {
      final mux = command.mode == CircuitMode.mux;
      channel.sink.add(
        jsonEncode({
          'type': mux ? 'mux' : 'demux',
          'selector': command.selector,
          if (mux) ...{
            for (var i = 0; i < 4; i++) 'd$i': command.muxInputs[i] ? 1 : 0,
          } else
            'd': command.demuxInput ? 1 : 0,
        }),
      );
    } catch (error, stack) {
      _endSession(session, DeviceConnectionState.error, error, stack);
    }
    return result;
  }

  @override
  Future<void> dispose() => _disposeFuture ??= _dispose();
  Future<void> _dispose() async {
    await disconnect();
    await _states.close();
  }
}
