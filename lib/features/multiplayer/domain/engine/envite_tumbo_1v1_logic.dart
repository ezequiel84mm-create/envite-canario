/// Lógica pura para la máquina de estados del envite y tumbo en 1vs1.
///
/// Sirve para centralizar las transiciones de estado y poder probarlas sin
/// depender de la UI o del runtime de Flutter.
class EnviteTumbo1v1Logic {
  final int nivelApuesta;
  final bool enviteCantado;
  final int quienCanto;
  final int nivelPropuesto;
  final int turnoApuesta;
  final bool manoEsDeTumbo;
  final int quienDecideTumbo;

  const EnviteTumbo1v1Logic({
    this.nivelApuesta = 0,
    this.enviteCantado = false,
    this.quienCanto = -1,
    this.nivelPropuesto = 0,
    this.turnoApuesta = -1,
    this.manoEsDeTumbo = false,
    this.quienDecideTumbo = -1,
  });

  factory EnviteTumbo1v1Logic.fromMap(Map<String, dynamic> data) {
    return EnviteTumbo1v1Logic(
      nivelApuesta: data['nivelApuesta'] as int? ?? 0,
      enviteCantado: data['enviteCantado'] as bool? ?? false,
      quienCanto: data['quienCanto'] as int? ?? -1,
      nivelPropuesto: data['nivelPropuesto'] as int? ?? 0,
      turnoApuesta: data['turnoApuesta'] as int? ?? -1,
      manoEsDeTumbo: data['manoEsDeTumbo'] as bool? ?? false,
      quienDecideTumbo: data['quienDecideTumbo'] as int? ?? -1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nivelApuesta': nivelApuesta,
      'enviteCantado': enviteCantado,
      'quienCanto': quienCanto,
      'nivelPropuesto': nivelPropuesto,
      'turnoApuesta': turnoApuesta,
      'manoEsDeTumbo': manoEsDeTumbo,
      'quienDecideTumbo': quienDecideTumbo,
    };
  }

  bool get hayEnvitePendiente => enviteCantado;
  bool get hayDecisionTumbo => quienDecideTumbo != -1;

  bool puedeCantar(int miAsiento) {
    return !enviteCantado &&
        nivelApuesta < 4 &&
        (turnoApuesta == -1 || turnoApuesta == miAsiento);
  }

  EnviteTumbo1v1Logic registrarCanto(int asiento) {
    if (enviteCantado || nivelApuesta >= 4) {
      return this;
    }
    return copyWith(
      enviteCantado: true,
      quienCanto: asiento,
      nivelPropuesto: nivelApuesta + 1,
    );
  }

  EnviteTumbo1v1Logic responder(String accion) {
    if (!enviteCantado) {
      return this;
    }

    switch (accion) {
      case 'juego':
        return copyWith(
          nivelApuesta: nivelPropuesto,
          enviteCantado: false,
          quienCanto: -1,
          turnoApuesta: quienCanto == 0 ? 1 : 0,
        );
      case 'paso':
        return copyWith(
          enviteCantado: false,
          quienCanto: -1,
          turnoApuesta: -1,
        );
      case 'subir':
        return copyWith(
          nivelPropuesto: nivelPropuesto + 1,
          quienCanto: quienCanto == 0 ? 1 : 0,
        );
      default:
        return this;
    }
  }

  EnviteTumbo1v1Logic decidirTumbo(bool juega) {
    if (quienDecideTumbo == -1) {
      return this;
    }

    if (juega) {
      return copyWith(
        manoEsDeTumbo: true,
        quienDecideTumbo: -1,
      );
    }

    return copyWith(
      quienDecideTumbo: -1,
      manoEsDeTumbo: false,
    );
  }

  EnviteTumbo1v1Logic copyWith({
    int? nivelApuesta,
    bool? enviteCantado,
    int? quienCanto,
    int? nivelPropuesto,
    int? turnoApuesta,
    bool? manoEsDeTumbo,
    int? quienDecideTumbo,
  }) {
    return EnviteTumbo1v1Logic(
      nivelApuesta: nivelApuesta ?? this.nivelApuesta,
      enviteCantado: enviteCantado ?? this.enviteCantado,
      quienCanto: quienCanto ?? this.quienCanto,
      nivelPropuesto: nivelPropuesto ?? this.nivelPropuesto,
      turnoApuesta: turnoApuesta ?? this.turnoApuesta,
      manoEsDeTumbo: manoEsDeTumbo ?? this.manoEsDeTumbo,
      quienDecideTumbo: quienDecideTumbo ?? this.quienDecideTumbo,
    );
  }
}
