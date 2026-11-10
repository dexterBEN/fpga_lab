import 'package:flutter/material.dart';

import '../../models/register_value.dart';
import 'circuit_primitives.dart';
import 'confirmed_parallel_load.dart';
import 'flip_flop_widget.dart';
import 'parallel_capture_overlay.dart';

/// Four independent D inputs; no stage's Q feeds the next stage's D.
class ParallelRegisterWidget extends StatelessWidget {
  const ParallelRegisterWidget({
    required this.value,
    required this.inputValue,
    this.stale = false,
    this.clockMhz,
    this.transition,
    this.animationProgress = 0,
    super.key,
  }) : assert(inputValue >= 0 && inputValue <= 15),
       assert(animationProgress >= 0 && animationProgress <= 1);

  final RegisterValue? value;
  final int inputValue;
  final bool stale;
  final double? clockMhz;
  final ConfirmedParallelLoad? transition;
  final double animationProgress;

  @override
  Widget build(BuildContext context) {
    final replay = stale ? null : transition;
    // Keep Q and the summary on the same previous sample until capture ends.
    // A missing previous sample remains unknown, including during the replay.
    final displayedValue = replay != null ? replay.before : value;
    final displayedInput = replay?.inputValue ?? inputValue;
    const top = 60.0;
    const busY = 224.0;
    final wires = <CircuitWire>[];
    final stages = <Widget>[];
    final clockXs = <double>[];
    final inputPaths = <CircuitWire>[];
    final inputLabels = <Rect>[];
    final flipFlops = <Rect>[];
    for (var column = 0; column < 4; column++) {
      final bitIndex = 3 - column;
      final x = 24.0 + column * 156;
      final input = (displayedInput >> bitIndex) & 1;
      final output = displayedValue?.q0ToQ3[bitIndex];
      final pinY = top + FlipFlopWidget.dataPinY;
      wires.add(
        CircuitWire(
          label: 'D$bitIndex to FF$bitIndex.D',
          bit: input,
          points: [
            Offset(x + 22, 28),
            Offset(x + 22, 40),
            Offset(x - 14, 40),
            Offset(x - 14, pinY),
            Offset(x, pinY),
          ],
        ),
      );
      inputPaths.add(wires.last);
      wires.add(
        CircuitWire(
          label: 'FF$bitIndex.Q to Q$bitIndex',
          bit: output,
          points: [
            Offset(x + FlipFlopWidget.width, pinY),
            Offset(x + 118, pinY),
            Offset(x + 118, 28),
          ],
        ),
      );
      clockXs.add(x + FlipFlopWidget.clockPinX);
      inputLabels.add(Rect.fromLTWH(x - 8, 0, 64, 24));
      flipFlops.add(
        Rect.fromLTWH(x, top, FlipFlopWidget.width, FlipFlopWidget.height),
      );
      stages.addAll([
        Positioned(
          left: x - 8,
          top: 2,
          width: 64,
          child: CircuitPinLabel(
            key: Key('parallel_d_$bitIndex'),
            name: 'D$bitIndex',
            bit: input,
          ),
        ),
        Positioned(
          left: x + 86,
          top: 2,
          width: 64,
          child: CircuitPinLabel(
            key: Key('parallel_q_$bitIndex'),
            name: 'Q$bitIndex',
            bit: output,
            stale: stale,
          ),
        ),
        Positioned(
          left: x,
          top: top,
          child: FlipFlopWidget(
            key: Key('parallel_ff_$bitIndex'),
            label: 'FF$bitIndex',
            dBit: input,
            qBit: output,
            stale: stale,
          ),
        ),
      ]);
    }
    wires.addAll(sharedClockWires(clockXs, busY, top + FlipFlopWidget.height));
    return RegisterCircuitFrame(
      register: 'parallel',
      value: displayedValue,
      stale: stale,
      diagramWidth: 648,
      caption: replay == null
          ? 'D3…D0 are independent inputs. LOAD = 1 captures all four bits on CLK ↑.'
          : 'Confirmed LOAD · pedagogical replay. All four D inputs capture together; all Q bits update together at the end.',
      valueCaption: replay == null
          ? 'Q[3:0] · confirmed'
          : 'Previous confirmed Q[3:0]',
      stateLabel: replay == null ? null : 'Replaying confirmed LOAD',
      diagram: CircuitDiagram(
        width: 648,
        height: 266,
        wires: wires,
        stale: stale,
        wiringKey: const Key('parallel_wiring'),
        children: [
          ...stages,
          Positioned(
            left: 28,
            top: 242,
            child: Text(
              'Shared CLK ↑${clockMhz == null ? '' : ' · ${clockMhz!.toStringAsFixed(0)} MHz'}   |   LOAD enable: all stages',
              style: const TextStyle(color: CircuitColors.clock, fontSize: 12),
            ),
          ),
          if (replay != null)
            Positioned.fill(
              child: ParallelCaptureOverlay(
                key: const Key('parallel_capture_overlay'),
                progress: animationProgress,
                inputPaths: inputPaths,
                clockPaths: wires.where((wire) => wire.clock).toList(),
                inputLabels: inputLabels,
                flipFlops: flipFlops,
              ),
            ),
        ],
      ),
    );
  }
}
