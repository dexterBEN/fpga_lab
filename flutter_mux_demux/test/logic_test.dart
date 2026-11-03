import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mux_demux/features/mux_demux/data/mux_demux_repository.dart';
import 'package:flutter_mux_demux/features/mux_demux/bloc/mux_demux_cubit.dart';
import 'package:flutter_mux_demux/features/mux_demux/model/circuit_state.dart';

void main() {
  test('MUX: all 64 combinations match the selection table', () {
    final repository = LocalMuxDemuxRepository();
    for (var bits = 0; bits < 16; bits++) {
      for (var i = 0; i < 4; i++) {
        repository.setMuxInput(i, bits & (1 << i) != 0);
      }
      for (var selector = 0; selector < 4; selector++) {
        expect(
          repository.setSelector(selector).muxOutput,
          bits & (1 << selector) != 0,
        );
      }
    }
  });
  test('DEMUX: all eight combinations leave other outputs low', () {
    final repository = LocalMuxDemuxRepository();
    for (final input in [false, true]) {
      repository.setDemuxInput(input);
      for (var selector = 0; selector < 4; selector++) {
        expect(
          repository.setSelector(selector).demuxOutputs,
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
      cubit.setMuxInput(0, true);
      cubit.setSelector(0);
      cubit.setMode(CircuitMode.demux);
      cubit.setDemuxInput(false);
      cubit.setMode(CircuitMode.mux);
      expect(cubit.state.muxOutput, true);
      expect(previous.muxInputs[0], false);
      expect(() => cubit.state.muxInputs[0] = false, throwsUnsupportedError);
      expect(() => cubit.setSelector(4), throwsRangeError);
      await cubit.close();
    },
  );
}
