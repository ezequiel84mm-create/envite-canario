import 'dart:async';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../sala/network/transporte_sala.dart';

/// Transporte del modo SALA por INTERNET (Firebase Realtime Database).
///
/// Misma interfaz que `ConexionSala` (la del WiFi). Cambia solo el transporte:
/// en vez de sockets, los mensajes viajan por la Realtime Database.
///
/// NOTA: no usamos Firebase Auth (login) porque en Windows su plugin tiene un
/// bug de hilos que cierra la app, y la base de datos esta en modo prueba
/// (acceso abierto). En su lugar generamos un id aleatorio por dispositivo.
/// Cuando pongamos reglas de seguridad (Fase 4) volveremos a meter el login,
/// probandolo ya en el movil (donde funciona bien).
///
/// Modelo de datos:
///   salas/(codigo)/
///     anfitrion: (uid)                       -> presencia del anfitrion
///     invitados/(idInv): { uid }             -> un hijo por invitado
///     aInvitado/(idInv)/(push): (mensaje)    -> anfitrion  -> ese invitado
///     alAnfitrion/(push): { de, msg }        -> invitado   -> anfitrion
class ConexionSalaOnline implements TransporteSala {
  static const int maxInvitados = 7;

  final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://envite-canario-default-rtdb.europe-west1.firebasedatabase.app',
  );

  String? _codigo;
  String? _miIdInvitado;
  @override
  bool soyAnfitrion = false;

  // Id propio ESTABLE: usamos el uid del login anonimo, que persiste entre
  // reinicios de la app/dispositivo. Es imprescindible para reconocer a quien
  // vuelve tras una desconexion (reconexion). Si no hay login (Windows, o si
  // fallo), caemos a un id aleatorio, unico al menos dentro de la sesion.
  late final String _miUid =
      FirebaseAuth.instance.currentUser?.uid ?? _generarUid();

  final Map<String, bool> _invitados = {};
  final List<StreamSubscription<DatabaseEvent>> _subs = [];

  @override
  void Function(String idInvitado, String mensaje)? alRecibirDeInvitado;
  @override
  void Function(String mensaje)? alRecibirDeAnfitrion;
  @override
  void Function(String idInvitado)? alConectarInvitado;
  @override
  void Function(String idInvitado)? alDesconectarInvitado;
  @override
  void Function()? alConectarConAnfitrion;
  @override
  void Function()? alPerderAnfitrion;

  // Canal FIABLE para la mano del invitado: el anfitrion la ESCRIBE en un sitio
  // fijo (manos/<id>) y el invitado la OBSERVA con onValue. A diferencia del
  // buzon aInvitado (push+borrar, que pierde mensajes en rafaga al arranque),
  // onValue siempre entrega el ultimo valor. Arregla "invitado sin cartas".
  void Function(List<dynamic> mano)? alRecibirMiManoFija;

  @override
  int get numInvitados => _invitados.length;
  @override
  List<String> get idsInvitados => _invitados.keys.toList();

  DatabaseReference get _sala => _db.ref('salas/$_codigo');

  String _generarUid() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random();
    return 'u_${List.generate(16, (_) => chars[r.nextInt(chars.length)]).join()}';
  }

  // Codigo de 4 letras/numeros, sin caracteres confusos (O/0, I/1).
  String _generarCodigo() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    return List.generate(4, (_) => chars[r.nextInt(chars.length)]).join();
  }

  // ===== ANFITRION =====
  @override
  Future<String?> crearSala() async {
    try {
      soyAnfitrion = true;

      String codigo = _generarCodigo();
      for (int i = 0; i < 5; i++) {
        final existe = (await _db.ref('salas/$codigo').get()).exists;
        if (!existe) break;
        codigo = _generarCodigo();
      }
      _codigo = codigo;

      await _sala.set({
        'anfitrion': _miUid,
        'creada': ServerValue.timestamp,
      });
      _sala.onDisconnect().remove();

      _subs.add(_sala.child('invitados').onChildAdded.listen((e) {
        final id = e.snapshot.key;
        if (id == null || _invitados.containsKey(id)) return;
        _invitados[id] = true;
        alConectarInvitado?.call(id);
      }));
      _subs.add(_sala.child('invitados').onChildRemoved.listen((e) {
        final id = e.snapshot.key;
        if (id == null) return;
        _invitados.remove(id);
        alDesconectarInvitado?.call(id);
      }));
      _subs.add(_sala.child('alAnfitrion').onChildAdded.listen((e) {
        final v = e.snapshot.value;
        if (v is Map) {
          final de = v['de']?.toString() ?? '';
          final msg = v['msg']?.toString() ?? '';
          if (msg.isNotEmpty) alRecibirDeInvitado?.call(de, msg);
        }
        e.snapshot.ref.remove();
      }));

      return codigo;
    } catch (_) {
      return null;
    }
  }

  @override
  void enviarATodos(String mensaje) {
    for (final id in _invitados.keys) {
      _sala.child('aInvitado/$id').push().set(mensaje);
    }
  }

  @override
  void enviarA(String idInvitado, String mensaje) {
    if (_codigo == null) return;
    _sala.child('aInvitado/$idInvitado').push().set(mensaje);
  }

  // Escribe la mano de un invitado en un sitio fijo (canal fiable, no buzon).
  void escribirMano(String idInvitado, List<String> mano) {
    if (_codigo == null) return;
    _sala.child('manos/$idInvitado').set(mano);
  }

  // El invitado LEE su mano del sitio fijo (get puntual). Cierra el hueco de que
  // onValue solo entrega al cambiar: si la mano se escribio antes de tener el
  // callback listo, este get la recupera igual. Se llama en el bucle de espera.
  Future<void> pedirMiManoFija() async {
    if (_codigo == null || _miIdInvitado == null) return;
    try {
      final snap = await _sala.child('manos/$_miIdInvitado').get();
      final v = snap.value;
      if (v is List) alRecibirMiManoFija?.call(v);
    } catch (_) {}
  }

  // ===== INVITADO =====
  @override
  Future<bool> unirseASala(String codigo) async {
    try {
      soyAnfitrion = false;
      _codigo = codigo.trim().toUpperCase();

      final snap = await _sala.get();
      if (!snap.exists) return false;

      final ref = _sala.child('invitados').push();
      _miIdInvitado = ref.key;
      await ref.set({'uid': _miUid});
      ref.onDisconnect().remove();

      _subs.add(
          _sala.child('aInvitado/$_miIdInvitado').onChildAdded.listen((e) {
        final msg = e.snapshot.value?.toString() ?? '';
        if (msg.isNotEmpty) alRecibirDeAnfitrion?.call(msg);
        e.snapshot.ref.remove();
      }));

      _subs.add(
          _sala.child('manos/$_miIdInvitado').onValue.listen((e) {
        final v = e.snapshot.value;
        if (v is List) alRecibirMiManoFija?.call(v);
      }));

      _subs.add(_sala.child('anfitrion').onValue.listen((e) {
        if (!e.snapshot.exists) alPerderAnfitrion?.call();
      }));

      alConectarConAnfitrion?.call();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void enviarAlAnfitrion(String mensaje) {
    if (_codigo == null || _miIdInvitado == null) return;
    _sala
        .child('alAnfitrion')
        .push()
        .set({'de': _miIdInvitado, 'msg': mensaje});
  }

  // ===== Comun =====
  @override
  void cerrar() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    try {
      if (soyAnfitrion && _codigo != null) {
        _sala.remove();
      } else if (_codigo != null && _miIdInvitado != null) {
        _sala.child('invitados/$_miIdInvitado').remove();
      }
    } catch (_) {}
    _invitados.clear();
    _codigo = null;
    _miIdInvitado = null;
  }
}
