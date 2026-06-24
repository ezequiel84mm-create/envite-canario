/// Catalogo de voces para las cantadas del envite.
/// Cada voz sabe en que carpeta estan sus audios y con que extension.
class Voz {
  final String id; // identificador interno (carpeta)
  final String nombre; // nombre visible
  final String extension; // 'm4a', 'mp3', etc.

  const Voz({required this.id, required this.nombre, required this.extension});

  /// Ruta del audio para un nivel (relativa a assets/audio/).
  String rutaNivel(String nombreArchivo) => 'voces/$id/$nombreArchivo.$extension';
}

/// Lista de voces disponibles en el juego.
class Voces {
  static const List<Voz> disponibles = [
    Voz(id: 'zeky', nombre: 'Zeky', extension: 'm4a'),
    Voz(id: 'manolo', nombre: 'Manolo', extension: 'mp3'),
  ];

  static Voz porId(String id) {
    return disponibles.firstWhere(
      (v) => v.id == id,
      orElse: () => disponibles.first,
    );
  }
}
