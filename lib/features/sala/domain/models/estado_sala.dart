import 'asiento.dart';

// Estado completo de la sala (lobby) antes de empezar la partida.
// El anfitrión es el "cerebro": mantiene este estado y lo reparte a todos.
class EstadoSala {
  static const int totalAsientos = 8; // 4v4 como máximo

  final List<Asiento> asientos; // siempre 8, fijos
  final String anfitrionId;     // id del jugador anfitrión
  bool partidaIniciada;         // true cuando el anfitrión pulsa "Empezar"

  EstadoSala({
    required this.asientos,
    required this.anfitrionId,
    this.partidaIniciada = false,
  });

  // Crea una sala vacía con los 8 asientos repartidos en dos equipos.
  // Equipos ALTERNOS: asientos pares = equipo 0, impares = equipo 1.
  factory EstadoSala.vacia(String anfitrionId) {
    final asientos = List.generate(totalAsientos, (i) {
      // Disposición en zigzag (tablero):
      //   Izq        Der
      //   [A] ------ [B]
      //   [B] ------ [A]
      // fila = i ~/ 2 ; lado = i % 2 (0=izq, 1=der).
      // Enfrentados = rivales; compañeros en diagonal.
      final fila = i ~/ 2;
      final lado = i % 2;
      return Asiento(numero: i, equipo: (fila + lado) % 2);
    });
    return EstadoSala(asientos: asientos, anfitrionId: anfitrionId);
  }

  // ---- Consultas útiles ----
  int get ocupados => asientos.where((a) => !a.estaVacio).length;
  int get humanos =>
      asientos.where((a) => !a.estaVacio && !a.esIA).length;
  int get equipoA => asientos.where((a) => a.equipo == 0 && !a.estaVacio).length;
  int get equipoB => asientos.where((a) => a.equipo == 1 && !a.estaVacio).length;

  // ¿Se puede empezar? Al menos 1 humano y los dos equipos con el mismo nº.
  bool get sePuedeEmpezar => humanos >= 1 && equipoA == equipoB && equipoA >= 1;

  // Busca el asiento que ocupa un jugador (por id), o null.
  Asiento? asientoDe(String jugadorId) {
    for (final a in asientos) {
      if (a.ocupante?.id == jugadorId) return a;
    }
    return null;
  }

  // ---- Conversión a/desde mapa (para la red) ----
  Map<String, dynamic> aMapa() {
    return {
      'asientos': asientos.map((a) => a.aMapa()).toList(),
      'anfitrionId': anfitrionId,
      'partidaIniciada': partidaIniciada,
    };
  }

  factory EstadoSala.desdeMapa(Map<String, dynamic> m) {
    final lista = (m['asientos'] as List?) ?? [];
    return EstadoSala(
      asientos: lista
          .map((a) => Asiento.desdeMapa(Map<String, dynamic>.from(a)))
          .toList(),
      anfitrionId: m['anfitrionId'] ?? '',
      partidaIniciada: m['partidaIniciada'] ?? false,
    );
  }
}
