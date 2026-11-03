import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/mux_demux_repository.dart';
import '../model/circuit_state.dart';

class MuxDemuxCubit extends Cubit<CircuitState> {
  MuxDemuxCubit(this.repository) : super(repository.state);
  final MuxDemuxRepository repository;
  void setMode(CircuitMode mode) => emit(repository.setMode(mode));
  void setSelector(int value) => emit(repository.setSelector(value));
  void setMuxInput(int index, bool value) =>
      emit(repository.setMuxInput(index, value));
  void setDemuxInput(bool value) => emit(repository.setDemuxInput(value));
}
