import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpga_register_control/bloc/register_system/register_bloc.dart';
import 'package:fpga_register_control/bloc/register_system/register_event.dart';
import 'package:fpga_register_control/models/register_mode.dart';
import 'package:fpga_register_control/models/register_snapshot.dart';
import 'package:fpga_register_control/models/register_value.dart';
import 'package:fpga_register_control/repository/register_repository.dart';
import 'package:fpga_register_control/repository/register_server_exception.dart';
import 'package:fpga_register_control/ui/widgets/flip_flop_widget.dart';
import 'package:fpga_register_control/ui/views/register_system_view.dart';
import 'package:fpga_register_control/ui/widgets/shift_transition_overlay.dart';
import 'package:fpga_register_control/ui/widgets/parallel_capture_overlay.dart';
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

  RegisterBloc registerBloc(WidgetTester tester) =>
      tester.element(find.byType(RegisterSystemView)).read<RegisterBloc>();

  List<int?> shiftBits(WidgetTester tester) => [
    for (var index = 0; index < 4; index++)
      tester.widget<FlipFlopWidget>(find.byKey(Key('shift_ff_$index'))).qBit,
  ];

  List<int?> parallelBits(WidgetTester tester) => [
    for (final index in [3, 2, 1, 0])
      tester.widget<FlipFlopWidget>(find.byKey(Key('parallel_ff_$index'))).qBit,
  ];

  List<int?> parallelInputs(WidgetTester tester) => [
    for (final index in [3, 2, 1, 0])
      tester.widget<FlipFlopWidget>(find.byKey(Key('parallel_ff_$index'))).dBit,
  ];

  Future<void> flushResponse(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  Future<void> finishShiftReplay(WidgetTester tester) => tester.pump(
    // Flutter completes the simulation on the first frame AFTER its duration.
    RegisterSystemView.shiftAnimationDuration + const Duration(milliseconds: 1),
  );

  Future<void> finishParallelReplay(WidgetTester tester) => tester.pump(
    RegisterSystemView.parallelAnimationDuration +
        const Duration(milliseconds: 1),
  );

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
    'LOAD highlights four independent inputs and captures all FFs together after confirmation',
    (tester) async {
      final response = Completer<RegisterSnapshot>();
      when(() => repository.loadParallel(5)).thenAnswer((_) => response.future);
      await mount(tester);
      await connect(tester);
      registerBloc(tester).add(const ParallelLoadRequested(5));
      await flushResponse(tester);
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byType(ParallelCaptureOverlay), findsNothing);
      expect(parallelBits(tester), [1, 0, 1, 0]);
      expect(textAt(tester, 'parallel_binary'), 'Binary: 1010');

      // The command's D value is 0101; the returned Q is deliberately different.
      // This response, rather than an optimistic copy from D, must win.
      response.complete(snapshot(parallel: 3));
      await flushResponse(tester);
      expect(parallelInputs(tester), [0, 1, 0, 1]);
      expect(parallelBits(tester), [1, 0, 1, 0]);
      expect(find.text('Previous confirmed Q[3:0]'), findsOneWidget);
      expect(find.byType(ShiftTransitionOverlay), findsNothing);
      expectCommandsEnabled(tester, false);

      await tester.pump(const Duration(milliseconds: 175));
      final inputs = tester.widget<ParallelCaptureOverlay>(
        find.byType(ParallelCaptureOverlay),
      );
      expect(inputs.inputIntensity, closeTo(1, 0.001));
      expect(inputs.captureIntensity, 0);
      expect(inputs.inputPaths.map((path) => path.label), [
        'D3 to FF3.D',
        'D2 to FF2.D',
        'D1 to FF1.D',
        'D0 to FF0.D',
      ]);
      expect(inputs.inputPaths.map((path) => path.bit), [0, 1, 0, 1]);
      expect(inputs.inputLabels, hasLength(4));
      for (var index = 0; index < 4; index++) {
        expect(
          inputs.inputPaths[index].points.last,
          inputs.flipFlops[index].topLeft +
              const Offset(0, FlipFlopWidget.dataPinY),
        );
      }
      expect(parallelBits(tester), [1, 0, 1, 0]);

      await tester.pump(const Duration(milliseconds: 175));
      final pulse =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const Key('parallel_capture_pulse')),
                  )
                  .painter!
              as ParallelCapturePainter;
      expect(pulse.clockIntensity, greaterThan(0.9));
      expect(pulse.captureIntensity, greaterThan(0));
      expect(pulse.clockPaths, hasLength(5)); // One bus plus four shared taps.
      expect(
        pulse.flipFlops,
        hasLength(4),
      ); // All receive one common intensity.
      expect(parallelBits(tester), [1, 0, 1, 0]);
      expect(textAt(tester, 'parallel_binary'), 'Binary: 1010');
      expect(textAt(tester, 'parallel_decimal'), 'Decimal: 10');

      await tester.pump(const Duration(milliseconds: 349));
      expect(parallelBits(tester), [1, 0, 1, 0]);
      await tester.pump(const Duration(milliseconds: 2));
      expect(find.byType(ParallelCaptureOverlay), findsNothing);
      expect(parallelBits(tester), [0, 0, 1, 1]);
      expect(textAt(tester, 'parallel_binary'), 'Binary: 0011');
      expect(textAt(tester, 'parallel_decimal'), 'Decimal: 3');
      expectCommandsEnabled(tester, true);
    },
  );

  testWidgets(
    'consecutive LOAD confirmations replay once each without overlapping',
    (tester) async {
      when(
        () => repository.loadParallel(5),
      ).thenAnswer((_) async => snapshot(parallel: 4));
      when(
        () => repository.loadParallel(15),
      ).thenAnswer((_) async => snapshot(parallel: 9));
      await mount(tester);
      await connect(tester);
      registerBloc(tester)
        ..add(const ParallelLoadRequested(5))
        ..add(const ParallelLoadRequested(15));
      await flushResponse(tester);
      expect(find.byType(ParallelCaptureOverlay), findsOneWidget);
      expect(parallelBits(tester), [1, 0, 1, 0]);
      expect(parallelInputs(tester), [0, 1, 0, 1]);
      expectCommandsEnabled(tester, false);

      await finishParallelReplay(tester);
      expect(find.byType(ParallelCaptureOverlay), findsOneWidget);
      expect(parallelBits(tester), [0, 1, 0, 0]);
      expect(textAt(tester, 'parallel_decimal'), 'Decimal: 4');
      expect(parallelInputs(tester), [1, 1, 1, 1]);
      expect(
        tester
            .widget<ParallelCaptureOverlay>(find.byType(ParallelCaptureOverlay))
            .progress,
        0,
      );
      expectCommandsEnabled(tester, false);

      await finishParallelReplay(tester);
      expect(find.byType(ParallelCaptureOverlay), findsNothing);
      expect(parallelBits(tester), [1, 0, 0, 1]);
      expect(textAt(tester, 'parallel_binary'), 'Binary: 1001');
      expect(textAt(tester, 'parallel_decimal'), 'Decimal: 9');
      expectCommandsEnabled(tester, true);
      verifyInOrder([
        () => repository.loadParallel(5),
        () => repository.loadParallel(15),
      ]);
    },
  );

  testWidgets(
    'repeated LOADs with unchanged snapshots still have distinct capture pulses',
    (tester) async {
      when(
        () => repository.loadParallel(10),
      ).thenAnswer((_) async => initialSnapshot);
      await mount(tester);
      await connect(tester);
      registerBloc(tester)
        ..add(const ParallelLoadRequested(10))
        ..add(const ParallelLoadRequested(10));
      await flushResponse(tester);
      expect(find.byType(ParallelCaptureOverlay), findsOneWidget);
      await finishParallelReplay(tester);
      expect(find.byType(ParallelCaptureOverlay), findsOneWidget);
      await finishParallelReplay(tester);
      expect(find.byType(ParallelCaptureOverlay), findsNothing);
      expect(parallelBits(tester), [1, 0, 1, 0]);
      verify(() => repository.loadParallel(10)).called(2);
    },
  );

  testWidgets('failed LOAD retains confirmed values without a capture pulse', (
    tester,
  ) async {
    final response = Completer<RegisterSnapshot>();
    when(() => repository.loadParallel(0)).thenAnswer((_) => response.future);
    await mount(tester);
    await connect(tester);
    await tester.tap(find.byKey(const Key('load_parallel')));
    await flushResponse(tester);
    expect(find.byType(ParallelCaptureOverlay), findsNothing);
    response.completeError(const RegisterServerException('LOAD rejected'));
    await flushResponse(tester);
    expect(find.byType(ParallelCaptureOverlay), findsNothing);
    expect(find.textContaining('LOAD rejected'), findsOneWidget);
    expect(parallelBits(tester), [1, 0, 1, 0]);
    expect(textAt(tester, 'parallel_decimal'), 'Decimal: 10');
    expectCommandsEnabled(tester, true);
  });

  testWidgets('read, SHIFT and mode changes do not trigger PIPO capture', (
    tester,
  ) async {
    await mount(tester);
    await connect(tester);
    when(
      () => repository.getState(),
    ).thenAnswer((_) async => snapshot(parallel: 0));
    when(
      () => repository.shiftBit(1),
    ).thenAnswer((_) async => snapshot(parallel: 4));
    when(
      () => repository.selectMode(RegisterMode.shift),
    ).thenAnswer((_) async => snapshot(parallel: 15));
    for (final event in const <RegisterEvent>[
      RegisterStateRequested(),
      ShiftRequested(1),
      RegisterModeChanged(RegisterMode.shift),
    ]) {
      registerBloc(tester).add(event);
      await flushResponse(tester);
      expect(find.byType(ParallelCaptureOverlay), findsNothing);
    }
    expect(textAt(tester, 'parallel_binary'), 'Binary: 1111');
  });

  testWidgets('connection loss cancels active and queued PIPO captures', (
    tester,
  ) async {
    when(
      () => repository.loadParallel(5),
    ).thenAnswer((_) async => snapshot(parallel: 4));
    when(
      () => repository.loadParallel(15),
    ).thenAnswer((_) async => snapshot(parallel: 9));
    await mount(tester);
    await connect(tester);
    registerBloc(tester)
      ..add(const ParallelLoadRequested(5))
      ..add(const ParallelLoadRequested(15));
    await flushResponse(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ParallelCaptureOverlay), findsOneWidget);
    connected = false;
    connectionChanges.add(false);
    await flushResponse(tester);
    expect(find.byType(ParallelCaptureOverlay), findsNothing);
    expect(parallelBits(tester), [1, 0, 0, 1]);
    expect(textAt(tester, 'parallel_decimal'), 'Decimal: 9');
    expect(textAt(tester, 'stale_snapshot'), contains('disconnected'));
    expectCommandsEnabled(tester, false);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(ParallelCaptureOverlay), findsNothing);
  });

  testWidgets(
    'late LOAD confirmation across reconnect waits for a fresh baseline without replay',
    (tester) async {
      final response = Completer<RegisterSnapshot>();
      when(() => repository.loadParallel(0)).thenAnswer((_) => response.future);
      await mount(tester);
      await connect(tester);
      registerBloc(tester).add(const ParallelLoadRequested(0));
      await flushResponse(tester);
      connected = false;
      connectionChanges.add(false);
      await flushResponse(tester);
      final refresh = Completer<RegisterSnapshot>();
      when(() => repository.getState()).thenAnswer((_) => refresh.future);
      await connect(tester, settle: false);
      response.complete(snapshot(parallel: 4));
      await flushResponse(tester);
      expect(find.byType(ParallelCaptureOverlay), findsNothing);
      expect(
        textAt(tester, 'stale_snapshot'),
        contains('fresh hardware response'),
      );
      refresh.complete(snapshot(parallel: 9));
      await tester.pumpAndSettle();
      expect(find.byType(ParallelCaptureOverlay), findsNothing);
      expect(textAt(tester, 'parallel_decimal'), 'Decimal: 9');
      expect(find.byKey(const Key('stale_snapshot')), findsNothing);
    },
  );

  testWidgets(
    'LOAD can replay from unknown Q without inventing a previous value',
    (tester) async {
      when(() => repository.getState()).thenAnswer((_) async {
        throw const RegisterServerException('Read unavailable');
      });
      when(
        () => repository.loadParallel(5),
      ).thenAnswer((_) async => snapshot(parallel: 5));
      await mount(tester);
      await connect(tester);
      registerBloc(tester).add(const ParallelLoadRequested(5));
      await flushResponse(tester);
      expect(find.byType(ParallelCaptureOverlay), findsOneWidget);
      expect(parallelBits(tester), [null, null, null, null]);
      expect(textAt(tester, 'parallel_binary'), 'Binary: —');
      await finishParallelReplay(tester);
      expect(parallelBits(tester), [0, 1, 0, 1]);
      expect(textAt(tester, 'parallel_decimal'), 'Decimal: 5');
    },
  );

  testWidgets(
    'reduced-motion preference skips PIPO replay and shows confirmed values',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      when(
        () => repository.loadParallel(5),
      ).thenAnswer((_) async => snapshot(parallel: 3));
      await mount(tester);
      await connect(tester);
      registerBloc(tester).add(const ParallelLoadRequested(5));
      await flushResponse(tester);
      expect(find.byType(ParallelCaptureOverlay), findsNothing);
      expect(parallelBits(tester), [0, 0, 1, 1]);
      expect(textAt(tester, 'parallel_decimal'), 'Decimal: 3');
      expectCommandsEnabled(tester, true);
    },
  );

  testWidgets(
    'unmounting during PIPO capture disposes the controller and pending replays',
    (tester) async {
      when(
        () => repository.loadParallel(0),
      ).thenAnswer((_) async => initialSnapshot);
      await mount(tester);
      await connect(tester);
      registerBloc(tester)
        ..add(const ParallelLoadRequested(0))
        ..add(const ParallelLoadRequested(0));
      await flushResponse(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ParallelCaptureOverlay), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
      verify(() => repository.dispose()).called(1);
    },
  );

  testWidgets(
    'confirmed SHIFT replays all paths and a shared clock before updating Q together',
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
      await flushResponse(tester);
      await tester.pump(const Duration(milliseconds: 400));

      // A submitted request is not a successful hardware operation.
      expect(find.byType(ShiftTransitionOverlay), findsNothing);
      expect(shiftBits(tester), [1, 1, 0, 1]);

      // Neither the count nor the returned bits are inferred locally. This
      // intentionally differs from shifting 1011 with serial input 1.
      response.complete(snapshot(shift: 4));
      await flushResponse(tester);
      final overlay = tester.widget<ShiftTransitionOverlay>(
        find.byType(ShiftTransitionOverlay),
      );
      expect(overlay.dataPaths.map((path) => path.label), [
        'Serial input to FF0.D',
        'FF0.Q to FF1.D',
        'FF1.Q to FF2.D',
        'FF2.Q to FF3.D',
        'FF3.Q discarded on SHIFT',
      ]);
      expect(overlay.dataPaths.map((path) => path.bit), [1, 1, 1, 0, 1]);
      expect(overlay.clockPaths, hasLength(5));
      expect(overlay.clockPaths.every((path) => path.clock), isTrue);
      expect(find.text('Previous confirmed Q[3:0]'), findsOneWidget);
      expectCommandsEnabled(tester, false);
      final starts = [
        for (var index = 0; index < 5; index++)
          tester.getCenter(find.byKey(Key('shift_travel_$index'))),
      ];

      await tester.pump(const Duration(milliseconds: 300));
      for (var index = 0; index < 5; index++) {
        final now = tester.getCenter(find.byKey(Key('shift_travel_$index')));
        expect(now.dx, greaterThan(starts[index].dx));
        expect(now.dy, starts[index].dy);
      }
      expect(shiftBits(tester), [1, 1, 0, 1]);
      expect(textAt(tester, 'shift_binary'), 'Binary: 1011');

      await tester.pump(const Duration(milliseconds: 450));
      final pulse =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const Key('shift_clock_pulse')),
                  )
                  .painter!
              as SharedClockPulsePainter;
      expect(pulse.intensity, greaterThan(0.9));
      expect(pulse.paths, hasLength(5));
      expect(shiftBits(tester), [1, 1, 0, 1]);

      await tester.pump(const Duration(milliseconds: 149));
      expect(shiftBits(tester), [1, 1, 0, 1]);
      await tester.pump(const Duration(milliseconds: 2));
      expect(find.byType(ShiftTransitionOverlay), findsNothing);
      expect(shiftBits(tester), [0, 0, 1, 0]);
      expect(textAt(tester, 'shift_binary'), 'Binary: 0100');
      expectCommandsEnabled(tester, true);
    },
  );

  testWidgets('failed SHIFT never starts a successful replay', (tester) async {
    when(() => repository.shiftBit(0)).thenAnswer((_) async {
      throw const RegisterServerException('SHIFT rejected');
    });
    await mount(tester);
    await connect(tester);
    await tester.tap(find.byKey(const Key('shift_register')));
    await flushResponse(tester);

    expect(find.byType(ShiftTransitionOverlay), findsNothing);
    expect(find.textContaining('SHIFT rejected'), findsOneWidget);
    expect(shiftBits(tester), [1, 1, 0, 1]);
    expectCommandsEnabled(tester, true);
  });

  testWidgets('read, LOAD and mode confirmations never masquerade as SHIFT', (
    tester,
  ) async {
    await mount(tester);
    await connect(tester);
    when(
      () => repository.getState(),
    ).thenAnswer((_) async => snapshot(shift: 2, shiftCount: 1));
    when(
      () => repository.loadParallel(5),
    ).thenAnswer((_) async => snapshot(shift: 6, shiftCount: 2));
    when(
      () => repository.selectMode(RegisterMode.shift),
    ).thenAnswer((_) async => snapshot(shift: 15, shiftCount: 3));
    final bloc = registerBloc(tester);
    for (final event in const <RegisterEvent>[
      RegisterStateRequested(),
      ParallelLoadRequested(5),
      RegisterModeChanged(RegisterMode.shift),
    ]) {
      bloc.add(event);
      await flushResponse(tester);
      expect(find.byType(ShiftTransitionOverlay), findsNothing);
    }
    expect(textAt(tester, 'shift_binary'), 'Binary: 1111');
  });

  testWidgets(
    'consecutive confirmed SHIFTs replay in submission order without overlap',
    (tester) async {
      when(
        () => repository.shiftBit(1),
      ).thenAnswer((_) async => snapshot(shift: 4));
      when(
        () => repository.shiftBit(0),
      ).thenAnswer((_) async => snapshot(shift: 9));
      await mount(tester);
      await connect(tester);
      final bloc = registerBloc(tester);
      bloc.add(const ShiftRequested(1));
      bloc.add(const ShiftRequested(0));
      await flushResponse(tester);

      expect(find.byType(ShiftTransitionOverlay), findsOneWidget);
      expect(shiftBits(tester), [1, 1, 0, 1]);
      expect(
        tester
            .widget<ShiftTransitionOverlay>(find.byType(ShiftTransitionOverlay))
            .dataPaths
            .first
            .bit,
        1,
      );
      expectCommandsEnabled(tester, false);

      await finishShiftReplay(tester);
      expect(find.byType(ShiftTransitionOverlay), findsOneWidget);
      expect(shiftBits(tester), [0, 0, 1, 0]);
      final second = tester.widget<ShiftTransitionOverlay>(
        find.byType(ShiftTransitionOverlay),
      );
      expect(second.progress, 0);
      expect(second.dataPaths.map((path) => path.bit), [0, 0, 0, 1, 0]);
      expectCommandsEnabled(tester, false);

      await finishShiftReplay(tester);
      expect(find.byType(ShiftTransitionOverlay), findsNothing);
      expect(shiftBits(tester), [1, 0, 0, 1]);
      expectCommandsEnabled(tester, true);
      verifyInOrder([
        () => repository.shiftBit(1),
        () => repository.shiftBit(0),
      ]);
    },
  );

  testWidgets(
    'a SHIFT with unchanged bits still replays its confirmed operation',
    (tester) async {
      when(
        () => repository.shiftBit(0),
      ).thenAnswer((_) async => initialSnapshot);
      await mount(tester);
      await connect(tester);
      registerBloc(tester).add(const ShiftRequested(0));
      await flushResponse(tester);
      expect(find.byType(ShiftTransitionOverlay), findsOneWidget);
      await finishShiftReplay(tester);
      expect(find.byType(ShiftTransitionOverlay), findsNothing);
      expect(shiftBits(tester), [1, 1, 0, 1]);
    },
  );

  testWidgets(
    'a late SHIFT response after connection loss cannot start a replay',
    (tester) async {
      final response = Completer<RegisterSnapshot>();
      when(() => repository.shiftBit(0)).thenAnswer((_) => response.future);
      await mount(tester);
      await connect(tester);
      registerBloc(tester).add(const ShiftRequested(0));
      await flushResponse(tester);
      connected = false;
      connectionChanges.add(false);
      await flushResponse(tester);

      response.complete(snapshot(shift: 4));
      await flushResponse(tester);
      expect(find.byType(ShiftTransitionOverlay), findsNothing);
      expect(textAt(tester, 'stale_snapshot'), contains('disconnected'));
      expectCommandsEnabled(tester, false);

      // Reconnection refreshes the baseline; that read must not replay a SHIFT.
      await connect(tester);
      expect(find.byType(ShiftTransitionOverlay), findsNothing);
      expect(shiftBits(tester), [1, 1, 0, 1]);
      when(
        () => repository.shiftBit(0),
      ).thenAnswer((_) async => snapshot(shift: 6));
      registerBloc(tester).add(const ShiftRequested(0));
      await flushResponse(tester);
      expect(find.byType(ShiftTransitionOverlay), findsOneWidget);
      await tester.pumpAndSettle();
      expect(textAt(tester, 'shift_binary'), 'Binary: 0110');
    },
  );

  testWidgets(
    'an old-session confirmation after reconnection is not replayed',
    (tester) async {
      final shiftResponse = Completer<RegisterSnapshot>();
      when(
        () => repository.shiftBit(0),
      ).thenAnswer((_) => shiftResponse.future);
      await mount(tester);
      await connect(tester);
      registerBloc(tester).add(const ShiftRequested(0));
      await flushResponse(tester);
      connected = false;
      connectionChanges.add(false);
      await flushResponse(tester);

      final refreshResponse = Completer<RegisterSnapshot>();
      when(
        () => repository.getState(),
      ).thenAnswer((_) => refreshResponse.future);
      await connect(tester, settle: false);
      shiftResponse.complete(snapshot(shift: 4));
      await flushResponse(tester);
      expect(find.byType(ShiftTransitionOverlay), findsNothing);
      expect(
        textAt(tester, 'stale_snapshot'),
        contains('fresh hardware response'),
      );
      expectCommandsEnabled(tester, false);

      refreshResponse.complete(snapshot(shift: 9));
      await tester.pumpAndSettle();
      expect(find.byType(ShiftTransitionOverlay), findsNothing);
      expect(find.byKey(const Key('stale_snapshot')), findsNothing);
      expect(shiftBits(tester), [1, 0, 0, 1]);
    },
  );

  testWidgets('SHIFT without a previous hardware sample does not invent one', (
    tester,
  ) async {
    when(() => repository.getState()).thenAnswer((_) async {
      throw const RegisterServerException('Read unavailable');
    });
    when(
      () => repository.shiftBit(0),
    ).thenAnswer((_) async => snapshot(shift: 4));
    await mount(tester);
    await connect(tester);
    expect(shiftBits(tester), [null, null, null, null]);
    registerBloc(tester).add(const ShiftRequested(0));
    await flushResponse(tester);
    expect(find.byType(ShiftTransitionOverlay), findsNothing);
    expect(shiftBits(tester), [0, 0, 1, 0]);
  });

  testWidgets('connection loss cancels both active and queued SHIFT replays', (
    tester,
  ) async {
    when(
      () => repository.shiftBit(1),
    ).thenAnswer((_) async => snapshot(shift: 4));
    when(
      () => repository.shiftBit(0),
    ).thenAnswer((_) async => snapshot(shift: 9));
    await mount(tester);
    await connect(tester);
    registerBloc(tester)
      ..add(const ShiftRequested(1))
      ..add(const ShiftRequested(0));
    await flushResponse(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ShiftTransitionOverlay), findsOneWidget);
    connected = false;
    connectionChanges.add(false);
    await flushResponse(tester);

    expect(find.byType(ShiftTransitionOverlay), findsNothing);
    expect(find.byKey(const Key('shift_clock_pulse')), findsNothing);
    expect(shiftBits(tester), [1, 0, 0, 1]);
    expect(textAt(tester, 'stale_snapshot'), contains('disconnected'));
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(ShiftTransitionOverlay), findsNothing);
    expectCommandsEnabled(tester, false);
  });

  testWidgets('failure of a following command cancels the active replay', (
    tester,
  ) async {
    when(
      () => repository.shiftBit(1),
    ).thenAnswer((_) async => snapshot(shift: 4));
    final response = Completer<RegisterSnapshot>();
    when(() => repository.shiftBit(0)).thenAnswer((_) => response.future);
    await mount(tester);
    await connect(tester);
    registerBloc(tester)
      ..add(const ShiftRequested(1))
      ..add(const ShiftRequested(0));
    await flushResponse(tester);
    expect(find.byType(ShiftTransitionOverlay), findsOneWidget);
    response.completeError(const RegisterServerException('SHIFT failed'));
    await flushResponse(tester);

    expect(find.byType(ShiftTransitionOverlay), findsNothing);
    expect(shiftBits(tester), [0, 0, 1, 0]);
    expect(find.textContaining('SHIFT failed'), findsOneWidget);
    expectCommandsEnabled(tester, true);
  });

  testWidgets(
    'reduced-motion preference displays the confirmed result directly',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      when(
        () => repository.shiftBit(0),
      ).thenAnswer((_) async => snapshot(shift: 4));
      await mount(tester);
      await connect(tester);
      registerBloc(tester).add(const ShiftRequested(0));
      await flushResponse(tester);
      expect(find.byType(ShiftTransitionOverlay), findsNothing);
      expect(shiftBits(tester), [0, 0, 1, 0]);
      expectCommandsEnabled(tester, true);
    },
  );

  testWidgets(
    'unmounting during a SHIFT disposes its active animation controller',
    (tester) async {
      when(
        () => repository.shiftBit(0),
      ).thenAnswer((_) async => snapshot(shift: 4));
      await mount(tester);
      await connect(tester);
      registerBloc(tester).add(const ShiftRequested(0));
      await flushResponse(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ShiftTransitionOverlay), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
      verify(() => repository.dispose()).called(1);
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
