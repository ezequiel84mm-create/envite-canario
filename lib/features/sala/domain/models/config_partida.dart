import 'estado_sala.dart';

/// Un jugador tal como entra a la partida (foto limpia de la sala).
class JugadorPartida {
  final String id;       // id del jugador (anfitrion, inv_X, ia_X)
  final String nombre;   // apodo a mostrar
  final int asiento;     // 0..7, posición en la mesa
  final int equipo;      // 0 o 1
  final bool esIA;

  const JugadorPartida({
    required this.id,
    required this.nombre,
    required this.asiento,
    required this.equipo,
    required this.esIA,
  });

  Map<String, dynamic> aMapa() => {
        'id': id,
        'nombre': nombre,
        'asiento': asiento,
        'equipo': equipo,
        'esIA': esIA,
      };

  factory JugadorPartida.desdeMapa(Map<String, dynamic> m) => JugadorPartida(
        id: m['id'] ?? '',
        nombre: m['nombre'] ?? 'Jugador',
        asiento: m['asiento'] ?? 0,
        equipo: m['equipo'] ?? 0,
        esIA: m['esIA'] ?? false,
      );
}

/// Configuración completa de una partida que arranca desde la sala.
/// Es lo que recibe la pantalla de juego.
class ConfigPartida {
  final List<JugadorPartida> jugadores; // solo asientos ocupados, ordenados
  final String idLocal; // id del jugador en ESTE dispositivo

  const ConfigPartida({required this.jugadores, required this.idLocal});

  int get numJugadores => jugadores.length;
  int get porEquipo => numJugadores ~/ 2; // 1, 2, 3 o 4

  /// Construye la config a partir del estado de la sala.
  /// idLocal: el id del jugador en este dispositivo ('anfitrion' o 'inv_X').
  factory ConfigPartida.desdeSala(EstadoSala sala, String idLocal) {
    final lista = <JugadorPartida>[];
    for (final a in sala.asientos) {
      if (!a.estaVacio) {
        lista.add(JugadorPartida(
          id: a.ocupante!.id,
          nombre: a.ocupante!.apodo,
          asiento: a.numero,
          equipo: a.equipo,
          esIA: a.ocupante!.esIA,
        ));
      }
    }
    // Ordenados por asiento para tener un orden estable de turnos.
    lista.sort((x, y) => x.asiento.compareTo(y.asiento));
    return ConfigPartida(jugadores: lista, idLocal: idLocal);
  }

  Map<String, dynamic> aMapa() => {
        'jugadores': jugadores.map((j) => j.aMapa()).toList(),
        'idLocal': idLocal,
      };

  factory ConfigPartida.desdeMapa(Map<String, dynamic> m) {
    final lista = (m['jugadores'] as List?) ?? [];
    return ConfigPartida(
      jugadores: lista
          .map((j) => JugadorPartida.desdeMapa(Map<String, dynamic>.from(j)))
          .toList(),
      idLocal: m['idLocal'] ?? '',
    );
  }
}
