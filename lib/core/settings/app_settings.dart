import 'package:flutter/foundation.dart';

/// Ajustes globales de la app. Un único objeto compartido (singleton)
/// que cualquier pantalla puede leer y modificar.
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  bool _musicaActivada = true;
  bool _efectosActivados = true;
  int _dificultadIA = 1; // 0 = Fácil, 1 = Normal, 2 = Difícil
  String _vozPropia = 'zeky'; // voz para mis cantadas
  String _vozRival = 'manolo'; // voz para las cantadas del rival

  bool get musicaActivada => _musicaActivada;
  bool get efectosActivados => _efectosActivados;
  int get dificultadIA => _dificultadIA;
  String get vozPropia => _vozPropia;
  String get vozRival => _vozRival;

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

  void setMusica(bool valor) {
    _musicaActivada = valor;
    notifyListeners();
  }

  void setEfectos(bool valor) {
    _efectosActivados = valor;
    notifyListeners();
  }

  void setDificultad(int valor) {
    _dificultadIA = valor;
    notifyListeners();
  }

  void setVozPropia(String id) {
    _vozPropia = id;
    notifyListeners();
  }

  void setVozRival(String id) {
    _vozRival = id;
    notifyListeners();
  }
}
