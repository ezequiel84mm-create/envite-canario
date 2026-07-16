/// Interfaz común de transporte de SALA.
///
/// La implementan tanto la conexión por WiFi (`ConexionSala`) como la online
/// por Firebase (`ConexionSalaOnline`). Gracias a esto, la pantalla de sala y
/// las de juego (2v2/3v3/4v4) funcionan igual con cualquiera de las dos, sin
/// duplicar código: solo cambia qué transporte se les pasa.
abstract class TransporteSala {
  abstract bool soyAnfitrion;

  // Anfitrión: llega un mensaje de un invitado (id, texto).
  abstract void Function(String idInvitado, String mensaje)? alRecibirDeInvitado;
  // Invitado: llega un mensaje del anfitrión.
  abstract void Function(String mensaje)? alRecibirDeAnfitrion;
  // Anfitrión: un invitado se conecta / se desconecta.
  abstract void Function(String idInvitado)? alConectarInvitado;
  abstract void Function(String idInvitado)? alDesconectarInvitado;
  // Invitado: conectado con el anfitrión / lo perdió.
  abstract void Function()? alConectarConAnfitrion;
  abstract void Function()? alPerderAnfitrion;

  int get numInvitados;
  List<String> get idsInvitados;

  /// Anfitrión: abre la sala. Devuelve el "código" a compartir (IP en WiFi,
  /// código corto en online), o null si falla.
  Future<String?> crearSala();

  /// Anfitrión: envía a todos los invitados / a uno concreto.
  void enviarATodos(String mensaje);
  void enviarA(String idInvitado, String mensaje);

  /// Invitado: se une a la sala con el código/dirección. Devuelve si lo logró.
  Future<bool> unirseASala(String direccion);

  /// Invitado: envía un mensaje al anfitrión.
  void enviarAlAnfitrion(String mensaje);

  /// Cierra la conexión y libera todo.
  void cerrar();
}
