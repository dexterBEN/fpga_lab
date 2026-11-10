import 'package:equatable/equatable.dart';

import 'json_fields.dart';

final class RegisterHistoryEntry extends Equatable {
  RegisterHistoryEntry({
    required this.action,
    this.value,
    this.bit,
    this.cycle,
    this.result,
  }) {
    if (action.trim().isEmpty) {
      throw ArgumentError.value(action, 'action', 'Must not be empty');
    }
    if (value != null) {
      RangeError.checkValueInInterval(value!, 0, 15, 'value');
    }
    if (bit != null) {
      RangeError.checkValueInInterval(bit!, 0, 1, 'bit');
    }
    if (cycle != null) {
      RangeError.checkNotNegative(cycle!, 'cycle');
    }
    if (result != null) {
      RangeError.checkValueInInterval(result!, 0, 15, 'result');
    }
  }

  factory RegisterHistoryEntry.fromJson(Map<String, dynamic> json) =>
      RegisterHistoryEntry(
        action: jsonString(json['action'], 'history.action'),
        value: jsonOptionalInteger(json['value'], 'history.value', max: 15),
        bit: jsonOptionalInteger(json['bit'], 'history.bit', max: 1),
        cycle: jsonOptionalInteger(json['cycle'], 'history.cycle'),
        result: jsonOptionalInteger(json['result'], 'history.result', max: 15),
      );

  final String action;
  final int? value;
  final int? bit;
  final int? cycle;
  final int? result;

  Map<String, dynamic> toJson() => {
    'action': action,
    if (value != null) 'value': value,
    if (bit != null) 'bit': bit,
    if (cycle != null) 'cycle': cycle,
    if (result != null) 'result': result,
  };

  @override
  List<Object?> get props => [action, value, bit, cycle, result];
}
