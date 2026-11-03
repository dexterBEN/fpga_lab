import '../model/circuit_state.dart';

abstract interface class MuxDemuxRepository {
  CircuitState get state;

  Future<CircuitState> setMode(CircuitMode mode);

  Future<CircuitState> setSelector(int selector);

  Future<CircuitState> setMuxInput(int index, bool value);

  Future<CircuitState> setDemuxInput(bool value);

  Future<CircuitState> connect();

  Future<CircuitState> disconnect();
}

class LocalMuxDemuxRepository implements MuxDemuxRepository {
  CircuitState _state = CircuitState();

  @override
  CircuitState get state => _state;

  @override
  Future<CircuitState> connect() async {
    return _state;
  }

  @override
  Future<CircuitState> disconnect() async {
    return _state;
  }

  @override
  Future<CircuitState> setMode(CircuitMode mode) async {
    return _state = _state.copyWith(mode: mode, dataSource: DataSource.local);
  }

  @override
  Future<CircuitState> setSelector(int selector) async {
    RangeError.checkValueInInterval(selector, 0, 3, 'selector');

    final demuxOutputs = _computeDemuxOutputs(_state.demuxInput, selector);

    return _state = _state.copyWith(
      selector: selector,
      demuxOutputs: demuxOutputs,
    );
  }

  @override
  Future<CircuitState> setMuxInput(int index, bool value) async {
    RangeError.checkValidIndex(index, _state.muxInputs);

    final inputs = [..._state.muxInputs];
    inputs[index] = value;

    return _state = _state.copyWith(muxInputs: inputs);
  }

  @override
  Future<CircuitState> setDemuxInput(bool value) async {
    final demuxOutputs = _computeDemuxOutputs(value, _state.selector);

    return _state = _state.copyWith(
      demuxInput: value,
      demuxOutputs: demuxOutputs,
    );
  }

  List<bool> _computeDemuxOutputs(bool input, int selector) {
    return List.generate(4, (index) => index == selector && input);
  }
}
