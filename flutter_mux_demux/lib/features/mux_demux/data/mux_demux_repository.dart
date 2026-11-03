import '../model/circuit_state.dart';

/// Boundary for a future notebook transport implementation.
abstract interface class MuxDemuxRepository {
  CircuitState get state;
  CircuitState setMode(CircuitMode mode);
  CircuitState setSelector(int selector);
  CircuitState setMuxInput(int index, bool value);
  CircuitState setDemuxInput(bool value);
}

class LocalMuxDemuxRepository implements MuxDemuxRepository {
  CircuitState _state = CircuitState();
  @override
  CircuitState get state => _state;
  @override
  CircuitState setMode(CircuitMode mode) =>
      _state = _state.copyWith(mode: mode);
  @override
  CircuitState setSelector(int selector) {
    RangeError.checkValueInInterval(selector, 0, 3, 'selector');
    return _state = _state.copyWith(selector: selector);
  }

  @override
  CircuitState setMuxInput(int index, bool value) {
    RangeError.checkValidIndex(index, _state.muxInputs);
    final inputs = [..._state.muxInputs]..[index] = value;
    return _state = _state.copyWith(muxInputs: inputs);
  }

  @override
  CircuitState setDemuxInput(bool value) =>
      _state = _state.copyWith(demuxInput: value);
}
