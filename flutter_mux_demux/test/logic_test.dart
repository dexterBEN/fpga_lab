import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mux_demux/features/mux_demux/data/mux_demux_repository.dart';
import 'package:flutter_mux_demux/features/mux_demux/bloc/mux_demux_cubit.dart';
import 'package:flutter_mux_demux/features/mux_demux/model/circuit_state.dart';

void main() {
  test('MUX: all 64 combinations match the selection table', () async {
    final repository = LocalMuxDemuxRepository();
    addTearDown(repository.dispose);
    for (var bits = 0; bits < 16; bits++) {
      for (var i = 0; i < 4; i++) {
        await repository.setMuxInput(i, bits & (1 << i) != 0);
      }
      for (var selector = 0; selector < 4; selector++) {
        expect(
          (await repository.setSelector(selector)).muxOutput,
          bits & (1 << selector) != 0,
        );
      }
    }
  });
  test('DEMUX: all eight combinations leave other outputs low', () async {
    final repository = LocalMuxDemuxRepository();
    addTearDown(repository.dispose);
    for (final input in [false, true]) {
      await repository.setDemuxInput(input);
      for (var selector = 0; selector < 4; selector++) {
        expect(
          (await repository.setSelector(selector)).demuxOutputs,
          List.generate(4, (i) => i == selector && input),
        );
      }
    }
  });
  test(
    'Cubit retains inputs across tab changes and exposes immutable snapshots',
    () async {
      final cubit = MuxDemuxCubit(LocalMuxDemuxRepository());
      final previous = cubit.state;
      await cubit.setMuxInput(0, true);
      await cubit.setSelector(0);
      await cubit.setMode(CircuitMode.demux);
      await cubit.setDemuxInput(false);
      await cubit.setMode(CircuitMode.mux);
      expect(cubit.state.muxOutput, true);
      expect(previous.muxInputs[0], false);
      expect(() => cubit.state.muxInputs[0] = false, throwsUnsupportedError);
      await expectLater(cubit.setSelector(4), throwsRangeError);
      await cubit.close();
    },
  );
  test(
    'Local streams publish once per command and close on disposal',
    () async {
      final local = LocalMuxDemuxRepository();
      final cubit = MuxDemuxCubit(local);
      final received = <CircuitState>[];
      final sub = cubit.stream.listen(received.add);
      await cubit.setSelector(2);
      await cubit.setDemuxInput(false);
      await Future<void>.delayed(Duration.zero);
      expect(received, hasLength(2));
      expect(received.last.demuxOutputs, [false, false, false, false]);
      await sub.cancel();
      await cubit.close();
      await expectLater(local.setSelector(0), throwsStateError);
      await local.dispose();
    },
  );
  test(
    'copyWith explicitly clears optional outputs/errors without resetting them implicitly',
    () {
      final state = CircuitState(remoteMuxOutput: true, lastError: 'previous');
      expect(state.copyWith().remoteMuxOutput, true);
      expect(state.copyWith(remoteMuxOutput: false).remoteMuxOutput, false);
      final cleared = state.copyWith(
        clearRemoteMuxOutput: true,
        clearError: true,
      );
      expect(cleared.remoteMuxOutput, isNull);
      expect(cleared.lastError, isNull);
      expect(state.lastError, 'previous');
    },
  );
}
