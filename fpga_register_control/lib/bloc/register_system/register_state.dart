import 'package:equatable/equatable.dart';

import '../../models/register_snapshot.dart';
import 'register_event.dart';

enum RegisterStatus { initial, loading, ready, failure }

final class RegisterState extends Equatable {
  const RegisterState({
    this.status = RegisterStatus.initial,
    this.snapshot,
    this.errorMessage,
    this.completedOperation,
  });

  final RegisterStatus status;

  /// Last successful server response, retained during loading and failure.
  final RegisterSnapshot? snapshot;
  final String? errorMessage;

  /// The successful request that produced this snapshot. This is command
  /// metadata; presentation code must not infer operations from bit changes.
  final RegisterEvent? completedOperation;

  @override
  List<Object?> get props => [
    status,
    snapshot,
    errorMessage,
    completedOperation,
  ];
}
