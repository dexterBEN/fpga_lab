import '../../models/register_value.dart';

/// Presentation data for one successful LOAD. Inputs describe the request;
/// both Q values are server samples, never values predicted from the inputs.
final class ConfirmedParallelLoad {
  const ConfirmedParallelLoad({
    required this.before,
    required this.after,
    required this.inputValue,
  }) : assert(inputValue >= 0 && inputValue <= 15);

  final RegisterValue? before;
  final RegisterValue after;
  final int inputValue;
}
