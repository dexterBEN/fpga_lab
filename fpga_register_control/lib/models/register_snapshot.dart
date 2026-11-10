import 'package:equatable/equatable.dart';

import 'json_fields.dart';
import 'register_history_entry.dart';
import 'register_mode.dart';
import 'register_value.dart';

/// Server-reported state. The two hardware values are read sequentially through
/// a shared MUX, not captured simultaneously. Clock frequency is server metadata.
final class RegisterSnapshot extends Equatable {
  RegisterSnapshot({
    required this.parallel,
    required this.shift,
    required this.selectedMode,
    required this.shiftCount,
    required List<RegisterHistoryEntry> history,
    required this.fclk0Mhz,
    required this.softwareResetAvailable,
  }) : history = List<RegisterHistoryEntry>.unmodifiable(history) {
    RangeError.checkNotNegative(shiftCount, 'shiftCount');
    if (!fclk0Mhz.isFinite || fclk0Mhz <= 0) {
      throw ArgumentError.value(
        fclk0Mhz,
        'fclk0Mhz',
        'Must be finite and positive',
      );
    }
  }

  factory RegisterSnapshot.fromJson(Map<String, dynamic> json) {
    final history = json['history'];
    if (history is! List) {
      throw const FormatException('history must be a JSON array');
    }
    final frequency = json['fclk0_mhz'];
    if (frequency is! num || !frequency.isFinite || frequency <= 0) {
      throw const FormatException('fclk0_mhz must be finite and positive');
    }
    final resetAvailable = json['software_reset_available'];
    if (resetAvailable is! bool) {
      throw const FormatException('software_reset_available must be a boolean');
    }
    return RegisterSnapshot(
      parallel: RegisterValue.fromJson(
        jsonObject(json['parallel'], 'parallel'),
      ),
      shift: RegisterValue.fromJson(jsonObject(json['shift'], 'shift')),
      selectedMode: RegisterMode.fromJson(json['selected_mode']),
      shiftCount: jsonInteger(json['shift_count'], 'shift_count'),
      history: history
          .map(
            (entry) => RegisterHistoryEntry.fromJson(
              jsonObject(entry, 'history entry'),
            ),
          )
          .toList(),
      fclk0Mhz: frequency.toDouble(),
      softwareResetAvailable: resetAvailable,
    );
  }

  final RegisterValue parallel;
  final RegisterValue shift;
  final RegisterMode selectedMode;

  /// Server command count, not the FPGA clock-cycle count.
  final int shiftCount;
  final List<RegisterHistoryEntry> history;
  final double fclk0Mhz;
  final bool softwareResetAvailable;

  Map<String, dynamic> toJson() => {
    'parallel': parallel.toJson(),
    'shift': shift.toJson(),
    'selected_mode': selectedMode.toJson(),
    'shift_count': shiftCount,
    'history': history.map((entry) => entry.toJson()).toList(),
    'fclk0_mhz': fclk0Mhz,
    'software_reset_available': softwareResetAvailable,
  };

  @override
  List<Object?> get props => [
    parallel,
    shift,
    selectedMode,
    shiftCount,
    history,
    fclk0Mhz,
    softwareResetAvailable,
  ];
}
