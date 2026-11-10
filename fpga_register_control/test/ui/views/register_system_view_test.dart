import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpga_register_control/models/register_mode.dart';
import 'package:fpga_register_control/models/register_snapshot.dart';
import 'package:fpga_register_control/models/register_value.dart';
import 'package:fpga_register_control/repository/register_repository.dart';
import 'package:fpga_register_control/repository/register_server_exception.dart';
import 'package:fpga_register_control/ui/widgets/flip_flop_widget.dart';
import 'package:fpga_register_control/main.dart';

class MockRegisterRepository extends Mock implements RegisterRepository {}

RegisterSnapshot snapshot({
  int parallel = 10,
  int shift = 11,
  RegisterMode mode = RegisterMode.parallel,
  int shiftCount = 0,
}) => RegisterSnapshot(
  parallel: RegisterValue(value: parallel),
  shift: RegisterValue(value: shift),
  selectedMode: mode,
  shiftCount: shiftCount,
  history: [],
  fclk0Mhz: 50,
  softwareResetAvailable: false,
);

void main() {
  late MockRegisterRepository repository;
  late StreamController<bool> connectionChanges;
  late bool connected;
  final initialSnapshot = snapshot();

  setUp(() {
    repository = MockRegisterRepository();
    connectionChanges = StreamController<bool>.broadcast();
    connected = false;
    when(() => repository.isConnected).thenAnswer((_) => connected);
    when(
      () => repository.connectionChanges,
    ).thenAnswer((_) => connectionChanges.stream);
    when(() => repository.connect()).thenAnswer((_) async {
      connected = true;
      connectionChanges.add(true);
    });
    when(() => repository.ping()).thenAnswer((_) async => true);
    when(() => repository.disconnect()).thenAnswer((_) async {
      connected = false;
      connectionChanges.add(false);
    });
    when(() => repository.dispose()).thenAnswer((_) async {
      connected = false;
      await connectionChanges.close();
    });
    when(() => repository.getState()).thenAnswer((_) async => initialSnapshot);
  });

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // The application owns the repository; tests do not dispose it separately.
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    await tester.pumpWidget(RegisterApp(repository: repository));
  }

  Future<void> connect(WidgetTester tester, {bool settle = true}) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
    await tester.pump();
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  String? textAt(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data;

  void expectCommandsEnabled(WidgetTester tester, bool enabled) {
    final callback = enabled ? isNotNull : isNull;
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('load_parallel')))
          .onPressed,
      callback,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('shift_register')))
          .onPressed,
      callback,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('refresh_registers')))
          .onPressed,
      callback,
    );
    expect(
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byKey(const Key('parallel_input')),
          )
          .onChanged,
      callback,
    );
    expect(
      tester
          .widget<SegmentedButton<int>>(find.byKey(const Key('serial_input')))
          .onSelectionChanged,
      callback,
    );
    expect(
      tester
          .widget<SegmentedButton<RegisterMode>>(
            find.byKey(const Key('register_mode')),
          )
          .onSelectionChanged,
      callback,
    );
  }

  testWidgets('disconnected view shows unknown values and disables commands', (
    tester,
  ) async {
    await mount(tester);

    expect(find.text('DISCONNECTED'), findsOneWidget);
    expect(find.text('No hardware snapshot received.'), findsOneWidget);
    expect(textAt(tester, 'parallel_decimal'), 'Decimal: —');
    expect(textAt(tester, 'parallel_binary'), 'Binary: —');
    expect(textAt(tester, 'shift_decimal'), 'Decimal: —');
    expect(textAt(tester, 'shift_binary'), 'Binary: —');
    expect(textAt(tester, 'confirmed_mode'), 'Confirmed mode: —');
    expect(textAt(tester, 'shift_counter'), 'Shift counter: —');
    expect(
      tester
          .widgetList<FlipFlopWidget>(find.byType(FlipFlopWidget))
          .map((stage) => stage.qBit),
      everyElement(isNull),
    );
    expect(
      tester
          .widget<SegmentedButton<RegisterMode>>(
            find.byKey(const Key('register_mode')),
          )
          .selected,
      isEmpty,
    );
    expectCommandsEnabled(tester, false);
    verifyNever(() => repository.connect());
    verifyNever(() => repository.getState());
  });

  testWidgets(
    'successful connection automatically reads the hardware snapshot',
    (tester) async {
      await mount(tester);
      await connect(tester);

      expect(find.text('CONNECTED'), findsOneWidget);
      expect(textAt(tester, 'parallel_decimal'), 'Decimal: 10');
      expect(textAt(tester, 'parallel_binary'), 'Binary: 1010');
      expect(textAt(tester, 'shift_decimal'), 'Decimal: 11');
      expect(textAt(tester, 'shift_binary'), 'Binary: 1011');
      expect(textAt(tester, 'confirmed_mode'), 'Confirmed mode: parallel');
      expect(textAt(tester, 'shift_counter'), 'Shift counter: 0');
      expect(find.byKey(const Key('stale_snapshot')), findsNothing);
      expectCommandsEnabled(tester, true);
      verify(() => repository.connect()).called(1);
      verify(() => repository.ping()).called(1);
      verify(() => repository.getState()).called(1);
    },
  );

  testWidgets('initial read displays loading without fabricating values', (
    tester,
  ) async {
    final response = Completer<RegisterSnapshot>();
    when(() => repository.getState()).thenAnswer((_) => response.future);
    await mount(tester);
    await connect(tester, settle: false);

    expect(find.byKey(const Key('register_loading')), findsOneWidget);
    expect(textAt(tester, 'parallel_decimal'), 'Decimal: —');
    expectCommandsEnabled(tester, false);
    response.complete(initialSnapshot);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('register_loading')), findsNothing);
    expect(textAt(tester, 'parallel_decimal'), 'Decimal: 10');
    expectCommandsEnabled(tester, true);
  });

  testWidgets('LOAD dispatches the input and waits for hardware confirmation', (
    tester,
  ) async {
    final response = Completer<RegisterSnapshot>();
    when(() => repository.loadParallel(3)).thenAnswer((_) => response.future);
    await mount(tester);
    await connect(tester);
    await tester.tap(find.byKey(const Key('parallel_input')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 (0011)').last);
    await tester.pumpAndSettle();

    expect(textAt(tester, 'parallel_decimal'), 'Decimal: 10');
    await tester.tap(find.byKey(const Key('load_parallel')));
    await tester.pump();
    verify(() => repository.loadParallel(3)).called(1);
    expect(textAt(tester, 'parallel_decimal'), 'Decimal: 10');
    expect(textAt(tester, 'parallel_binary'), 'Binary: 1010');
    expect(
      tester
          .widget<FlipFlopWidget>(find.byKey(const Key('parallel_ff_3')))
          .qBit,
      1,
    );
    expect(find.byKey(const Key('register_loading')), findsOneWidget);
    expectCommandsEnabled(tester, false);

    response.complete(snapshot(parallel: 3));
    await tester.pumpAndSettle();
    expect(textAt(tester, 'parallel_decimal'), 'Decimal: 3');
    expect(textAt(tester, 'parallel_binary'), 'Binary: 0011');
    expect(
      tester
          .widget<FlipFlopWidget>(find.byKey(const Key('parallel_ff_3')))
          .qBit,
      0,
    );
    expect(
      tester
          .widget<FlipFlopWidget>(find.byKey(const Key('parallel_ff_0')))
          .qBit,
      1,
    );
    expectCommandsEnabled(tester, true);
  });

  testWidgets(
    'SHIFT dispatches one bit and displays the returned value and count',
    (tester) async {
      final response = Completer<RegisterSnapshot>();
      when(() => repository.shiftBit(1)).thenAnswer((_) => response.future);
      await mount(tester);
      await connect(tester);
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('serial_input')),
          matching: find.text('1'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('shift_register')));
      await tester.pump();
      verify(() => repository.shiftBit(1)).called(1);
      expect(textAt(tester, 'shift_decimal'), 'Decimal: 11');
      expect(textAt(tester, 'shift_counter'), 'Shift counter: 0');
      expect(
        tester.widget<FlipFlopWidget>(find.byKey(const Key('shift_ff_0'))).qBit,
        1,
      );
      expectCommandsEnabled(tester, false);

      // Deliberately differs from a shift calculated from the previous snapshot.
      response.complete(snapshot(shift: 4, shiftCount: 9));
      await tester.pumpAndSettle();
      expect(textAt(tester, 'shift_decimal'), 'Decimal: 4');
      expect(textAt(tester, 'shift_binary'), 'Binary: 0100');
      expect(textAt(tester, 'shift_counter'), 'Shift counter: 9');
      expect(
        tester.widget<FlipFlopWidget>(find.byKey(const Key('shift_ff_0'))).qBit,
        0,
      );
      expect(
        tester.widget<FlipFlopWidget>(find.byKey(const Key('shift_ff_2'))).qBit,
        1,
      );
    },
  );

  testWidgets('mode selection reflects only the confirmed server mode', (
    tester,
  ) async {
    final response = Completer<RegisterSnapshot>();
    when(
      () => repository.selectMode(RegisterMode.shift),
    ).thenAnswer((_) => response.future);
    await mount(tester);
    await connect(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('register_mode')),
        matching: find.text('Shift'),
      ),
    );
    await tester.pump();

    verify(() => repository.selectMode(RegisterMode.shift)).called(1);
    expect(textAt(tester, 'confirmed_mode'), 'Confirmed mode: parallel');
    expect(
      tester
          .widget<SegmentedButton<RegisterMode>>(
            find.byKey(const Key('register_mode')),
          )
          .selected,
      {RegisterMode.parallel},
    );
    expectCommandsEnabled(tester, false);
    response.complete(snapshot(mode: RegisterMode.shift));
    await tester.pumpAndSettle();
    expect(textAt(tester, 'confirmed_mode'), 'Confirmed mode: shift');
    expect(
      tester
          .widget<SegmentedButton<RegisterMode>>(
            find.byKey(const Key('register_mode')),
          )
          .selected,
      {RegisterMode.shift},
    );
  });

  testWidgets('manual refresh replaces values only after a server response', (
    tester,
  ) async {
    await mount(tester);
    await connect(tester);
    final response = Completer<RegisterSnapshot>();
    when(() => repository.getState()).thenAnswer((_) => response.future);
    await tester.tap(find.byKey(const Key('refresh_registers')));
    await tester.pump();
    expect(textAt(tester, 'parallel_decimal'), 'Decimal: 10');
    expect(textAt(tester, 'shift_decimal'), 'Decimal: 11');
    expectCommandsEnabled(tester, false);

    response.complete(snapshot(parallel: 15, shift: 0, shiftCount: 8));
    await tester.pumpAndSettle();
    expect(textAt(tester, 'parallel_binary'), 'Binary: 1111');
    expect(textAt(tester, 'shift_binary'), 'Binary: 0000');
    expect(textAt(tester, 'shift_counter'), 'Shift counter: 8');
    verify(() => repository.getState()).called(2);
  });

  testWidgets(
    'command error retains the snapshot and refresh clears the error',
    (tester) async {
      when(() => repository.loadParallel(0)).thenAnswer((_) async {
        throw const RegisterServerException('MMIO busy');
      });
      await mount(tester);
      await connect(tester);
      await tester.tap(find.byKey(const Key('load_parallel')));
      await tester.pumpAndSettle();

      expect(find.textContaining('MMIO busy'), findsOneWidget);
      expect(find.text('Showing the last confirmed snapshot.'), findsOneWidget);
      expect(textAt(tester, 'parallel_decimal'), 'Decimal: 10');
      expectCommandsEnabled(tester, true);
      final response = Completer<RegisterSnapshot>();
      when(() => repository.getState()).thenAnswer((_) => response.future);
      await tester.tap(find.byKey(const Key('refresh_registers')));
      await tester.pump();
      expect(find.byKey(const Key('register_error')), findsNothing);
      expect(textAt(tester, 'parallel_decimal'), 'Decimal: 10');
      response.complete(snapshot(parallel: 6));
      await tester.pumpAndSettle();
      expect(textAt(tester, 'parallel_decimal'), 'Decimal: 6');
    },
  );

  testWidgets(
    'disconnection preserves a stale snapshot and reconnection refreshes it',
    (tester) async {
      await mount(tester);
      await connect(tester);
      connected = false;
      connectionChanges.add(false);
      await tester.pumpAndSettle();
      expect(find.text('DISCONNECTED'), findsOneWidget);
      expect(textAt(tester, 'parallel_decimal'), 'Decimal: 10');
      expect(textAt(tester, 'stale_snapshot'), contains('disconnected'));
      expect(
        tester
            .widgetList<FlipFlopWidget>(find.byType(FlipFlopWidget))
            .map((stage) => stage.stale),
        everyElement(isTrue),
      );
      expectCommandsEnabled(tester, false);

      final response = Completer<RegisterSnapshot>();
      when(() => repository.getState()).thenAnswer((_) => response.future);
      await connect(tester, settle: false);
      expect(find.text('CONNECTED'), findsOneWidget);
      expect(
        textAt(tester, 'stale_snapshot'),
        contains('fresh hardware response'),
      );
      expectCommandsEnabled(tester, false);
      response.complete(
        snapshot(parallel: 2, shift: 7, mode: RegisterMode.shift),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('stale_snapshot')), findsNothing);
      expect(textAt(tester, 'parallel_decimal'), 'Decimal: 2');
      expect(textAt(tester, 'shift_decimal'), 'Decimal: 7');
      verify(() => repository.getState()).called(2);
      verify(() => repository.connect()).called(2);
    },
  );

  testWidgets(
    'failed reconnect refresh leaves the previous snapshot marked stale',
    (tester) async {
      await mount(tester);
      await connect(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Disconnect'));
      await tester.pumpAndSettle();
      when(() => repository.getState()).thenAnswer((_) async {
        throw const RegisterServerException('Read unavailable');
      });
      await connect(tester);
      expect(find.textContaining('Read unavailable'), findsOneWidget);
      expect(textAt(tester, 'parallel_decimal'), 'Decimal: 10');
      expect(find.byKey(const Key('stale_snapshot')), findsOneWidget);
      expectCommandsEnabled(tester, true);
    },
  );

  testWidgets(
    'connection failure is visible and does not read or invent hardware state',
    (tester) async {
      when(
        () => repository.connect(),
      ).thenThrow(Exception('Connection refused'));
      await mount(tester);
      await connect(tester);
      expect(find.text('FAILURE'), findsOneWidget);
      expect(find.textContaining('Connection refused'), findsOneWidget);
      expect(textAt(tester, 'parallel_decimal'), 'Decimal: —');
      expectCommandsEnabled(tester, false);
      verifyNever(() => repository.getState());
    },
  );

  testWidgets(
    'app rebuild reuses the repository and shutdown disposes it once',
    (tester) async {
      await mount(tester);
      await connect(tester);
      await tester.pumpWidget(RegisterApp(repository: repository));
      await tester.pumpAndSettle();
      verifyNever(() => repository.dispose());
      verify(() => repository.connect()).called(1);
      verify(() => repository.getState()).called(1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      verify(() => repository.dispose()).called(1);
      expect(connectionChanges.isClosed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shutdown disposes shared resources during an in-flight operation',
    (tester) async {
      final response = Completer<RegisterSnapshot>();
      when(() => repository.loadParallel(0)).thenAnswer((_) => response.future);
      when(() => repository.dispose()).thenAnswer((_) async {
        response.completeError(StateError('Repository disposed'));
        connected = false;
        await connectionChanges.close();
      });
      await mount(tester);
      await connect(tester);
      await tester.tap(find.byKey(const Key('load_parallel')));
      await tester.pump();
      expect(find.byKey(const Key('register_loading')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      verify(() => repository.dispose()).called(1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'controls remain accessible without overflow on a narrow screen',
    (tester) async {
      await mount(tester);
      tester.view.physicalSize = const Size(320, 900);
      await tester.pumpAndSettle();
      await connect(tester);
      await tester.ensureVisible(find.byKey(const Key('register_mode')));
      await tester.pumpAndSettle();
      expect(find.text('Parallel'), findsOneWidget);
      expect(find.text('Shift'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
