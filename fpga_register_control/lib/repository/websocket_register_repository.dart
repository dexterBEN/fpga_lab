import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/json_fields.dart';
import '../models/register_mode.dart';
import '../models/register_snapshot.dart';
import 'register_repository.dart';
import 'register_server_exception.dart';

class WebSocketRegisterRepository implements RegisterRepository {
  WebSocketRegisterRepository({
    required this.url,
    required this.token,
    this.requestTimeout = const Duration(seconds: 5),
    this.connectionTimeout = const Duration(seconds: 5),
  }) {
    if (requestTimeout <= Duration.zero) {
      throw ArgumentError.value(
        requestTimeout,
        'requestTimeout',
        'Must be positive',
      );
    }
    if (connectionTimeout <= Duration.zero) {
      throw ArgumentError.value(
        connectionTimeout,
        'connectionTimeout',
        'Must be positive',
      );
    }
  }

  final String url;
  final String token;
  final Duration requestTimeout;
  final Duration connectionTimeout;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Completer<void>? _connectionEnded;
  Future<void>? _connecting;
  Future<void>? _disconnecting;
  Future<void>? _disposing;
  final _connectionController = StreamController<bool>.broadcast();
  final _pendingRequests = <String, _PendingRequest>{};
  final _hardwareQueue = Queue<_HardwareOperation>();
  bool _connected = false;
  bool _disposed = false;
  bool _hardwareBusy = false;
  int _requestCounter = 0;
  int _generation = 0;

  @override
  bool get isConnected => _connected;

  @override
  Stream<bool> get connectionChanges => _connectionController.stream;

  void _setConnected(bool connected) {
    if (_connected == connected) return;
    _connected = connected;
    if (!_connectionController.isClosed) {
      _connectionController.add(connected);
    }
  }

  @override
  Future<void> connect() {
    if (_disposed) return Future.error(StateError('Repository is disposed'));
    if (_connected) return Future.value();
    final existing = _connecting;
    if (existing != null) return existing;

    late final Future<void> attempt;
    attempt = _openConnection(_generation).whenComplete(() {
      if (identical(_connecting, attempt)) _connecting = null;
    });
    _connecting = attempt;
    return attempt;
  }

  Future<void> _openConnection(int generation) async {
    await _disconnecting;
    if (_disposed || generation != _generation) {
      throw StateError('Connection attempt cancelled');
    }
    final channel = WebSocketChannel.connect(Uri.parse(url));
    final ended = Completer<void>();
    _channel = channel;
    _connectionEnded = ended;
    // This is the only subscription; every reply is dispatched by its ID.
    _subscription = channel.stream.listen(
      (message) {
        if (identical(_channel, channel)) _handleMessage(message);
      },
      onError: (Object error) => _abortConnection(channel, error),
      onDone: () =>
          _abortConnection(channel, StateError('WebSocket connection closed')),
    );

    try {
      await Future.any<void>([
        channel.ready,
        ended.future.then<void>(
          (_) => throw StateError('Connection attempt cancelled'),
        ),
      ]).timeout(connectionTimeout);
      if (_disposed || !identical(_channel, channel)) {
        throw StateError('Connection attempt cancelled');
      }
      _setConnected(true);
    } catch (_) {
      if (identical(_channel, channel)) await disconnect();
      rethrow;
    }
  }

  void _abortConnection(WebSocketChannel channel, Object error) {
    if (!identical(_channel, channel)) return;
    // Pending requests receive the original error. Cleanup runs independently
    // of the stream callback, including when the transport itself has failed.
    unawaited(_disconnectWithError(error).catchError((Object _) {}));
  }

  void _handleMessage(dynamic message) {
    try {
      if (message is! String) {
        throw const FormatException('Expected a JSON text response');
      }
      final decoded = jsonObject(jsonDecode(message), 'response');
      final type = decoded['type'];
      // Broadcasts never resolve a request, even if they include an ID.
      if (type == 'hello' || type == 'state_changed') return;

      final id = decoded['id'];
      if (id == null) {
        if (type == 'error') {
          throw RegisterServerException(
            jsonString(decoded['message'], 'message'),
          );
        }
        if (type == 'result' || type == 'pong') {
          throw const FormatException('Response is missing its request ID');
        }
        return;
      }
      if (id is! String) {
        throw const FormatException('Response ID must be a string');
      }
      final pending = _pendingRequests.remove(id);
      if (pending == null) return; // Unknown, duplicate or late reply.
      pending.timer?.cancel();
      if (type == 'error') {
        final message = decoded['message'];
        pending.completer.completeError(
          message is String && message.trim().isNotEmpty
              ? RegisterServerException(message, requestId: id)
              : const FormatException('Server error is missing its message'),
        );
      } else if (type == pending.expectedType) {
        pending.completer.complete(decoded);
      } else {
        pending.completer.completeError(
          FormatException('Expected ${pending.expectedType} for request $id'),
        );
      }
    } catch (error) {
      final channel = _channel;
      if (channel != null) _abortConnection(channel, error);
    }
  }

  WebSocketChannel _requireConnection() {
    if (_disposed) throw StateError('Repository is disposed');
    final channel = _channel;
    if (!_connected || channel == null) {
      throw StateError('WebSocket is not connected');
    }
    return channel;
  }

  Future<Map<String, dynamic>> _sendRequest(
    String action, {
    String expectedType = 'result',
    Map<String, dynamic> parameters = const {},
  }) async {
    final channel = _requireConnection();
    final id = 'flutter-${++_requestCounter}';
    final pending = _PendingRequest(expectedType);
    _pendingRequests[id] = pending;
    pending.timer = Timer(requestTimeout, () {
      if (_pendingRequests.remove(id) == null) return;
      pending.completer.completeError(
        TimeoutException('Request $id ($action) timed out', requestTimeout),
      );
    });
    try {
      channel.sink.add(
        jsonEncode({'id': id, 'token': token, 'action': action, ...parameters}),
      );
    } catch (error) {
      _abortConnection(channel, error);
    }
    return await pending.completer.future;
  }

  @override
  Future<bool> ping() async {
    await _sendRequest('ping', expectedType: 'pong');
    return true;
  }

  @override
  Future<RegisterSnapshot> getState() => _enqueueHardware('get_state');

  @override
  Future<RegisterSnapshot> loadParallel(int value) async {
    RangeError.checkValueInInterval(value, 0, 15, 'value');
    return await _enqueueHardware('load_parallel', {'value': value});
  }

  @override
  Future<RegisterSnapshot> shiftBit(int bit) async {
    RangeError.checkValueInInterval(bit, 0, 1, 'bit');
    return await _enqueueHardware('shift', {'bit': bit});
  }

  @override
  Future<RegisterSnapshot> selectMode(RegisterMode mode) =>
      _enqueueHardware('select_mode', {'mode': mode.toJson()});

  Future<RegisterSnapshot> _enqueueHardware(
    String action, [
    Map<String, dynamic> parameters = const {},
  ]) async {
    final operation = _HardwareOperation(
      action,
      parameters,
      _requireConnection(),
    );
    _hardwareQueue.add(operation);
    unawaited(_drainHardwareQueue());
    return await operation.completer.future;
  }

  Future<void> _drainHardwareQueue() async {
    if (_hardwareBusy) return;
    _hardwareBusy = true;
    try {
      while (_hardwareQueue.isNotEmpty) {
        final operation = _hardwareQueue.removeFirst();
        try {
          if (!identical(_channel, operation.channel)) {
            throw StateError(
              'Connection changed before hardware command was sent',
            );
          }
          final response = await _sendRequest(
            operation.action,
            parameters: operation.parameters,
          );
          operation.completer.complete(
            RegisterSnapshot.fromJson(jsonObject(response['state'], 'state')),
          );
        } catch (error, stack) {
          operation.completer.completeError(error, stack);
          if (error is TimeoutException &&
              identical(_channel, operation.channel)) {
            // A timeout does not cancel server-side MMIO. Discard unsent work
            // and require reconnection instead of continuing an uncertain sequence.
            await _disconnectWithError(
              StateError(
                'Hardware request timed out; reconnect before issuing more commands',
              ),
            ).catchError((Object _) {});
          }
        }
      }
    } finally {
      _hardwareBusy = false;
    }
  }

  @override
  Future<void> disconnect() => _disconnectWithError(StateError('Disconnected'));

  Future<void> _disconnectWithError(Object error) {
    _generation++;
    _connecting = null;
    final closing = _disconnecting;
    if (closing != null) return closing;
    final subscription = _subscription;
    final channel = _channel;
    final ended = _connectionEnded;
    _subscription = null;
    _channel = null;
    _connectionEnded = null;
    _setConnected(false);
    ended?.complete();
    for (final pending in _pendingRequests.values) {
      pending.timer?.cancel();
      pending.completer.completeError(error);
    }
    _pendingRequests.clear();
    while (_hardwareQueue.isNotEmpty) {
      _hardwareQueue.removeFirst().completer.completeError(error);
    }
    late final Future<void> cleanup;
    cleanup = _closeTransport(subscription, channel).whenComplete(() {
      if (identical(_disconnecting, cleanup)) _disconnecting = null;
    });
    _disconnecting = cleanup;
    return cleanup;
  }

  Future<void> _closeTransport(
    StreamSubscription<dynamic>? subscription,
    WebSocketChannel? channel,
  ) async {
    try {
      await subscription?.cancel();
    } finally {
      await channel?.sink.close();
    }
  }

  @override
  Future<void> dispose() {
    _disposed = true;
    return _disposing ??= _dispose();
  }

  Future<void> _dispose() async {
    try {
      await disconnect();
    } finally {
      await _connectionController.close();
    }
  }
}

class _PendingRequest {
  _PendingRequest(this.expectedType);
  final String expectedType;
  final completer = Completer<Map<String, dynamic>>();
  Timer? timer;
}

class _HardwareOperation {
  _HardwareOperation(this.action, this.parameters, this.channel);
  final String action;
  final Map<String, dynamic> parameters;
  final WebSocketChannel channel;
  final completer = Completer<RegisterSnapshot>();
}
