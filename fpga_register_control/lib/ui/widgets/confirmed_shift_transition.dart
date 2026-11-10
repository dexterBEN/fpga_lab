import '../../models/register_value.dart';

/// Presentation data captured from a successful SHIFT response. Both register
/// values are hardware-confirmed; [after] is never calculated from [before].
final class ConfirmedShiftTransition {
  const ConfirmedShiftTransition({
    required this.before,
    required this.after,
    required this.serialInput,
  }) : assert(serialInput == 0 || serialInput == 1);

  final RegisterValue before;
  final RegisterValue after;
  final int serialInput;
}
