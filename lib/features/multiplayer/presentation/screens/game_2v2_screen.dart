import 'package:flutter/material.dart';
import '../../../sala/domain/models/config_partida.dart';
import '../../../sala/network/conexion_sala.dart';
import '../../../sala/network/mensajes_sala.dart';
import '../../network/mensajes_red.dart';
import '../../network/traductor_cartas.dart';
import '../../../../core/enums/suit.dart';
import '../../../../core/enums/card_value.dart';
import '../../../game/data/models/card_model.dart';
import '../../../game/presentation/widgets/card_widget.dart';
import '../../domain/engine/deal_engine_2v2.dart';
import '../../domain/engine/trick_engine_2v2.dart';
import '../../domain/ai/ai_player_2v2.dart';
import '../../../../core/settings/music_controller.dart';

/// Pantalla del 2vs2 con diseño (Etapa B).
/// Asientos: 0 = tú (abajo), 1 = rival izq, 2 = compañero (arriba), 3 = rival der.
/// Equipo A (tú): 0 y 2. Equipo B (rivales): 1 y 3.
class Game2v2Screen extends StatefulWidget {
  final ConfigPartida? config; // null = modo local de prueba (2v2 con IA)
  final ConexionSala? conexion; // null = modo local; viva = partida en red
  const Game2v2Screen({super.key, this.config, this.conexion});

  @override
  State<Game2v2Screen> createState() => _Game2v2ScreenState();
}

class _Game2v2ScreenState extends State<Game2v2Screen> {
  // Inicializadas con valores neutros: el invitado las dibuja vacías
  // hasta recibir el estado real del anfitrión.
  List<List<CardModel>> _manos = [];
  Suit _paloVirado = Suit.oros;
  CardModel _vira = const CardModel(suit: Suit.oros, value: CardValue.uno);

  List<CartaJugada2v2> _baza = [];
  int _turno = 0;
  int _manosEquipo0 = 0;
  int _manosEquipo1 = 0;
  String _mensaje = '';
  bool _rondaTerminada = false;
  int _numJug = 4; // jugadores en la partida (4, 6 u 8); 4 por defecto
  int _barajador = 0; // quién baraja esta mano; sale el de su izquierda

  // ¿Esta partida es en red? (hay conexión y config)
  bool get _enRed => widget.conexion != null && widget.config != null;
  // ¿Soy el anfitrión? (en modo local, sí por defecto)
  bool get _soyAnfitrion => widget.conexion?.soyAnfitrion ?? true;

  List<CardModel> _miManoRed = []; // mano del invitado recibida por red
  List<int> _numCartasPorAsiento = []; // cuántas cartas tiene cada asiento

  @override
  void initState() {
    super.initState();
    MusicController.instance.pausar();
    if (widget.config != null) {
      _numJug = widget.config!.numJugadores;
    }
    if (_enRed) {
      _configurarRed();
      if (_soyAnfitrion) {
        _repartirNuevaRonda();
      } else {
        widget.conexion!.enviarAlAnfitrion(
          MensajeRed(TipoMensajeSala.jugarCarta, {'pedirEstado': true})
              .codificar());
        _mensaje = 'Esperando reparto...';
      }
    } else {
      _repartirNuevaRonda();
    }
  }

  void _configurarRed() {
    final con = widget.conexion!;
    if (_soyAnfitrion) {
      con.alRecibirDeInvitado = (idInvitado, texto) {
        final msg = MensajeRed.decodificar(texto);
        if (msg == null) return;
        if (msg.tipo == TipoMensajeSala.jugarCarta) {
          if (msg.datos['pedirEstado'] == true) {
            _enviarEstadoJuego();
          } else {
            final carta = TraductorCartas.desdeTexto(msg.datos['carta']);
            final asiento = msg.datos['asiento'];
            if (carta != null && asiento != null) {
              _anfitrionRecibeJugada(asiento, carta);
            }
          }
        }
      };
    } else {
      con.alRecibirDeAnfitrion = (texto) {
        final msg = MensajeRed.decodificar(texto);
        if (msg == null) return;
        if (msg.tipo == TipoMensajeSala.estadoJuego) {
          _invitadoRecibeEstado(msg.datos);
        } else if (msg.tipo == TipoMensajeSala.miMano) {
          setState(() {
            _miManoRed = TraductorCartas.listaDesdeTexto(msg.datos['mano'] ?? []);
          });
        }
      };
    }
  }

  void _enviarEstadoJuego() {
    if (!_enRed || !_soyAnfitrion) return;
    final con = widget.conexion!;
    final baza = _baza
        .map((j) => {'asiento': j.asiento, 'carta': TraductorCartas.aTexto(j.carta)})
        .toList();
    final comun = {
      'vira': TraductorCartas.aTexto(_vira),
      'baza': baza,
      'turno': _turno,
      'manosEquipo0': _manosEquipo0,
      'manosEquipo1': _manosEquipo1,
      'rondaTerminada': _rondaTerminada,
      'mensaje': _mensaje,
      'numCartas': _manos.map((m) => m.length).toList(),
    };
    con.enviarATodos(
        MensajeRed(TipoMensajeSala.estadoJuego, comun).codificar());

    final cfg = widget.config!;
    for (int asiento = 0; asiento < cfg.jugadores.length; asiento++) {
      final jug = cfg.jugadores[asiento];
      if (jug.esIA) continue;
      if (jug.id == 'anfitrion') continue;
      con.enviarA(
          jug.id,
          MensajeRed(TipoMensajeSala.miMano, {
            'mano': TraductorCartas.listaATexto(_manos[asiento]),
          }).codificar());
    }
  }

  void _anfitrionRecibeJugada(int asiento, CardModel carta) {
    if (asiento != _turno || _rondaTerminada) return;
    final mano = _manos[asiento];
    final existe = mano.any((cc) =>
        cc.suit == carta.suit && cc.value == carta.value);
    if (!existe) return;
    _jugarCarta(asiento, carta);
    _enviarEstadoJuego();
  }

  void _invitadoRecibeEstado(Map<String, dynamic> d) {
    setState(() {
      _vira = TraductorCartas.desdeTexto(d['vira'])!;
      _paloVirado = _vira.suit;
      _baza = ((d['baza'] as List?) ?? []).map((j) {
        return CartaJugada2v2(
          asiento: j['asiento'],
          carta: TraductorCartas.desdeTexto(j['carta'])!,
        );
      }).toList();
      _turno = d['turno'] ?? 0;
      _manosEquipo0 = d['manosEquipo0'] ?? 0;
      _manosEquipo1 = d['manosEquipo1'] ?? 0;
      _rondaTerminada = d['rondaTerminada'] ?? false;
      _mensaje = d['mensaje'] ?? '';
      _numCartasPorAsiento =
          ((d['numCartas'] as List?) ?? []).map((e) => e as int).toList();
    });
  }


  // Nombre del jugador en un ASIENTO ABSOLUTO (el que viene en el estado).
  String _nombrePosicion(int asiento) {
    final cfg = widget.config;
    if (cfg != null) {
      if (asiento < cfg.jugadores.length) {
        return cfg.jugadores[asiento].nombre;
      }
    }
    return _nombreAsiento(asiento); // modo local: etiquetas
  }

  @override
  void dispose() {
    MusicController.instance.reanudar();
    super.dispose();
  }

  // Mensaje del turno actual, según quién soy yo.
  String _mensajeTurno() {
    final miAsiento = (_enRed && !_soyAnfitrion) ? _miAsientoEnRed() : 0;
    if (_turno == miAsiento) return '¡Tu turno!';
    return 'Turno de ${_nombrePosicion(_turno)}';
  }

  void _repartirNuevaRonda() {
    // (El barajador se habrá rotado al terminar la ronda anterior.)
    final reparto = DealEngine2v2.repartirPara(_numJug);
    _manos = reparto.manos;
    _paloVirado = reparto.paloVirado;
    _vira = reparto.vira;
    _baza = [];
    _turno = (_barajador + 1) % _numJug; // sale el de la izquierda del que baraja
    _manosEquipo0 = 0;
    _manosEquipo1 = 0;
    _rondaTerminada = false;
    _mensaje = _mensajeTurno();
    setState(() {});
    _continuarSiTocaIA();
    if (_enRed && _soyAnfitrion) _enviarEstadoJuego();
  }

  List<CardModel> _validasDe(int asiento) {
    // En red, el invitado calcula sus válidas sobre su mano recibida.
    final List<CardModel> mano;
    if (_enRed && !_soyAnfitrion) {
      mano = _miManoRed;
    } else if (asiento < _manos.length) {
      mano = _manos[asiento];
    } else {
      return <CardModel>[];
    }
    final paloInicial = _baza.isEmpty ? null : _baza.first.carta.suit;
    return TrickEngine2v2.cartasValidas(
      mano: mano,
      paloInicialBaza: paloInicial,
      paloVirado: _paloVirado,
    );
  }

  // Mi asiento en la partida (índice en la config cuyo id == idLocal).
  int _miAsientoEnRed() {
    final cfg = widget.config!;
    for (int i = 0; i < cfg.jugadores.length; i++) {
      if (cfg.jugadores[i].id == cfg.idLocal) return i;
    }
    return 0;
  }

  void _jugarCartaHumano(CardModel carta) {
    if (_enRed && !_soyAnfitrion) {
      // El invitado manda su carta al anfitrión (no la juega local).
      widget.conexion!.enviarAlAnfitrion(
        MensajeRed(TipoMensajeSala.jugarCarta, {
          'carta': TraductorCartas.aTexto(carta),
          'asiento': _miAsientoEnRed(),
        }).codificar());
      return;
    }
    if (_turno != 0 || _rondaTerminada) return;
    final validas = _validasDe(0);
    if (!validas.contains(carta)) {
      setState(() => _mensaje = 'Esa carta no es válida ahora.');
      return;
    }
    _jugarCarta(0, carta);
  }

  void _jugarCarta(int asiento, CardModel carta) {
    _manos[asiento].remove(carta);
    _baza.add(CartaJugada2v2(asiento: asiento, carta: carta));

    if (_baza.length == _numJug) {
      _resolverBaza();
    } else {
      _turno = (_turno + 1) % _numJug;
      _mensaje = _mensajeTurno();
      setState(() {});
      if (_enRed && _soyAnfitrion) _enviarEstadoJuego();
      _continuarSiTocaIA();
    }
  }

  void _continuarSiTocaIA() {
    if (_rondaTerminada) return;
    if (_baza.length == _numJug) return;
    if (_enRed) {
      if (!_soyAnfitrion) return;
      final cfg = widget.config!;
      if (_turno >= cfg.jugadores.length) return;
      if (!cfg.jugadores[_turno].esIA) return;
    } else {
      if (_turno == 0) return;
    }

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted || _rondaTerminada) return;
      final asiento = _turno;
      final validas = _validasDe(asiento);
      final carta = AiPlayer2v2.elegirCarta(
        miAsiento: asiento,
        validas: validas,
        bazaActual: _baza,
        paloVirado: _paloVirado,
      );
      _jugarCarta(asiento, carta);
    });
  }

  void _resolverBaza() {
    final ganador = TrickEngine2v2.determinarGanador(
      jugadas: _baza,
      paloVirado: _paloVirado,
    );
    final equipoGanador = ganador.asiento % 2;
    if (equipoGanador == 0) {
      _manosEquipo0++;
    } else {
      _manosEquipo1++;
    }
    _mensaje = '${_nombrePosicion(ganador.asiento)} gana la mano';
    _turno = ganador.asiento;

    setState(() {});

    // Pausa para que se vea la baza completa antes de limpiarla.
    if (_enRed && _soyAnfitrion) _enviarEstadoJuego();
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      _baza = [];
      final cartasRestantes = _manos.fold<int>(0, (s, m) => s + m.length);
      if (cartasRestantes == 0) {
        _rondaTerminada = true;
        _barajador = (_barajador + 1) % _numJug; // rota para la próxima mano
        _mensaje = _manosEquipo0 > _manosEquipo1
            ? '¡TU EQUIPO gana la ronda! ($_manosEquipo0 - $_manosEquipo1)'
            : 'Equipo rival gana la ronda ($_manosEquipo0 - $_manosEquipo1)';
      }
      setState(() {});
      if (_enRed && _soyAnfitrion) _enviarEstadoJuego();
      if (!_rondaTerminada) _continuarSiTocaIA();
    });
  }

  String _nombreAsiento(int asiento) {
    // Si hay config de sala, usar el apodo real del jugador en ese asiento.
    final cfg = widget.config;
    if (cfg != null) {
      for (final j in cfg.jugadores) {
        if (j.asiento == asiento) return j.nombre;
      }
    }
    // Sin config (modo local de prueba): etiquetas genéricas.
    switch (asiento) {
      case 0:
        return 'Tú';
      case 1:
        return 'Rival izq.';
      case 2:
        return 'Compañero';
      default:
        return 'Rival der.';
    }
  }

  // Carta jugada por un asiento en la baza actual (o null si no ha jugado).
  // Mi asiento absoluto (0 si soy anfitrión o modo local).
  int get _miAsientoBase =>
      (_enRed && !_soyAnfitrion) ? _miAsientoEnRed() : 0;

  // Asiento absoluto que se dibuja en una POSICIÓN visual.
  // posición 0 = abajo (yo), 1 = izq, 2 = arriba, 3 = der.
  int _asientoEnPos(int posicion) {
    return (_miAsientoBase + posicion) % _numJug;
  }

  CardModel? _cartaEnMesaDe(int asiento) {
    for (final j in _baza) {
      if (j.asiento == asiento) return j.carta;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final misCartas = (_enRed && !_soyAnfitrion)
        ? _miManoRed
        : (_manos.isNotEmpty ? _manos[0] : <CardModel>[]);
    final miAsiento = (_enRed && !_soyAnfitrion) ? _miAsientoEnRed() : 0;
    final validas = _turno == miAsiento && !_rondaTerminada
        ? _validasDe(miAsiento)
        : <CardModel>[];

    return Scaffold(
      body: Stack(
        children: [
          // Tablero verde de fondo
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Barra superior: volver + marcador
                _barraSuperior(),

                // Compañero (arriba)
                _jugadorRival(asiento: _asientoEnPos(2), etiqueta: _nombrePosicion(_asientoEnPos(2)), esCompanero: true),

                // Zona central: rivales a los lados + cartas jugadas
                Expanded(
                  child: Row(
                    children: [
                      _jugadorRivalLateral(asiento: _asientoEnPos(1), etiqueta: _nombrePosicion(_asientoEnPos(1))),
                      Expanded(child: _zonaCentral()),
                      _jugadorRivalLateral(asiento: _asientoEnPos(3), etiqueta: _nombrePosicion(_asientoEnPos(3))),
                    ],
                  ),
                ),

                // Mensaje de estado
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 4),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _mensaje,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),

                // Tus cartas (abajo, en abanico)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 10),
                  child: _misCartasAbanico(misCartas, validas),
                ),

                if (_rondaTerminada)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ElevatedButton(
                      onPressed: _repartirNuevaRonda,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEFAF1F),
                        foregroundColor: const Color(0xFF3A2B12),
                      ),
                      child: const Text('Nueva ronda'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _barraSuperior() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.chevron_left, color: Colors.white),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _marcadorEquipo('NOSOTROS', _manosEquipo0, Colors.lightBlueAccent),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    children: [
                      const Text('Triunfo',
                          style: TextStyle(color: Colors.white60, fontSize: 10)),
                      Text(_vira.suit.displayName,
                          style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ],
                  ),
                ),
                _marcadorEquipo('ELLOS', _manosEquipo1, Colors.redAccent),
              ],
            ),
          ),
          const SizedBox(width: 38),
        ],
      ),
    );
  }

  Widget _marcadorEquipo(String titulo, int valor, Color color) {
    return Column(
      children: [
        Text(titulo,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        Text('$valor',
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // Compañero arriba: cartas boca abajo en mini.
  // Número de cartas que tiene un asiento (en red usa lo recibido).
  int _cartasDe(int asiento) {
    if (_enRed && !_soyAnfitrion) {
      if (asiento < _numCartasPorAsiento.length) {
        return _numCartasPorAsiento[asiento];
      }
      return 0;
    }
    return _manos.isNotEmpty ? _manos[asiento].length : 0;
  }

  Widget _jugadorRival({
    required int asiento,
    required String etiqueta,
    bool esCompanero = false,
  }) {
    final numCartas = _cartasDe(asiento);
    final esTurno = _turno == asiento && !_rondaTerminada;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: esTurno ? const Color(0xFFEFAF1F) : Colors.black38,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              etiqueta,
              style: TextStyle(
                color: esTurno ? const Color(0xFF3A2B12) : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          _miniCartasBocaAbajo(numCartas),
        ],
      ),
    );
  }

  // Rivales laterales: etiqueta + cartas boca abajo en vertical mini.
  Widget _jugadorRivalLateral({required int asiento, required String etiqueta}) {
    final numCartas = _cartasDe(asiento);
    final esTurno = _turno == asiento && !_rondaTerminada;
    return SizedBox(
      width: 56,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: esTurno ? const Color(0xFFEFAF1F) : Colors.black38,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              etiqueta,
              style: TextStyle(
                color: esTurno ? const Color(0xFF3A2B12) : Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          _miniCartasBocaAbajo(numCartas, pequeno: true),
        ],
      ),
    );
  }

  Widget _miniCartasBocaAbajo(int n, {bool pequeno = false}) {
    final ancho = pequeno ? 26.0 : 34.0;
    final alto = pequeno ? 40.0 : 52.0;
    final solap = pequeno ? 12.0 : 16.0;
    if (n == 0) return SizedBox(height: alto);
    return SizedBox(
      width: ancho + (n - 1) * solap,
      height: alto,
      child: Stack(
        children: List.generate(n, (i) {
          return Positioned(
            left: i * solap,
            child: Container(
              width: ancho,
              height: alto,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/cards/trasera.png', fit: BoxFit.cover),
            ),
          );
        }),
      ),
    );
  }

  // Zona central: muestra las cartas jugadas en sus posiciones.
  Widget _zonaCentral() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Compañero (arriba) = posición 2
        Align(alignment: Alignment.topCenter,
            child: _cartaJugadaMini(_asientoEnPos(2))),
        // Rival izq = posición 1
        Align(alignment: Alignment.centerLeft,
            child: _cartaJugadaMini(_asientoEnPos(1))),
        // Rival der = posición 3
        Align(alignment: Alignment.centerRight,
            child: _cartaJugadaMini(_asientoEnPos(3))),
        // Tú (abajo) = posición 0
        Align(alignment: Alignment.bottomCenter,
            child: _cartaJugadaMini(_asientoEnPos(0))),
      ],
    );
  }

  Widget _cartaJugadaMini(int asiento) {
    final carta = _cartaEnMesaDe(asiento);
    if (carta == null) return const SizedBox(width: 60, height: 95);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        width: 60,
        height: 95,
        child: FittedBox(child: CardWidget(card: carta)),
      ),
    );
  }

  Widget _misCartasAbanico(List<CardModel> cartas, List<CardModel> validas) {
    if (cartas.isEmpty) return const SizedBox(height: 135);
    final widgets = cartas.map((c) {
      final jugable = validas.contains(c);
      return GestureDetector(
        onTap: jugable ? () => _jugarCartaHumano(c) : null,
        child: Opacity(
          opacity: jugable ? 1.0 : 0.45,
          child: CardWidget(card: c),
        ),
      );
    }).toList();

    return _Abanico2v2(cartas: widgets);
  }
}

/// Abanico de cartas (copia adaptada del usado en 1vs1).
class _Abanico2v2 extends StatelessWidget {
  final List<Widget> cartas;
  const _Abanico2v2({required this.cartas});

  @override
  Widget build(BuildContext context) {
    final n = cartas.length;
    const anchoCarta = 85.0;
    const altoCarta = 135.0;
    const solapamiento = 52.0;
    if (n == 0) return const SizedBox(width: anchoCarta, height: altoCarta);

    final anchoTotal = anchoCarta + (n - 1) * solapamiento;
    const anguloMax = 6.0;

    return SizedBox(
      width: anchoTotal,
      height: altoCarta + 16,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(n, (i) {
          final centro = (n - 1) / 2;
          final distancia = i - centro;
          final angulo = n > 1 ? (distancia / centro) * anguloMax : 0.0;
          final offsetY = distancia.abs() * 4;
          return Positioned(
            left: i * solapamiento,
            top: offsetY,
            child: Transform.rotate(
              angle: angulo * 3.14159 / 180,
              alignment: Alignment.bottomCenter,
              child: cartas[i],
            ),
          );
        }),
      ),
    );
  }
}