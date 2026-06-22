import '../../../core/enums/suit.dart';
import '../../../core/enums/card_value.dart';
import '../../game/data/models/card_model.dart';

/// Convierte cartas a texto y viceversa, para enviarlas por la red.
/// Formato: "palo:numero"  (ej: "oros:12" = Rey de oros)
class TraductorCartas {
  /// Carta -> texto
  static String aTexto(CardModel carta) {
    return '${carta.suit.name}:${carta.value.numero}';
  }

  /// Texto -> carta (o null si el texto es inválido)
  static CardModel? desdeTexto(String texto) {
    try {
      final partes = texto.split(':');
      if (partes.length != 2) return null;
      final suit = Suit.values.firstWhere((s) => s.name == partes[0]);
      final numero = int.parse(partes[1]);
      final value = CardValue.values.firstWhere((v) => v.numero == numero);
      return CardModel(suit: suit, value: value);
    } catch (e) {
      return null;
    }
  }

  /// Lista de cartas -> lista de textos
  static List<String> listaATexto(List<CardModel> cartas) {
    return cartas.map(aTexto).toList();
  }

  /// Lista de textos -> lista de cartas
  static List<CardModel> listaDesdeTexto(List<dynamic> textos) {
    final cartas = <CardModel>[];
    for (final t in textos) {
      final c = desdeTexto(t.toString());
      if (c != null) cartas.add(c);
    }
    return cartas;
  }
}
