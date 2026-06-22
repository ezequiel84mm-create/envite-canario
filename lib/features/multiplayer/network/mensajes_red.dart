import 'dart:convert';

/// Tipos de mensajes que viajan entre anfitrión e invitado en el 1vs1.
class TipoMensaje {
  // Del ANFITRIÓN al invitado: el estado completo de la partida.
  static const String estado = 'ESTADO';
  // Del INVITADO al anfitrión: "quiero jugar esta carta".
  static const String jugarCarta = 'JUGAR_CARTA';
  // Del INVITADO al anfitrión: respuesta a un envite (aceptar/subir/pasar).
  static const String respuestaEnvite = 'RESP_ENVITE';
  // Del INVITADO al anfitrión: "propongo un envite".
  static const String proponerEnvite = 'PROP_ENVITE';
  // Del INVITADO al anfitrión: decisión de tumbo (jugar/retirarse).
  static const String decisionTumbo = 'DEC_TUMBO';
  // Saludo inicial para confirmar conexión / apodo.
  static const String hola = 'HOLA';
}

/// Utilidad para crear y leer mensajes en formato texto (JSON).
class MensajeRed {
  final String tipo;
  final Map<String, dynamic> datos;

  MensajeRed(this.tipo, [this.datos = const {}]);

  /// Convierte el mensaje a texto para enviarlo por la red.
  String codificar() {
    return jsonEncode({'tipo': tipo, 'datos': datos});
  }

  /// Reconstruye un mensaje a partir del texto recibido.
  static MensajeRed? decodificar(String texto) {
    try {
      final mapa = jsonDecode(texto) as Map<String, dynamic>;
      final tipo = mapa['tipo'] as String;
      final datos = (mapa['datos'] as Map<String, dynamic>?) ?? {};
      return MensajeRed(tipo, datos);
    } catch (e) {
      return null;
    }
  }
}
