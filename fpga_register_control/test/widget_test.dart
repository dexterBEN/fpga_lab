import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fpga_register_control/main.dart';
import 'package:fpga_register_control/repository/websocket_register_repository.dart';

void main() {
  testWidgets('Shows the disconnected connection screen', (
    WidgetTester tester,
  ) async {
    final repository = WebSocketRegisterRepository(
      url: 'ws://127.0.0.1:8765',
      token: '',
    );
    await tester.pumpWidget(RegisterApp(repository: repository));

    expect(find.text('FPGA Register Control'), findsOneWidget);
    expect(find.text('DISCONNECTED'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Connect'), findsOneWidget);
    expect(find.byIcon(Icons.link_off), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
