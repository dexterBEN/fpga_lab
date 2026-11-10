import 'package:flutter/material.dart';

import 'circuit_primitives.dart';

/// Presentational rising-edge D flip-flop. Null Q means no confirmed sample.
/// D is the value currently presented at the input, not a prediction of Q.
class FlipFlopWidget extends StatelessWidget {
  const FlipFlopWidget({
    required this.label,
    required this.qBit,
    this.dBit,
    this.stale = false,
    super.key,
  }) : assert(qBit == null || qBit == 0 || qBit == 1),
       assert(dBit == null || dBit == 0 || dBit == 1);

  static const double width = 96;
  static const double height = 128;
  static const double dataPinY = 26;
  static const double clockPinX = width / 2;

  final String label;
  final int? qBit;
  final int? dBit;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final color = CircuitColors.bit(qBit, stale: stale);
    return Semantics(
      label:
          '$label, D ${dBit ?? 'unknown'}, Q ${qBit ?? 'unknown'}, rising-edge CLK${stale ? ', stale snapshot' : ''}',
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          height: height,
          child: DecoratedBox(
            key: const Key('flip_flop_body'),
            decoration: BoxDecoration(
              color: CircuitColors.surface,
              border: Border.all(color: color, width: 2),
              borderRadius: BorderRadius.circular(10),
              boxShadow: qBit == 1 && !stale
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.12),
                        blurRadius: 12,
                      ),
                    ]
                  : [],
            ),
            child: CustomPaint(
              foregroundPainter: _ClockNotchPainter(color),
              child: Stack(
                children: [
                  Positioned(
                    left: 9,
                    top: 15,
                    child: Text(
                      'D',
                      style: TextStyle(
                        color: CircuitColors.bit(dBit, stale: stale),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Positioned(
                    right: 9,
                    top: 15,
                    child: Text(
                      'Q',
                      style: TextStyle(
                        color: CircuitColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 39,
                    child: Text(
                      '${qBit ?? '—'}',
                      key: const Key('flip_flop_q'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: color,
                        fontFamily: 'monospace',
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 86,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: CircuitColors.text,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 9,
                    bottom: 7,
                    child: Text(
                      'CLK',
                      style: TextStyle(color: CircuitColors.low, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClockNotchPainter extends CustomPainter {
  const _ClockNotchPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final notch = Path()
      ..moveTo(size.width / 2 - 8, size.height - 1)
      ..lineTo(size.width / 2, size.height - 11)
      ..lineTo(size.width / 2 + 8, size.height - 1);
    canvas.drawPath(
      notch,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_ClockNotchPainter oldDelegate) =>
      oldDelegate.color != color;
}
