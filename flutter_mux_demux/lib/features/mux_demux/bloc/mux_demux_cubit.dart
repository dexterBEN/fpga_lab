import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/mux_demux_repository.dart';
import '../model/circuit_state.dart';

class MuxDemuxCubit extends Cubit<CircuitState> {
  MuxDemuxCubit(this.localRepository, {this.websocketRepository})
    : _repository = localRepository,
      super(localRepository.state);

  final MuxDemuxRepository localRepository;
  final MuxDemuxRepository? websocketRepository;
  MuxDemuxRepository _repository;
  Future<void> _pending = Future.value();

  // Keep request/response pairs ordered, including rapid control changes.
  Future<void> _enqueue(Future<void> Function() action) {
    final result = _pending.then((_) async {
      if (!isClosed) await action();
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _update(Future<CircuitState> Function() action) =>
      _enqueue(() async {
        try {
          emit(await action());
        } catch (error) {
          if (_repository == localRepository) rethrow;
          emit(
            state.copyWith(
              connectionState: DeviceConnectionState.error,
              lastError: error.toString(),
            ),
          );
        }
      });

  Future<void> setMode(CircuitMode mode) =>
      _update(() => _repository.setMode(mode));
  Future<void> setSelector(int value) =>
      _update(() => _repository.setSelector(value));
  Future<void> setMuxInput(int index, bool value) =>
      _update(() => _repository.setMuxInput(index, value));
  Future<void> setDemuxInput(bool value) =>
      _update(() => _repository.setDemuxInput(value));

  Future<void> connect() => _enqueue(() async {
    final remote = websocketRepository;
    if (remote == null) return;
    emit(
      state.copyWith(
        connectionState: DeviceConnectionState.connecting,
        clearError: true,
      ),
    );
    try {
      await remote.connect();
      // Synchronize the visible values and read an actual server response.
      await remote.setMode(state.mode);
      if (state.mode == CircuitMode.mux) {
        for (var i = 0; i < 4; i++) {
          await remote.setMuxInput(i, state.muxInputs[i]);
        }
      } else {
        await remote.setDemuxInput(state.demuxInput);
      }
      final synced = await remote.setSelector(state.selector);
      _repository = remote;
      emit(synced);
    } catch (error) {
      await remote.disconnect();
      _repository = localRepository;
      emit(
        localRepository.state.copyWith(
          connectionState: DeviceConnectionState.error,
          lastError: error.toString(),
        ),
      );
    }
  });

  Future<void> disconnect() => _enqueue(() async {
    await websocketRepository?.disconnect();
    _repository = localRepository;
    emit(localRepository.state.copyWith(clearError: true));
  });

  @override
  Future<void> close() async {
    await _pending;
    await websocketRepository?.disconnect();
    return super.close();
  }
}
