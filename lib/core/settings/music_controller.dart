import 'package:audioplayers/audioplayers.dart';

/// Puente global para controlar la música del menú desde otras pantallas
/// (por ejemplo, pausarla durante la guía rápida con voz).
class MusicController {
  MusicController._();
  static final MusicController instance = MusicController._();

  AudioPlayer? _player;
  double _volumen = 1.0;
  bool Function()? _puedeReanudar;

  void registrar(AudioPlayer player, bool Function() puedeReanudar) {
    _player = player;
    _puedeReanudar = puedeReanudar;
    player.setVolume(_volumen);
  }

  void pausar() {
    _player?.pause();
  }

  void reanudar() {
    if (_puedeReanudar != null && _puedeReanudar!()) {
      _player?.resume();
    }
  }

  void setVolumen(double v) {
    _volumen = v;
    _player?.setVolume(v);
  }
}
