import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/app.dart';
import '../bloc/mux_demux_cubit.dart';
import '../model/circuit_state.dart';
import 'widgets/node_graph.dart';

class MuxDemuxPage extends StatelessWidget {
  const MuxDemuxPage({super.key});
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<MuxDemuxCubit, CircuitState>(
    builder: (context, state) {
      final cubit = context.read<MuxDemuxCubit>();
      final mux = state.mode == CircuitMode.mux;
      return Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 24,
                      runSpacing: 16,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.hub_outlined, color: mint, size: 32),
                            SizedBox(width: 12),
                            Text(
                              'MUX / DEMUX',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const Chip(
                          avatar: Icon(
                            Icons.science_outlined,
                            size: 18,
                            color: mint,
                          ),
                          label: Text('Simulation locale'),
                        ),
                        const Text(
                          '●  FPGA : déconnectée',
                          style: TextStyle(color: muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Explorez le routage des signaux, un bit à la fois.',
                      style: TextStyle(color: muted),
                    ),
                    const SizedBox(height: 28),
                    SegmentedButton<CircuitMode>(
                      segments: const [
                        ButtonSegment(
                          value: CircuitMode.mux,
                          label: Text('MUX'),
                          icon: Icon(Icons.call_merge),
                        ),
                        ButtonSegment(
                          value: CircuitMode.demux,
                          label: Text('DEMUX'),
                          icon: Icon(Icons.call_split),
                        ),
                      ],
                      selected: {state.mode},
                      onSelectionChanged: (s) => cubit.setMode(s.first),
                    ),
                    const SizedBox(height: 24),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            children: [
                              Text(
                                mux
                                    ? 'Multiplexeur 4 → 1'
                                    : 'Démultiplexeur 1 → 4',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                state.route,
                                style: const TextStyle(
                                  color: mint,
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            mux
                                ? 'Le sélecteur choisit l’entrée transmise à Y.'
                                : 'Le sélecteur choisit la sortie qui reçoit D.',
                            style: const TextStyle(color: muted),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(height: 370, child: NodeGraph(state: state)),
                          const Wrap(
                            spacing: 24,
                            runSpacing: 8,
                            children: [
                              Text(
                                '━  Chemin sélectionné',
                                style: TextStyle(color: mint),
                              ),
                              Text(
                                '●  Impulsion : niveau 1',
                                style: TextStyle(color: muted),
                              ),
                              Text(
                                'Touchez une entrée pour changer sa valeur.',
                                style: TextStyle(color: muted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final controls = _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Commandes',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (mux)
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 8,
                                  children: List.generate(
                                    4,
                                    (i) => _toggle(
                                      'D$i',
                                      state.muxInputs[i],
                                      (v) => cubit.setMuxInput(i, v),
                                    ),
                                  ),
                                )
                              else
                                _toggle(
                                  'D',
                                  state.demuxInput,
                                  cubit.setDemuxInput,
                                ),
                              const Divider(height: 32),
                              const Text(
                                'Sélecteur · S1 S0',
                                style: TextStyle(color: muted),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: List.generate(
                                  4,
                                  (i) => ChoiceChip(
                                    label: Text(
                                      i.toRadixString(2).padLeft(2, '0'),
                                    ),
                                    selected: state.selector == i,
                                    onSelected: (_) => cubit.setSelector(i),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 20,
                                children: [
                                  _toggle(
                                    'S1',
                                    state.selector & 2 != 0,
                                    (v) => cubit.setSelector(
                                      v
                                          ? state.selector | 2
                                          : state.selector & 1,
                                    ),
                                  ),
                                  _toggle(
                                    'S0',
                                    state.selector & 1 != 0,
                                    (v) => cubit.setSelector(
                                      v
                                          ? state.selector | 1
                                          : state.selector & 2,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                        final inspector = _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Inspecteur',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _info('Sélecteur', state.binary),
                              _info('Chemin', state.route),
                              _info(
                                mux ? 'Sortie Y' : 'Sorties Y0…Y3',
                                mux
                                    ? (state.muxOutput ? '1' : '0')
                                    : state.demuxOutputs
                                          .map((v) => v ? '1' : '0')
                                          .join('  '),
                              ),
                              _info('Source', 'Simulation locale'),
                              _info('FPGA', 'Déconnectée'),
                              const SizedBox(height: 12),
                              Text(
                                mux
                                    ? 'Y = D[S1 S0]'
                                    : 'Y[S1 S0] = D ; autres sorties = 0',
                                style: const TextStyle(color: mint),
                              ),
                            ],
                          ),
                        );
                        if (constraints.maxWidth < 740) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              controls,
                              const SizedBox(height: 20),
                              inspector,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: controls),
                            const SizedBox(width: 20),
                            Expanded(child: inspector),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Table de sélection',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...List.generate(
                            4,
                            (i) => Semantics(
                              selected: i == state.selector,
                              child: InkWell(
                                onTap: () => cubit.setSelector(i),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: i == state.selector
                                        ? mint.withValues(alpha: .10)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        i.toRadixString(2).padLeft(2, '0'),
                                        style: TextStyle(
                                          color: i == state.selector
                                              ? mint
                                              : muted,
                                        ),
                                      ),
                                      const SizedBox(width: 32),
                                      Expanded(
                                        child: Text(
                                          mux ? 'D$i → Y' : 'D → Y$i',
                                        ),
                                      ),
                                      Text(
                                        mux
                                            ? 'Y = ${state.muxInputs[i] ? 1 : 0}'
                                            : 'Y$i = ${state.demuxInput ? 1 : 0}',
                                        style: const TextStyle(color: muted),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        i == state.selector
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_off,
                                        size: 18,
                                        color: i == state.selector
                                            ? mint
                                            : muted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'PYNQ-Z2 / Exercices 05 & 06 · Logique combinatoire',
                      style: TextStyle(color: muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$label  ${value ? 1 : 0}'),
      const SizedBox(width: 4),
      Semantics(
        label: label,
        child: Switch(value: value, onChanged: onChanged),
      ),
    ],
  );
  Widget _info(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: muted)),
        ),
        Text(value),
      ],
    ),
  );
  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: panel,
      border: Border.all(color: const Color(0xFF303B49)),
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );
}
