/// Representa a un jugador sentado en una mesa multijugador.
///
/// Los asientos se numeran del 0 al 3 (en 2vs2) dando la vuelta a la mesa.
/// Los asientos ENFRENTADOS forman pareja:
///   - Equipo A: asientos 0 y 2
///   - Equipo B: asientos 1 y 3
class JugadorMesa {
  /// Asiento que ocupa (0..3 en 2vs2).
  final int asiento;

  /// Apodo que mostrará en la mesa.
  final String apodo;

  /// true si lo controla la IA; false si es una persona.
  final bool esIA;

  JugadorMesa({
    required this.asiento,
    required this.apodo,
    required this.esIA,
  });

  /// Equipo al que pertenece según el asiento.
  /// Asientos pares (0, 2) = equipo 0. Asientos impares (1, 3) = equipo 1.
  int get equipo => asiento % 2;

  @override
  String toString() =>
      'JugadorMesa(asiento: $asiento, apodo: $apodo, esIA: $esIA, equipo: $equipo)';
}
