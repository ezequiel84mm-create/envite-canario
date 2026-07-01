import 'dart:async';
import 'dart:math';
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
import 'package:audioplayers/audioplayers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/settings/voces.dart';
import '../widgets/widgets_mesa.dart';
import '../widgets/rueda_senas.dart';
import '../../domain/models/senas.dart';

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
  // Bazas ganadas por cada jugador (asiento 0..numJug-1).
  List<int> _bazasAsiento = [0, 0, 0, 0];
  final Map<int, String> _senaVisible = {};
  final List<MapEntry<int, String>> _colaSenas = [];
  bool _mostrandoSena = false;
  // Marcador del Envite por EQUIPO (como el 1v1 pero por bando).
  int _piedrasEquipo0 = 0;
  int _piedrasEquipo1 = 0;
  int _chicosEquipo0 = 0;
  int _chicosEquipo1 = 0;
  // ===== Envite por equipo =====
  int _nivelApuesta = 0;       // 0=Base,1=Envido,2=Siete,3=Nueve,4=ChicoFuera
  bool _enviteCantado = false; // ¿hay un envite esperando respuesta?
  final _random22 = Random();
  int _equipoCanto = -1;       // qué equipo cantó el envite pendiente (0/1)
  int _nivelPropuesto = 0;     // nivel al que subiría si se acepta
  int _equipoTurnoApuesta = -1; // -1=cualquiera puede cantar; si no, solo ese equipo
  // ===== Diálogo fin de mano/chico/partida =====
  String _pendienteDialogo = 'ninguno'; // ninguno/mano/chico/partida
  int _piedrasSumadasDialogo = 0;
  int _ganadorDialogoEquipo = -1; // equipo (0/1) que gana lo que muestra el diálogo
  // ===== Tumbo por equipo =====
  bool _manoEsDeTumbo = false;
  int _equipoDecideTumbo = -1; // -1=sin tumbo/forzoso, 0=eq0 decide, 1=eq1
  String _mensaje = '';
  bool _mensajeEsTurno = false; // si true, el invitado recalcula el texto
  bool _rondaTerminada = false;
  int _numJug = 4; // jugadores en la partida (4, 6 u 8); 4 por defecto
  int _barajador = 0; // quién baraja esta mano; sale el de su izquierda

  // ¿Esta partida es en red? (hay conexión y config)
  bool get _enRed => widget.conexion != null && widget.config != null;
  // ¿Soy el anfitrión? (en modo local, sí por defecto)
  bool get _soyAnfitrion => widget.conexion?.soyAnfitrion ?? true;

  List<CardModel> _miManoRed = []; // mano del invitado recibida por red
  List<int> _numCartasPorAsiento = []; // cuántas cartas tiene cada asiento

  // Reproductor de efectos (voz de los envites).
  final AudioPlayer _sfxPlayer = AudioPlayer();

  // Reproduce el canto de voz según el nivel de apuesta.
  // nivel 1=Envido, 2=Siete, 3=Nueve, 4=Chico Fuera.
  void _sonidoApuesta(int nivel, {required int equipoCanta}) {
    if (!AppSettings.instance.efectosActivados) return;
    const nombres = {1: 'envido', 2: 'siete', 3: 'nueve', 4: 'chico_fuera'};
    final nombre = nombres[nivel];
    if (nombre == null) return;
    // El equipo local usa la voz propia; el rival una voz por defecto.
    final idVoz = (equipoCanta == _miEquipo())
        ? AppSettings.instance.vozPropia
        : Voces.disponibles.first.id;
    final voz = Voces.porId(idVoz);
    _sfxPlayer.play(AssetSource('audio/${voz.rutaNivel(nombre)}'));
  }

  // Reproduce un efecto simple (reparto, recoger baraja).
  void _reproducirEfecto(String archivo) {
    if (!AppSettings.instance.efectosActivados) return;
    _sfxPlayer.play(AssetSource('audio/$archivo'));
  }

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
        if (!mounted) return;
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
        } else if (msg.tipo == TipoMensajeSala.decisionTumbo) {
          _anfitrionResuelveTumboEquipo(msg.datos['juega'] == true);
        } else if (msg.tipo == TipoMensajeSala.enviarSena) {
          final asiento = msg.datos['asiento'];
          final senaId = msg.datos['sena'];
          if (asiento != null && senaId != null) {
            _procesarSena(asiento, senaId);
          }
        }
      };
      // Si un invitado se cae a media partida, su asiento pasa a IA.
      con.alDesconectarInvitado = (idInvitado) {
        if (!mounted) return;
        _jugadorDesconectado(idInvitado);
      };
    } else {
      con.alRecibirDeAnfitrion = (texto) {
        if (!mounted) return;
        final msg = MensajeRed.decodificar(texto);
        if (msg == null) return;
        if (msg.tipo == TipoMensajeSala.estadoJuego) {
          _invitadoRecibeEstado(msg.datos);
        } else if (msg.tipo == TipoMensajeSala.enviarSena) {
          final asiento = msg.datos['asiento'];
          final senaId = msg.datos['sena'];
          final ver = msg.datos['ver'] == true;
          final s = senaId != null ? senaPorId(senaId) : null;
          if (s != null) {
            if (s.sonido) _reproducirEfecto('silbido.m4a');
            if (ver && asiento != null) _mostrarSenaLocal(asiento, senaId);
          }
        } else if (msg.tipo == TipoMensajeSala.miMano) {
          setState(() {
            _miManoRed = TraductorCartas.listaDesdeTexto(msg.datos['mano'] ?? []);
          });
        }
      };
    }
  }

  // ===== SEÑAS ENTRE COMPAÑEROS =====

  void _enviarSena(Sena sena) {
    final asiento = _miAsientoBase;
    if (_soyAnfitrion) {
      _procesarSena(asiento, sena.id);
    } else {
      widget.conexion!.enviarAlAnfitrion(
          MensajeRed(TipoMensajeSala.enviarSena,
              {'asiento': asiento, 'sena': sena.id}).codificar());
    }
  }

  void _procesarSena(int asiento, String senaId) {
    final sena = senaPorId(senaId);
    if (sena == null) return;
    final equipo = _equipoDeAsiento(asiento);
    if (sena.sonido) _reproducirEfecto('silbido.m4a');
    if (_equipoDeAsiento(_miAsientoBase) == equipo) {
      _mostrarSenaLocal(asiento, senaId);
    }
    if (_enRed) {
      final cfg = widget.config;
      if (cfg != null) {
        for (final j in cfg.jugadores) {
          if (j.esIA) continue;
          if (j.id == widget.config!.idLocal) continue;
          final mismoEquipo = _equipoDeAsiento(j.asiento) == equipo;
          if (mismoEquipo || sena.sonido) {
            widget.conexion!.enviarA(
                j.id,
                MensajeRed(TipoMensajeSala.enviarSena, {
                  'asiento': asiento,
                  'sena': senaId,
                  'ver': mismoEquipo,
                }).codificar());
          }
        }
      }
    }
  }

  void _mostrarSenaLocal(int asiento, String senaId) {
    _colaSenas.add(MapEntry(asiento, senaId));
    _procesarColaSenas();
  }

  void _procesarColaSenas() {
    if (_mostrandoSena) return;
    if (_colaSenas.isEmpty) return;
    _mostrandoSena = true;
    final entrada = _colaSenas.removeAt(0);
    final asiento = entrada.key;
    final senaId = entrada.value;
    setState(() {
      _senaVisible[asiento] = senaId;
    });
    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _senaVisible.remove(asiento);
      });
      Timer(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        _mostrandoSena = false;
        _procesarColaSenas();
      });
    });
  }

  int _tiempoParaSenas() {
    if (_enRed && !_soyAnfitrion) return 0;
    if (_manoEsDeTumbo || _equipoDecideTumbo != -1) return 1200;
    int total = 0;
    for (int a = 0; a < _numJug; a++) {
      if (_esIA(a) && a < _manos.length) {
        total += _senasDeMano(_manos[a]).length;
      }
    }
    if (total == 0) return 1200;
    final ms = 1000 + total * 1400;
    return ms > 6000 ? 6000 : ms;
  }

  void _iaCompanerasSenan() {
    if (_enRed && !_soyAnfitrion) return;
    if (_manoEsDeTumbo || _equipoDecideTumbo != -1) return;
    final pendientes = <MapEntry<int, String>>[];
    for (int asiento = 0; asiento < _numJug; asiento++) {
      if (!_esIA(asiento)) continue;
      if (asiento >= _manos.length) continue;
      for (final senaId in _senasDeMano(_manos[asiento])) {
        pendientes.add(MapEntry(asiento, senaId));
      }
    }
    if (pendientes.isEmpty) return;
    _procesarSena(pendientes.first.key, 'silbido');
    for (final e in pendientes) {
      _procesarSena(e.key, e.value);
    }
  }

  bool _esIA(int asiento) {
    final cfg = widget.config;
    if (cfg == null) return asiento != 0;
    for (final j in cfg.jugadores) {
      if (j.asiento == asiento) return j.esIA;
    }
    return false;
  }

  // En 2v2 no hay fijas: triunfo = carta del palo virado. Solo se señan
  // Malilla y Rey (el modelo filtra por aplicaEn(4)).
  List<String> _senasDeMano(List<CardModel> mano) {
    final res = <String>[];
    int triunfos = 0;
    for (final c in mano) {
      if (c.suit == _paloVirado) triunfos++;
      if (c.suit == _paloVirado && c.value == CardValue.dos) {
        res.add('malilla');
      } else if (c.suit == _paloVirado && c.value == CardValue.rey) {
        res.add('rey');
      } else if (c.suit == _paloVirado && c.value == CardValue.caballo) {
        res.add('caballo');
      } else if (c.suit == Suit.oros && c.value == CardValue.sota) {
        res.add('perica');
      }
    }
    if (triunfos == 0) {
      res.add('ciego');
    } else if (triunfos == 3) {
      res.add('flus');
    }
    return res.where((id) {
      final s = senaPorId(id);
      return s != null && s.aplicaEn(_numJug);
    }).toList();
  }

  Widget _globoSena(int asiento) {
    final senaId = _senaVisible[asiento];
    if (senaId == null) return const SizedBox.shrink();
    final s = senaPorId(senaId);
    if (s == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(s.emoji, style: const TextStyle(fontSize: 22)),
    );
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
      'bazasAsiento': _bazasAsiento,
      'piedrasEquipo0': _piedrasEquipo0,
      'piedrasEquipo1': _piedrasEquipo1,
      'chicosEquipo0': _chicosEquipo0,
      'chicosEquipo1': _chicosEquipo1,
      'nivelApuesta': _nivelApuesta,
      'manoEsDeTumbo': _manoEsDeTumbo,
      'equipoDecideTumbo': _equipoDecideTumbo,
      'pendienteDialogo': _pendienteDialogo,
      'piedrasSumadasDialogo': _piedrasSumadasDialogo,
      'ganadorDialogoEquipo': _ganadorDialogoEquipo,
      'enviteCantado': _enviteCantado,
      'equipoCanto': _equipoCanto,
      'nivelPropuesto': _nivelPropuesto,
      'equipoTurnoApuesta': _equipoTurnoApuesta,
      'rondaTerminada': _rondaTerminada,
      'mensaje': _mensaje,
      'mensajeEsTurno': _mensajeEsTurno,
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
    final anteriorDialogo = _pendienteDialogo;
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
      _bazasAsiento = ((d['bazasAsiento'] as List?) ?? [0, 0, 0, 0])
          .map((e) => e as int)
          .toList();
      _piedrasEquipo0 = d['piedrasEquipo0'] ?? 0;
      _piedrasEquipo1 = d['piedrasEquipo1'] ?? 0;
      _chicosEquipo0 = d['chicosEquipo0'] ?? 0;
      _chicosEquipo1 = d['chicosEquipo1'] ?? 0;
      _nivelApuesta = d['nivelApuesta'] ?? 0;
      _manoEsDeTumbo = d['manoEsDeTumbo'] ?? false;
      _equipoDecideTumbo = d['equipoDecideTumbo'] ?? -1;
      _pendienteDialogo = d['pendienteDialogo'] ?? 'ninguno';
      _piedrasSumadasDialogo = d['piedrasSumadasDialogo'] ?? 0;
      _ganadorDialogoEquipo = d['ganadorDialogoEquipo'] ?? -1;
      _enviteCantado = d['enviteCantado'] ?? false;
      _equipoCanto = d['equipoCanto'] ?? -1;
      _nivelPropuesto = d['nivelPropuesto'] ?? 0;
      _equipoTurnoApuesta = d['equipoTurnoApuesta'] ?? -1;
      _rondaTerminada = d['rondaTerminada'] ?? false;
      _mensajeEsTurno = d['mensajeEsTurno'] ?? false;
      _mensaje = _mensajeEsTurno ? _mensajeTurno() : (d['mensaje'] ?? '');
      _numCartasPorAsiento =
          ((d['numCartas'] as List?) ?? []).map((e) => e as int).toList();
    });
    if (_pendienteDialogo != 'ninguno' && anteriorDialogo == 'ninguno') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mostrarDialogoFinEquipos();
      });
    }
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
    widget.conexion?.alRecibirDeInvitado = null;
    widget.conexion?.alRecibirDeAnfitrion = null;
    _sfxPlayer.dispose();
    MusicController.instance.reanudar();
    super.dispose();
  }

  // ===== ENVITE =====
  // ¿Puede el equipo local cantar/subir ahora?
  bool get _puedoCantar {
    if (_rondaTerminada || _equipoDecideTumbo != -1) return false;
    if (_manoEsDeTumbo) return false; // en tumbo no se canta envite
    if (_enviteCantado) return false;
    if (_nivelApuesta >= 4) return false;
    if (_equipoTurnoApuesta != -1 && _equipoTurnoApuesta != _miEquipo()) {
      return false;
    }
    return true;
  }


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
    if (_enviteCantado) return;
    if (_nivelApuesta >= 4) return;
    if (_equipoTurnoApuesta != -1 && _equipoTurnoApuesta != equipo) return;
    _enviteCantado = true;
    _equipoCanto = equipo;
    _nivelPropuesto = _nivelApuesta + 1;
    _sonidoApuesta(_nivelPropuesto, equipoCanta: equipo);
    _mensaje = 'Envite cantado. ¡Responde el rival!';
    setState(() {});
    _enviarEstadoJuego();
    _quizaRespondeIA();
  }

  // La IA del asiento considera proponer un envite antes de jugar.
  // Devuelve true si canto (en ese caso no juega carta todavia).
  bool _iaConsideraEnvite(int asiento) {
    if (_enviteCantado) return false;
    if (_manoEsDeTumbo || _equipoDecideTumbo != -1) return false;
    if (_nivelApuesta >= 4) return false;
    final equipo = _equipoDeAsiento(asiento);
    if (_equipoTurnoApuesta != -1 && _equipoTurnoApuesta != equipo) {
      return false;
    }
    int triunfos = 0;
    int triunfosAltos = 0;
    if (asiento < _manos.length) {
      for (final cc in _manos[asiento]) {
        if (cc.suit == _paloVirado) {
          triunfos++;
          // Triunfo alto: malilla (el 2) o figura (fuerza >= 8).
          if (cc.value.numero == 2 || cc.value.fuerza >= 8) triunfosAltos++;
        }
      }
    }
    double prob;
    if (triunfosAltos >= 1) {
      prob = 0.45;
    } else if (triunfos >= 2) {
      prob = 0.25;
    } else if (triunfos == 1) {
      prob = 0.10;
    } else {
      prob = 0.03;
    }
    if (_random22.nextDouble() >= prob) return false;
    _anfitrionRegistraCanto(equipo);
    return true;
  }

  // Si el equipo que debe responder es solo IA, decide automaticamente.
  void _quizaRespondeIA() {
    if (_enRed && !_soyAnfitrion) return; // solo el cerebro decide
    if (!_enviteCantado) return;
    final equipoResponde = _equipoCanto == 0 ? 1 : 0;
    if (!_equipoEsSoloIA(equipoResponde)) return;
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (!mounted || !_enviteCantado) return;
      final accion = _iaDecideRespuesta(equipoResponde);
      _anfitrionResuelveRespuesta(accion);
      if (accion == 'subir') _quizaRespondeIA();
    });
  }

  bool _equipoEsSoloIA(int equipo) {
    final cfg = widget.config;
    if (cfg == null) return true; // modo local: rival = IA
    for (final j in cfg.jugadores) {
      if (_equipoDeAsiento(j.asiento) == equipo && !j.esIA) return false;
    }
    return true;
  }

void _jugadorDesconectado(String idInvitado) {
    final cfg = widget.config;
    if (cfg == null) return;
    final idx = cfg.jugadores.indexWhere((j) => j.id == idInvitado);
    if (idx == -1) return;
    final caido = cfg.jugadores[idx];
    if (caido.esIA) return;
    cfg.jugadores[idx] = caido.copiarComoIA();
    _mensaje = '${caido.nombre} se desconecto. Le sustituye una IA.';
    setState(() {});
    _enviarEstadoJuego();
    _continuarSiTocaIA();
    _quizaRespondeIA();
    _quizaDecideTumboIA();
  }

  int _equipoDeAsiento(int asiento) {
    final cfg = widget.config;
    if (cfg != null) {
      for (final j in cfg.jugadores) {
        if (j.asiento == asiento) return j.equipo;
      }
    }
    return asiento % 2;
  }

  String _iaDecideRespuesta(int equipo) {
    final valores = [2, 4, 7, 9, 12];
    final valorProx = valores[_nivelPropuesto];
    bool tieneTriunfo = false;
    for (int a = 0; a < _manos.length; a++) {
      if (_equipoDeAsiento(a) != equipo) continue;
      if (_manos[a].any((cc) => cc.suit == _paloVirado)) {
        tieneTriunfo = true;
        break;
      }
    }
    final acepta = tieneTriunfo || valorProx <= 7;
    if (!acepta) return 'paso';
    if (tieneTriunfo && _nivelPropuesto < 4 && _random22.nextDouble() < 0.25) {
      return 'subir';
    }
    return 'juego';
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
      final aceptante = _equipoCanto == 0 ? 1 : 0;
      _nivelApuesta = _nivelPropuesto;
      _enviteCantado = false;
      _equipoCanto = -1;
      _equipoTurnoApuesta = aceptante;
      _mensaje = 'Envite aceptado. Seguid jugando.';
    } else if (accion == 'paso') {
      // NO QUIERO = juega con lo que tenemos: se queda en el ultimo nivel
      // aceptado (_nivelApuesta sin tocar) y la mano sigue. Se cobra al ganar.
      _enviteCantado = false;
      _equipoCanto = -1;
      _equipoTurnoApuesta = -1;
      _mensaje = 'Juegan con lo apostado (${_nombreNivel(_nivelApuesta)}).';
    } else if (accion == 'subir') {
      if (_nivelPropuesto < 4) {
        _nivelPropuesto += 1;
        _equipoCanto = _equipoCanto == 0 ? 1 : 0;
        _sonidoApuesta(_nivelPropuesto, equipoCanta: _equipoCanto);
        _mensaje = 'Suben la apuesta. ¡Responde el rival!';
      }
    }
    setState(() {});
    _enviarEstadoJuego();
    if (_enviteCantado) {
      // Sigue habiendo envite pendiente: que responda la IA si toca.
      _quizaRespondeIA();
    } else {
      // El envite se resolvio y la mano sigue: reanudar el turno de juego
      // (la IA que canto el envite aun no jugo su carta).
      _continuarSiTocaIA();
    }
  }


  // Suma las piedras de la mano al equipo ganador y comprueba el chico.
  void _finalizarRondaEquipos() {
    final valores = [2, 4, 7, 9, 12];
    _reproducirEfecto('sonido_recoger_baraja.mp3');
    final valorMano = _manoEsDeTumbo ? 3 : valores[_nivelApuesta];
    final gana0 = _manosEquipo0 > _manosEquipo1;
    if (gana0) {
      _piedrasEquipo0 += valorMano;
    } else {
      _piedrasEquipo1 += valorMano;
    }
    _ganadorDialogoEquipo = gana0 ? 0 : 1;
    _piedrasSumadasDialogo = valorMano;
    _comprobarFinYMostrarDialogo();
  }

  // Detección central: chico (12 piedras) y partida (2 chicos).
  // Fija _pendienteDialogo y dispara el diálogo (anfitrión).
  void _comprobarFinYMostrarDialogo() {
    const chicosParaGanar = 4; // 2v2 se gana a 4 chicos
    bool huboChico = false;
    if (_piedrasEquipo0 >= 12) {
      _chicosEquipo0++;
      _piedrasEquipo0 = 0;
      _piedrasEquipo1 = 0;
      _ganadorDialogoEquipo = 0;
      huboChico = true;
    } else if (_piedrasEquipo1 >= 12) {
      _chicosEquipo1++;
      _piedrasEquipo0 = 0;
      _piedrasEquipo1 = 0;
      _ganadorDialogoEquipo = 1;
      huboChico = true;
    }
    final finPartida = _chicosEquipo0 >= chicosParaGanar ||
        _chicosEquipo1 >= chicosParaGanar;
    if (finPartida) {
      _pendienteDialogo = 'partida';
    } else if (huboChico) {
      _pendienteDialogo = 'chico';
    } else {
      _pendienteDialogo = 'mano';
    }
    _rondaTerminada = true;
    setState(() {});
    if (_enRed && _soyAnfitrion) _enviarEstadoJuego();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mostrarDialogoFinEquipos();
    });
  }

  void _mostrarDialogoFinEquipos() {
    if (!mounted || _pendienteDialogo == 'ninguno') return;
    final miEquipo = _miEquipo();
    final ganaMiEquipo = _ganadorDialogoEquipo == miEquipo;
    final esChico = _pendienteDialogo == 'chico';
    final esPartida = _pendienteDialogo == 'partida';
    // Sonido de fin de partida: victoria o derrota.
    if (esPartida) {
      _reproducirEfecto(
          ganaMiEquipo ? 'chacaras.mp3' : 'se_me_fue_el_baifo.mp3');
    }
    final misChicos = miEquipo == 0 ? _chicosEquipo0 : _chicosEquipo1;
    final chicosRival = miEquipo == 0 ? _chicosEquipo1 : _chicosEquipo0;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoFinManoEquipos(
        gano: ganaMiEquipo,
        huboChico: esChico,
        finPartida: esPartida,
        piedrasSumadas: _piedrasSumadasDialogo,
        chicosYo: misChicos,
        chicosRival: chicosRival,
        ganadorEsYo: ganaMiEquipo,
        onContinuar: () {
          Navigator.pop(context);
          _pendienteDialogo = 'ninguno';
          if (_soyAnfitrion || !_enRed) {
            if (esPartida) {
              _chicosEquipo0 = 0;
              _chicosEquipo1 = 0;
            }
            _repartirNuevaRonda();
          }
        },
        onSalir: esPartida
            ? () => Navigator.of(context).popUntil((r) => r.isFirst)
            : null,
      ),
    );
  }

  // El equipo del jugador local (0 o 1).
  int _miEquipo() {
    return _equipoDeAsiento(_miAsientoBase);
  }

  // Mensaje del turno actual, según quién soy yo.
  String _mensajeTurno() {
    final miAsiento = _enRed
        ? (_soyAnfitrion ? 0 : _miAsientoEnRed())
        : 0;
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
      // La mano de tumbo arranca: si le toca salir a una IA, que juegue.
      setState(() {});
      _enviarEstadoJuego();
      _continuarSiTocaIA();
      return;
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
      // El rival gana 1 piedra y la mano termina: usar el flujo del dialogo.
      _ganadorDialogoEquipo = rival;
      _piedrasSumadasDialogo = 1;
      _comprobarFinYMostrarDialogo();
      return;
    }
  }

  void _repartirNuevaRonda() {
    _reproducirEfecto('sonido_reparto.mp3');
    _colaSenas.clear();
    _senaVisible.clear();
    _mostrandoSena = false;
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
    _equipoTurnoApuesta = -1;
    _manoEsDeTumbo = false;
    _equipoDecideTumbo = -1;
    _turno = _siguienteEnCirculo(_barajador); // sale el de la izquierda del que baraja
    _manosEquipo0 = 0;
    _manosEquipo1 = 0;
    _bazasAsiento = List.filled(_numJug, 0);
    _rondaTerminada = false;
    _mensaje = _mensajeTurno();
    _mensajeEsTurno = true;
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
    if (_enRed && _soyAnfitrion) _enviarEstadoJuego();
    _iaCompanerasSenan();
    final tiempoSenas = _tiempoParaSenas();
    Timer(Duration(milliseconds: tiempoSenas), () {
      if (!mounted || _rondaTerminada) return;
      _continuarSiTocaIA();
      _quizaDecideTumboIA();
    });
  }

  // Si el equipo que decide el tumbo es solo IA, decide automaticamente.
  void _quizaDecideTumboIA() {
    if (_enRed && !_soyAnfitrion) return;
    if (_equipoDecideTumbo == -1) return;
    final equipo = _equipoDecideTumbo;
    if (!_equipoEsSoloIA(equipo)) return;
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted || _equipoDecideTumbo != equipo) return;
      final juega = _iaDecideTumbo(equipo);
      _anfitrionResuelveTumboEquipo(juega);
    });
  }

  // Decision IA del tumbo: juega si tiene triunfos (mano fuerte).
  bool _iaDecideTumbo(int equipo) {
    int triunfos = 0;
    for (int a = 0; a < _manos.length; a++) {
      if (_equipoDeAsiento(a) != equipo) continue;
      triunfos += _manos[a].where((cc) => cc.suit == _paloVirado).length;
    }
    if (triunfos >= 2) return _random22.nextDouble() < 0.7;
    if (triunfos == 1) return _random22.nextDouble() < 0.4;
    return _random22.nextDouble() < 0.15;
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
      baza: _baza,
      asiento: asiento,
      equipoDe: _equipoDeAsiento,
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
      _turno = _siguienteEnCirculo(_turno);
      _mensaje = _mensajeTurno();
      _mensajeEsTurno = true;
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
      // Antes de jugar, la IA considera proponer un envite.
      if (_iaConsideraEnvite(asiento)) return; // canto: espera respuesta
      final validas = _validasDe(asiento);
      final carta = AiPlayer2v2.elegirCarta(
        miAsiento: asiento,
        validas: validas,
        bazaActual: _baza,
        paloVirado: _paloVirado,
        equipoDe: _equipoDeAsiento,
      );
      _jugarCarta(asiento, carta);
    });
  }

  void _resolverBaza() {
    final ganador = TrickEngine2v2.determinarGanador(
      jugadas: _baza,
      paloVirado: _paloVirado,
    );
    final equipoGanador = _equipoDeAsiento(ganador.asiento);
    if (equipoGanador == 0) {
      _manosEquipo0++;
    } else {
      _manosEquipo1++;
    }
    if (ganador.asiento < _bazasAsiento.length) {
      _bazasAsiento[ganador.asiento]++;
    }
    _mensaje = '${_nombrePosicion(ganador.asiento)} gana la mano';
    _mensajeEsTurno = false;
    _turno = ganador.asiento;

    setState(() {});

    // Pausa para que se vea la baza completa antes de limpiarla.
    if (_enRed && _soyAnfitrion) _enviarEstadoJuego();
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      _baza = [];
      _reproducirEfecto('sonido_recoger_baraja.mp3');
      // La mano se gana al llegar a 2 bazas (no hace falta jugar la 3a).
      // Si se acaban las cartas sin que nadie llegue a 2 (no deberia pasar
      // en 2 de 3), tambien se cierra.
      final cartasRestantes = _manos.fold<int>(0, (s, m) => s + m.length);
      final hayGanador2Bazas = _manosEquipo0 >= 2 || _manosEquipo1 >= 2;
      if (hayGanador2Bazas || cartasRestantes == 0) {
        _rondaTerminada = true;
        _barajador = _siguienteEnCirculo(_barajador); // rota para la próxima mano
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
  // Orden circular del 2v2: tú, rival, compañero, rival (equipos reales
  // {0,3} y {1,2}). Mantiene la alternancia de equipos en turnos y layout.
  static const List<int> _ordenCircular4 = [0, 1, 3, 2];
  int _asientoEnPos(int posicion) {
    final miIdx = _ordenCircular4.indexOf(_miAsientoBase);
    if (miIdx == -1) return (_miAsientoBase + posicion) % _numJug;
    return _ordenCircular4[(miIdx + posicion) % 4];
  }

  // Siguiente asiento en el orden de juego (círculo de la mesa).
  int _siguienteEnCirculo(int asiento) {
    final idx = _ordenCircular4.indexOf(asiento);
    if (idx == -1) return (asiento + 1) % _numJug;
    return _ordenCircular4[(idx + 1) % 4];
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
                Center(child: _globoSena(_asientoEnPos(0))),
                // Tus cartas (abajo) + tu pila de bazas
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _pilaJugador(_asientoEnPos(0), escala: 0.5),
                      Flexible(child: _misCartasAbanico(misCartas, validas)),
                    ],
                  ),
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
          if (_enRed)
            Positioned(
              right: 0,
              bottom: 0,
              child: RuedaSenas(
                numJugadores: _numJug,
                onEnviar: _enviarSena,
              ),
            ),
        ],
      ),
    );
  }

  Widget _barraSuperior() {
    final misPiedras = _miEquipo() == 0 ? _piedrasEquipo0 : _piedrasEquipo1;
    final piedrasRival = _miEquipo() == 0 ? _piedrasEquipo1 : _piedrasEquipo0;
    final misChicos = _miEquipo() == 0 ? _chicosEquipo0 : _chicosEquipo1;
    final chicosRival = _miEquipo() == 0 ? _chicosEquipo1 : _chicosEquipo0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.chevron_left, color: Colors.white),
            ),
          ),
          const SizedBox(width: 6),
          // NOSOTROS (azul)
          Expanded(
            child: _panelMarcador(
              titulo: 'NOSOTROS',
              piedras: misPiedras,
              colorTop: const Color(0xFF2E78C9),
              colorBottom: const Color(0xFF154A82),
              colorTitulo: const Color(0xFFE6F1FB),
              colorPiedras: const Color(0xFFCFE3F7),
            ),
          ),
          const SizedBox(width: 6),
          // chicos (negro)
          Container(
            width: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2A2A2A), Color(0xFF111111)],
              ),
              border: Border.all(color: Colors.white12),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Text('$misChicos - $chicosRival',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 2),
                const Text('chicos',
                    style: TextStyle(fontSize: 8, color: Color(0xFFB4B2A9))),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // ELLOS (rojo)
          Expanded(
            child: _panelMarcador(
              titulo: 'ELLOS',
              piedras: piedrasRival,
              colorTop: const Color(0xFFC24747),
              colorBottom: const Color(0xFF8F2424),
              colorTitulo: const Color(0xFFFCEBEB),
              colorPiedras: const Color(0xFFF7C1C1),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _panelMarcador({
    required String titulo,
    required int piedras,
    required Color colorTop,
    required Color colorBottom,
    required Color colorTitulo,
    required Color colorPiedras,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colorTop, colorBottom],
        ),
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Column(
        children: [
          Text(titulo, style: TextStyle(fontSize: 11, color: colorTitulo)),
          const SizedBox(height: 6),
          Garbanzos(piedras: piedras, color: const Color(0xFFE3C28A)),
          const SizedBox(height: 6),
          Text('$piedras piedras',
              style: TextStyle(fontSize: 9, color: colorPiedras)),
        ],
      ),
    );
  }

  // Numero de cartas que tiene un asiento (en red usa lo recibido).
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
          _globoSena(asiento),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _pilaJugador(asiento),
              _miniCartasBocaAbajo(numCartas),
            ],
          ),
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
          _globoSena(asiento),
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
          _pilaJugador(asiento, escala: 0.32),
        ],
      ),
    );
  }

  // Mini pila de bazas ganadas por un jugador concreto.
  Widget _pilaJugador(int asiento, {double escala = 0.42}) {
    final n = asiento < _bazasAsiento.length ? _bazasAsiento[asiento] : 0;
    if (n <= 0) return const SizedBox.shrink();
    return Transform.scale(
      scale: escala,
      child: PilaGanada(cantidad: n, label: ''),
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
              SizedBox(
                width: 66,
                height: 104,
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
  // Fila de botones del envite, al estilo 1v1 pero por equipo.
  Widget _botonesEnvite() {
    if (_rondaTerminada || _equipoDecideTumbo != -1) {
      return const SizedBox.shrink();
    }
    const nombres = ['Base', 'ENVIDO', 'SIETE', 'NUEVE', 'CHICO FUERA'];

    // CASO A: hay envite y mi equipo debe responder (no fue el que canto).
    if (_enviteCantado && _equipoCanto != _miEquipo()) {
      final puedeSubir = _nivelPropuesto < 4;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Text('El rival canta ${nombres[_nivelPropuesto]}',
                style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _botonEnvite('JUEGO', Colors.green,
                    () => _responderEnvite('juego')),
                _botonEnvite('NO QUIERO', Colors.red,
                    () => _responderEnvite('paso')),
                if (puedeSubir)
                  _botonEnvite(nombres[_nivelPropuesto + 1], Colors.orange,
                      () => _responderEnvite('subir')),
              ],
            ),
          ],
        ),
      );
    }

    // CASO B: mi equipo canto y espera respuesta del rival.
    if (_enviteCantado && _equipoCanto == _miEquipo()) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text('Esperando respuesta del rival...',
            style: TextStyle(color: Colors.white70, fontSize: 12)),
      );
    }

    // CASO C: no hay envite pendiente -> puedo cantar el siguiente nivel.
    if (_puedoCantar) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: _botonEnvite(
            nombres[_nivelApuesta + 1], Colors.amber, _cantarEnvite),
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
class DialogoFinManoEquipos extends StatelessWidget {
  final bool gano;
  final bool huboChico;
  final bool finPartida;
  final int piedrasSumadas;
  final int chicosYo;
  final int chicosRival;
  final bool ganadorEsYo;
  final VoidCallback onContinuar;
  final VoidCallback? onSalir;

  const DialogoFinManoEquipos({
    super.key,
    required this.gano,
    required this.huboChico,
    required this.finPartida,
    required this.piedrasSumadas,
    required this.chicosYo,
    required this.chicosRival,
    required this.ganadorEsYo,
    required this.onContinuar,
    this.onSalir,
  });

  Widget _garbanzo() {
    return Container(
      width: 16,
      height: 13,
      decoration: BoxDecoration(
        color: const Color(0xFFC9A24A),
        border: Border.all(color: const Color(0xFF7A5A28), width: 1.5),
        borderRadius: BorderRadius.circular(7),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8D4A8), Color(0xFFDCC290)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: huboChico ? const Color(0xFFC8870F) : const Color(0xFF8A6A35),
            width: huboChico ? 3 : 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (finPartida)
              ..._contenidoPartida()
            else if (huboChico)
              ..._contenidoChico()
            else
              ..._contenidoMano(),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onContinuar,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFEFAF1F), Color(0xFFC8870F)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF8A6A35), width: 1.5),
                ),
                child: Text(
                  finPartida
                      ? 'Nueva partida'
                      : (huboChico ? 'Empezar nuevo chico' : 'Jugar otra mano'),
                  style: const TextStyle(
                    color: Color(0xFF3A2B12),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            if (onSalir != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onSalir,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 24),
                  decoration: BoxDecoration(
                    color: const Color(0x33000000),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF8A6A35), width: 1),
                  ),
                  child: const Text(
                    'Salir al menú',
                    style: TextStyle(
                      color: Color(0xFF3A2B12),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _contenidoMano() {
    return [
      Text(
        gano ? '¡TU EQUIPO GANA LA MANO!' : 'EL EQUIPO RIVAL GANA LA MANO',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Georgia',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF3A2B12),
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 16),
      Container(width: 160, height: 1, color: const Color(0x808A6A35)),
      const SizedBox(height: 14),
      Text(
        gano ? 'Tu equipo suma' : 'El equipo rival suma',
        style: const TextStyle(fontSize: 13, color: Color(0xFF6B5424)),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 6,
        alignment: WrapAlignment.center,
        children: List.generate(piedrasSumadas.clamp(0, 12), (_) => _garbanzo()),
      ),
      const SizedBox(height: 6),
      Text(
        '$piedrasSumadas piedras',
        style: const TextStyle(fontSize: 12, color: Color(0xFF6B5424)),
      ),
    ];
  }

  List<Widget> _contenidoChico() {
    return [
      const Text(
        '★ ★ ★',
        style: TextStyle(
          fontSize: 13,
          color: Color(0xFF995C0A),
          letterSpacing: 3,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 2),
      const Text(
        '¡CHICO!',
        style: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 34,
          fontWeight: FontWeight.bold,
          color: Color(0xFF9A3A0A),
          letterSpacing: 2,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        ganadorEsYo
            ? 'Tu equipo se lleva el chico'
            : 'El equipo rival se lleva el chico',
        style: const TextStyle(fontSize: 13, color: Color(0xFF6B5424)),
      ),
      const SizedBox(height: 16),
      Container(width: 160, height: 1, color: const Color(0x80C8870F)),
      const SizedBox(height: 14),
      const Text(
        'Chicos ganados',
        style: TextStyle(fontSize: 13, color: Color(0xFF6B5424)),
      ),
      const SizedBox(height: 8),
      const Text('🏆', style: TextStyle(fontSize: 26)),
      const SizedBox(height: 6),
      Text(
        'Tu equipo $chicosYo  ·  Rival $chicosRival',
        style: const TextStyle(fontSize: 12, color: Color(0xFF6B5424)),
      ),
    ];
  }

  List<Widget> _contenidoPartida() {
    return [
      const Text('🏅', style: TextStyle(fontSize: 38)),
      const SizedBox(height: 6),
      Text(
        ganadorEsYo ? '¡GANÁIS LA PARTIDA!' : 'EL EQUIPO RIVAL GANA LA PARTIDA',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Georgia',
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Color(0xFF9A3A0A),
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Tu equipo $chicosYo  ·  Rival $chicosRival',
        style: const TextStyle(fontSize: 13, color: Color(0xFF6B5424)),
      ),
    ];
  }
}
