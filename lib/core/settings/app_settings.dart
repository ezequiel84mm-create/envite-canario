import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  int _dificultadIA = 1; // 0 = Fácil, 1 = Normal, 2 = Difícil
  String _vozPropia = 'zeky';
  String _vozRival = 'manolo';
  String _alias = ''; // se rellena al cargar

  bool get musicaActivada => _musicaActivada;
  bool get efectosActivados => _efectosActivados;
  int get dificultadIA => _dificultadIA;
  String get vozPropia => _vozPropia;
  String get vozRival => _vozRival;
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
    _dificultadIA = p.getInt('dificultad') ?? 1;
    _vozPropia = p.getString('vozPropia') ?? 'zeky';
    _vozRival = p.getString('vozRival') ?? 'manolo';

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

  void setAlias(String valor) {
    final limpio = valor.trim();
    if (limpio.isEmpty) return; // no permitimos alias vacío
    _alias = limpio;
    _prefs?.setString('alias', limpio);
    notifyListeners();
  }
}
