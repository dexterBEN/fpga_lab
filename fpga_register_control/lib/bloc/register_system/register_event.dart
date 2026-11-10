import 'package:equatable/equatable.dart';

import '../../models/register_mode.dart';

sealed class RegisterEvent extends Equatable {
  const RegisterEvent();

  @override
  List<Object?> get props => [];
}

final class RegisterStateRequested extends RegisterEvent {
  const RegisterStateRequested();
}

final class ParallelLoadRequested extends RegisterEvent {
  const ParallelLoadRequested(this.value);

  final int value;

  @override
  List<Object?> get props => [value];
}

final class ShiftRequested extends RegisterEvent {
  const ShiftRequested(this.bit);

  final int bit;

  @override
  List<Object?> get props => [bit];
}

final class RegisterModeChanged extends RegisterEvent {
  const RegisterModeChanged(this.mode);

  final RegisterMode mode;

  @override
  List<Object?> get props => [mode];
}
