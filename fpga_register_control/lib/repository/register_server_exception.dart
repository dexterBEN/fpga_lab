/// A correlated error returned by the Python server, not a hardware snapshot.
final class RegisterServerException implements Exception {
  const RegisterServerException(this.message, {this.requestId});

  final String message;
  final String? requestId;

  @override
  String toString() => 'RegisterServerException: $message';
}
