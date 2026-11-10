import 'package:flutter/material.dart';

import '../../models/register_value.dart';

abstract final class CircuitColors {
  static const background = Color(0xff0b1422);
  static const surface = Color(0xff111e30);
  static const outline = Color(0xff2c4059);
  static const high = Color(0xff4ade80);
  static const low = Color(0xffa5c9ef);
  static const unknown = Color(0xff718096);
  static const clock = Color(0xff38bdf8);
  static const text = Color(0xffe2e8f0);

  static Color bit(int? value, {bool stale = false}) => stale || value == null
      ? unknown
      : value == 1
      ? high
      : low;
}

/// A polyline used by both the diagram and its accessibility description.
/// The endpoints describe real pin connections, independent of register values.
class CircuitWire {
  const CircuitWire({
    required this.label,
    required this.points,
    this.bit,
    this.clock = false,
    this.arrow = true,
    this.junction = false,
  });

  final String label;
  final List<Offset> points;
  final int? bit;
  final bool clock;
  final bool arrow;
  final bool junction;
}

class CircuitWiringPainter extends CustomPainter {
  const CircuitWiringPainter({required this.wires, this.stale = false});

  final List<CircuitWire> wires;
  final bool stale;

  @override
  void paint(Canvas canvas, Size size) {
    for (final wire in wires) {
      if (wire.points.length < 2) continue;
      final color = wire.clock
          ? CircuitColors.clock
          : CircuitColors.bit(wire.bit, stale: stale);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      final path = Path()..moveTo(wire.points.first.dx, wire.points.first.dy);
      for (final point in wire.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
      paint.style = PaintingStyle.fill;
      if (wire.junction) canvas.drawCircle(wire.points.first, 3.5, paint);
      if (wire.arrow) {
        final tip = wire.points.last;
        final delta = tip - wire.points[wire.points.length - 2];
        if (delta.distance == 0) continue;
        final direction = delta / delta.distance;
        final normal = Offset(-direction.dy, direction.dx);
        final arrow = Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(
            (tip - direction * 8 + normal * 4).dx,
            (tip - direction * 8 + normal * 4).dy,
          )
          ..lineTo(
            (tip - direction * 8 - normal * 4).dx,
            (tip - direction * 8 - normal * 4).dy,
          )
          ..close();
        canvas.drawPath(arrow, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CircuitWiringPainter oldDelegate) =>
      oldDelegate.wires != wires || oldDelegate.stale != stale;
}

/// A circuit stays legible at its natural size; narrow viewports can pan it.
class CircuitDiagram extends StatelessWidget {
  const CircuitDiagram({
    required this.width,
    required this.height,
    required this.children,
    required this.wires,
    required this.wiringKey,
    this.stale = false,
    super.key,
  });

  final double width;
  final double height;
  final List<Widget> children;
  final List<CircuitWire> wires;
  final Key wiringKey;
  final bool stale;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Semantics(
                    label: wires.map((wire) => wire.label).join('; '),
                    child: CustomPaint(
                      key: wiringKey,
                      painter: CircuitWiringPainter(wires: wires, stale: stale),
                    ),
                  ),
                ),
                ...children,
              ],
            ),
          ),
        ),
        if (constraints.maxWidth < width)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Scroll horizontally to inspect the circuit.',
              style: TextStyle(color: CircuitColors.low, fontSize: 12),
            ),
          ),
      ],
    ),
  );
}

class CircuitPinLabel extends StatelessWidget {
  const CircuitPinLabel({
    required this.name,
    required this.bit,
    this.stale = false,
    super.key,
  });
  final String name;
  final int? bit;
  final bool stale;

  @override
  Widget build(BuildContext context) => Text(
    '$name = ${bit ?? '—'}',
    textAlign: TextAlign.center,
    style: TextStyle(
      color: CircuitColors.bit(bit, stale: stale),
      fontWeight: FontWeight.w600,
      fontSize: 13,
    ),
  );
}

/// Clock is a static schematic symbol, not an animation or a sampled logic level.
List<CircuitWire> sharedClockWires(
  List<double> pinXs,
  double busY,
  double pinY,
) => [
  CircuitWire(
    label: 'Shared CLK bus',
    points: [Offset(pinXs.first - 36, busY), Offset(pinXs.last + 12, busY)],
    clock: true,
    arrow: false,
  ),
  for (var stage = 0; stage < pinXs.length; stage++)
    CircuitWire(
      label: 'Shared CLK to stage $stage',
      points: [Offset(pinXs[stage], busY), Offset(pinXs[stage], pinY)],
      clock: true,
      arrow: false,
      junction: true,
    ),
];

class RegisterCircuitFrame extends StatelessWidget {
  const RegisterCircuitFrame({
    required this.register,
    required this.value,
    required this.diagram,
    required this.diagramWidth,
    required this.caption,
    this.valueCaption = 'Q[3:0] · confirmed',
    this.stateLabel,
    this.stale = false,
    super.key,
  });
  final String register;
  final RegisterValue? value;
  final Widget diagram;
  final double diagramWidth;
  final String caption;
  final String valueCaption;
  final String? stateLabel;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final color = stale ? CircuitColors.unknown : CircuitColors.high;
    final summary = Container(
      key: Key('${register}_summary'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CircuitColors.surface,
        border: Border.all(color: CircuitColors.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            valueCaption,
            style: const TextStyle(color: CircuitColors.text, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            'Binary: ${value?.bits ?? '—'}',
            key: Key('${register}_binary'),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: value == null ? CircuitColors.unknown : color,
            ),
          ),
          Text(
            'Decimal: ${value?.value ?? '—'}',
            key: Key('${register}_decimal'),
            style: const TextStyle(color: CircuitColors.text),
          ),
          const SizedBox(height: 6),
          Text(
            stateLabel ??
                (value == null
                    ? 'Not yet read'
                    : stale
                    ? 'Last known · stale'
                    : 'Hardware confirmed'),
            style: TextStyle(
              color: stale || value == null
                  ? CircuitColors.unknown
                  : CircuitColors.low,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CircuitColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= diagramWidth + 196) {
                  return Row(
                    children: [
                      Expanded(child: diagram),
                      const SizedBox(width: 12),
                      SizedBox(width: 184, child: summary),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [diagram, summary],
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              caption,
              style: const TextStyle(color: CircuitColors.low, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
