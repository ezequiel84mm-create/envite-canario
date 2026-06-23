class ScoreModel {
  int piedrasTu = 0;
  int piedrasIA = 0;
  int chicosTu = 0;
  int chicosIA = 0;

  static const int objetivoChico = 12;
  static const int umbralTumbo = 11;

  /// Suma piedras a un jugador tras ganar una mano.
  /// Si llega a 12, gana el chico automáticamente y se resetean los piedras.
  /// Devuelve true si se ganó un chico con esta jugada.
  bool sumarPiedras(String ganadorId, int piedras) {
    if (ganadorId == 'tu') {
      piedrasTu += piedras;
      if (piedrasTu >= objetivoChico) {
        piedrasTu = objetivoChico;
        chicosTu++;
        _resetPiedras();
        return true;
      }
    } else {
      piedrasIA += piedras;
      if (piedrasIA >= objetivoChico) {
        piedrasIA = objetivoChico;
        chicosIA++;
        _resetPiedras();
        return true;
      }
    }
    return false;
  }

  void _resetPiedras() {
    piedrasTu = 0;
    piedrasIA = 0;
  }

  /// Devuelve el id del jugador que está en fase de Tumbo
  /// (llegó a 11 piedras), o null si nadie está en tumbo.
  String? get equipoEnTumbo {
    if (piedrasTu == umbralTumbo) return 'tu';
    if (piedrasIA == umbralTumbo) return 'ia';
    return null;
  }

  /// True si AMBOS estan en tumbo (11 piedras): tumbo forzoso, hay que jugar.
  bool get tumboForzoso =>
      piedrasTu == umbralTumbo && piedrasIA == umbralTumbo;

  /// Devuelve el id del ganador de la partida si alguien llegó a 2 chicos,
  /// o null si la partida sigue.
  String? get ganadorPartida {
    if (chicosTu >= 2) return 'tu';
    if (chicosIA >= 2) return 'ia';
    return null;
  }
}
