import 'dart:convert';

/// Validated inbound protocol types. JSON stays in the data layer.
sealed class WebSocketMessage {
  const WebSocketMessage();

  static WebSocketMessage decode(Object? raw) {
    if (raw is! String) throw const FormatException('Réponse texte attendue');
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Objet JSON attendu');
    }
    switch (data['type']) {
      case 'mux_state':
        return MuxStateMessage(
          _selector(data['selector']),
          List.generate(4, (i) => _bit(data['d$i'], 'd$i')),
          _bit(data['y'], 'y'),
        );
      case 'demux_state':
        return DemuxStateMessage(
          _selector(data['selector']),
          _bit(data['d'], 'd'),
          _outputs(data['outputs']),
        );
      case 'physical_inputs':
        final selector = _selector(data['selector']);
        final s0 = _bit(data['s0'], 's0') ? 1 : 0;
        final s1 = _bit(data['s1'], 's1') ? 1 : 0;
        if (selector != ((s1 << 1) | s0)) {
          throw const FormatException(
            'physical_inputs : selector incohérent avec s1/s0',
          );
        }
        return PhysicalInputsMessage(
          selector,
          _bit(data['d'], 'd'),
          _outputs(data['outputs']),
        );
      case 'error':
        final message = data['message'];
        if (message is! String) {
          throw const FormatException('Message erreur attendu');
        }
        return ServerErrorMessage(message);
      default:
        throw FormatException('Type WebSocket inconnu : ${data['type']}');
    }
  }

  static int _selector(Object? value) {
    if (value is! int || value < 0 || value > 3) {
      throw const FormatException('Sélecteur invalide (entier 0…3 attendu)');
    }
    return value;
  }

  static bool _bit(Object? value, String field) {
    if (value is! int || (value != 0 && value != 1)) {
      throw FormatException('$field : bit entier 0 ou 1 attendu');
    }
    return value == 1;
  }

  static List<bool> _outputs(Object? value) {
    if (value is! List || value.length != 4) {
      throw const FormatException('Quatre sorties attendues');
    }
    return List.unmodifiable(
      List.generate(4, (i) => _bit(value[i], 'outputs[$i]')),
    );
  }
}

final class MuxStateMessage extends WebSocketMessage {
  MuxStateMessage(this.selector, List<bool> inputs, this.output)
    : inputs = List.unmodifiable(inputs);
  final int selector;
  final List<bool> inputs;
  final bool output;
}

final class DemuxStateMessage extends WebSocketMessage {
  const DemuxStateMessage(this.selector, this.input, this.outputs);
  final int selector;
  final bool input;
  final List<bool> outputs;
}

final class PhysicalInputsMessage extends WebSocketMessage {
  const PhysicalInputsMessage(this.selector, this.input, this.outputs);
  final int selector;
  final bool input;
  final List<bool> outputs;
}

final class ServerErrorMessage extends WebSocketMessage {
  const ServerErrorMessage(this.message);
  final String message;
}
