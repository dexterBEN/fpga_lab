import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/mux_demux_repository.dart';
import '../model/circuit_state.dart';

class MuxDemuxCubit extends Cubit<CircuitState> {
  MuxDemuxCubit(this.localRepository, {this.websocketRepository})
    : _repository = localRepository,
      super(localRepository.state) {
    _listen(localRepository);
  }

  /// This Cubit owns the repositories injected at construction.
  final MuxDemuxRepository localRepository;
  final MuxDemuxRepository? websocketRepository;
  MuxDemuxRepository _repository;
  StreamSubscription<CircuitState>? _subscription;
  int _observation = 0;
  Future<void> _pending = Future.value();
  bool _closing = false;
  Future<void>? _closeFuture;

  void _listen(MuxDemuxRepository repository) {
    final observation = ++_observation;
    _subscription = repository.states.listen((next) {
      if (!_closing && !isClosed && observation == _observation) {
        // Repository stream is the sole authority for command/event updates.
        emit(next);
      }
    });
  }

  Future<void> _activate(
    MuxDemuxRepository repository, {
    bool publishSnapshot = true,
  }) async {
    ++_observation; // Invalidate callbacks before the asynchronous cancellation.
    await _subscription?.cancel();
    _subscription = null;
    if (_closing) return;
    _repository = repository;
    _listen(repository);
    // Streams do not replay. Source switches read the snapshot after subscribing.
    if (publishSnapshot && !identical(state, repository.state)) {
      emit(repository.state);
    }
  }

  // Serialize user actions only; repository stream events bypass this queue.
  Future<void> _enqueue(Future<void> Function() action) {
    if (_closing) return Future.value();
    final result = _pending.then((_) async {
      if (!_closing && !isClosed) await action();
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _update(Future<CircuitState> Function() action) => _enqueue(
    () async {
      try {
        await action(); // The stream already published the new state.
      } catch (_) {
        if (_repository == localRepository) rethrow;
        // The remote repository publishes protocol/server/transport failures.
        // Do not emit a stale snapshot or throw into an unawaited UI callback.
      }
    },
  );

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
    final mode = state.mode;
    await _activate(remote, publishSnapshot: false);
    if (_closing) return;
    try {
      // Select the initial tab without writing old Flutter values to the FPGA.
      // No get_physical_inputs: the current backend's query also writes MMIO.
      await remote.connect(mode: mode);
    } catch (_) {
      // Keep the remote error snapshot visible. The user can return to the
      // preserved local session or explicitly reconnect; no implicit writes.
    }
  });

  Future<void> disconnect() => _enqueue(() async {
    await websocketRepository?.disconnect();
    await _activate(localRepository);
  });

  @override
  Future<void> close() => _closeFuture ??= () async {
    await _release();
    await super.close();
  }();

  Future<void> _release() async {
    _closing = true;
    ++_observation;
    await _subscription?.cancel();
    _subscription = null;
    // Cancel any in-flight remote future before waiting for the action queue.
    await websocketRepository?.disconnect();
    await _pending;
    await websocketRepository?.dispose();
    if (!identical(localRepository, websocketRepository)) {
      await localRepository.dispose();
    }
  }
}
