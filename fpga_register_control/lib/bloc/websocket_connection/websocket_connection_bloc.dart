import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../repository/register_repository.dart';
import 'websocket_connection_event.dart';
import 'websocket_connection_state.dart';

class WebSocketConnectionBloc
    extends Bloc<WebSocketConnectionEvent, WebSocketConnectionState> {
  WebSocketConnectionBloc(this._repository)
    : super(const WebSocketConnectionState()) {
    on<WebSocketConnectRequested>(_onWebSocketConnectRequested);
    on<WebSocketDisconnectRequested>(_onWebSocketDisconnectRequested);
    on<WebSocketConnectionStatusChanged>(_onWebSocketConnectionStatusChanged);

    _subscription = _repository.connectionChanges.listen((connected) {
      if (!isClosed) {
        add(WebSocketConnectionStatusChanged(connected));
      }
    });
  }

  final RegisterRepository _repository;
  StreamSubscription<bool>? _subscription;

  Future<void> _onWebSocketConnectRequested(
    WebSocketConnectRequested event,
    Emitter<WebSocketConnectionState> emit,
  ) async {
    if (state.status == WebSocketConnectionStatus.connected ||
        state.status == WebSocketConnectionStatus.connecting) {
      return;
    }

    emit(
      state.copyWith(
        status: WebSocketConnectionStatus.connecting,
        clearError: true,
      ),
    );

    try {
      await _repository.connect();

      // Verify that the Python server responds.
      final pong = await _repository.ping();

      if (!pong) {
        throw StateError('Ping verification failed');
      }

      emit(state.copyWith(status: WebSocketConnectionStatus.connected));
    } catch (error) {
      await _repository.disconnect();

      emit(
        state.copyWith(
          status: WebSocketConnectionStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _onWebSocketDisconnectRequested(
    WebSocketDisconnectRequested event,
    Emitter<WebSocketConnectionState> emit,
  ) async {
    emit(state.copyWith(status: WebSocketConnectionStatus.disconnecting));

    try {
      await _repository.disconnect();
      emit(
        state.copyWith(
          status: WebSocketConnectionStatus.disconnected,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: WebSocketConnectionStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  void _onWebSocketConnectionStatusChanged(
    WebSocketConnectionStatusChanged event,
    Emitter<WebSocketConnectionState> emit,
  ) {
    if (!event.connected) {
      if (state.status == WebSocketConnectionStatus.failure ||
          state.status == WebSocketConnectionStatus.disconnecting) {
        return;
      }

      emit(state.copyWith(status: WebSocketConnectionStatus.disconnected));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
