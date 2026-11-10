import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpga_register_control/models/register_history_entry.dart';
import 'package:fpga_register_control/models/register_mode.dart';
import 'package:fpga_register_control/models/register_snapshot.dart';
import 'package:fpga_register_control/models/register_value.dart';

import '../support/register_fixtures.dart';

void main() {
  group('RegisterValue', () {
    test('distinguishes MSB-first text from Q0-to-Q3 ordering', () {
      final value = RegisterValue.fromJson(snapshotJson()['parallel']);
      expect(value.value, 10);
      expect(value.bits, '1010');
      expect(value.q0ToQ3, [0, 1, 0, 1]);
      expect(RegisterValue(value: 1).bits, '0001');
      expect(RegisterValue(value: 1).q0ToQ3, [1, 0, 0, 0]);
      expect(RegisterValue(value: 8).bits, '1000');
      expect(RegisterValue(value: 8).q0ToQ3, [0, 0, 0, 1]);
    });

    test('round trips all four-bit values and compares by value', () {
      for (var number = 0; number <= 15; number++) {
        final value = RegisterValue(value: number);
        final copy = RegisterValue.fromJson(
          jsonDecode(jsonEncode(value.toJson())),
        );
        expect(copy, value);
        expect(copy.hashCode, value.hashCode);
        expect(copy.bits, hasLength(4));
      }
      expect(RegisterValue(value: 10), isNot(RegisterValue(value: 11)));
    });

    test('rejects out-of-range constructor values', () {
      for (final number in [-1, 16]) {
        expect(() => RegisterValue(value: number), throwsRangeError);
      }
    });

    test('exposes immutable bits', () {
      final value = RegisterValue(value: 10);
      expect(() => value.q0ToQ3[0] = 1, throwsUnsupportedError);
    });

    final invalidFields = <String, Object?>{
      'negative value': {'value': -1},
      'too large value': {'value': 16},
      'fractional value': {'value': 10.0},
      'string value': {'value': '10'},
      'missing value': {'value': null},
      'missing bits': {'bits': null},
      'short bits': {'bits': '101'},
      'inconsistent bits': {'bits': '0101'},
      'nonbinary bits': {'bits': 'abcd'},
      'missing Q bits': {'q0_to_q3': null},
      'short Q bits': {
        'q0_to_q3': [0, 1, 0],
      },
      'wrong Q order': {
        'q0_to_q3': [1, 0, 1, 0],
      },
      'nonbinary Q bit': {
        'q0_to_q3': [0, 2, 0, 1],
      },
      'fractional Q bit': {
        'q0_to_q3': [0, 1.0, 0, 1],
      },
    };
    for (final entry in invalidFields.entries) {
      test('rejects ${entry.key}', () {
        final json = Map<String, dynamic>.from(snapshotJson()['parallel']);
        json.addAll(entry.value as Map<String, dynamic>);
        expect(() => RegisterValue.fromJson(json), throwsFormatException);
      });
    }
  });

  group('RegisterMode', () {
    test('round trips both wire values', () {
      for (final mode in RegisterMode.values) {
        expect(RegisterMode.fromJson(mode.toJson()), mode);
      }
    });

    test('rejects missing or unknown modes', () {
      for (final mode in [null, 0, 'other', 'SHIFT']) {
        expect(() => RegisterMode.fromJson(mode), throwsFormatException);
      }
    });
  });

  group('RegisterHistoryEntry', () {
    test('preserves optional fields and omits absent values on the wire', () {
      final minimal = RegisterHistoryEntry.fromJson({
        'action': 'load_parallel',
      });
      final nulls = RegisterHistoryEntry.fromJson({
        'action': 'load_parallel',
        'value': null,
        'bit': null,
        'cycle': null,
        'result': null,
      });
      expect(minimal, nulls);
      expect(minimal.toJson(), {'action': 'load_parallel'});

      final entry = RegisterHistoryEntry.fromJson({
        'action': 'shift',
        'value': 10,
        'bit': 1,
        'cycle': 4,
        'result': 11,
      });
      expect(entry.action, 'shift');
      expect(entry.value, 10);
      expect(entry.bit, 1);
      expect(entry.cycle, 4);
      expect(entry.result, 11);
      expect(RegisterHistoryEntry.fromJson(entry.toJson()), entry);
      expect(entry, isNot(RegisterHistoryEntry(action: 'shift', bit: 0)));
    });

    for (final fields in <Map<String, dynamic>>[
      {'action': null},
      {'action': ''},
      {'action': '  '},
      {'action': 1},
      {'value': -1},
      {'value': 16},
      {'bit': 2},
      {'bit': '1'},
      {'cycle': -1},
      {'cycle': 1.0},
      {'result': 16},
      {'result': false},
    ]) {
      test('rejects invalid history fields $fields', () {
        expect(
          () => RegisterHistoryEntry.fromJson({'action': 'shift', ...fields}),
          throwsFormatException,
        );
      });
    }

    test('validates manually constructed entries', () {
      expect(() => RegisterHistoryEntry(action: ''), throwsArgumentError);
      expect(
        () => RegisterHistoryEntry(action: 'shift', bit: 2),
        throwsRangeError,
      );
      expect(
        () => RegisterHistoryEntry(action: 'shift', cycle: -1),
        throwsRangeError,
      );
      expect(
        () => RegisterHistoryEntry(action: 'load_parallel', value: 16),
        throwsRangeError,
      );
      expect(
        () => RegisterHistoryEntry(action: 'shift', result: -1),
        throwsRangeError,
      );
    });
  });

  group('RegisterSnapshot', () {
    test('reads every server field and round trips JSON', () {
      final json = snapshotJson()
        ..['selected_mode'] = 'shift'
        ..['shift_count'] = 4
        ..['history'] = [
          {'action': 'load_parallel', 'value': 10, 'result': 10},
          {'action': 'shift', 'bit': 1, 'cycle': 4, 'result': 11},
        ];
      final snapshot = RegisterSnapshot.fromJson(json);
      expect(snapshot.parallel.value, 10);
      expect(snapshot.shift.value, 11);
      expect(snapshot.selectedMode, RegisterMode.shift);
      expect(snapshot.shiftCount, 4);
      expect(snapshot.history, hasLength(2));
      expect(snapshot.history.last.result, 11);
      expect(snapshot.fclk0Mhz, 50.0);
      expect(snapshot.softwareResetAvailable, isFalse);
      final copy = RegisterSnapshot.fromJson(
        jsonDecode(jsonEncode(snapshot.toJson())),
      );
      expect(copy, snapshot);
      expect(copy.hashCode, snapshot.hashCode);
    });

    test('equality includes all snapshot properties', () {
      final snapshot = RegisterSnapshot.fromJson(snapshotJson());
      final variants = <String, Object>{
        'parallel': snapshotJson()['shift'],
        'shift': snapshotJson()['parallel'],
        'selected_mode': 'shift',
        'shift_count': 1,
        'history': [
          {'action': 'shift', 'bit': 1},
        ],
        'fclk0_mhz': 25.0,
        'software_reset_available': true,
      };
      for (final entry in variants.entries) {
        final json = snapshotJson()..[entry.key] = entry.value;
        expect(
          RegisterSnapshot.fromJson(json),
          isNot(snapshot),
          reason: entry.key,
        );
      }
    });

    test('defensively copies history and JSON data', () {
      final history = [RegisterHistoryEntry(action: 'shift', bit: 1)];
      final snapshot = RegisterSnapshot(
        parallel: RegisterValue(value: 10),
        shift: RegisterValue(value: 11),
        selectedMode: RegisterMode.parallel,
        shiftCount: 1,
        history: history,
        fclk0Mhz: 50,
        softwareResetAvailable: false,
      );
      history.clear();
      expect(snapshot.history, hasLength(1));
      expect(() => snapshot.history.clear(), throwsUnsupportedError);
      final json = snapshot.toJson();
      (json['history'] as List).clear();
      json['parallel']['q0_to_q3'] = [1, 1, 1, 1];
      expect(snapshot.history, hasLength(1));
      expect(snapshot.parallel.q0ToQ3, [0, 1, 0, 1]);
    });

    test(
      'accepts integer clock metadata without changing the reported value',
      () {
        final json = snapshotJson()..['fclk0_mhz'] = 50;
        expect(RegisterSnapshot.fromJson(json).fclk0Mhz, 50.0);
      },
    );

    final invalidFields = <Map<String, dynamic>>[
      {'parallel': null},
      {'parallel': []},
      {'shift': {}},
      {'selected_mode': 'unknown'},
      {'shift_count': -1},
      {'shift_count': 0.0},
      {'history': null},
      {'history': {}},
      {
        'history': [null],
      },
      {
        'history': [
          {'action': 'shift', 'bit': 2},
        ],
      },
      {'fclk0_mhz': '50'},
      {'fclk0_mhz': 0},
      {'fclk0_mhz': -1},
      {'fclk0_mhz': double.nan},
      {'fclk0_mhz': double.infinity},
      {'software_reset_available': null},
      {'software_reset_available': 0},
    ];
    for (final fields in invalidFields) {
      test('rejects malformed snapshot $fields', () {
        expect(
          () => RegisterSnapshot.fromJson(snapshotJson()..addAll(fields)),
          throwsFormatException,
        );
      });
    }

    test('rejects missing required fields', () {
      for (final field in snapshotJson().keys) {
        final json = snapshotJson()..remove(field);
        expect(
          () => RegisterSnapshot.fromJson(json),
          throwsFormatException,
          reason: field,
        );
      }
    });
  });
}
