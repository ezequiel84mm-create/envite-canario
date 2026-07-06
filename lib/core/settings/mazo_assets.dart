import 'app_settings.dart';

/// Devuelve la ruta de los assets de cartas según la baraja elegida
/// en Opciones ('espanola' o 'canaria'). Centraliza la lógica para que
/// todas las pantallas usen la misma carpeta.
class MazoAssets {
  /// Carpeta base de la baraja activa, ej: 'assets/cards/canaria'
  static String get _carpeta =>
      'assets/cards/${AppSettings.instance.baraja}';

  /// Ruta de una carta concreta, ej: 'assets/cards/canaria/bastos_01.png'
  static String carta(String assetName) => '$_carpeta/$assetName';

  /// Ruta de la trasera (reverso) de la baraja activa.
  static String get trasera => '$_carpeta/trasera.png';

  /// True si la baraja activa es la canaria (cartas algo mas anchas).
  static bool get esCanaria => AppSettings.instance.baraja == 'canaria';
}
