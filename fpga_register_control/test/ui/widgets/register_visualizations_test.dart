import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpga_register_control/models/register_value.dart';
import 'package:fpga_register_control/ui/widgets/circuit_primitives.dart';
import 'package:fpga_register_control/ui/widgets/flip_flop_widget.dart';
import 'package:fpga_register_control/ui/widgets/parallel_register_widget.dart';
import 'package:fpga_register_control/ui/widgets/shift_register_widget.dart';

void main() {
  Future<void> show(
    WidgetTester tester,
    Widget widget, {
    double width = 1100,
  }) async {
    tester.view.physicalSize = Size(width, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: widget),
          ),
        ),
      ),
    );
  }

  FlipFlopWidget stage(WidgetTester tester, String register, int index) =>
      tester.widget<FlipFlopWidget>(find.byKey(Key('${register}_ff_$index')));

  Color borderColor(WidgetTester tester, Finder flipFlop) {
    final body = find.descendant(
      of: flipFlop,
      matching: find.byKey(const Key('flip_flop_body')),
    );
    final decoration =
        tester.widget<DecoratedBox>(body).decoration as BoxDecoration;
    return (decoration.border! as Border).top.color;
  }

  CircuitWiringPainter wiring(WidgetTester tester, String register) =>
      tester.widget<CustomPaint>(find.byKey(Key('${register}_wiring'))).painter!
          as CircuitWiringPainter;

  Rect localStageRect(WidgetTester tester, String register, int index) {
    final origin = tester.getTopLeft(find.byKey(Key('${register}_wiring')));
    return tester
        .getRect(find.byKey(Key('${register}_ff_$index')))
        .shift(-origin);
  }

  for (final bit in [0, 1]) {
    testWidgets(
      'flip-flop renders confirmed Q = $bit with D, Q and clock pins',
      (tester) async {
        await show(
          tester,
          FlipFlopWidget(label: 'FF0', dBit: 1 - bit, qBit: bit),
        );
        expect(find.text('D'), findsOneWidget);
        expect(find.text('Q'), findsOneWidget);
        expect(find.text('CLK'), findsOneWidget);
        expect(find.text('FF0'), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(const Key('flip_flop_q'))).data,
          '$bit',
        );
      },
    );
  }

  testWidgets('zero and one have visually distinct outlines', (tester) async {
    await show(
      tester,
      const Row(
        children: [
          FlipFlopWidget(key: Key('low'), label: 'FF0', qBit: 0),
          FlipFlopWidget(key: Key('high'), label: 'FF1', qBit: 1),
        ],
      ),
    );
    expect(
      borderColor(tester, find.byKey(const Key('low'))),
      CircuitColors.low,
    );
    expect(
      borderColor(tester, find.byKey(const Key('high'))),
      CircuitColors.high,
    );
    expect(CircuitColors.high, isNot(CircuitColors.low));
  });

  testWidgets(
    'unknown Q has a placeholder and an accessible unknown description',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await show(
          tester,
          const FlipFlopWidget(label: 'FF0', dBit: 0, qBit: null),
        );
        expect(
          tester.widget<Text>(find.byKey(const Key('flip_flop_q'))).data,
          '—',
        );
        expect(
          tester.getSemantics(find.byType(FlipFlopWidget)).label,
          contains('Q unknown'),
        );
        expect(
          borderColor(tester, find.byType(FlipFlopWidget)),
          CircuitColors.unknown,
        );
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('parallel stages follow D3/Q3 through D0/Q0 from left to right', (
    tester,
  ) async {
    await show(
      tester,
      ParallelRegisterWidget(value: RegisterValue(value: 10), inputValue: 5),
    );
    expect(
      [
        for (final index in [3, 2, 1, 0]) stage(tester, 'parallel', index).qBit,
      ],
      [1, 0, 1, 0],
    );
    expect(
      [
        for (final index in [3, 2, 1, 0]) stage(tester, 'parallel', index).dBit,
      ],
      [0, 1, 0, 1],
    );
    for (var index = 3; index >= 0; index--) {
      final input = tester.widget<CircuitPinLabel>(
        find.byKey(Key('parallel_d_$index')),
      );
      final output = tester.widget<CircuitPinLabel>(
        find.byKey(Key('parallel_q_$index')),
      );
      expect(input.name, 'D$index');
      expect(output.name, 'Q$index');
      expect(output.bit, stage(tester, 'parallel', index).qBit);
      if (index > 0) {
        expect(
          localStageRect(tester, 'parallel', index).left,
          lessThan(localStageRect(tester, 'parallel', index - 1).left),
        );
      }
    }
    expect(find.text('Binary: 1010'), findsOneWidget);
    expect(find.text('Decimal: 10'), findsOneWidget);
  });

  testWidgets(
    'parallel input wires are independent and all clock taps reach a flip-flop',
    (tester) async {
      await show(
        tester,
        ParallelRegisterWidget(
          value: RegisterValue(value: 10),
          inputValue: 5,
          clockMhz: 50,
        ),
      );
      final wires = wiring(tester, 'parallel').wires;
      expect(wires.where((wire) => !wire.clock), hasLength(8));
      expect(wires.where((wire) => wire.clock && wire.junction), hasLength(4));
      for (var index = 0; index < 4; index++) {
        final rect = localStageRect(tester, 'parallel', index);
        final input = wires.singleWhere(
          (wire) => wire.label == 'D$index to FF$index.D',
        );
        final output = wires.singleWhere(
          (wire) => wire.label == 'FF$index.Q to Q$index',
        );
        expect(
          input.points.last,
          rect.topLeft + const Offset(0, FlipFlopWidget.dataPinY),
        );
        expect(
          output.points.first,
          rect.topRight + const Offset(0, FlipFlopWidget.dataPinY),
        );
        final clock = wires.singleWhere(
          (wire) => wire.clock && wire.points.last == rect.bottomCenter,
        );
        expect(clock.arrow, isFalse);
        expect(clock.points.first.dy, 224);
      }
      expect(wires.any((wire) => wire.label.contains('.Q to FF')), isFalse);
      expect(find.textContaining('50 MHz'), findsOneWidget);
      expect(find.textContaining('LOAD = 1'), findsOneWidget);
    },
  );

  testWidgets(
    'SIPO renders Q0, Q1, Q2, Q3 left to right, distinct from binary text',
    (tester) async {
      await show(
        tester,
        ShiftRegisterWidget(value: RegisterValue(value: 10), serialInput: 1),
      );
      expect(
        [
          for (var index = 0; index < 4; index++)
            stage(tester, 'shift', index).qBit,
        ],
        [0, 1, 0, 1],
      );
      // Inputs are the serial bit followed by upstream confirmed outputs.
      expect(
        [
          for (var index = 0; index < 4; index++)
            stage(tester, 'shift', index).dBit,
        ],
        [1, 0, 1, 0],
      );
      for (var index = 0; index < 4; index++) {
        expect(
          tester
              .widget<CircuitPinLabel>(find.byKey(Key('shift_q_$index')))
              .name,
          'Q$index',
        );
        if (index < 3) {
          expect(
            localStageRect(tester, 'shift', index).left,
            lessThan(localStageRect(tester, 'shift', index + 1).left),
          );
        }
      }
      expect(find.text('Binary: 1010'), findsOneWidget);
      expect(
        find.textContaining('Serial in → Q0 → Q1 → Q2 → Q3 → discarded'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'SIPO arrows connect serial to Q0 stage, Q0 to Q1 through Q3 and discard',
    (tester) async {
      await show(
        tester,
        ShiftRegisterWidget(value: RegisterValue(value: 11), serialInput: 0),
      );
      final wires = wiring(tester, 'shift').wires;
      final entry = wires.singleWhere(
        (wire) => wire.label == 'Serial input to FF0.D',
      );
      expect(
        entry.points.last,
        localStageRect(tester, 'shift', 0).topLeft +
            const Offset(0, FlipFlopWidget.dataPinY),
      );
      expect(entry.points.first.dx, lessThan(entry.points.last.dx));
      expect(entry.arrow, isTrue);
      for (var index = 0; index < 3; index++) {
        final link = wires.singleWhere(
          (wire) => wire.label == 'FF$index.Q to FF${index + 1}.D',
        );
        expect(
          link.points.first,
          localStageRect(tester, 'shift', index).topRight +
              const Offset(0, FlipFlopWidget.dataPinY),
        );
        expect(
          link.points.last,
          localStageRect(tester, 'shift', index + 1).topLeft +
              const Offset(0, FlipFlopWidget.dataPinY),
        );
        expect(link.points.first.dx, lessThan(link.points.last.dx));
        expect(link.arrow, isTrue);
      }
      final discarded = wires.singleWhere(
        (wire) => wire.label == 'FF3.Q discarded on SHIFT',
      );
      expect(
        discarded.points.first,
        localStageRect(tester, 'shift', 3).topRight +
            const Offset(0, FlipFlopWidget.dataPinY),
      );
      expect(
        discarded.points.last.dx,
        greaterThan(localStageRect(tester, 'shift', 3).right),
      );
      expect(wires.where((wire) => wire.clock && wire.junction), hasLength(4));
    },
  );

  for (final register in ['parallel', 'shift']) {
    Widget diagram(RegisterValue? value, {bool stale = false}) =>
        register == 'parallel'
        ? ParallelRegisterWidget(value: value, inputValue: 0, stale: stale)
        : ShiftRegisterWidget(value: value, serialInput: 0, stale: stale);

    testWidgets(
      '$register updates from new confirmed values without retaining its own register state',
      (tester) async {
        await show(tester, diagram(RegisterValue(value: 10)));
        await show(tester, diagram(RegisterValue(value: 5)));
        for (var index = 0; index < 4; index++) {
          expect(stage(tester, register, index).qBit, [1, 0, 1, 0][index]);
        }
        expect(find.text('Binary: 0101'), findsOneWidget);
        expect(find.text('Decimal: 5'), findsOneWidget);
      },
    );

    testWidgets(
      '$register does not fabricate Q when no hardware snapshot exists',
      (tester) async {
        await show(tester, diagram(null));
        for (var index = 0; index < 4; index++) {
          expect(stage(tester, register, index).qBit, isNull);
        }
        expect(find.text('Binary: —'), findsOneWidget);
        expect(find.text('Decimal: —'), findsOneWidget);
        expect(find.text('Not yet read'), findsOneWidget);
        expect(find.textContaining('50 MHz'), findsNothing);
      },
    );

    testWidgets('$register keeps stale Q values but mutes and labels them', (
      tester,
    ) async {
      await show(tester, diagram(RegisterValue(value: 15), stale: true));
      for (var index = 0; index < 4; index++) {
        expect(stage(tester, register, index).qBit, 1);
        expect(stage(tester, register, index).stale, isTrue);
        expect(
          borderColor(tester, find.byKey(Key('${register}_ff_$index'))),
          CircuitColors.unknown,
        );
      }
      expect(find.text('Binary: 1111'), findsOneWidget);
      expect(find.text('Last known · stale'), findsOneWidget);
    });

    testWidgets(
      '$register circuit stays legible through horizontal scrolling on narrow screens',
      (tester) async {
        await show(tester, diagram(RegisterValue(value: 10)), width: 320);
        expect(
          find.text('Scroll horizontally to inspect the circuit.'),
          findsOneWidget,
        );
        expect(
          tester.getSize(find.byType(FlipFlopWidget).first).width,
          FlipFlopWidget.width,
        );
        final scroll = find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        );
        await tester.drag(scroll, const Offset(-600, 0));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
