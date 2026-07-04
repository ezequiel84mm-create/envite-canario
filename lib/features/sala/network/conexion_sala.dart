import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Servicio de red para el modo SALA (varios jugadores en la misma wifi).
///
/// El ANFITRIÓN abre un servidor y acepta VARIOS invitados a la vez
/// (hasta el máximo que decidamos). Mantiene una lista de conexiones.
/// Cada INVITADO se conecta al anfitrión con un solo socket.
class ConexionSala {
  static const int puerto = 4568; // distinto al del 1v1 (4567)
  static const int maxInvitados = 7; // 8 jugadores - 1 anfitrión

  ServerSocket? _servidor;

  final Map<String, Socket> _invitados = {};
  int _contadorIds = 0;

  Socket? _socketHaciaAnfitrion;

  bool soyAnfitrion = false;

  void Function(String idInvitado, String mensaje)? alRecibirDeInvitado;
  void Function(String mensaje)? alRecibirDeAnfitrion;
  void Function(String idInvitado)? alConectarInvitado;
  void Function(String idInvitado)? alDesconectarInvitado;
  void Function()? alConectarConAnfitrion;
  void Function()? alPerderAnfitrion;

  int get numInvitados => _invitados.length;
  List<String> get idsInvitados => _invitados.keys.toList();

  // ===== ANFITRIÓN: abrir la sala =====
  Future<String?> crearSala() async {
    try {
      soyAnfitrion = true;
      // Un solo servidor por puerto (sin shared) para que las conexiones no
      // se repartan con un servidor viejo a medio cerrar. Si el puerto sigue
      // ocupado tras salir de una partida (TIME_WAIT), reintentamos.
      _servidor = null;
      for (int intento = 0; intento < 6 && _servidor == null; intento++) {
        try {
          _servidor = await ServerSocket.bind(InternetAddress.anyIPv4, puerto);
        } catch (_) {
          await Future.delayed(const Duration(milliseconds: 400));
        }
      }
      if (_servidor == null) return null; // no se pudo abrir el puerto
      _servidor!.listen((socket) {
        if (_invitados.length >= maxInvitados) {
          socket.close();
          return;
        }
        final id = 'inv_${_contadorIds++}';
        _invitados[id] = socket;
        _escucharInvitado(id, socket);
        alConectarInvitado?.call(id);
      });
      return await _obtenerIPLocal();
    } catch (e) {
      return null;
    }
  }

  void _escucharInvitado(String id, Socket socket) {
    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (linea) {
        if (linea.isNotEmpty) {
          alRecibirDeInvitado?.call(id, linea);
        }
      },
      onDone: () {
        _invitados.remove(id);
        alDesconectarInvitado?.call(id);
      },
      onError: (_) {
        _invitados.remove(id);
        alDesconectarInvitado?.call(id);
      },
    );
  }

  void enviarATodos(String mensaje) {
    for (final socket in _invitados.values) {
      try {
        socket.write('$mensaje\n');
      } catch (_) {}
    }
  }

  void enviarA(String idInvitado, String mensaje) {
    final socket = _invitados[idInvitado];
    if (socket == null) return;
    try {
      socket.write('$mensaje\n');
    } catch (_) {}
  }

  // ===== INVITADO: unirse a la sala =====
  Future<bool> unirseASala(String direccionAnfitrion) async {
    try {
      soyAnfitrion = false;
      _socketHaciaAnfitrion = await Socket.connect(
        direccionAnfitrion,
        puerto,
        timeout: const Duration(seconds: 8),
      );
      _escucharAnfitrion();
      alConectarConAnfitrion?.call();
      return true;
    } catch (e) {
      return false;
    }
  }

  void _escucharAnfitrion() {
    _socketHaciaAnfitrion!
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (linea) {
        if (linea.isNotEmpty) {
          alRecibirDeAnfitrion?.call(linea);
        }
      },
      onDone: () {
        alPerderAnfitrion?.call();
        _socketHaciaAnfitrion = null;
      },
      onError: (_) {
        alPerderAnfitrion?.call();
        _socketHaciaAnfitrion = null;
      },
    );
  }

  void enviarAlAnfitrion(String mensaje) {
    if (_socketHaciaAnfitrion == null) return;
    try {
      _socketHaciaAnfitrion!.write('$mensaje\n');
    } catch (_) {
      alPerderAnfitrion?.call();
    }
  }

  // ===== Común =====
  Future<String?> _obtenerIPLocal() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final interfaz in interfaces) {
        for (final addr in interfaz.addresses) {
          if (addr.address.startsWith('192.168.') ||
              addr.address.startsWith('10.') ||
              addr.address.startsWith('172.')) {
            return addr.address;
          }
        }
      }
      if (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
        return interfaces.first.addresses.first.address;
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  void cerrar() {
    // Copia con toList(): al destruir un socket se dispara su onDone, que
    // hace _invitados.remove(...). Si iteraramos sobre _invitados.values
    // directamente, esa modificacion daria ConcurrentModificationError y
    // dejaria la conexion a medio cerrar (bloqueando crear otra sala).
    for (final socket in _invitados.values.toList()) {
      try {
        socket.destroy();
      } catch (_) {}
    }
    _invitados.clear();
    try {
      _socketHaciaAnfitrion?.destroy();
    } catch (_) {}
    try {
      _servidor?.close();
    } catch (_) {}
    _socketHaciaAnfitrion = null;
    _servidor = null;
  }
}
