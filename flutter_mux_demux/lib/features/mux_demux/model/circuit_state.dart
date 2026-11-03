enum CircuitMode { mux, demux }

class CircuitState {
  CircuitState({
    this.mode = CircuitMode.mux,
    this.selector = 1,
    List<bool> muxInputs = const [false, true, false, true],
    this.demuxInput = true,
  }) : muxInputs = List.unmodifiable(muxInputs);
  final CircuitMode mode;
  final int selector;
  final List<bool> muxInputs;
  final bool demuxInput;
  bool get muxOutput => muxInputs[selector];
  List<bool> get demuxOutputs =>
      List.generate(4, (i) => i == selector && demuxInput);
  bool get routedValue => mode == CircuitMode.mux ? muxOutput : demuxInput;
  String get binary => selector.toRadixString(2).padLeft(2, '0');
  String get route =>
      mode == CircuitMode.mux ? 'D$selector → Y' : 'D → Y$selector';
  CircuitState copyWith({
    CircuitMode? mode,
    int? selector,
    List<bool>? muxInputs,
    bool? demuxInput,
  }) => CircuitState(
    mode: mode ?? this.mode,
    selector: selector ?? this.selector,
    muxInputs: muxInputs ?? this.muxInputs,
    demuxInput: demuxInput ?? this.demuxInput,
  );
}
