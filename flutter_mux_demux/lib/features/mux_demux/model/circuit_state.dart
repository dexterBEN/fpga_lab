enum CircuitMode { mux, demux }

enum DataSource { local, websocket }

enum DeviceConnectionState { disconnected, connecting, connected, error }

class CircuitState {
  CircuitState({
    this.mode = CircuitMode.mux,
    this.selector = 1,
    List<bool> muxInputs = const [false, true, false, true],
    this.demuxInput = true,
    List<bool> demuxOutputs = const [false, true, false, false],
    this.dataSource = DataSource.local,
    this.connectionState = DeviceConnectionState.disconnected,
    this.lastError,
    this.remoteMuxOutput,
  }) : muxInputs = List.unmodifiable(muxInputs),
       demuxOutputs = List.unmodifiable(demuxOutputs);

  final CircuitMode mode;
  final int selector;

  final List<bool> muxInputs;
  final bool demuxInput;
  final List<bool> demuxOutputs;

  final DataSource dataSource;
  final DeviceConnectionState connectionState;
  final String? lastError;
  final bool? remoteMuxOutput;

  bool get muxOutput => dataSource == DataSource.websocket
      ? (remoteMuxOutput ?? muxInputs[selector])
      : muxInputs[selector];

  bool get routedValue =>
      mode == CircuitMode.mux ? muxOutput : demuxOutputs[selector];

  String get binary => selector.toRadixString(2).padLeft(2, '0');

  String get route =>
      mode == CircuitMode.mux ? 'D$selector → Y' : 'D → Y$selector';

  CircuitState copyWith({
    CircuitMode? mode,
    int? selector,
    List<bool>? muxInputs,
    bool? demuxInput,
    List<bool>? demuxOutputs,
    DataSource? dataSource,
    DeviceConnectionState? connectionState,
    String? lastError,
    bool clearError = false,
    bool? remoteMuxOutput,
    bool clearRemoteMuxOutput = false,
  }) => CircuitState(
    mode: mode ?? this.mode,
    selector: selector ?? this.selector,
    muxInputs: muxInputs ?? this.muxInputs,
    demuxInput: demuxInput ?? this.demuxInput,
    demuxOutputs: demuxOutputs ?? this.demuxOutputs,
    dataSource: dataSource ?? this.dataSource,
    connectionState: connectionState ?? this.connectionState,
    lastError: clearError ? null : lastError ?? this.lastError,
    remoteMuxOutput: clearRemoteMuxOutput
        ? null
        : remoteMuxOutput ?? this.remoteMuxOutput,
  );
}
