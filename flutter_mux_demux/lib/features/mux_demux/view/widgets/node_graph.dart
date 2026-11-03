import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../app/app.dart';
import '../../bloc/mux_demux_cubit.dart';
import '../../model/circuit_state.dart';

class NodeGraph extends StatefulWidget {
  const NodeGraph({super.key, required this.state});
  final CircuitState state;
  @override
  State<NodeGraph> createState() => _NodeGraphState();
}

class _NodeGraphState extends State<NodeGraph>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final mux = s.mode == CircuitMode.mux;
    final cubit = context.read<MuxDemuxCubit>();
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: constraints.maxWidth < 570 ? 570 : constraints.maxWidth,
          height: 370,
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              Widget node(
                String label,
                bool value,
                bool selected,
                double x,
                double y, {
                VoidCallback? onTap,
              }) => Positioned(
                left: x,
                top: y,
                width: 94,
                height: 54,
                child: Semantics(
                  label:
                      '$label, ${value ? 1 : 0}${selected ? ", sélectionné" : ""}',
                  button: onTap != null,
                  child: Material(
                    color: selected ? const Color(0xFF17322E) : panel,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selected ? mint : const Color(0xFF536275),
                            width: selected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              value ? '1' : '0',
                              style: TextStyle(
                                fontSize: 18,
                                color: value ? mint : muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
              return Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) => CustomPaint(
                        painter: _Edges(
                          s,
                          controller.value,
                          MediaQuery.disableAnimationsOf(context),
                        ),
                      ),
                    ),
                  ),
                  if (mux)
                    ...List.generate(
                      4,
                      (i) => node(
                        'D$i',
                        s.muxInputs[i],
                        i == s.selector,
                        12,
                        20 + i * 70.0,
                        onTap: () => cubit.setMuxInput(i, !s.muxInputs[i]),
                      ),
                    )
                  else
                    node(
                      'D',
                      s.demuxInput,
                      true,
                      12,
                      125,
                      onTap: () => cubit.setDemuxInput(!s.demuxInput),
                    ),
                  if (mux)
                    node('Y', s.muxOutput, true, w - 106, 125)
                  else
                    ...List.generate(
                      4,
                      (i) => node(
                        'Y$i',
                        s.demuxOutputs[i],
                        i == s.selector,
                        w - 106,
                        20 + i * 70.0,
                      ),
                    ),
                  Positioned(
                    left: w / 2 - 70,
                    top: 100,
                    width: 140,
                    height: 105,
                    child: Container(
                      decoration: BoxDecoration(
                        color: panel,
                        border: Border.all(
                          color: const Color(0xFF536275),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            mux ? 'MUX 4→1' : 'DEMUX 1→4',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            mux
                                ? 'entrée D${s.selector}'
                                : 'sortie Y${s.selector}',
                            style: const TextStyle(color: mint),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: w / 2 - 60,
                    top: 285,
                    width: 120,
                    height: 60,
                    child: Container(
                      decoration: BoxDecoration(
                        color: panel,
                        border: Border.all(color: const Color(0xFF536275)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('S1 S0', style: TextStyle(color: muted)),
                          Text(
                            s.binary,
                            style: const TextStyle(color: mint, fontSize: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Edges extends CustomPainter {
  _Edges(this.state, this.progress, this.reducedMotion);
  final CircuitState state;
  final double progress;
  final bool reducedMotion;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final mux = state.mode == CircuitMode.mux;
    for (var x = 0.0; x < w; x += 22) {
      for (var y = 0.0; y < size.height; y += 22) {
        canvas.drawCircle(
          Offset(x, y),
          .7,
          Paint()..color = const Color(0xFF2B3440),
        );
      }
    }
    void edge(Offset start, Offset end, bool active) {
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          (start.dx + end.dx) / 2,
          start.dy,
          (start.dx + end.dx) / 2,
          end.dy,
          end.dx,
          end.dy,
        );
      canvas.drawPath(
        path,
        Paint()
          ..color = active ? mint : const Color(0xFF536275)
          ..strokeWidth = active ? 3 : 1.2
          ..style = PaintingStyle.stroke,
      );
      if (active && state.routedValue && !reducedMotion) {
        final metric = path.computeMetrics().first;
        final point = metric
            .getTangentForOffset(metric.length * progress)!
            .position;
        canvas.drawCircle(
          point,
          8,
          Paint()..color = mint.withValues(alpha: .16),
        );
        canvas.drawCircle(point, 3.5, Paint()..color = Colors.white);
      }
    }

    for (var i = 0; i < 4; i++) {
      if (mux) {
        edge(
          Offset(106, 47 + i * 70),
          Offset(w / 2 - 70, 120 + i * 21),
          i == state.selector,
        );
      } else {
        edge(
          Offset(w / 2 + 70, 120 + i * 21),
          Offset(w - 106, 47 + i * 70),
          i == state.selector,
        );
      }
    }
    if (mux) {
      edge(Offset(w / 2 + 70, 152), Offset(w - 106, 152), true);
    } else {
      edge(const Offset(106, 152), Offset(w / 2 - 70, 152), true);
    }
    canvas.drawLine(
      Offset(w / 2, 285),
      Offset(w / 2, 205),
      Paint()
        ..color = const Color(0xFF8090A4)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _Edges oldDelegate) => true;
}
