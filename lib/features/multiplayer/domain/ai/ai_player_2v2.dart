import 'dart:math';
import '../../../../core/enums/suit.dart';
import '../../../../core/enums/fuerza_2v2.dart';
import '../../../game/data/models/card_model.dart';
import '../engine/trick_engine_2v2.dart';

/// IA para el modo 2vs2. A diferencia del 1vs1, tiene en cuenta a su
/// compañero de equipo: no le "pisa" la mano si ya va ganando.
class AiPlayer2v2 {
  static final Random _random = Random();

  /// Probabilidad de jugar de forma subóptima (para que no sea perfecta).
  static const double margenDeError = 0.20;

  /// Elige qué carta juega la IA del asiento [miAsiento].
  static CardModel elegirCarta({
    required int miAsiento,
    required List<CardModel> validas,
    required List<CartaJugada2v2> bazaActual,
    required Suit paloVirado,
  }) {
    if (validas.length == 1) return validas.first;

    // Margen de error: a veces juega suboptimo, pero solo entre las cartas
    // mas flojas (mitad inferior), para no malgastar la malilla ni triunfos
    // altos a la basura.
    if (_random.nextDouble() < margenDeError) {
      final ord = [...validas]
        ..sort((a, b) =>
            _fuerza(a, paloVirado).compareTo(_fuerza(b, paloVirado)));
      final mitad = (ord.length / 2).ceil();
      final flojas = ord.take(mitad).toList();
      return flojas[_random.nextInt(flojas.length)];
    }

    // Si abre la baza (nadie ha jugado aún).
    if (bazaActual.isEmpty) {
      return _elegirAlAbrir(validas, paloVirado);
    }

    // Responde a una baza en curso.
    return _elegirAlResponder(miAsiento, validas, bazaActual, paloVirado);
  }

  /// Fuerza de una carta (triunfo o no) para ordenar.
  static int _fuerza(CardModel c, Suit paloVirado) {
    if (c.suit == paloVirado) {
      // Sumamos 100 para que cualquier triunfo valga más que un no-triunfo.
      return 100 + Fuerza2v2.comoTriunfo(c.value);
    }
    return Fuerza2v2.comoNoTriunfo(c.value);
  }

  static CardModel _elegirAlAbrir(List<CardModel> validas, Suit paloVirado) {
    final ordenadas = [...validas]
      ..sort((a, b) => _fuerza(a, paloVirado).compareTo(_fuerza(b, paloVirado)));
    // Al abrir, conservador: tira una carta floja.
    return ordenadas.first;
  }

  static CardModel _elegirAlResponder(
    int miAsiento,
    List<CardModel> validas,
    List<CartaJugada2v2> bazaActual,
    Suit paloVirado,
  ) {
    // ¿Quién va ganando la baza ahora mismo?
    final ganadorActual = TrickEngine2v2.determinarGanador(
      jugadas: bazaActual,
      paloVirado: paloVirado,
    );

    // ¿El que va ganando es de mi equipo? (mismo equipo = misma paridad)
    final ganadorEsCompanero =
        (ganadorActual.asiento % 2) == (miAsiento % 2);

    final ordenadas = [...validas]
      ..sort((a, b) => _fuerza(a, paloVirado).compareTo(_fuerza(b, paloVirado)));

    if (ganadorEsCompanero) {
      // Mi compañero va ganando: no malgasto, tiro la más floja.
      return ordenadas.first;
    }

    // Va ganando un rival: intento superarlo con la más floja que me alcance.
    final ganadoras = <CardModel>[];
    for (final carta in validas) {
      final simulada = [
        ...bazaActual,
        CartaJugada2v2(asiento: miAsiento, carta: carta),
      ];
      final ganador = TrickEngine2v2.determinarGanador(
        jugadas: simulada,
        paloVirado: paloVirado,
      );
      if (ganador.asiento == miAsiento) {
        ganadoras.add(carta);
      }
    }

    if (ganadoras.isNotEmpty) {
      ganadoras.sort(
          (a, b) => _fuerza(a, paloVirado).compareTo(_fuerza(b, paloVirado)));
      return ganadoras.first;
    }

    // No puedo ganar: descarto la más floja.
    return ordenadas.first;
  }
}