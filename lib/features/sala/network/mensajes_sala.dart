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
}
