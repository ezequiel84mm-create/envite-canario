// Representa a un jugador dentro de la sala (lobby).
// Puede ser una persona real o una IA que rellena un hueco.
class JugadorSala {
  final String id;       // identificador único (ej. id de conexión, o 'ia_3')
  final String apodo;    // nombre que se muestra en su asiento
  final bool esIA;       // true si lo controla el anfitrión como IA
  final bool listo;      // true si el jugador ya confirmó que está listo

  const JugadorSala({
    required this.id,
    required this.apodo,
    this.esIA = false,
    this.listo = false,
  });

  // Crea un jugador IA con un apodo automático.
  factory JugadorSala.ia(int numero) {
    return JugadorSala(
      id: 'ia_$numero',
      apodo: 'IA $numero',
      esIA: true,
      listo: true,
    );
  }

  // ---- Conversión a/desde un mapa simple (para mandarlo por la red) ----
  Map<String, dynamic> aMapa() {
    return {
      'id': id,
      'apodo': apodo,
      'esIA': esIA,
      'listo': listo,
    };
  }

  factory JugadorSala.desdeMapa(Map<String, dynamic> m) {
    return JugadorSala(
      id: m['id'] ?? '',
      apodo: m['apodo'] ?? 'Jugador',
      esIA: m['esIA'] ?? false,
      listo: m['listo'] ?? false,
    );
  }
}
