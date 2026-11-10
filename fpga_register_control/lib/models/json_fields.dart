// Shared validation for the server's JSON payloads. Reject malformed hardware
// data rather than silently replacing it with a successful-looking default.
Map<String, dynamic> jsonObject(Object? value, String field) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('$field must be a JSON object');
  }
  return value;
}

int jsonInteger(Object? value, String field, {int min = 0, int? max}) {
  if (value is! int || value < min || (max != null && value > max)) {
    throw FormatException(
      '$field must be an integer from $min to ${max ?? 'infinity'}',
    );
  }
  return value;
}

int? jsonOptionalInteger(Object? value, String field, {int min = 0, int? max}) {
  return value == null ? null : jsonInteger(value, field, min: min, max: max);
}

String jsonString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be a nonempty string');
  }
  return value;
}
