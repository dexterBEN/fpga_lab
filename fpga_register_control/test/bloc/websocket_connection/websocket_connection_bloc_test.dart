import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpga_register_control/bloc/websocket_connection/websocket_connection_bloc.dart';
import 'package:fpga_register_control/bloc/websocket_connection/websocket_connection_event.dart';
import 'package:fpga_register_control/bloc/websocket_connection/websocket_connection_state.dart';
import 'package:fpga_register_control/repository/register_repository.dart';

class MockRegisterRepository extends Mock implements RegisterRepository {}

void main() {
  late MockRegisterRepository repository;

  setUp(() {
    repository = MockRegisterRepository();

    when(
      () => repository.connectionChanges,
    ).thenAnswer((_) => const Stream<bool>.empty());

    when(() => repository.connect()).thenAnswer((_) async {});
    when(() => repository.ping()).thenAnswer((_) async => true);
    when(() => repository.disconnect()).thenAnswer((_) async {});
  });

  test('Initial state is disconnected', () async {
    final bloc = WebSocketConnectionBloc(repository);

    expect(bloc.state.status, WebSocketConnectionStatus.disconnected);

    await bloc.close();
  });

  blocTest<WebSocketConnectionBloc, WebSocketConnectionState>(
    'WebSocketConnectRequested emits connecting then connected',
    build: () => WebSocketConnectionBloc(repository),
    act: (bloc) => bloc.add(const WebSocketConnectRequested()),
    expect: () => [
      const WebSocketConnectionState(
        status: WebSocketConnectionStatus.connecting,
      ),
      const WebSocketConnectionState(
        status: WebSocketConnectionStatus.connected,
      ),
    ],
    verify: (_) {
      verify(() => repository.connect()).called(1);
      verify(() => repository.ping()).called(1);
    },
  );

  blocTest<WebSocketConnectionBloc, WebSocketConnectionState>(
    'Failed connection emits failure',
    setUp: () {
      when(
        () => repository.connect(),
      ).thenThrow(Exception('Connection refused'));
    },
    build: () => WebSocketConnectionBloc(repository),
    act: (bloc) => bloc.add(const WebSocketConnectRequested()),
    expect: () => [
      const WebSocketConnectionState(
        status: WebSocketConnectionStatus.connecting,
      ),
      isA<WebSocketConnectionState>()
          .having(
            (state) => state.status,
            'status',
            WebSocketConnectionStatus.failure,
          )
          .having(
            (state) => state.errorMessage,
            'errorMessage',
            contains('Connection refused'),
          ),
    ],
    verify: (_) {
      verify(() => repository.disconnect()).called(1);
    },
  );

  blocTest<WebSocketConnectionBloc, WebSocketConnectionState>(
    'WebSocketDisconnectRequested emits disconnecting then disconnected',
    build: () => WebSocketConnectionBloc(repository),
    act: (bloc) => bloc.add(const WebSocketDisconnectRequested()),
    expect: () => [
      const WebSocketConnectionState(
        status: WebSocketConnectionStatus.disconnecting,
      ),
      const WebSocketConnectionState(
        status: WebSocketConnectionStatus.disconnected,
      ),
    ],
    verify: (_) {
      verify(() => repository.disconnect()).called(1);
    },
  );
}
