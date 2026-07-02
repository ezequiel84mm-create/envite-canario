import 'dart:math';
import '../../../../core/enums/suit.dart';
import '../../../game/data/models/card_model.dart';
import '../engine/trick_engine_2v2.dart' show CartaJugada2v2;
import '../engine/trick_engine_4v4.dart';

/// IA para el modo 3vs3. Usa el motor 4v4 (con cartas fijas) y los
/// equipos REALES de cada asiento (no la paridad), para no malgastar
/// cartas altas cuando un compañero ya va ganando la baza.
class AiPlayer4v4 {
  static final Random _random = Random();
  /// Este es el valor para dificultad "Normal"; ver [margenPara].
  static const double margenDeError = 0.15;

  /// Traduce la dificultad guardada en Opciones (0=Fácil, 1=Normal,
  /// 2=Difícil) al margen de error real de esta IA.
  static double margenPara(int dificultadIA) {
    switch (dificultadIA) {
      case 0:
        return 0.30; // Fácil
      case 2:
        return 0.05; // Difícil
      default:
        return 0.15; // Normal
    }
  }

  /// [equipoDe] devuelve el equipo (0/1) de un asiento dado.
  static CardModel elegirCarta({
    required int miAsiento,
    required List<CardModel> validas,
    required List<CartaJugada2v2> bazaActual,
    required Suit paloVirado,
    required int Function(int asiento) equipoDe,
    double? margen,
  }) {
    if (validas.length == 1) return validas.first;
    final m = margen ?? margenDeError;
    final ordenadas = [...validas]
      ..sort((a, b) =>
          _fuerza(a, paloVirado, bazaActual).compareTo(
              _fuerza(b, paloVirado, bazaActual)));
    // Margen de error: a veces juega subóptimo, PERO solo entre las cartas
    // más flojas (la mitad inferior), para no malgastar fijas ni triunfos
    // altos a la basura.
    if (_random.nextDouble() < m) {
      final mitad = (ordenadas.length / 2).ceil();
      final flojas = ordenadas.take(mitad).toList();
      return flojas[_random.nextInt(flojas.length)];
    }

    // Si abre la baza: conservador, tira floja.
    if (bazaActual.isEmpty) {
      return ordenadas.first;
    }

    // ¿Quién va ganando ahora?
    final ganadorActual = TrickEngine4v4.determinarGanador(
      jugadas: bazaActual,
      paloVirado: paloVirado,
    );
    final ganadorEsCompanero =
        equipoDe(ganadorActual.asiento) == equipoDe(miAsiento);

    if (ganadorEsCompanero) {
      // Mi compañero ya gana: NO malgasto, tiro la más floja.
      return ordenadas.first;
    }

    // Va ganando un rival: busco la carta más floja que GANE la baza.
    final ganadoras = <CardModel>[];
    for (final carta in validas) {
      final simulada = [
        ...bazaActual,
        CartaJugada2v2(asiento: miAsiento, carta: carta),
      ];
      final g = TrickEngine4v4.determinarGanador(
        jugadas: simulada,
        paloVirado: paloVirado,
      );
      if (g.asiento == miAsiento) ganadoras.add(carta);
    }
    if (ganadoras.isNotEmpty) {
      ganadoras.sort((a, b) =>
          _fuerza(a, paloVirado, bazaActual).compareTo(
              _fuerza(b, paloVirado, bazaActual)));
      return ganadoras.first; // la más floja que gana
    }

    // No puedo ganar: descarto la más floja.
    return ordenadas.first;
  }

  // Fuerza relativa de una carta para ordenar (más alto = más fuerte).
  // Usa la puntuación del motor 4v4 vía una baza ficticia.
  static int _fuerza(
      CardModel c, Suit paloVirado, List<CartaJugada2v2> baza) {
    // Palo inicial: el de la baza si existe, si no el propio (da igual
    // para ordenar dentro de la mano de la IA de forma aproximada).
    final paloInicial = baza.isNotEmpty ? baza.first.carta.suit : c.suit;
    return TrickEngine4v4.puntuacionPublica(c, paloVirado, paloInicial);
  }
}
