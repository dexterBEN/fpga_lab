import 'package:equatable/equatable.dart';

import '../../models/register_snapshot.dart';

enum RegisterStatus { initial, loading, ready, failure }

final class RegisterState extends Equatable {
  const RegisterState({
    this.status = RegisterStatus.initial,
    this.snapshot,
    this.errorMessage,
  });

  final RegisterStatus status;

  /// Last successful server response, retained during loading and failure.
  final RegisterSnapshot? snapshot;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, snapshot, errorMessage];
}
