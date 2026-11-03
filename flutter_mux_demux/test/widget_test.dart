import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mux_demux/app/app.dart';

void main() {
  testWidgets('Switch modes and interact with the routing controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MuxDemuxApp());
    expect(find.text('Multiplexeur 4 → 1'), findsOneWidget);
    await tester.tap(find.text('DEMUX'));
    await tester.pump();
    expect(find.text('Démultiplexeur 1 → 4'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '11'));
    await tester.pump();
    expect(find.text('D → Y3'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Narrow screen remains usable without layout overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MuxDemuxApp());
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('DEMUX'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
