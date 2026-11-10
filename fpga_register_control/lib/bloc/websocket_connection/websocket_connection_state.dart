import 'package:equatable/equatable.dart';

enum WebSocketConnectionStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
  failure,
}

final class WebSocketConnectionState extends Equatable {
  const WebSocketConnectionState({
    this.status = WebSocketConnectionStatus.disconnected,
    this.errorMessage,
  });

  final WebSocketConnectionStatus status;
  final String? errorMessage;

  WebSocketConnectionState copyWith({
    WebSocketConnectionStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return WebSocketConnectionState(
      status: status ?? this.status,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
