import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../sala/network/transporte_sala.dart';

/// Transporte del modo SALA por INTERNET (Firebase Realtime Database).
///
/// Tiene la MISMA interfaz que `ConexionSala` (la del WiFi), para que las
/// pantallas de sala y de partida la usen exactamente igual. Lo único que
/// cambia es "cómo viajan" los mensajes: en vez de sockets por la wifi,
/// van por la Realtime Database de Firebase (funciona por internet).
///
/// Modelo de datos en la base de datos:
///   salas/{codigo}/
///     anfitrion: (uid)                       -> presencia del anfitrion
///     creada: (timestamp)
///     invitados/(idInv): { uid }             -> un hijo por invitado
///                                               (onDisconnect lo borra solo)
///     aInvitado/(idInv)/(push): (mensaje)    -> anfitrion  -> ese invitado
///     alAnfitrion/{push}: { de, msg }        -> invitado   -> anfitrión
///
/// El "código" que devuelve crearSala() es lo que el anfitrión comparte con
/// los demás para que se unan (el equivalente a la IP del WiFi).
class ConexionSalaOnline implements TransporteSala {
  static const int maxInvitados = 7; // 8 jugadores - 1 anfitrión

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _codigo;
  String? _miIdInvitado; // solo invitado: su id dentro de la sala
  @override
  bool soyAnfitrion = false;

  // Solo el anfitrión: invitados presentes (id -> true).
  final Map<String, bool> _invitados = {};
  final List<StreamSubscription<DatabaseEvent>> _subs = [];

  // ===== Mismos callbacks que ConexionSala =====
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

  @override
  int get numInvitados => _invitados.length;
  @override
  List<String> get idsInvitados => _invitados.keys.toList();

  DatabaseReference get _sala => _db.ref('salas/$_codigo');

  Future<void> _login() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
  }

  // Código de 4 letras/números, sin caracteres confusos (O/0, I/1).
  String _generarCodigo() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    return List.generate(4, (_) => chars[r.nextInt(chars.length)]).join();
  }

  // ===== ANFITRIÓN: abrir la sala =====
  @override
  Future<String?> crearSala() async {
    try {
      await _login();
      soyAnfitrion = true;
      final uid = _auth.currentUser!.uid;

      // Busca un código libre.
      String codigo = _generarCodigo();
      for (int i = 0; i < 5; i++) {
        final existe = (await _db.ref('salas/$codigo').get()).exists;
        if (!existe) break;
        codigo = _generarCodigo();
      }
      _codigo = codigo;

      await _sala.set({
        'anfitrion': uid,
        'creada': ServerValue.timestamp,
      });
      // Si el anfitrión se cae/cierra, se borra la sala entera.
      _sala.onDisconnect().remove();

      // Invitados que entran/salen.
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

      // Mensajes de los invitados (cola global).
      _subs.add(_sala.child('alAnfitrion').onChildAdded.listen((e) {
        final v = e.snapshot.value;
        if (v is Map) {
          final de = v['de']?.toString() ?? '';
          final msg = v['msg']?.toString() ?? '';
          if (msg.isNotEmpty) alRecibirDeInvitado?.call(de, msg);
        }
        e.snapshot.ref.remove(); // consumido
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

  // ===== INVITADO: unirse a la sala =====
  @override
  Future<bool> unirseASala(String codigo) async {
    try {
      await _login();
      soyAnfitrion = false;
      _codigo = codigo.trim().toUpperCase();

      final snap = await _sala.get();
      if (!snap.exists) return false; // no existe ninguna sala con ese código

      final uid = _auth.currentUser!.uid;
      final ref = _sala.child('invitados').push();
      _miIdInvitado = ref.key;
      await ref.set({'uid': uid});
      // Si me caigo/cierro, el anfitrión ve que me fui.
      ref.onDisconnect().remove();

      // Mensajes que el anfitrión me manda a mí.
      _subs.add(
          _sala.child('aInvitado/$_miIdInvitado').onChildAdded.listen((e) {
        final msg = e.snapshot.value?.toString() ?? '';
        if (msg.isNotEmpty) alRecibirDeAnfitrion?.call(msg);
        e.snapshot.ref.remove(); // consumido
      }));

      // Si desaparece el anfitrión (se borra la sala), aviso.
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

  // ===== Común =====
  @override
  void cerrar() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    try {
      if (soyAnfitrion && _codigo != null) {
        _sala.remove(); // el anfitrión cierra: borra la sala
      } else if (_codigo != null && _miIdInvitado != null) {
        _sala.child('invitados/$_miIdInvitado').remove();
      }
    } catch (_) {}
    _invitados.clear();
    _codigo = null;
    _miIdInvitado = null;
  }
}
