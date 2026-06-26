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
  // Marcador del Envite por EQUIPO (como el 1v1 pero por bando).
  int _piedrasEquipo0 = 0;
  int _piedrasEquipo1 = 0;
  int _chicosEquipo0 = 0;
  int _chicosEquipo1 = 0;
  // ===== Envite por equipo =====
  int _nivelApuesta = 0;       // 0=Base,1=Envido,2=Siete,3=Nueve,4=ChicoFuera
  bool _enviteCantado = false; // ¿hay un envite esperando respuesta?
  int _equipoCanto = -1;       // qué equipo cantó el envite pendiente (0/1)
  int _nivelPropuesto = 0;     // nivel al que subiría si se acepta
  // ===== Tumbo por equipo =====
  bool _manoEsDeTumbo = false;
  int _equipoDecideTumbo = -1; // -1=sin tumbo/forzoso, 0=eq0 decide, 1=eq1
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
        } else if (msg.tipo == TipoMensajeSala.proponerEnvite) {
          final equipo = msg.datos['equipo'];
          if (equipo != null) _anfitrionRegistraCanto(equipo);
        } else if (msg.tipo == TipoMensajeSala.respuestaEnvite) {
          _anfitrionResuelveRespuesta(msg.datos['accion']);
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
      'piedrasEquipo0': _piedrasEquipo0,
      'piedrasEquipo1': _piedrasEquipo1,
      'chicosEquipo0': _chicosEquipo0,
      'chicosEquipo1': _chicosEquipo1,
      'nivelApuesta': _nivelApuesta,
      'manoEsDeTumbo': _manoEsDeTumbo,
      'equipoDecideTumbo': _equipoDecideTumbo,
      'enviteCantado': _enviteCantado,
      'equipoCanto': _equipoCanto,
      'nivelPropuesto': _nivelPropuesto,
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
      _piedrasEquipo0 = d['piedrasEquipo0'] ?? 0;
      _piedrasEquipo1 = d['piedrasEquipo1'] ?? 0;
      _chicosEquipo0 = d['chicosEquipo0'] ?? 0;
      _chicosEquipo1 = d['chicosEquipo1'] ?? 0;
      _nivelApuesta = d['nivelApuesta'] ?? 0;
      _manoEsDeTumbo = d['manoEsDeTumbo'] ?? false;
      _equipoDecideTumbo = d['equipoDecideTumbo'] ?? -1;
      _enviteCantado = d['enviteCantado'] ?? false;
      _equipoCanto = d['equipoCanto'] ?? -1;
      _nivelPropuesto = d['nivelPropuesto'] ?? 0;
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

  // ===== ENVITE =====
  // ¿Puede el equipo local cantar/subir ahora?
  bool get _puedoCantar {
    if (_rondaTerminada || _equipoDecideTumbo != -1) return false;
    if (_nivelApuesta >= 4 && !_enviteCantado) return false;
    final miEquipo = _miEquipo();
    if (_enviteCantado) {
      // Hay envite pendiente: solo puede SUBIR el equipo contrario al que cantó.
      return _equipoCanto != miEquipo && _nivelPropuesto < 4;
    }
    // No hay envite pendiente: cualquiera puede cantar si no se llegó al máximo.
    return _nivelApuesta < 4;
  }

  // ¿Debe el equipo local responder (hay envite del rival)?
  bool get _deboResponder =>
      _enviteCantado && _equipoCanto != _miEquipo();

  // Lo llama quien pulsa ENVIDAR / SUBIR.
  void _cantarEnvite() {
    if (!_puedoCantar) return;
    final miEquipo = _miEquipo();
    if (_soyAnfitrion) {
      _anfitrionRegistraCanto(miEquipo);
    } else {
      widget.conexion!.enviarAlAnfitrion(
        MensajeRed(TipoMensajeSala.proponerEnvite, {'equipo': miEquipo})
            .codificar());
    }
  }

  void _anfitrionRegistraCanto(int equipo) {
    if (_rondaTerminada) return;
    if (_enviteCantado) {
      // SUBIR: solo el equipo contrario al que cantó.
      if (equipo == _equipoCanto) return;
      if (_nivelPropuesto >= 4) return;
      _nivelPropuesto += 1; // sube un nivel más
      _equipoCanto = equipo; // ahora cantó este equipo; responde el otro
      _mensaje = 'Suben la apuesta. ¡Responded!';
    } else {
      if (_nivelApuesta >= 4) return;
      _enviteCantado = true;
      _equipoCanto = equipo;
      _nivelPropuesto = _nivelApuesta + 1;
      _mensaje = 'Envite cantado. ¡Responded!';
    }
    setState(() {});
    _enviarEstadoJuego();
  }

  void _responderEnvite(String accion) {
    if (!_enviteCantado) return;
    if (_soyAnfitrion) {
      _anfitrionResuelveRespuesta(accion);
    } else {
      widget.conexion!.enviarAlAnfitrion(
        MensajeRed(TipoMensajeSala.respuestaEnvite, {'accion': accion})
            .codificar());
    }
  }

  void _anfitrionResuelveRespuesta(String accion) {
    if (!_enviteCantado) return;
    if (accion == 'juego') {
      _nivelApuesta = _nivelPropuesto;
      _enviteCantado = false;
      _equipoCanto = -1;
      _mensaje = 'Envite aceptado.';
    } else if (accion == 'paso') {
      final valores = [2, 4, 7, 9, 12];
      final nivelAnterior = _nivelPropuesto - 1;
      final ganaPiedras = nivelAnterior == 0 ? 1 : valores[nivelAnterior];
      if (_equipoCanto == 0) {
        _piedrasEquipo0 += ganaPiedras;
      } else {
        _piedrasEquipo1 += ganaPiedras;
      }
      _enviteCantado = false;
      _equipoCanto = -1;
      _mensaje = 'No quieren. +$ganaPiedras piedras.';
      _comprobarChicoEquipos();
    }
    setState(() {});
    _enviarEstadoJuego();
  }

  void _comprobarChicoEquipos() {
    if (_piedrasEquipo0 >= 12) {
      _chicosEquipo0++;
      _piedrasEquipo0 = 0;
      _piedrasEquipo1 = 0;
    } else if (_piedrasEquipo1 >= 12) {
      _chicosEquipo1++;
      _piedrasEquipo0 = 0;
      _piedrasEquipo1 = 0;
    }
  }

  // Suma las piedras de la mano al equipo ganador y comprueba el chico.
  void _finalizarRondaEquipos() {
    final valores = [2, 4, 7, 9, 12];
    final valorMano = _manoEsDeTumbo ? 3 : valores[_nivelApuesta];
    final gana0 = _manosEquipo0 > _manosEquipo1;
    if (gana0) {
      _piedrasEquipo0 += valorMano;
    } else {
      _piedrasEquipo1 += valorMano;
    }
    // Comprobar chico (12 piedras) y fin de partida (2 chicos).
    if (_piedrasEquipo0 >= 12) {
      _chicosEquipo0++;
      _piedrasEquipo0 = 0;
      _piedrasEquipo1 = 0;
    } else if (_piedrasEquipo1 >= 12) {
      _chicosEquipo1++;
      _piedrasEquipo0 = 0;
      _piedrasEquipo1 = 0;
    }
    final miEquipo = _miEquipo();
    final ganadorEquipo = gana0 ? 0 : 1;
    _mensaje = (ganadorEquipo == miEquipo)
        ? '¡Tu equipo gana la mano! (+$valorMano)'
        : 'El equipo rival gana la mano (+$valorMano)';
  }

  // El equipo del jugador local (0 o 1).
  int _miEquipo() {
    final cfg = widget.config;
    if (cfg == null) return 0;
    final miAsiento = (_enRed && !_soyAnfitrion) ? _miAsientoEnRed() : 0;
    if (miAsiento < cfg.jugadores.length) {
      return cfg.jugadores[miAsiento].equipo;
    }
    return miAsiento % 2;
  }

  // Mensaje del turno actual, según quién soy yo.
  String _mensajeTurno() {
    final miAsiento = (_enRed && !_soyAnfitrion) ? _miAsientoEnRed() : 0;
    if (_turno == miAsiento) return '¡Tu turno!';
    return 'Turno de ${_nombrePosicion(_turno)}';
  }

  void _decidirTumboEquipo(bool juega) {
    if (_soyAnfitrion) {
      _anfitrionResuelveTumboEquipo(juega);
    } else {
      widget.conexion!.enviarAlAnfitrion(
          MensajeRed(TipoMensajeSala.decisionTumbo, {'juega': juega}).codificar());
    }
  }

  void _anfitrionResuelveTumboEquipo(bool juega) {
    if (_equipoDecideTumbo == -1) return;
    final quien = _equipoDecideTumbo;
    if (juega) {
      _manoEsDeTumbo = true;
      _equipoDecideTumbo = -1;
      final nombre = quien == 0 ? 'Equipo A' : 'Equipo B';
      _mensaje = '$nombre juega el tumbo (vale 3)';
    } else {
      final rival = quien == 0 ? 1 : 0;
      if (rival == 0) {
        _piedrasEquipo0 += 1;
      } else {
        _piedrasEquipo1 += 1;
      }
      _equipoDecideTumbo = -1;
      final nombre = quien == 0 ? 'Equipo A' : 'Equipo B';
      _mensaje = '$nombre se retira. Rival +1 piedra.';
      if (_piedrasEquipo0 >= 12) {
        _chicosEquipo0++;
        _piedrasEquipo0 = 0;
        _piedrasEquipo1 = 0;
      } else if (_piedrasEquipo1 >= 12) {
        _chicosEquipo1++;
        _piedrasEquipo0 = 0;
        _piedrasEquipo1 = 0;
      }
    }
    setState(() {});
    _enviarEstadoJuego();
    if (!juega) Future.delayed(const Duration(seconds: 2), _repartirNuevaRonda);
  }

  void _repartirNuevaRonda() {
    // (El barajador se habrá rotado al terminar la ronda anterior.)
    final reparto = DealEngine2v2.repartirPara(_numJug);
    _manos = reparto.manos;
    _paloVirado = reparto.paloVirado;
    _vira = reparto.vira;
    _baza = [];
    _nivelApuesta = 0;
    _enviteCantado = false;
    _equipoCanto = -1;
    _nivelPropuesto = 0;
    _manoEsDeTumbo = false;
    _equipoDecideTumbo = -1;
    _turno = (_barajador + 1) % _numJug; // sale el de la izquierda del que baraja
    _manosEquipo0 = 0;
    _manosEquipo1 = 0;
    _rondaTerminada = false;
    _mensaje = _mensajeTurno();
    // Tumbo: comprobar si algún equipo tiene exactamente 11 piedras.
    final eq0EnTumbo = _piedrasEquipo0 == 11;
    final eq1EnTumbo = _piedrasEquipo1 == 11;
    if (eq0EnTumbo && eq1EnTumbo) {
      _manoEsDeTumbo = true;
      _mensaje = '🔥 ¡Tumbo forzoso! Los dos equipos a 11.';
    } else if (eq0EnTumbo) {
      _equipoDecideTumbo = 0;
      _mensaje = '🔥 Equipo A a 11 piedras. ¿Juegan el tumbo?';
    } else if (eq1EnTumbo) {
      _equipoDecideTumbo = 1;
      _mensaje = '🔥 Equipo B a 11 piedras. ¿Juegan el tumbo?';
    }
    setState(() {});
    _continuarSiTocaIA();
    if (_enRed && _soyAnfitrion) _enviarEstadoJuego();
  }

  List<CardModel> _validasDe(int asiento) {
    if (_equipoDecideTumbo != -1) return [];
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
        _finalizarRondaEquipos();
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

                // Tumbo pendiente
                _botonesTumbo(),
                // Botones del envite (cantar/subir/responder)
                _botonesEnvite(),
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
                _marcadorEquipo('NOSOTROS', _miEquipo(), Colors.lightBlueAccent),
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
                _marcadorEquipo('ELLOS', 1 - _miEquipo(), Colors.redAccent),
              ],
            ),
          ),
          const SizedBox(width: 38),
        ],
      ),
    );
  }

  Widget _marcadorEquipo(String titulo, int equipo, Color color) {
    final chicos = equipo == 0 ? _chicosEquipo0 : _chicosEquipo1;
    final piedras = equipo == 0 ? _piedrasEquipo0 : _piedrasEquipo1;
    final bazas = equipo == 0 ? _manosEquipo0 : _manosEquipo1;
    return Column(
      children: [
        Text(titulo,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        // Chicos y piedras (el marcador real del Envite)
        Text('$chicos chico${chicos == 1 ? "" : "s"}',
            style: const TextStyle(color: Colors.white70, fontSize: 10)),
        Text('$piedras',
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const Text('piedras',
            style: TextStyle(color: Colors.white54, fontSize: 9)),
        // Bazas de la mano actual
        Text('bazas: $bazas',
            style: const TextStyle(color: Colors.amber, fontSize: 10)),
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
        // La VIRA (triunfo) en el centro, detrás de las cartas jugadas.
        Align(
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Triunfo',
                  style: TextStyle(
                      color: Colors.white60,
                      fontSize: 9,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              SizedBox(
                width: 44,
                height: 70,
                child: FittedBox(child: CardWidget(card: _vira)),
              ),
            ],
          ),
        ),
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

  // Nombre del nivel de apuesta propuesto.
  String _nombreNivel(int nivel) {
    const nombres = ['Base', 'Envido', 'Siete', 'Nueve', 'Chico fuera'];
    if (nivel >= 0 && nivel < nombres.length) return nombres[nivel];
    return '';
  }

  Widget _botonesTumbo() {
    if (_equipoDecideTumbo == -1) return const SizedBox.shrink();
    final miEquipo = _miEquipo();
    if (miEquipo == _equipoDecideTumbo) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _decidirTumboEquipo(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('🔥 JUGAR TUMBO (3)',
                  style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => _decidirTumboEquipo(false),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
              child: const Text('RETIRARME',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        '🔥 El equipo rival decide el tumbo...',
        style: const TextStyle(color: Colors.orange, fontStyle: FontStyle.italic),
      ),
    );
  }

  // Fila de botones del envite según el estado.
  Widget _botonesEnvite() {
    if (_rondaTerminada) return const SizedBox.shrink();

    // Si mi equipo debe responder a un envite del rival:
    if (_deboResponder) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${_nombreNivel(_nivelPropuesto)}: ',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
            _botonEnvite('ACEPTAR', Colors.green,
                () => _responderEnvite('juego')),
            const SizedBox(width: 6),
            if (_nivelPropuesto < 4)
              _botonEnvite('SUBIR', Colors.orange, _cantarEnvite),
            const SizedBox(width: 6),
            _botonEnvite('NO QUIERO', Colors.red,
                () => _responderEnvite('paso')),
          ],
        ),
      );
    }

    // Si puedo cantar (y no hay nada pendiente para mí):
    if (_puedoCantar && !_enviteCantado) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: _botonEnvite(
            'ENVIDAR (${_nombreNivel(_nivelApuesta + 1)})',
            Colors.amber, _cantarEnvite),
      );
    }

    // Si mi equipo cantó y espera respuesta del rival:
    if (_enviteCantado && _equipoCanto == _miEquipo()) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text('Esperando respuesta del rival...',
            style: TextStyle(color: Colors.white70, fontSize: 12)),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _botonEnvite(String texto, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 32),
      ),
      child: Text(texto,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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