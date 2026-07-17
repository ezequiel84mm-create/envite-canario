import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'music_controller.dart';

/// Ajustes globales de la app. Un único objeto compartido (singleton)
/// que cualquier pantalla puede leer y modificar.
/// Los ajustes se guardan en el dispositivo (SharedPreferences) y se
/// cargan al arrancar la app, así se mantienen entre sesiones.
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  SharedPreferences? _prefs;

  bool _musicaActivada = true;
  bool _efectosActivados = true;
  double _volumen = 1.0;
  int _dificultadIA = 1; // 0 = Fácil, 1 = Normal, 2 = Difícil
  String _vozPropia = 'zeky';
  String _vozRival = 'manolo';
  String _baraja = 'espanola'; // 'espanola' o 'canaria'
  String _alias = ''; // se rellena al cargar

  /// En Windows el plugin de audio (audioplayers) tiene un bug de hilos que
  /// puede cerrar la app, así que desactivamos TODO el audio solo en Windows.
  /// En Android, iPhone, Mac y web el sonido funciona con normalidad.
  static bool get audioBloqueadoEnPlataforma =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  bool get musicaActivada => !audioBloqueadoEnPlataforma && _musicaActivada;
  bool get efectosActivados =>
      !audioBloqueadoEnPlataforma && _efectosActivados;
  double get volumen => _volumen;
  int get dificultadIA => _dificultadIA;
  String get vozPropia => _vozPropia;
  String get vozRival => _vozRival;
  String get baraja => _baraja;
  String get alias => _alias;

  String get nombreDificultad {
    switch (_dificultadIA) {
      case 0:
        return 'Fácil';
      case 2:
        return 'Difícil';
      default:
        return 'Normal';
    }
  }

  /// Carga los ajustes guardados. Hay que llamarlo una vez al arrancar la app
  /// (en main, antes de runApp).
  Future<void> cargar() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    _musicaActivada = p.getBool('musica') ?? true;
    _efectosActivados = p.getBool('efectos') ?? true;
    _volumen = p.getDouble('volumen') ?? 1.0;
    MusicController.instance.setVolumen(_volumen);
    _dificultadIA = p.getInt('dificultad') ?? 1;
    _vozPropia = p.getString('vozPropia') ?? 'zeky';
    _vozRival = p.getString('vozRival') ?? 'manolo';
    _baraja = p.getString('baraja') ?? 'espanola';

    // Alias: si no hay uno guardado, generamos uno por defecto y lo guardamos.
    final guardado = p.getString('alias');
    if (guardado == null || guardado.trim().isEmpty) {
      _alias = 'Jugador ${100 + Random().nextInt(9900)}';
      await p.setString('alias', _alias);
    } else {
      _alias = guardado;
    }
    notifyListeners();
  }

  void setMusica(bool valor) {
    _musicaActivada = valor;
    _prefs?.setBool('musica', valor);
    notifyListeners();
  }

  void setEfectos(bool valor) {
    _efectosActivados = valor;
    _prefs?.setBool('efectos', valor);
    notifyListeners();
  }

  void setVolumen(double valor) {
    _volumen = valor.clamp(0.0, 1.0).toDouble();
    _prefs?.setDouble('volumen', _volumen);
    MusicController.instance.setVolumen(_volumen);
    notifyListeners();
  }

  void setDificultad(int valor) {
    _dificultadIA = valor;
    _prefs?.setInt('dificultad', valor);
    notifyListeners();
  }

  void setVozPropia(String id) {
    _vozPropia = id;
    _prefs?.setString('vozPropia', id);
    notifyListeners();
  }

  void setVozRival(String id) {
    _vozRival = id;
    _prefs?.setString('vozRival', id);
    notifyListeners();
  }

  void setBaraja(String id) {
    _baraja = id;
    _prefs?.setString('baraja', id);
    notifyListeners();
  }

  void setAlias(String valor) {
    final limpio = valor.trim();
    if (limpio.isEmpty) return; // no permitimos alias vacío
    _alias = limpio;
    _prefs?.setString('alias', limpio);
    notifyListeners();
  }
}
