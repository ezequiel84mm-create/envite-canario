import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Servicio de red para conexión 1vs1 en la misma wifi (peer to peer).
///
/// Un dispositivo hace de ANFITRIÓN (abre un servidor y espera) y el otro
/// de INVITADO (se conecta a la dirección del anfitrión).
/// Una vez conectados, ambos pueden enviar y recibir mensajes de texto.
class ConexionP2P {
  static const int puerto = 4567; // puerto fijo para la partida

  ServerSocket? _servidor;
  Socket? _socket;

  /// Se llama cada vez que llega un mensaje del otro jugador.
  void Function(String mensaje)? alRecibir;

  /// Se llama cuando se establece la conexión con el otro jugador.
  void Function()? alConectar;

  /// Se llama si la conexión se pierde o se cierra.
  void Function()? alDesconectar;

  bool get conectado => _socket != null;

  /// ANFITRIÓN: abre el servidor y espera a que alguien se conecte.
  /// Devuelve la dirección IP local (el "código" a compartir).
  Future<String?> crearComoAnfitrion() async {
    try {
      // Un solo servidor por puerto (sin shared) para no repartir conexiones
      // con un servidor viejo a medio cerrar. Reintentos por si el puerto
      // sigue en TIME_WAIT tras salir de una partida anterior.
      _servidor = null;
      for (int intento = 0; intento < 6 && _servidor == null; intento++) {
        try {
          _servidor = await ServerSocket.bind(InternetAddress.anyIPv4, puerto);
        } catch (_) {
          await Future.delayed(const Duration(milliseconds: 400));
        }
      }
      if (_servidor == null) return null;
      _servidor!.listen((socket) {
        // Solo aceptamos un invitado (1vs1).
        if (_socket != null) {
          socket.close();
          return;
        }
        _socket = socket;
        _escucharSocket();
        alConectar?.call();
      });
      return await _obtenerIPLocal();
    } catch (e) {
      return null;
    }
  }

  /// INVITADO: se conecta al anfitrión usando su dirección (código).
  Future<bool> unirseComoInvitado(String direccionAnfitrion) async {
    try {
      _socket = await Socket.connect(
        direccionAnfitrion,
        puerto,
        timeout: const Duration(seconds: 8),
      );
      _escucharSocket();
      alConectar?.call();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Envía un mensaje de texto al otro jugador.
  void enviar(String mensaje) {
    if (_socket == null) return;
    try {
      // Añadimos un salto de línea como separador entre mensajes.
      _socket!.write('$mensaje\n');
    } catch (e) {
      // Si falla el envío, consideramos la conexión perdida.
      alDesconectar?.call();
    }
  }

  void _escucharSocket() {
    _socket!
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (linea) {
        if (linea.isNotEmpty) {
          alRecibir?.call(linea);
        }
      },
      onDone: () {
        alDesconectar?.call();
        _socket = null;
      },
      onError: (_) {
        alDesconectar?.call();
        _socket = null;
      },
    );
  }

  /// Obtiene la dirección IP local del dispositivo en la wifi.
  Future<String?> _obtenerIPLocal() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final interfaz in interfaces) {
        for (final addr in interfaz.addresses) {
          // Direcciones típicas de red local empiezan por 192.168 o 10. o 172.
          if (addr.address.startsWith('192.168.') ||
              addr.address.startsWith('10.') ||
              addr.address.startsWith('172.')) {
            return addr.address;
          }
        }
      }
      // Si no encontró una típica, devuelve la primera disponible.
      if (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
        return interfaces.first.addresses.first.address;
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  /// Cierra la conexión y libera todo.
  void cerrar() {
    try {
      _socket?.destroy();
    } catch (_) {}
    try {
      _servidor?.close();
    } catch (_) {}
    _socket = null;
    _servidor = null;
  }
}
