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
import '../widgets/parallel_register_widget.dart';
import '../widgets/shift_register_widget.dart';

class RegisterSystemView extends StatefulWidget {
  const RegisterSystemView({super.key});

  @override
  State<RegisterSystemView> createState() => _RegisterSystemViewState();
}

class _RegisterSystemViewState extends State<RegisterSystemView> {
  int _parallelInput = 0;
  int _serialInput = 0;
  bool _awaitingFreshSnapshot = true;

  @override
  void initState() {
    super.initState();
    // Also refresh if the view is mounted into an already connected session.
    if (context.read<WebSocketConnectionBloc>().state.status ==
        WebSocketConnectionStatus.connected) {
      _requestState();
    }
  }

  void _requestState() =>
      context.read<RegisterBloc>().add(const RegisterStateRequested());

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<WebSocketConnectionBloc, WebSocketConnectionState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            setState(() => _awaitingFreshSnapshot = true);
            if (state.status == WebSocketConnectionStatus.connected) {
              _requestState();
            }
          },
        ),
        BlocListener<RegisterBloc, RegisterState>(
          listener: (context, state) {
            if (state.status == RegisterStatus.ready &&
                context.read<WebSocketConnectionBloc>().state.status ==
                    WebSocketConnectionStatus.connected) {
              setState(() => _awaitingFreshSnapshot = false);
            }
          },
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
                final enabled = connected && !loading;
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
        circuit: ParallelRegisterWidget(
          value: snapshot?.parallel,
          inputValue: _parallelInput,
          stale: stale,
          clockMhz: snapshot?.fclk0Mhz,
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
    circuit: ShiftRegisterWidget(
      value: snapshot?.shift,
      serialInput: _serialInput,
      stale: stale,
      clockMhz: snapshot?.fclk0Mhz,
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
