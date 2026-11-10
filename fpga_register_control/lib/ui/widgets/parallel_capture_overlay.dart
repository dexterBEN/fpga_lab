import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'circuit_primitives.dart';

/// One pulse per phase, applied to all four independent inputs/stages together.
/// No travelling bits or inter-stage data paths are used for a parallel load.
class ParallelCaptureOverlay extends StatelessWidget {
  const ParallelCaptureOverlay({
    required this.progress,
    required this.inputPaths,
    required this.clockPaths,
    required this.inputLabels,
    required this.flipFlops,
    super.key,
  }) : assert(progress >= 0 && progress <= 1);

  final double progress;
  final List<CircuitWire> inputPaths;
  final List<CircuitWire> clockPaths;
  final List<Rect> inputLabels;
  final List<Rect> flipFlops;

  double _pulse(double start, double end) =>
      progress <= start || progress >= end
      ? 0
      : math.sin((progress - start) / (end - start) * math.pi);

  double get inputIntensity => _pulse(0, 0.5);
  double get clockIntensity => _pulse(0.2, 0.75);
  double get captureIntensity => _pulse(0.35, 1);

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Semantics(
      label:
          'Confirmed LOAD: all four D inputs capture together on a shared clock edge.',
      child: CustomPaint(
        key: const Key('parallel_capture_pulse'),
        painter: ParallelCapturePainter(
          inputPaths: inputPaths,
          clockPaths: clockPaths,
          inputLabels: inputLabels,
          flipFlops: flipFlops,
          inputIntensity: inputIntensity,
          clockIntensity: clockIntensity,
          captureIntensity: captureIntensity,
        ),
      ),
    ),
  );
}

class ParallelCapturePainter extends CustomPainter {
  const ParallelCapturePainter({
    required this.inputPaths,
    required this.clockPaths,
    required this.inputLabels,
    required this.flipFlops,
    required this.inputIntensity,
    required this.clockIntensity,
    required this.captureIntensity,
  });

  final List<CircuitWire> inputPaths;
  final List<CircuitWire> clockPaths;
  final List<Rect> inputLabels;
  final List<Rect> flipFlops;
  final double inputIntensity;
  final double clockIntensity;
  final double captureIntensity;

  void _highlight(Canvas canvas, Path path, double intensity) {
    if (intensity <= 0) return;
    canvas.drawPath(
      path,
      Paint()
        ..color = CircuitColors.clock.withValues(alpha: intensity * 0.7)
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = CircuitColors.clock.withValues(alpha: intensity)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
  }

  void _wires(Canvas canvas, List<CircuitWire> wires, double intensity) {
    for (final wire in wires) {
      final path = Path()..moveTo(wire.points.first.dx, wire.points.first.dy);
      for (final point in wire.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      _highlight(canvas, path, intensity);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _wires(canvas, inputPaths, inputIntensity);
    _wires(canvas, clockPaths, clockIntensity);
    for (final rect in inputLabels) {
      _highlight(
        canvas,
        Path()
          ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6))),
        inputIntensity,
      );
    }
    // Every stage receives exactly the same intensity on the same frame.
    for (final rect in flipFlops) {
      _highlight(
        canvas,
        Path()
          ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10))),
        captureIntensity,
      );
    }
  }

  @override
  bool shouldRepaint(ParallelCapturePainter oldDelegate) =>
      inputIntensity != oldDelegate.inputIntensity ||
      clockIntensity != oldDelegate.clockIntensity ||
      captureIntensity != oldDelegate.captureIntensity ||
      inputPaths != oldDelegate.inputPaths ||
      clockPaths != oldDelegate.clockPaths ||
      inputLabels != oldDelegate.inputLabels ||
      flipFlops != oldDelegate.flipFlops;
}
