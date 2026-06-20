class ApuestaModel {
  static const List<int> valores = [2, 4, 7, 9, 12];
  static const List<String> nombres = [
    'Base',
    'Envite',
    'Siete',
    'Nueve',
    'Chico Fuera',
  ];

  int nivelIndex = 0;

  int get valorActual => valores[nivelIndex];
  String get nombreActual => nombres[nivelIndex];
  bool get esMaximo => nivelIndex >= valores.length - 1;
  bool get esChicoFuera => nivelIndex == valores.length - 1;

  int get proximoValor => valores[nivelIndex + 1];
  String get proximoNombre => nombres[nivelIndex + 1];

  /// Piedras que gana quien propuso la subida si el rival pasa.
  int get valorSiRechaza {
    if (nivelIndex == 0) return 1;
    return valores[nivelIndex];
  }

  void reset() {
    nivelIndex = 0;
  }
}
