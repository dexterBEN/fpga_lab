import 'package:equatable/equatable.dart';

sealed class WebSocketConnectionEvent extends Equatable {
  const WebSocketConnectionEvent();

  @override
  List<Object?> get props => [];
}

final class WebSocketConnectRequested extends WebSocketConnectionEvent {
  const WebSocketConnectRequested();
}

final class WebSocketDisconnectRequested extends WebSocketConnectionEvent {
  const WebSocketDisconnectRequested();
}

final class WebSocketConnectionStatusChanged extends WebSocketConnectionEvent {
  const WebSocketConnectionStatusChanged(this.connected);

  final bool connected;

  @override
  List<Object?> get props => [connected];
}
