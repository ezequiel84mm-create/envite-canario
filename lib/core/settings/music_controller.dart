import 'package:audioplayers/audioplayers.dart';

/// Puente global para controlar la música del menú desde otras pantallas
/// (por ejemplo, pausarla durante la guía rápida con voz).
class MusicController {
  MusicController._();
  static final MusicController instance = MusicController._();

  AudioPlayer? _player;
  bool Function()? _puedeReanudar;

  void registrar(AudioPlayer player, bool Function() puedeReanudar) {
    _player = player;
    _puedeReanudar = puedeReanudar;
  }

  void pausar() {
    _player?.pause();
  }

  void reanudar() {
    if (_puedeReanudar != null && _puedeReanudar!()) {
      _player?.resume();
    }
  }
}
