import 'package:flutter_bloc/flutter_bloc.dart';

import '../../repository/register_repository.dart';
import 'register_event.dart';
import 'register_state.dart';

/// Controls both registers through the repository shared with
/// WebSocketConnectionBloc. Connection management belongs to that BLoC;
/// this BLoC neither opens nor disposes the shared repository.
class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  RegisterBloc(this._repository) : super(const RegisterState()) {
    // One handler gives all event types a common queue. asyncExpand waits for
    // each handler to finish before starting the next, without dropping events.
    on<RegisterEvent>(
      _onRegisterEvent,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
  }

  final RegisterRepository _repository;

  Future<void> _onRegisterEvent(
    RegisterEvent event,
    Emitter<RegisterState> emit,
  ) async {
    final previousSnapshot = state.snapshot;
    emit(
      RegisterState(status: RegisterStatus.loading, snapshot: previousSnapshot),
    );

    try {
      // Check when executing, since a queued command may outlive its connection.
      if (!_repository.isConnected) {
        throw StateError(
          'WebSocket is not connected. Reconnect before issuing register commands.',
        );
      }
      final snapshot = await switch (event) {
        RegisterStateRequested() => _repository.getState(),
        ParallelLoadRequested(:final value) => _repository.loadParallel(value),
        ShiftRequested(:final bit) => _repository.shiftBit(bit),
        RegisterModeChanged(:final mode) => _repository.selectMode(mode),
      };
      emit(
        RegisterState(
          status: RegisterStatus.ready,
          snapshot: snapshot,
          completedOperation: event,
        ),
      );
    } catch (error) {
      emit(
        RegisterState(
          status: RegisterStatus.failure,
          snapshot: previousSnapshot,
          errorMessage: error.toString(),
        ),
      );
    }
  }
}
