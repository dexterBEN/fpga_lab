import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpga_register_control/bloc/register_system/register_bloc.dart';
import 'package:fpga_register_control/bloc/register_system/register_event.dart';
import 'package:fpga_register_control/bloc/register_system/register_state.dart';
import 'package:fpga_register_control/bloc/websocket_connection/websocket_connection_bloc.dart';
import 'package:fpga_register_control/bloc/websocket_connection/websocket_connection_event.dart';
import 'package:fpga_register_control/bloc/websocket_connection/websocket_connection_state.dart';
import 'package:fpga_register_control/models/register_mode.dart';
import 'package:fpga_register_control/models/register_snapshot.dart';
import 'package:fpga_register_control/models/register_value.dart';
import 'package:fpga_register_control/repository/register_repository.dart';
import 'package:fpga_register_control/repository/register_server_exception.dart';

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
  final initialSnapshot = snapshot();
  final updatedSnapshot = snapshot(parallel: 3, shift: 4, shiftCount: 17);

  setUp(() {
    repository = MockRegisterRepository();
    when(() => repository.isConnected).thenReturn(true);
  });

  test(
    'starts with no snapshot or error and does not access the repository',
    () async {
      final bloc = RegisterBloc(repository);
      addTearDown(bloc.close);

      expect(bloc.state, const RegisterState());
      expect(bloc.state.status, RegisterStatus.initial);
      expect(bloc.state.snapshot, isNull);
      expect(bloc.state.errorMessage, isNull);
      verifyZeroInteractions(repository);
    },
  );

  blocTest<RegisterBloc, RegisterState>(
    'retrieves hardware state',
    setUp: () {
      when(
        () => repository.getState(),
      ).thenAnswer((_) async => initialSnapshot);
    },
    build: () => RegisterBloc(repository),
    act: (bloc) => bloc.add(const RegisterStateRequested()),
    expect: () => [
      const RegisterState(status: RegisterStatus.loading),
      RegisterState(status: RegisterStatus.ready, snapshot: initialSnapshot),
    ],
    verify: (bloc) {
      verify(() => repository.getState()).called(1);
      expect(identical(bloc.state.snapshot, initialSnapshot), isTrue);
    },
  );

  blocTest<RegisterBloc, RegisterState>(
    'loads the parallel register and uses the actual returned snapshot',
    setUp: () {
      when(
        () => repository.loadParallel(10),
      ).thenAnswer((_) async => updatedSnapshot);
    },
    build: () => RegisterBloc(repository),
    seed: () =>
        RegisterState(status: RegisterStatus.ready, snapshot: initialSnapshot),
    act: (bloc) => bloc.add(const ParallelLoadRequested(10)),
    expect: () => [
      RegisterState(status: RegisterStatus.loading, snapshot: initialSnapshot),
      RegisterState(status: RegisterStatus.ready, snapshot: updatedSnapshot),
    ],
    verify: (bloc) {
      verify(() => repository.loadParallel(10)).called(1);
      expect(identical(bloc.state.snapshot, updatedSnapshot), isTrue);
    },
  );

  blocTest<RegisterBloc, RegisterState>(
    'shifts the requested bit without calculating the next register value',
    setUp: () {
      when(
        () => repository.shiftBit(1),
      ).thenAnswer((_) async => updatedSnapshot);
    },
    build: () => RegisterBloc(repository),
    seed: () =>
        RegisterState(status: RegisterStatus.ready, snapshot: initialSnapshot),
    act: (bloc) => bloc.add(const ShiftRequested(1)),
    expect: () => [
      RegisterState(status: RegisterStatus.loading, snapshot: initialSnapshot),
      RegisterState(status: RegisterStatus.ready, snapshot: updatedSnapshot),
    ],
    verify: (_) {
      verify(() => repository.shiftBit(1)).called(1);
    },
  );

  blocTest<RegisterBloc, RegisterState>(
    'selects the requested mode without assuming the server accepted it',
    setUp: () {
      when(
        () => repository.selectMode(RegisterMode.shift),
      ).thenAnswer((_) async => updatedSnapshot);
    },
    build: () => RegisterBloc(repository),
    act: (bloc) => bloc.add(const RegisterModeChanged(RegisterMode.shift)),
    expect: () => [
      const RegisterState(status: RegisterStatus.loading),
      RegisterState(status: RegisterStatus.ready, snapshot: updatedSnapshot),
    ],
    verify: (_) {
      verify(() => repository.selectMode(RegisterMode.shift)).called(1);
    },
  );

  blocTest<RegisterBloc, RegisterState>(
    'reports a repository failure without inventing an initial snapshot',
    setUp: () {
      when(
        () => repository.getState(),
      ).thenThrow(const RegisterServerException('MMIO unavailable'));
    },
    build: () => RegisterBloc(repository),
    act: (bloc) => bloc.add(const RegisterStateRequested()),
    expect: () => [
      const RegisterState(status: RegisterStatus.loading),
      const RegisterState(
        status: RegisterStatus.failure,
        errorMessage: 'RegisterServerException: MMIO unavailable',
      ),
    ],
  );

  blocTest<RegisterBloc, RegisterState>(
    'retains the last successful snapshot on async failure and continues the queue',
    setUp: () {
      when(
        () => repository.getState(),
      ).thenAnswer((_) async => initialSnapshot);
      when(() => repository.loadParallel(10)).thenAnswer((_) async {
        throw const RegisterServerException('Load rejected');
      });
      when(
        () => repository.shiftBit(1),
      ).thenAnswer((_) async => updatedSnapshot);
    },
    build: () => RegisterBloc(repository),
    act: (bloc) => bloc
      ..add(const RegisterStateRequested())
      ..add(const ParallelLoadRequested(10))
      ..add(const ShiftRequested(1)),
    expect: () => [
      const RegisterState(status: RegisterStatus.loading),
      RegisterState(status: RegisterStatus.ready, snapshot: initialSnapshot),
      RegisterState(status: RegisterStatus.loading, snapshot: initialSnapshot),
      RegisterState(
        status: RegisterStatus.failure,
        snapshot: initialSnapshot,
        errorMessage: 'RegisterServerException: Load rejected',
      ),
      RegisterState(status: RegisterStatus.loading, snapshot: initialSnapshot),
      RegisterState(status: RegisterStatus.ready, snapshot: updatedSnapshot),
    ],
    verify: (_) {
      verifyInOrder([
        () => repository.getState(),
        () => repository.loadParallel(10),
        () => repository.shiftBit(1),
      ]);
    },
  );

  blocTest<RegisterBloc, RegisterState>(
    'clears a stale error when starting a new operation',
    setUp: () {
      when(
        () => repository.getState(),
      ).thenAnswer((_) async => updatedSnapshot);
    },
    build: () => RegisterBloc(repository),
    seed: () => RegisterState(
      status: RegisterStatus.failure,
      snapshot: initialSnapshot,
      errorMessage: 'Previous command failed',
    ),
    act: (bloc) => bloc.add(const RegisterStateRequested()),
    expect: () => [
      RegisterState(status: RegisterStatus.loading, snapshot: initialSnapshot),
      RegisterState(status: RegisterStatus.ready, snapshot: updatedSnapshot),
    ],
  );

  test(
    'all event types and repeated commands share one sequential queue',
    () async {
      final bloc = RegisterBloc(repository);
      addTearDown(bloc.close);
      final states = <RegisterState>[];
      final subscription = bloc.stream.listen(states.add);
      addTearDown(subscription.cancel);
      final gates = List.generate(5, (_) => Completer<RegisterSnapshot>());
      final started = List.generate(5, (_) => Completer<void>());
      final results = List.generate(
        5,
        (index) => snapshot(shiftCount: index + 1),
      );
      final calls = <String>[];
      var active = 0;
      var shiftCalls = 0;

      Future<RegisterSnapshot> execute(String command, int index) {
        calls.add(command);
        active++;
        expect(active, 1, reason: 'Hardware operations must never overlap');
        started[index].complete();
        return gates[index].future.whenComplete(() => active--);
      }

      when(
        () => repository.getState(),
      ).thenAnswer((_) => execute('get_state', 0));
      when(
        () => repository.loadParallel(10),
      ).thenAnswer((_) => execute('load_parallel', 1));
      when(
        () => repository.shiftBit(1),
      ).thenAnswer((_) => execute('shift', shiftCalls++ == 0 ? 2 : 4));
      when(
        () => repository.selectMode(RegisterMode.shift),
      ).thenAnswer((_) => execute('select_mode', 3));

      bloc
        ..add(const RegisterStateRequested())
        ..add(const ParallelLoadRequested(10))
        ..add(const ShiftRequested(1))
        ..add(const RegisterModeChanged(RegisterMode.shift))
        ..add(const ShiftRequested(1));

      const expectedCalls = [
        'get_state',
        'load_parallel',
        'shift',
        'select_mode',
        'shift',
      ];
      for (var index = 0; index < gates.length; index++) {
        await started[index].future;
        // Flush submitted events while the current operation is still unresolved.
        // Concurrent handlers or separate per-type queues would start too early.
        await Future<void>.delayed(Duration.zero);
        expect(calls, expectedCalls.take(index + 1).toList());
        gates[index].complete(results[index]);
      }
      await bloc.stream.firstWhere(
        (state) =>
            state.status == RegisterStatus.ready &&
            identical(state.snapshot, results.last),
      );
      expect(active, 0);
      expect(states, [
        for (var index = 0; index < results.length; index++) ...[
          RegisterState(
            status: RegisterStatus.loading,
            snapshot: index == 0 ? null : results[index - 1],
          ),
          RegisterState(status: RegisterStatus.ready, snapshot: results[index]),
        ],
      ]);
      verifyNever(() => repository.connect());
      verifyNever(() => repository.disconnect());
      verifyNever(() => repository.dispose());
    },
  );

  for (final event in const <RegisterEvent>[
    RegisterStateRequested(),
    ParallelLoadRequested(10),
    ShiftRequested(1),
    RegisterModeChanged(RegisterMode.shift),
  ]) {
    blocTest<RegisterBloc, RegisterState>(
      'reports $event while disconnected without sending a command',
      setUp: () {
        when(() => repository.isConnected).thenReturn(false);
      },
      build: () => RegisterBloc(repository),
      seed: () => RegisterState(
        status: RegisterStatus.ready,
        snapshot: initialSnapshot,
      ),
      act: (bloc) => bloc.add(event),
      expect: () => [
        RegisterState(
          status: RegisterStatus.loading,
          snapshot: initialSnapshot,
        ),
        isA<RegisterState>()
            .having((state) => state.status, 'status', RegisterStatus.failure)
            .having(
              (state) => state.snapshot,
              'snapshot',
              same(initialSnapshot),
            )
            .having(
              (state) => state.errorMessage,
              'errorMessage',
              contains('WebSocket is not connected'),
            ),
      ],
      verify: (_) {
        verify(() => repository.isConnected).called(1);
        verifyNoMoreInteractions(repository);
      },
    );
  }

  test(
    'rechecks connection for queued commands and can refresh after reconnect',
    () async {
      final bloc = RegisterBloc(repository);
      addTearDown(bloc.close);
      final response = Completer<RegisterSnapshot>();
      final started = Completer<void>();
      when(() => repository.getState()).thenAnswer((_) {
        started.complete();
        return response.future;
      });

      bloc
        ..add(const RegisterStateRequested())
        ..add(const ShiftRequested(1));
      await started.future;
      when(() => repository.isConnected).thenReturn(false);
      final disconnected = bloc.stream.firstWhere(
        (state) => state.status == RegisterStatus.failure,
      );
      response.complete(initialSnapshot);
      final failure = await disconnected;
      expect(failure.snapshot, same(initialSnapshot));
      expect(failure.errorMessage, contains('WebSocket is not connected'));
      verifyNever(() => repository.shiftBit(1));

      when(() => repository.isConnected).thenReturn(true);
      when(
        () => repository.getState(),
      ).thenAnswer((_) async => updatedSnapshot);
      final refreshed = bloc.stream.firstWhere(
        (state) => state.status == RegisterStatus.ready,
      );
      bloc.add(const RegisterStateRequested());
      expect((await refreshed).snapshot, same(updatedSnapshot));
      expect(bloc.state.errorMessage, isNull);
      verifyNever(() => repository.connect());
    },
  );

  test(
    'connection BLoC shares the repository and owns its connection lifecycle',
    () async {
      var connected = false;
      when(() => repository.isConnected).thenAnswer((_) => connected);
      when(
        () => repository.connectionChanges,
      ).thenAnswer((_) => const Stream<bool>.empty());
      when(() => repository.connect()).thenAnswer((_) async {
        connected = true;
      });
      when(() => repository.ping()).thenAnswer((_) async => true);
      when(() => repository.disconnect()).thenAnswer((_) async {
        connected = false;
      });
      when(
        () => repository.getState(),
      ).thenAnswer((_) async => initialSnapshot);
      final connectionBloc = WebSocketConnectionBloc(repository);
      final registerBloc = RegisterBloc(repository);
      addTearDown(connectionBloc.close);
      addTearDown(registerBloc.close);

      final connectionReady = connectionBloc.stream.firstWhere(
        (state) => state.status == WebSocketConnectionStatus.connected,
      );
      connectionBloc.add(const WebSocketConnectRequested());
      await connectionReady;
      final registersReady = registerBloc.stream.firstWhere(
        (state) => state.status == RegisterStatus.ready,
      );
      registerBloc.add(const RegisterStateRequested());
      expect((await registersReady).snapshot, same(initialSnapshot));
      await registerBloc.close();
      expect(connected, isTrue);
      verifyNever(() => repository.disconnect());
      verifyNever(() => repository.dispose());

      final disconnected = connectionBloc.stream.firstWhere(
        (state) => state.status == WebSocketConnectionStatus.disconnected,
      );
      connectionBloc.add(const WebSocketDisconnectRequested());
      await disconnected;
      expect(connected, isFalse);
      verify(() => repository.connect()).called(1);
      verify(() => repository.ping()).called(1);
      verify(() => repository.getState()).called(1);
      verify(() => repository.disconnect()).called(1);
    },
  );

  test('events compare their payloads and event types', () {
    expect(const RegisterStateRequested(), const RegisterStateRequested());
    expect(const ParallelLoadRequested(10), const ParallelLoadRequested(10));
    expect(
      const ParallelLoadRequested(10),
      isNot(const ParallelLoadRequested(11)),
    );
    expect(const ShiftRequested(1), const ShiftRequested(1));
    expect(const ShiftRequested(1), isNot(const ShiftRequested(0)));
    expect(const ParallelLoadRequested(1), isNot(const ShiftRequested(1)));
    expect(
      const RegisterModeChanged(RegisterMode.shift),
      const RegisterModeChanged(RegisterMode.shift),
    );
    expect(
      const RegisterModeChanged(RegisterMode.shift),
      isNot(const RegisterModeChanged(RegisterMode.parallel)),
    );
  });

  test('state equality includes status, snapshot and error', () {
    final state = RegisterState(
      status: RegisterStatus.ready,
      snapshot: initialSnapshot,
    );
    expect(
      state,
      RegisterState(status: RegisterStatus.ready, snapshot: snapshot()),
    );
    expect(
      state,
      isNot(
        RegisterState(
          status: RegisterStatus.loading,
          snapshot: initialSnapshot,
        ),
      ),
    );
    expect(
      state,
      isNot(
        RegisterState(status: RegisterStatus.ready, snapshot: updatedSnapshot),
      ),
    );
    expect(
      state,
      isNot(
        RegisterState(
          status: RegisterStatus.ready,
          snapshot: initialSnapshot,
          errorMessage: 'Failure',
        ),
      ),
    );
  });
}
