import 'dart:math';
import '../../../../core/enums/suit.dart';
import '../../data/models/card_model.dart';
import '../engine/trick_engine.dart';

class AiPlayer {
  static final Random _random = Random();

  /// Probabilidad de que la IA juegue de forma subóptima (no perfecta).
  static const double margenDeError = 0.20;

  /// Elige qué carta jugar de las válidas disponibles.
  static CardModel elegirCarta({
    required List<CardModel> validas,
    required List<PlayedCard> bazaActual,
    required Suit paloDeLaMano,
    required int bazasGanadasIA,
    required int bazasGanadasTu,
  }) {
    if (validas.length == 1) return validas.first;

    // Margen de error: a veces juega al azar entre las válidas.
    if (_random.nextDouble() < margenDeError) {
      return validas[_random.nextInt(validas.length)];
    }

    // Caso 1: la IA es la primera en jugar (abre la baza).
    if (bazaActual.isEmpty) {
      return _elegirAlAbrir(validas, paloDeLaMano, bazasGanadasIA, bazasGanadasTu);
    }

    // Caso 2: la IA responde a una carta ya jugada.
    return _elegirAlResponder(validas, bazaActual, paloDeLaMano);
  }

  static CardModel _elegirAlAbrir(
    List<CardModel> validas,
    Suit paloDeLaMano,
    int bazasGanadasIA,
    int bazasGanadasTu,
  ) {
    final ordenadas = [...validas]
      ..sort((a, b) => a.value.fuerza.compareTo(b.value.fuerza));

    final vaGanando = bazasGanadasIA > bazasGanadasTu;

    if (vaGanando) {
      // Conservadora: abre con su carta más floja.
      return ordenadas.first;
    } else {
      // Más agresiva: prueba con algo de fuerza media para presionar.
      final medio = ordenadas.length ~/ 2;
      return ordenadas[medio];
    }
  }

  static CardModel _elegirAlResponder(
    List<CardModel> validas,
    List<PlayedCard> bazaActual,
    Suit paloDeLaMano,
  ) {
    // Probar cada carta válida: ¿cuál gana si la juego?
    final ganadoras = <CardModel>[];
    final perdedoras = <CardModel>[];

    for (final carta in validas) {
      final jugadasSimuladas = [
        ...bazaActual,
        PlayedCard(playerId: 'ia', card: carta),
      ];
      final ganador = TrickEngine.determinarGanador(
        jugadas: jugadasSimuladas,
        paloDeLaMano: paloDeLaMano,
      );
      if (ganador.playerId == 'ia') {
        ganadoras.add(carta);
      } else {
        perdedoras.add(carta);
      }
    }

    if (ganadoras.isNotEmpty) {
      // Gana con la carta más floja posible que le alcance.
      ganadoras.sort((a, b) => a.value.fuerza.compareTo(b.value.fuerza));
      return ganadoras.first;
    }

    // No puede ganar: tira la más floja para no desperdiciar.
    perdedoras.sort((a, b) => a.value.fuerza.compareTo(b.value.fuerza));
    return perdedoras.first;
  }
}
