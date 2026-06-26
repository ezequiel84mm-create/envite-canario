/// Tipos de mensajes que viajan en el modo SALA (lobby) entre el
/// anfitrión y los invitados. Reutilizamos la clase MensajeRed del 1v1
/// para codificar/decodificar (solo cambian los tipos).
class TipoMensajeSala {
  // INVITADO -> ANFITRIÓN: "me uno, mi alias es X".
  static const String hola = 'SALA_HOLA';

  // ANFITRIÓN -> TODOS: el estado completo de la sala (asientos, ocupantes).
  static const String estadoSala = 'SALA_ESTADO';

  // INVITADO -> ANFITRIÓN: "quiero sentarme en el asiento N".
  static const String elegirAsiento = 'SALA_ELEGIR_ASIENTO';

  // ANFITRIÓN -> TODOS: "la partida empieza".
  static const String empezar = 'SALA_EMPEZAR';

  // ANFITRIÓN -> UN invitado: "tu id en la sala es X".
  static const String tuId = 'SALA_TU_ID';

  // ===== Mensajes de la PARTIDA (ya en juego) =====
  // ANFITRIÓN -> TODOS: estado común de la partida (baza, turno, marcador).
  static const String estadoJuego = 'JUEGO_ESTADO';

  // ANFITRIÓN -> UN invitado: su mano personal de cartas.
  static const String miMano = 'JUEGO_MI_MANO';

  // INVITADO -> ANFITRIÓN: "juego esta carta".
  static const String jugarCarta = 'JUEGO_JUGAR_CARTA';

  // INVITADO -> ANFITRIÓN: "mi equipo canta/sube el envite".
  static const String proponerEnvite = 'JUEGO_PROPONER_ENVITE';

  // INVITADO -> ANFITRIÓN: respuesta al envite (juego/paso).
  static const String respuestaEnvite = 'JUEGO_RESPUESTA_ENVITE';
}
