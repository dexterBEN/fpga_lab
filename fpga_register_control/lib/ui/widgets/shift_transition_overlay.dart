import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'circuit_primitives.dart';

/// Replays the five data paths together, then pulses the single shared clock.
/// Timing is pedagogical; it does not depict actual FPGA propagation delays.
class ShiftTransitionOverlay extends StatelessWidget {
  const ShiftTransitionOverlay({
    required this.progress,
    required this.dataPaths,
    required this.clockPaths,
    super.key,
  }) : assert(progress >= 0 && progress <= 1);

  final double progress;
  final List<CircuitWire> dataPaths;
  final List<CircuitWire> clockPaths;

  double get travelProgress =>
      Curves.easeInOut.transform((progress / 0.65).clamp(0.0, 1.0));

  double get clockIntensity => progress <= 0.65
      ? 0
      : math.sin(((progress - 0.65) / 0.35).clamp(0.0, 1.0) * math.pi);

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            key: const Key('shift_clock_pulse'),
            painter: SharedClockPulsePainter(
              paths: clockPaths,
              intensity: clockIntensity,
            ),
          ),
        ),
        for (var index = 0; index < dataPaths.length; index++)
          _travellingBit(index, dataPaths[index]),
      ],
    ),
  );

  Widget _travellingBit(int index, CircuitWire path) {
    final position = Offset.lerp(
      path.points.first,
      path.points.last,
      travelProgress,
    )!;
    final color = CircuitColors.bit(path.bit);
    return Positioned(
      left: position.dx - 12,
      top: position.dy - 12,
      child: Semantics(
        label: '${path.label}, previous bit ${path.bit}',
        child: Container(
          key: Key('shift_travel_$index'),
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: CircuitColors.background,
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 8),
            ],
          ),
          child: Text(
            '${path.bit}',
            style: TextStyle(
              color: color,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class SharedClockPulsePainter extends CustomPainter {
  const SharedClockPulsePainter({required this.paths, required this.intensity});
  final List<CircuitWire> paths;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;
    final glow = Paint()
      ..color = CircuitColors.clock.withValues(alpha: intensity * 0.7)
      ..strokeWidth = 9
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: intensity)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    for (final wire in paths) {
      final path = Path()..moveTo(wire.points.first.dx, wire.points.first.dy);
      for (final point in wire.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, glow);
      canvas.drawPath(path, highlight);
    }
  }

  @override
  bool shouldRepaint(SharedClockPulsePainter oldDelegate) =>
      intensity != oldDelegate.intensity || paths != oldDelegate.paths;
}
