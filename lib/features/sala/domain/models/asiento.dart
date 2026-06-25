import 'jugador_sala.dart';

// Un asiento de la mesa de la sala.
// La mesa tiene 8 asientos: 0..3 en el equipo A, 4..7 en el equipo B
// (o como decidamos numerarlos). Cada asiento puede estar vacío u ocupado.
class Asiento {
  final int numero;        // 0..7, posición fija en la mesa
  final int equipo;        // 0 = equipo A, 1 = equipo B
  JugadorSala? ocupante;   // null = asiento vacío

  Asiento({
    required this.numero,
    required this.equipo,
    this.ocupante,
  });

  bool get estaVacio => ocupante == null;
  bool get esIA => ocupante?.esIA ?? false;

  // ---- Conversión a/desde mapa (para la red) ----
  Map<String, dynamic> aMapa() {
    return {
      'numero': numero,
      'equipo': equipo,
      'ocupante': ocupante?.aMapa(),
    };
  }

  factory Asiento.desdeMapa(Map<String, dynamic> m) {
    final oc = m['ocupante'];
    return Asiento(
      numero: m['numero'] ?? 0,
      equipo: m['equipo'] ?? 0,
      ocupante: oc != null
          ? JugadorSala.desdeMapa(Map<String, dynamic>.from(oc))
          : null,
    );
  }
}
