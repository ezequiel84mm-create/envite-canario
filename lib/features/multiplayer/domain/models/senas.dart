/// Catálogo de señas del Envite (gestos tradicionales entre compañeros).
///
/// Cada seña es un emoji que aparece como globo temporal encima del nombre
/// del jugador que la envía, visible SOLO para su equipo. La única con sonido
/// es el silbido, que lo oye toda la mesa (para confundir).
///
/// Cada seña indica en qué modos (numero de jugadores) tiene sentido. En los
/// modos donde no aplica, la paleta la muestra como hueco vacío (invisible)
/// para no descolocar la cuadrícula.

library;

class Sena {
  final String id;          // identificador corto y estable (para la red)
  final String emoji;       // lo que se muestra en el globo
  final String nombre;      // texto descriptivo (tooltip / accesibilidad)
  final String gesto;       // el gesto real que representa
  final bool sonido;        // true solo para el silbido
  final Set<int> modos;     // en qué modos aplica: 4=2v2, 6=3v3, 8=4v4

  const Sena({
    required this.id,
    required this.emoji,
    required this.nombre,
    required this.gesto,
    required this.modos,
    this.sonido = false,
  });

  bool aplicaEn(int numJugadores) => modos.contains(numJugadores);
}

// Conjuntos de modos para no repetir.
const _todos = {4, 6, 8};       // 2v2, 3v3, 4v4
const _soloEquiposFijas = {6, 8}; // 3v3 y 4v4 (tienen fijas)

/// Lista fija de las 10 señas disponibles (5 cartas + 5 situaciones).
const List<Sena> senasDisponibles = [
  // ===== Grupo 1: cartas principales (triunfos) =====
  Sena(
    id: 'perica',
    emoji: '😉',
    nombre: 'La Perica (sota de oros)',
    gesto: 'guiñar un ojo',
    modos: _soloEquiposFijas, // en 2v2 no es fija: oculta
  ),
  Sena(
    id: 'malilla',
    emoji: '😛',
    nombre: 'La Malilla (dos de la vira)',
    gesto: 'sacar la punta de la lengua',
    modos: _todos,
  ),
  Sena(
    id: 'rey',
    emoji: '🤨',
    nombre: 'El Rey (de la vira)',
    gesto: 'levantar las cejas / arrugar el entrecejo',
    modos: _todos,
  ),
  Sena(
    id: 'caballo',
    emoji: '😏',
    nombre: 'El Caballo (de la vira)',
    gesto: 'torcer la boca hacia un lado',
    modos: _soloEquiposFijas, // en 2v2 no se seña: oculta
  ),
  Sena(
    id: 'tresbastos',
    emoji: '👃',
    nombre: 'Tres de bastos / Cinco de oros',
    gesto: 'arrugar la nariz',
    modos: _soloEquiposFijas, // no hay fijas en 2v2: oculta
  ),
  // ===== Grupo 2: juego y situaciones (aplican siempre) =====
  Sena(
    id: 'ciego',
    emoji: '😫',
    nombre: 'Ir ciego (sin triunfos)',
    gesto: 'cerrar los ojos',
    modos: _todos,
  ),
  Sena(
    id: 'flus',
    emoji: '🐡',
    nombre: 'Full (tener tres triunfos)',
    gesto: 'inflar los carrillos',
    modos: _todos,
  ),
  Sena(
    id: 'envido',
    emoji: '😌',
    nombre: 'Envido',
    gesto: 'dar una cabezadita leve',
    modos: _todos,
  ),
  Sena(
    id: 'menores',
    emoji: '🤌',
    nombre: 'Triunfos menores',
    gesto: 'chasquear los dedos',
    modos: _todos,
  ),
  Sena(
    id: 'silbido',
    emoji: '😗',
    nombre: 'Silbido (aviso a tu equipo)',
    gesto: 'silbar para que tu compañero mire',
    sonido: true,
    modos: _todos,
  ),
];

/// Las 5 señas de carta (grupo 1) y las 5 de situación (grupo 2).
List<Sena> get senasCartas => senasDisponibles.sublist(0, 5);
List<Sena> get senasSituaciones => senasDisponibles.sublist(5, 10);

/// Busca una seña por su id. Devuelve null si no existe.
Sena? senaPorId(String id) {
  for (final s in senasDisponibles) {
    if (s.id == id) return s;
  }
  return null;
}
