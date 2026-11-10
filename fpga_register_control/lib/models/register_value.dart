import 'package:equatable/equatable.dart';

import 'json_fields.dart';

final class RegisterValue extends Equatable {
  RegisterValue({required this.value}) {
    RangeError.checkValueInInterval(value, 0, 15, 'value');
  }

  factory RegisterValue.fromJson(Map<String, dynamic> json) {
    final register = RegisterValue(
      value: jsonInteger(json['value'], 'value', max: 15),
    );
    if (json['bits'] != register.bits) {
      throw const FormatException('bits must match value in Q3-to-Q0 order');
    }
    final pins = json['q0_to_q3'];
    if (pins is! List || pins.length != 4) {
      throw const FormatException('q0_to_q3 must contain four bits');
    }
    final expected = register.q0ToQ3;
    for (var index = 0; index < 4; index++) {
      if (jsonInteger(pins[index], 'q0_to_q3[$index]', max: 1) !=
          expected[index]) {
        throw const FormatException(
          'q0_to_q3 must match value in Q0-to-Q3 order',
        );
      }
    }
    return register;
  }

  final int value;

  /// Human-readable binary representation, most significant bit first.
  String get bits => value.toRadixString(2).padLeft(4, '0');

  /// Physical pin ordering: least significant bit first.
  List<int> get q0ToQ3 => List<int>.unmodifiable(
    List<int>.generate(4, (index) => (value >> index) & 1),
  );

  Map<String, dynamic> toJson() => {
    'value': value,
    'bits': bits,
    'q0_to_q3': q0ToQ3,
  };

  @override
  List<Object?> get props => [value];
}
