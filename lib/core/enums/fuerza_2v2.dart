import 'card_value.dart';

/// Fuerza de las cartas en el modo 2vs2.
///
/// Diferencia clave con el 1vs1: dentro del palo de lo virado (triunfos),
/// la MALILLA (el 2) es la carta más fuerte, por encima del Rey.
///
/// Orden de triunfos (mayor a menor):
///   Malilla(2) > Rey > Caballo > Sota > As(1) > 7 > 6 > 5 > 4 > 3
class Fuerza2v2 {
  /// Fuerza cuando ES triunfo (del palo de lo virado).
  static int comoTriunfo(CardValue value) {
    switch (value) {
      case CardValue.dos:
        return 11;
      case CardValue.rey:
        return 10;
      case CardValue.caballo:
        return 9;
      case CardValue.sota:
        return 8;
      case CardValue.uno:
        return 7;
      case CardValue.siete:
        return 6;
      case CardValue.seis:
        return 5;
      case CardValue.cinco:
        return 4;
      case CardValue.cuatro:
        return 3;
      case CardValue.tres:
        return 2;
    }
  }

  /// Fuerza cuando NO es triunfo (orden normal).
  static int comoNoTriunfo(CardValue value) {
    switch (value) {
      case CardValue.rey:
        return 10;
      case CardValue.caballo:
        return 9;
      case CardValue.sota:
        return 8;
      case CardValue.uno:
        return 7;
      case CardValue.siete:
        return 6;
      case CardValue.seis:
        return 5;
      case CardValue.cinco:
        return 4;
      case CardValue.cuatro:
        return 3;
      case CardValue.tres:
        return 2;
      case CardValue.dos:
        return 1;
    }
  }
}
