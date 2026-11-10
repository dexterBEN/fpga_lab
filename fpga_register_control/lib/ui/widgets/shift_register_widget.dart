import 'package:flutter/material.dart';

import '../../models/register_value.dart';
import 'circuit_primitives.dart';
import 'flip_flop_widget.dart';

/// Q0 is the first stage from the left, matching stored(2 downto 0) & serial_in.
/// D pin values show the wiring from confirmed Q values, never a simulated shift.
class ShiftRegisterWidget extends StatelessWidget {
  const ShiftRegisterWidget({
    required this.value,
    required this.serialInput,
    this.stale = false,
    this.clockMhz,
    super.key,
  }) : assert(serialInput == 0 || serialInput == 1);

  final RegisterValue? value;
  final int serialInput;
  final bool stale;
  final double? clockMhz;

  @override
  Widget build(BuildContext context) {
    const top = 72.0;
    const busY = 224.0;
    const pinY = top + FlipFlopWidget.dataPinY;
    final wires = <CircuitWire>[
      CircuitWire(
        label: 'Serial input to FF0.D',
        bit: serialInput,
        points: const [Offset(46, pinY), Offset(88, pinY)],
      ),
    ];
    final stages = <Widget>[];
    final clockXs = <double>[];
    for (var bitIndex = 0; bitIndex < 4; bitIndex++) {
      final x = 88.0 + bitIndex * 156;
      final output = value?.q0ToQ3[bitIndex];
      final input = bitIndex == 0 ? serialInput : value?.q0ToQ3[bitIndex - 1];
      clockXs.add(x + FlipFlopWidget.clockPinX);
      wires.add(
        CircuitWire(
          label: bitIndex < 3
              ? 'FF$bitIndex.Q to FF${bitIndex + 1}.D'
              : 'FF3.Q discarded on SHIFT',
          bit: output,
          points: [
            Offset(x + FlipFlopWidget.width, pinY),
            Offset(bitIndex < 3 ? x + 156 : 730, pinY),
          ],
        ),
      );
      wires.add(
        CircuitWire(
          label: 'FF$bitIndex.Q to Q$bitIndex',
          bit: output,
          junction: true,
          points: [Offset(x + 122, pinY), Offset(x + 122, 44)],
        ),
      );
      stages.addAll([
        Positioned(
          left: x,
          top: top,
          child: FlipFlopWidget(
            key: Key('shift_ff_$bitIndex'),
            label: 'FF$bitIndex',
            dBit: input,
            qBit: output,
            stale: stale,
          ),
        ),
        Positioned(
          left: x + 90,
          top: 16,
          width: 64,
          child: CircuitPinLabel(
            key: Key('shift_q_$bitIndex'),
            name: 'Q$bitIndex',
            bit: output,
            stale: stale,
          ),
        ),
      ]);
    }
    wires.addAll(sharedClockWires(clockXs, busY, top + FlipFlopWidget.height));
    return RegisterCircuitFrame(
      register: 'shift',
      value: value,
      stale: stale,
      diagramWidth: 744,
      caption:
          'Serial in → Q0 → Q1 → Q2 → Q3 → discarded. SHIFT = 1 advances on CLK ↑; the summary reads Q3…Q0.',
      diagram: CircuitDiagram(
        width: 744,
        height: 266,
        wires: wires,
        stale: stale,
        wiringKey: const Key('shift_wiring'),
        children: [
          ...stages,
          const Positioned(
            left: 4,
            top: 50,
            child: Text(
              'Serial in',
              style: TextStyle(color: CircuitColors.text, fontSize: 12),
            ),
          ),
          Positioned(
            left: 10,
            top: 78,
            width: 36,
            height: 40,
            child: Center(
              child: Text(
                '$serialInput',
                key: const Key('shift_serial_bit'),
                style: TextStyle(
                  color: CircuitColors.bit(serialInput),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const Positioned(
            left: 660,
            top: 116,
            width: 80,
            child: Text(
              'Discarded\non SHIFT',
              textAlign: TextAlign.center,
              style: TextStyle(color: CircuitColors.low, fontSize: 11),
            ),
          ),
          Positioned(
            left: 100,
            top: 242,
            child: Text(
              'Shared CLK ↑${clockMhz == null ? '' : ' · ${clockMhz!.toStringAsFixed(0)} MHz'}   |   SHIFT enable: all stages',
              style: const TextStyle(color: CircuitColors.clock, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
