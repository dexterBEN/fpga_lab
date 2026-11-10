enum RegisterMode {
  parallel,
  shift;

  factory RegisterMode.fromJson(Object? value) => switch (value) {
    'parallel' => parallel,
    'shift' => shift,
    _ => throw const FormatException('selected_mode must be parallel or shift'),
  };

  String toJson() => name;
}
