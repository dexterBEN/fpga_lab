import 'dart:async';

import '../model/circuit_state.dart';

/// Repositories own their snapshots and publish every successful change.
/// [states] is synchronous broadcast, without replay; subscribe before reading
/// [state]. Remote runtime failures are snapshots with lastError, never stream
/// errors. Invalid arguments/lifecycle calls can reject only their command future.
/// Command futures acknowledge completion; observers must not publish them again.
/// The owner (MuxDemuxCubit in the app) must call [dispose].
abstract interface class MuxDemuxRepository {
  CircuitState get state;
  Stream<CircuitState> get states;

  Future<CircuitState> setMode(CircuitMode mode);
  Future<CircuitState> setSelector(int selector);
  Future<CircuitState> setMuxInput(int index, bool value);
  Future<CircuitState> setDemuxInput(bool value);

  /// [mode] selects the initial view without sending a hardware command.
  Future<CircuitState> connect({CircuitMode? mode});
  Future<CircuitState> disconnect();
  Future<void> dispose();
}

class LocalMuxDemuxRepository implements MuxDemuxRepository {
  CircuitState _state = CircuitState();
  final _states = StreamController<CircuitState>.broadcast(sync: true);
  Future<void>? _disposeFuture;

  @override
  CircuitState get state => _state;
  @override
  Stream<CircuitState> get states => _states.stream;

  CircuitState _publish(CircuitState next) {
    if (_disposeFuture != null) throw StateError('Repository disposed');
    _state = next;
    _states.add(next);
    return next;
  }

  @override
  Future<CircuitState> connect({CircuitMode? mode}) async =>
      _publish(_state.copyWith(mode: mode));
  @override
  Future<CircuitState> disconnect() async => _state;

  @override
  Future<CircuitState> setMode(CircuitMode mode) async =>
      _publish(_state.copyWith(mode: mode, dataSource: DataSource.local));

  @override
  Future<CircuitState> setSelector(int selector) async {
    RangeError.checkValueInInterval(selector, 0, 3, 'selector');
    return _publish(
      _state.copyWith(
        selector: selector,
        demuxOutputs: _computeDemuxOutputs(_state.demuxInput, selector),
      ),
    );
  }

  @override
  Future<CircuitState> setMuxInput(int index, bool value) async {
    RangeError.checkValidIndex(index, _state.muxInputs);
    final inputs = [..._state.muxInputs]..[index] = value;
    return _publish(_state.copyWith(muxInputs: inputs));
  }

  @override
  Future<CircuitState> setDemuxInput(bool value) async => _publish(
    _state.copyWith(
      demuxInput: value,
      demuxOutputs: _computeDemuxOutputs(value, _state.selector),
    ),
  );

  List<bool> _computeDemuxOutputs(bool input, int selector) =>
      List.generate(4, (index) => index == selector && input);

  @override
  Future<void> dispose() => _disposeFuture ??= _states.close();
}
