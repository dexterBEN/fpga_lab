import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/register_system/register_bloc.dart';
import '../../bloc/register_system/register_event.dart';
import '../../bloc/register_system/register_state.dart';
import '../../bloc/websocket_connection/websocket_connection_bloc.dart';
import '../../bloc/websocket_connection/websocket_connection_state.dart';
import '../../models/register_mode.dart';
import '../../models/register_snapshot.dart';
import 'connection_view.dart';
import '../widgets/circuit_primitives.dart';
import '../widgets/confirmed_parallel_load.dart';
import '../widgets/confirmed_shift_transition.dart';
import '../widgets/parallel_register_widget.dart';
import '../widgets/shift_register_widget.dart';

class RegisterSystemView extends StatefulWidget {
  const RegisterSystemView({super.key});

  static const shiftAnimationDuration = Duration(milliseconds: 900);
  static const parallelAnimationDuration = Duration(milliseconds: 700);

  @override
  State<RegisterSystemView> createState() => _RegisterSystemViewState();
}

class _RegisterSystemViewState extends State<RegisterSystemView>
    with TickerProviderStateMixin {
  int _parallelInput = 0;
  int _serialInput = 0;
  bool _awaitingFreshSnapshot = true;
  late final AnimationController _shiftAnimation;
  final _confirmedShifts = Queue<ConfirmedShiftTransition>();
  ConfirmedShiftTransition? _activeShift;
  late final AnimationController _parallelAnimation;
  final _confirmedLoads = Queue<ConfirmedParallelLoad>();
  ConfirmedParallelLoad? _activeLoad;
  RegisterSnapshot? _beforeOperation;
  int _connectionGeneration = 0;
  int? _operationConnectionGeneration;
  bool _operationStartedFresh = false;

  @override
  void initState() {
    super.initState();
    _shiftAnimation = AnimationController(
      vsync: this,
      duration: RegisterSystemView.shiftAnimationDuration,
    )..addStatusListener(_onShiftAnimationStatus);
    _parallelAnimation = AnimationController(
      vsync: this,
      duration: RegisterSystemView.parallelAnimationDuration,
    )..addStatusListener(_onParallelAnimationStatus);
    // Also refresh if the view is mounted into an already connected session.
    if (context.read<WebSocketConnectionBloc>().state.status ==
        WebSocketConnectionStatus.connected) {
      _requestState();
    }
  }

  void _requestState() =>
      context.read<RegisterBloc>().add(const RegisterStateRequested());

  void _clearShiftReplays() {
    _shiftAnimation.stop();
    _shiftAnimation.reset();
    _confirmedShifts.clear();
    _activeShift = null;
  }

  void _startNextShiftReplay() {
    _activeShift = _confirmedShifts.removeFirst();
    _shiftAnimation.forward(from: 0);
  }

  void _clearParallelReplays() {
    _parallelAnimation.stop();
    _parallelAnimation.reset();
    _confirmedLoads.clear();
    _activeLoad = null;
  }

  void _clearReplays() {
    _clearShiftReplays();
    _clearParallelReplays();
  }

  void _startNextParallelReplay() {
    _activeLoad = _confirmedLoads.removeFirst();
    _parallelAnimation.forward(from: 0);
  }

  void _onParallelAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() {
      _activeLoad = null;
      if (_confirmedLoads.isNotEmpty) _startNextParallelReplay();
    });
  }

  void _onShiftAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() {
      _activeShift = null;
      if (_confirmedShifts.isNotEmpty) _startNextShiftReplay();
    });
  }

  void _onRegisterState(RegisterState state) {
    final connected =
        context.read<WebSocketConnectionBloc>().state.status ==
        WebSocketConnectionStatus.connected;
    if (state.status == RegisterStatus.loading) {
      // Capture the last server sample before this operation, even if an older
      // confirmation is still being replayed. Never use the drawn intermediate frame.
      _beforeOperation = state.snapshot;
      _operationConnectionGeneration = connected ? _connectionGeneration : null;
      _operationStartedFresh = !_awaitingFreshSnapshot;
      return;
    }
    if (state.status != RegisterStatus.ready &&
        state.status != RegisterStatus.failure) {
      return;
    }
    final before = _beforeOperation;
    final sameConnection =
        connected && _operationConnectionGeneration == _connectionGeneration;
    final wasFresh = _operationStartedFresh;
    _beforeOperation = null;
    _operationConnectionGeneration = null;
    _operationStartedFresh = false;
    final operation = state.completedOperation;
    final snapshot = state.snapshot;
    setState(() {
      if (state.status == RegisterStatus.failure || !sameConnection) {
        _clearReplays();
        return;
      }
      _awaitingFreshSnapshot = false;
      final animationsEnabled =
          !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
      if (operation is ParallelLoadRequested &&
          snapshot != null &&
          animationsEnabled) {
        _clearShiftReplays();
        _confirmedLoads.add(
          ConfirmedParallelLoad(
            before: before?.parallel,
            after: snapshot.parallel,
            inputValue: operation.value,
          ),
        );
        if (_activeLoad == null) _startNextParallelReplay();
        return;
      }
      _clearParallelReplays();
      if (operation is ShiftRequested &&
          before != null &&
          snapshot != null &&
          wasFresh &&
          animationsEnabled) {
        _confirmedShifts.add(
          ConfirmedShiftTransition(
            before: before.shift,
            after: snapshot.shift,
            serialInput: operation.bit,
          ),
        );
        if (_activeShift == null) _startNextShiftReplay();
      } else {
        // Refresh, LOAD and mode replies must never masquerade as SHIFT.
        _clearShiftReplays();
      }
    });
  }

  @override
  void dispose() {
    _shiftAnimation.dispose();
    _parallelAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<WebSocketConnectionBloc, WebSocketConnectionState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            setState(() {
              _connectionGeneration++;
              _operationConnectionGeneration = null;
              _beforeOperation = null;
              _operationStartedFresh = false;
              _awaitingFreshSnapshot = true;
              _clearReplays();
            });
            if (state.status == WebSocketConnectionStatus.connected) {
              _requestState();
            }
          },
        ),
        BlocListener<RegisterBloc, RegisterState>(
          listener: (context, state) => _onRegisterState(state),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(title: const Text('FPGA Register Control')),
        body: BlocBuilder<WebSocketConnectionBloc, WebSocketConnectionState>(
          builder: (context, connectionState) {
            return BlocBuilder<RegisterBloc, RegisterState>(
              builder: (context, state) {
                final connected =
                    connectionState.status ==
                    WebSocketConnectionStatus.connected;
                final loading = state.status == RegisterStatus.loading;
                final enabled =
                    connected &&
                    !loading &&
                    _activeShift == null &&
                    _activeLoad == null;
                final snapshot = state.snapshot;
                final stale =
                    snapshot != null && (!connected || _awaitingFreshSnapshot);

                return SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1440),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const ConnectionView(),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Hardware registers',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                OutlinedButton.icon(
                                  key: const Key('refresh_registers'),
                                  onPressed: enabled ? _requestState : null,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Refresh'),
                                ),
                              ],
                            ),
                            if (loading) ...[
                              const SizedBox(height: 12),
                              const LinearProgressIndicator(
                                key: Key('register_loading'),
                              ),
                              const SizedBox(height: 8),
                              const Text('Waiting for hardware confirmation…'),
                            ],
                            if (state.errorMessage != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                state.errorMessage!,
                                key: const Key('register_error'),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                              if (snapshot != null)
                                const Text(
                                  'Showing the last confirmed snapshot.',
                                ),
                            ],
                            if (snapshot == null) ...[
                              const SizedBox(height: 12),
                              const Text('No hardware snapshot received.'),
                            ],
                            if (stale) ...[
                              const SizedBox(height: 12),
                              Text(
                                connected
                                    ? 'Stale snapshot — waiting for a fresh hardware response.'
                                    : 'Stale snapshot — disconnected. Values may have changed.',
                                key: const Key('stale_snapshot'),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            _parallelCard(snapshot, enabled, stale),
                            const SizedBox(height: 16),
                            _shiftCard(snapshot, enabled, stale),
                            const SizedBox(height: 16),
                            _modeCard(snapshot, enabled),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _parallelCard(RegisterSnapshot? snapshot, bool enabled, bool stale) =>
      _RegisterPanel(
        title: 'Parallel register (PIPO)',
        description:
            'Four bits captured together through independent D inputs.',
        icon: Icons.layers_outlined,
        circuit: AnimatedBuilder(
          animation: _parallelAnimation,
          builder: (context, _) => ParallelRegisterWidget(
            value: _activeLoad?.after ?? snapshot?.parallel,
            inputValue: _parallelInput,
            stale: stale,
            clockMhz: snapshot?.fclk0Mhz,
            transition: _activeLoad,
            animationProgress: _parallelAnimation.value,
          ),
        ),
        controls: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'D[3:0] inputs',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: const Key('parallel_input'),
              isExpanded: true,
              initialValue: _parallelInput,
              decoration: const InputDecoration(
                labelText: 'Parallel input (0–15)',
                border: OutlineInputBorder(),
              ),
              items: [
                for (var value = 0; value <= 15; value++)
                  DropdownMenuItem(
                    value: value,
                    child: Text(
                      '$value (${value.toRadixString(2).padLeft(4, '0')})',
                    ),
                  ),
              ],
              onChanged: enabled
                  ? (value) {
                      if (value != null) setState(() => _parallelInput = value);
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('load_parallel'),
              onPressed: enabled
                  ? () => context.read<RegisterBloc>().add(
                      ParallelLoadRequested(_parallelInput),
                    )
                  : null,
              child: const Text('LOAD'),
            ),
          ],
        ),
      );

  Widget _shiftCard(
    RegisterSnapshot? snapshot,
    bool enabled,
    bool stale,
  ) => _RegisterPanel(
    title: 'Shift register (SIPO)',
    description:
        'Serial input enters Q0. Each enabled edge advances bits toward Q3.',
    icon: Icons.arrow_forward,
    circuit: AnimatedBuilder(
      animation: _shiftAnimation,
      builder: (context, _) => ShiftRegisterWidget(
        value: _activeShift?.after ?? snapshot?.shift,
        serialInput: _serialInput,
        stale: stale,
        clockMhz: snapshot?.fclk0Mhz,
        transition: _activeShift,
        animationProgress: _shiftAnimation.value,
      ),
    ),
    controls: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Serial input'),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          key: const Key('serial_input'),
          segments: const [
            ButtonSegment(value: 0, label: Text('0')),
            ButtonSegment(value: 1, label: Text('1')),
          ],
          selected: {_serialInput},
          onSelectionChanged: enabled
              ? (selected) => setState(() => _serialInput = selected.single)
              : null,
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('shift_register'),
          onPressed: enabled
              ? () => context.read<RegisterBloc>().add(
                  ShiftRequested(_serialInput),
                )
              : null,
          child: const Text('SHIFT'),
        ),
      ],
    ),
  );

  Widget _modeCard(RegisterSnapshot? snapshot, bool enabled) => _RegisterCard(
    title: 'Register output',
    children: [
      Text(
        'Confirmed mode: ${snapshot?.selectedMode.name ?? '—'}',
        key: const Key('confirmed_mode'),
      ),
      Text(
        'Shift counter: ${snapshot?.shiftCount ?? '—'}',
        key: const Key('shift_counter'),
      ),
      const SizedBox(height: 12),
      SegmentedButton<RegisterMode>(
        key: const Key('register_mode'),
        segments: const [
          ButtonSegment(value: RegisterMode.parallel, label: Text('Parallel')),
          ButtonSegment(value: RegisterMode.shift, label: Text('Shift')),
        ],
        selected: {if (snapshot != null) snapshot.selectedMode},
        emptySelectionAllowed: snapshot == null,
        onSelectionChanged: enabled
            ? (selected) {
                if (selected.isNotEmpty) {
                  context.read<RegisterBloc>().add(
                    RegisterModeChanged(selected.single),
                  );
                }
              }
            : null,
      ),
    ],
  );
}

class _RegisterCard extends StatelessWidget {
  const _RegisterCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}

class _RegisterPanel extends StatelessWidget {
  const _RegisterPanel({
    required this.title,
    required this.description,
    required this.icon,
    required this.controls,
    required this.circuit,
  });

  final String title;
  final String description;
  final IconData icon;
  final Widget controls;
  final Widget circuit;

  @override
  Widget build(BuildContext context) => Card(
    color: CircuitColors.background,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: CircuitColors.outline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          color: CircuitColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, color: CircuitColors.clock, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: CircuitColors.text,
                        ),
                      ),
                      Text(
                        description,
                        style: const TextStyle(color: CircuitColors.low),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final inputs = DecoratedBox(
                decoration: BoxDecoration(
                  color: CircuitColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: controls,
                ),
              );
              if (constraints.maxWidth >= 1060) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 240, child: inputs),
                    const SizedBox(width: 16),
                    Expanded(child: circuit),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [circuit, const SizedBox(height: 16), inputs],
              );
            },
          ),
        ),
      ],
    ),
  );
}
