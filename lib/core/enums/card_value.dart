enum CardValue {
  uno(1),
  dos(2),
  tres(3),
  cuatro(4),
  cinco(5),
  seis(6),
  siete(7),
  sota(10),
  caballo(11),
  rey(12);

  final int numero;
  const CardValue(this.numero);

  String get displayName {
    switch (this) {
      case CardValue.uno:
        return 'As';
      case CardValue.sota:
        return 'Sota';
      case CardValue.caballo:
        return 'Caballo';
      case CardValue.rey:
        return 'Rey';
      default:
        return numero.toString();
    }
  }

  /// Jerarquía de fuerza para ganar bazas: a mayor número, más fuerte.
  /// Orden: Rey > Caballo > Sota > As > 7 > 6 > 5 > 4 > 3 > 2
  int get fuerza {
    switch (this) {
      case CardValue.rey:
        return 10;
      case CardValue.caballo:
        return 9;
      case CardValue.sota:
        return 8;
      case CardValue.uno:
        return 7;
      case CardValue.siete:
        return 6;
      case CardValue.seis:
        return 5;
      case CardValue.cinco:
        return 4;
      case CardValue.cuatro:
        return 3;
      case CardValue.tres:
        return 2;
      case CardValue.dos:
        return 1;
    }
  }
}
