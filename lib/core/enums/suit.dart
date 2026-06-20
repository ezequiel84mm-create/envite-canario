enum Suit {
  oros,
  copas,
  espadas,
  bastos;

  String get displayName {
    switch (this) {
      case Suit.oros:
        return 'Oros';
      case Suit.copas:
        return 'Copas';
      case Suit.espadas:
        return 'Espadas';
      case Suit.bastos:
        return 'Bastos';
    }
  }
}
