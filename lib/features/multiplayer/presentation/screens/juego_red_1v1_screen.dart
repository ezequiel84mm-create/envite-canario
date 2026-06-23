import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../core/settings/music_controller.dart';
import '../../../../core/enums/suit.dart';
import '../../../game/data/models/card_model.dart';
import '../../../game/presentation/widgets/card_widget.dart';
import '../../../../core/utils/deck_generator.dart';
import '../../../game/domain/engine/trick_engine.dart';
import '../../network/conexion_p2p.dart';
import '../../network/mensajes_red.dart';
import '../../network/traductor_cartas.dart';
import '../widgets/widgets_mesa.dart';

/// Pantalla de juego 1vs1 en red (Capa 1: repartir, jugar cartas, ganar manos).
/// El ANFITRIÓN tiene la lógica; el INVITADO muestra lo que recibe.
class JuegoRed1v1Screen extends StatefulWidget {
  final ConexionP2P conexion;
  final bool soyAnfitrion;

  const JuegoRed1v1Screen({
    super.key,
    required this.conexion,
    required this.soyAnfitrion,
  });

  @override
  State<JuegoRed1v1Screen> createState() => _JuegoRed1v1ScreenState();
}

class _JuegoRed1v1ScreenState extends State<JuegoRed1v1Screen> {
  // Estado del juego (lo gestiona el anfitrión; el invitado lo recibe).
  List<CardModel> _miMano = [];
  Suit? _paloVirado;
  CardModel? _vira;

  // Cartas jugadas en la baza actual: {asiento: carta}
  CardModel? _cartaMia;
  CardModel? _cartaRival;

  int _turno = 0; // 0 = anfitrión, 1 = invitado
  int _manosAnfitrion = 0;
  int _manosInvitado = 0;
  String _mensaje = '';
  bool _rondaTerminada = false;

  // ===== Estado del envite (Pieza 1: esqueleto) =====
  // Piedras y chicos de cada jugador (perspectiva del anfitrión).
  int _piedrasAnfitrion = 0;
  int _piedrasInvitado = 0;
  int _chicosAnfitrion = 0;
  int _chicosInvitado = 0;
  // Nivel de apuesta actual: 0=Base,1=Envido,2=Siete,3=Nueve,4=ChicoFuera
  int _nivelApuesta = 0;
  // ¿Hay un envite cantado esperando respuesta? Y ¿quién lo cantó? (0/1)
  bool _enviteCantado = false;
  int _quienCanto = -1;
  // Nivel que se está proponiendo al cantar (al cual subiría si se acepta).
  int _nivelPropuesto = 0;
  // Quién puede cantar ahora: -1=cualquiera, 0=solo anfitrión, 1=solo invitado.
  int _turnoApuesta = -1;
  // ===== Tumbo =====
  // ¿Esta mano es de tumbo (vale 3)? Y ¿quién debe decidir? (-1 nadie)
  bool _manoEsDeTumbo = false;
  int _quienDecideTumbo = -1;

  // Solo el anfitrión usa esto:
  List<CardModel> _manoAnfitrion = [];
  List<CardModel> _manoInvitado = [];

  int get _miAsiento => widget.soyAnfitrion ? 0 : 1;

  // Reproductor de efectos (voz de los envites).
  final AudioPlayer _sfxPlayer = AudioPlayer();

  // Reproduce el canto de voz segun el nivel de apuesta.
  // nivel 1=Envido, 2=Siete, 3=Nueve, 4=Chico Fuera.
  void _sonidoApuesta(int nivel) {
    const archivos = {
      1: 'envido.m4a',
      2: 'siete.m4a',
      3: 'nueve.m4a',
      4: 'chico_fuera.m4a',
    };
    final archivo = archivos[nivel];
    if (archivo != null) {
      _sfxPlayer.play(AssetSource('audio/$archivo'));
    }
  }

  @override
  void initState() {
    super.initState();
    MusicController.instance.pausar();
    // Escuchar mensajes del otro jugador.
    widget.conexion.alRecibir = _alRecibirMensaje;
    widget.conexion.alDesconectar = () {
      if (!mounted) return;
      setState(() => _mensaje = 'El otro jugador se desconectó.');
    };

    if (widget.soyAnfitrion) {
      _repartirComoAnfitrion();
    } else {
      _mensaje = 'Esperando al anfitrión...';
      // Pide el estado actual por si el anfitrion ya repartio.
      widget.conexion.enviar(MensajeRed(TipoMensaje.hola, {}).codificar());
    }
  }

  // ===== ANFITRIÓN: reparte y manda el estado =====
  void _repartirComoAnfitrion() {
    final mazo = DeckGenerator.generateShuffledDeck();
    _manoAnfitrion = mazo.sublist(0, 3);
    _manoInvitado = mazo.sublist(3, 6);
    _vira = mazo[6];
    _paloVirado = _vira!.suit;
    _cartaMia = null;
    _cartaRival = null;
    _turno = 0;
    _rondaTerminada = false;
    _manosAnfitrion = 0;
    _manosInvitado = 0;
    _enviteCantado = false;
    _quienCanto = -1;
    _turnoApuesta = -1;
    _manoEsDeTumbo = false;

    // Tumbo: comprobamos quien tiene 11 piedras.
    final anfitrionEnTumbo = _piedrasAnfitrion == 11;
    final invitadoEnTumbo = _piedrasInvitado == 11;

    if (anfitrionEnTumbo && invitadoEnTumbo) {
      // TUMBO FORZOSO: ambos a 11 -> obligatorio jugar, sin decision.
      _manoEsDeTumbo = true;
      _quienDecideTumbo = -1;
    } else if (anfitrionEnTumbo) {
      _quienDecideTumbo = 0; // el anfitrion decide
    } else if (invitadoEnTumbo) {
      _quienDecideTumbo = 1; // el invitado decide
    } else {
      _quienDecideTumbo = -1;
    }

    _miMano = _manoAnfitrion;
    if (anfitrionEnTumbo && invitadoEnTumbo) {
      _mensaje = '🔥 ¡Tumbo forzoso! Hay que jugar.';
    } else if (_quienDecideTumbo == -1) {
      _mensaje = 'Tu turno';
    } else if (_quienDecideTumbo == 0) {
      _mensaje = 'Decides el tumbo...';
    } else {
      _mensaje = 'El rival decide el tumbo...';
    }
    setState(() {});
    _enviarEstado();
  }

  // El anfitrión manda a ambos el estado actual.
  void _enviarEstado() {
    // Carta en mesa del anfitrión (asiento 0) y del invitado (asiento 1)
    final datos = {
      'vira': _vira != null ? TraductorCartas.aTexto(_vira!) : null,
      'manoInvitado': TraductorCartas.listaATexto(_manoInvitado),
      'cartaAnfitrion':
          _cartaMia != null ? TraductorCartas.aTexto(_cartaMia!) : null,
      'cartaInvitado':
          _cartaRival != null ? TraductorCartas.aTexto(_cartaRival!) : null,
      'turno': _turno,
      'manosAnfitrion': _manosAnfitrion,
      'manosInvitado': _manosInvitado,
      'rondaTerminada': _rondaTerminada,
      'mensaje': _mensaje,
      'piedrasAnfitrion': _piedrasAnfitrion,
      'piedrasInvitado': _piedrasInvitado,
      'chicosAnfitrion': _chicosAnfitrion,
      'chicosInvitado': _chicosInvitado,
      'nivelApuesta': _nivelApuesta,
      'enviteCantado': _enviteCantado,
      'quienCanto': _quienCanto,
      'nivelPropuesto': _nivelPropuesto,
      'turnoApuesta': _turnoApuesta,
      'manoEsDeTumbo': _manoEsDeTumbo,
      'quienDecideTumbo': _quienDecideTumbo,
    };
    widget.conexion.enviar(MensajeRed(TipoMensaje.estado, datos).codificar());
  }

  // ===== Recepción de mensajes =====
  void _alRecibirMensaje(String texto) {
    final msg = MensajeRed.decodificar(texto);
    if (msg == null) return;

    if (widget.soyAnfitrion) {
      // El anfitrión recibe la jugada del invitado.
      if (msg.tipo == TipoMensaje.jugarCarta) {
        final carta = TraductorCartas.desdeTexto(msg.datos['carta']);
        if (carta != null) _anfitrionRecibeJugada(carta);
      } else if (msg.tipo == TipoMensaje.proponerEnvite) {
        // El invitado (asiento 1) canta un envite.
        _anfitrionRegistraCanto(1);
      } else if (msg.tipo == TipoMensaje.respuestaEnvite) {
        // El invitado responde a un envite.
        _anfitrionResuelveRespuesta(msg.datos['accion']);
      } else if (msg.tipo == TipoMensaje.hola) {
        // El invitado pide el estado actual: se lo reenviamos.
        _enviarEstado();
      } else if (msg.tipo == TipoMensaje.decisionTumbo) {
        _anfitrionResuelveTumbo(msg.datos['juega'] == true);
      }
    } else {
      // El invitado recibe el estado del anfitrión.
      if (msg.tipo == TipoMensaje.estado) {
        _invitadoRecibeEstado(msg.datos);
      }
    }
  }

  // El invitado actualiza su pantalla con el estado recibido.
  void _invitadoRecibeEstado(Map<String, dynamic> d) {
    final huboEnviteAntes = _enviteCantado;
    final nivelPropAntes = _nivelPropuesto;
    setState(() {
      _vira = d['vira'] != null ? TraductorCartas.desdeTexto(d['vira']) : null;
      _paloVirado = _vira?.suit;
      _miMano = TraductorCartas.listaDesdeTexto(d['manoInvitado'] ?? []);
      // Para el invitado: "mía" es la del invitado, "rival" la del anfitrión.
      _cartaMia = d['cartaInvitado'] != null
          ? TraductorCartas.desdeTexto(d['cartaInvitado'])
          : null;
      _cartaRival = d['cartaAnfitrion'] != null
          ? TraductorCartas.desdeTexto(d['cartaAnfitrion'])
          : null;
      // El turno llega en perspectiva del anfitrión (0=anfitrion,1=invitado).
      _turno = d['turno'];
      _manosAnfitrion = d['manosAnfitrion'];
      _manosInvitado = d['manosInvitado'];
      _rondaTerminada = d['rondaTerminada'];
      _mensaje = d['mensaje'] ?? '';
      _piedrasAnfitrion = d['piedrasAnfitrion'] ?? 0;
      _piedrasInvitado = d['piedrasInvitado'] ?? 0;
      _chicosAnfitrion = d['chicosAnfitrion'] ?? 0;
      _chicosInvitado = d['chicosInvitado'] ?? 0;
      _nivelApuesta = d['nivelApuesta'] ?? 0;
      _enviteCantado = d['enviteCantado'] ?? false;
      _quienCanto = d['quienCanto'] ?? -1;
      _nivelPropuesto = d['nivelPropuesto'] ?? 0;
      _turnoApuesta = d['turnoApuesta'] ?? -1;
      _manoEsDeTumbo = d['manoEsDeTumbo'] ?? false;
      _quienDecideTumbo = d['quienDecideTumbo'] ?? -1;
    });
    // Si apareció un envite nuevo (o subió de nivel), suena el canto.
    final hayEnviteNuevo = _enviteCantado &&
        (!huboEnviteAntes || _nivelPropuesto != nivelPropAntes);
    if (hayEnviteNuevo) {
      _sonidoApuesta(_nivelPropuesto);
    }
  }

  // ===== Jugar una carta =====
  void _jugarCarta(CardModel carta) {
    if (_rondaTerminada) return;
    if (_quienDecideTumbo != -1) return; // hay un tumbo por decidir
    if (_enviteCantado) return;          // hay un envite por responder
    if (_turno != _miAsiento) return;    // no es mi turno

    if (widget.soyAnfitrion) {
      _anfitrionJuegaCarta(0, carta);
    } else {
      // El invitado manda su jugada al anfitrión.
      widget.conexion.enviar(
        MensajeRed(TipoMensaje.jugarCarta,
            {'carta': TraductorCartas.aTexto(carta)}).codificar(),
      );
    }
  }

  // El anfitrión procesa que el invitado jugó.
  void _anfitrionRecibeJugada(CardModel carta) {
    _anfitrionJuegaCarta(1, carta);
  }

  // Lógica central del anfitrión cuando alguien juega.
  void _anfitrionJuegaCarta(int asiento, CardModel carta) {
    if (asiento == 0) {
      _manoAnfitrion.remove(carta);
      _cartaMia = carta;
    } else {
      _manoInvitado.remove(carta);
      _cartaRival = carta;
    }

    // ¿Están las dos cartas en mesa?
    if (_cartaMia != null && _cartaRival != null) {
      _resolverBaza();
    } else {
      _turno = asiento == 0 ? 1 : 0;
      _mensaje = _turno == 0 ? 'Tu turno' : 'Turno del rival';
    }
    _miMano = _manoAnfitrion;
    setState(() {});
    _enviarEstado();
  }

  void _resolverBaza() {
    final jugadas = [
      PlayedCard(playerId: 'anfitrion', card: _cartaMia!),
      PlayedCard(playerId: 'invitado', card: _cartaRival!),
    ];
    final ganador = TrickEngine.determinarGanador(
      jugadas: jugadas,
      paloDeLaMano: _paloVirado!,
    );
    final ganoAnfitrion = ganador.playerId == 'anfitrion';
    if (ganoAnfitrion) {
      _manosAnfitrion++;
      _turno = 0;
      _mensaje = 'Ganaste la mano';
    } else {
      _manosInvitado++;
      _turno = 1;
      _mensaje = 'El rival gana la mano';
    }

    _cartaMia = null;
    _cartaRival = null;

    // ¿Termina la ronda? Al ganar 2 bazas o agotarse las cartas.
    final cartasAgotadas = _manoAnfitrion.isEmpty && _manoInvitado.isEmpty;
    if (_manosAnfitrion >= 2 || _manosInvitado >= 2 || cartasAgotadas) {
      _finalizarRonda();
    }
  }

  // Suma las piedras de la apuesta al ganador de la ronda y comprueba chico.
  void _finalizarRonda() {
    final valores = [2, 4, 7, 9, 12];
    final valorMano = _manoEsDeTumbo ? 3 : valores[_nivelApuesta];
    final ganaAnfitrion = _manosAnfitrion > _manosInvitado;

    if (ganaAnfitrion) {
      _piedrasAnfitrion += valorMano;
    } else {
      _piedrasInvitado += valorMano;
    }

    _mensaje = ganaAnfitrion
        ? 'Ganaste la ronda (+$valorMano piedras)'
        : 'El rival gana la ronda (+$valorMano piedras)';

    _comprobarChicosYReiniciar();
  }

  @override
  void dispose() {
    MusicController.instance.reanudar();
    _sfxPlayer.dispose();
    widget.conexion.cerrar();
    super.dispose();
  }

  // ===== ENVITE: cantar =====
  // Lo llama quien toca el boton ENVIDAR.
  void _cantarEnvite() {
    if (_enviteCantado) return;          // ya hay uno pendiente
    if (_rondaTerminada) return;
    if (_nivelApuesta >= 4) return;      // ya esta en el maximo
    // Solo puede cantar quien tenga el turno de apuesta (o cualquiera si -1).
    if (_turnoApuesta != -1 && _turnoApuesta != _miAsiento) return;

    if (widget.soyAnfitrion) {
      _anfitrionRegistraCanto(0);        // el anfitrion canta (asiento 0)
    } else {
      // El invitado pide al anfitrion proponer envite.
      widget.conexion.enviar(
        MensajeRed(TipoMensaje.proponerEnvite, {}).codificar(),
      );
    }
  }

  // El anfitrion registra que alguien (asiento) cantó un envite.
  void _anfitrionRegistraCanto(int asiento) {
    if (_enviteCantado) return;
    if (_nivelApuesta >= 4) return;
    _enviteCantado = true;
    _quienCanto = asiento;
    _nivelPropuesto = _nivelApuesta + 1;
    _sonidoApuesta(_nivelPropuesto);
    _mensaje = asiento == 0
        ? 'Cantaste. Esperando al rival...'
        : 'El rival canta. ¡Responde!';
    setState(() {});
    _enviarEstado();
  }

  // ===== ENVITE: responder (Pieza 3) =====
  // Lo llama quien debe responder al envite cantado.
  void _responderEnvite(String accion) {
    // accion: 'juego' (aceptar), 'paso' (rechazar), 'subir'
    if (widget.soyAnfitrion) {
      _anfitrionResuelveRespuesta(accion);
    } else {
      widget.conexion.enviar(
        MensajeRed(TipoMensaje.respuestaEnvite, {'accion': accion}).codificar(),
      );
    }
  }

  // El anfitrion resuelve la respuesta al envite.
  void _anfitrionResuelveRespuesta(String accion) {
    if (!_enviteCantado) return;

    if (accion == 'juego') {
      // Aceptar: la apuesta sube al nivel propuesto.
      // El que acepto es el rival del que canto; solo el podra recantar.
      final aceptante = _quienCanto == 0 ? 1 : 0;
      _nivelApuesta = _nivelPropuesto;
      _enviteCantado = false;
      _quienCanto = -1;
      _turnoApuesta = aceptante; // solo el que acepto puede subir
      _mensaje = 'Envite aceptado. Seguid jugando.';
    } else if (accion == 'paso') {
      // Rechazar: el que canto gana las piedras del nivel anterior.
      final valores = [2, 4, 7, 9, 12];
      final nivelAnterior = _nivelPropuesto - 1; // el que estaba antes de cantar
      final ganaPiedras = nivelAnterior == 0 ? 1 : valores[nivelAnterior];

      if (_quienCanto == 0) {
        _piedrasAnfitrion += ganaPiedras;
      } else {
        _piedrasInvitado += ganaPiedras;
      }
      _enviteCantado = false;
      final quien = _quienCanto;
      _quienCanto = -1;
      _mensaje = quien == 0
          ? 'El rival pasó. Anfitrión gana $ganaPiedras.'
          : 'Has pasado. El rival gana $ganaPiedras.';
      // Tras pasar, la mano del envite termina: nueva ronda.
      _comprobarChicosYReiniciar();
    } else if (accion == 'subir') {
      // Subir: reenvida al siguiente nivel; ahora responde el otro.
      _nivelPropuesto = _nivelPropuesto + 1;
      _sonidoApuesta(_nivelPropuesto);
      _quienCanto = _quienCanto == 0 ? 1 : 0; // cambia quien espera respuesta
      _mensaje = 'Envite subido. ¡Responde!';
    }
    setState(() {});
    _enviarEstado();
  }

  // Comprueba si alguien llego a 12 piedras (un chico) y reinicia la ronda.
  void _comprobarChicosYReiniciar() {
    if (_piedrasAnfitrion >= 12) {
      _chicosAnfitrion++;
      _piedrasAnfitrion = 0;
      _piedrasInvitado = 0;
    } else if (_piedrasInvitado >= 12) {
      _chicosInvitado++;
      _piedrasAnfitrion = 0;
      _piedrasInvitado = 0;
    }
    // Reparte una nueva ronda (el anfitrion).
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _nivelApuesta = 0;
      _repartirComoAnfitrion();
    });
  }

  // ===== TUMBO: decidir =====
  void _decidirTumbo(bool juega) {
    if (widget.soyAnfitrion) {
      _anfitrionResuelveTumbo(juega);
    } else {
      widget.conexion.enviar(
        MensajeRed(TipoMensaje.decisionTumbo, {'juega': juega}).codificar(),
      );
    }
  }

  void _anfitrionResuelveTumbo(bool juega) {
    if (_quienDecideTumbo == -1) return;
    final quien = _quienDecideTumbo;

    if (juega) {
      // Jugar el tumbo: la mano vale 3, se juega normal.
      _manoEsDeTumbo = true;
      _quienDecideTumbo = -1;
      _mensaje = quien == 0
          ? 'Juegas el tumbo (vale 3)'
          : 'El rival juega el tumbo (vale 3)';
      setState(() {});
      _enviarEstado();
    } else {
      // Retirarse: el rival gana 1 piedra, nueva ronda.
      final rival = quien == 0 ? 1 : 0;
      if (rival == 0) {
        _piedrasAnfitrion += 1;
      } else {
        _piedrasInvitado += 1;
      }
      _quienDecideTumbo = -1;
      _mensaje = quien == 0
          ? 'Te retiras del tumbo. El rival gana 1.'
          : 'El rival se retira. Ganas 1 piedra.';
      setState(() {});
      _enviarEstado();
      _comprobarChicosYReiniciar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final esMiTurno = _turno == _miAsiento &&
        !_rondaTerminada &&
        _quienDecideTumbo == -1 &&
        !_enviteCantado;
    final misManos = widget.soyAnfitrion ? _manosAnfitrion : _manosInvitado;
    final manosRival = widget.soyAnfitrion ? _manosInvitado : _manosAnfitrion;
    final misPiedras = widget.soyAnfitrion ? _piedrasAnfitrion : _piedrasInvitado;
    final piedrasRival =
        widget.soyAnfitrion ? _piedrasInvitado : _piedrasAnfitrion;
    final misChicos = widget.soyAnfitrion ? _chicosAnfitrion : _chicosInvitado;
    final chicosRival = widget.soyAnfitrion ? _chicosInvitado : _chicosAnfitrion;
    final enTumbo = _manoEsDeTumbo || _quienDecideTumbo != -1;
    final numCartasRival =
        widget.soyAnfitrion ? _manoInvitado.length : _manoAnfitrion.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0B3D2E),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            children: [
              // Cabecera: volver + titulo
              SizedBox(
                height: 36,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Center(
                      child: Text('ENVITE',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              letterSpacing: 2,
                              fontFamily: 'Georgia')),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () =>
                            Navigator.of(context).popUntil((r) => r.isFirst),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.chevron_left,
                              color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              if (enTumbo)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('\u{1F525} TUMBO',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              // Marcador: RIVAL (rojo) - chicos (negro) - TU (azul)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFC24747), Color(0xFF8F2424)],
                        ),
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding:
                          const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                      child: Column(
                        children: [
                          const Text('RIVAL',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFFFCEBEB))),
                          const SizedBox(height: 6),
                          Garbanzos(
                              piedras: piedrasRival,
                              color: const Color(0xFFE3C28A)),
                          const SizedBox(height: 6),
                          Text('$piedrasRival piedras',
                              style: const TextStyle(
                                  fontSize: 9, color: Color(0xFFF7C1C1))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 56,
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
                        Text('$chicosRival - $misChicos',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        const SizedBox(height: 2),
                        const Text('chicos',
                            style: TextStyle(
                                fontSize: 8, color: Color(0xFFB4B2A9))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF2E78C9), Color(0xFF154A82)],
                        ),
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding:
                          const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                      child: Column(
                        children: [
                          const Text('TÚ',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFFE6F1FB))),
                          const SizedBox(height: 6),
                          Garbanzos(
                              piedras: misPiedras,
                              color: const Color(0xFFE3C28A)),
                          const SizedBox(height: 6),
                          Text('$misPiedras piedras',
                              style: const TextStyle(
                                  fontSize: 9, color: Color(0xFFB5D4F4))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Rival: pila ganada + abanico boca abajo
              const Text('Rival',
                  style: TextStyle(color: Colors.white, fontSize: 15)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PilaGanada(cantidad: manosRival, label: 'Rival'),
                  const SizedBox(width: 50),
                  AbanicoCartas(
                    anchoCarta: 65,
                    altoCarta: 90,
                    solapamiento: 35,
                    cartas: List.generate(
                        numCartasRival,
                        (_) => Container(
                          width: 65,
                          height: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: Colors.white24, width: 1.5),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset('assets/cards/trasera.png',
                              fit: BoxFit.cover),
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              // Centro: vira + cartas jugadas
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(children: [
                    const SizedBox(height: 6),
                    _vira != null
                        ? CardWidget(card: _vira!)
                        : const SizedBox(width: 70, height: 100),
                  ]),
                  const SizedBox(width: 20),
                  Column(children: [
                    const SizedBox(height: 6),
                    _cartaRival != null
                        ? CardWidget(card: _cartaRival!)
                        : const SizedBox(width: 70, height: 100),
                  ]),
                  const SizedBox(width: 20),
                  Column(children: [
                    const SizedBox(height: 6),
                    _cartaMia != null
                        ? CardWidget(card: _cartaMia!)
                        : const SizedBox(width: 70, height: 100),
                  ]),
                ],
              ),
              const SizedBox(height: 12),
              Text('${_manoEsDeTumbo ? 3 : [2, 4, 7, 9, 12][_nivelApuesta]} piedras',
                  style: const TextStyle(
                      color: Colors.orangeAccent, fontSize: 14)),
              // Controles del envite / tumbo
              _controlesEnvite(),
              if (_mensaje.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(_mensaje,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.greenAccent)),
              ],
              const SizedBox(height: 20),
              // Tu zona: abanico (tus cartas) + pila ganada
              const Text('Tú',
                  style: TextStyle(color: Colors.white, fontSize: 15)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AbanicoCartas(
                    anchoCarta: 65,
                    altoCarta: 90,
                    solapamiento: 35,
                    cartas: _miMano.map((c) {
                      return GestureDetector(
                        onTap: esMiTurno ? () => _jugarCarta(c) : null,
                        child: Opacity(
                          opacity: esMiTurno ? 1.0 : 0.45,
                          child: CardWidget(card: c),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(width: 50),
                  PilaGanada(cantidad: misManos, label: 'Tú'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Construye los botones del envite segun la situacion.
  Widget _controlesEnvite() {
    if (_rondaTerminada) return const SizedBox.shrink();

    // ===== TUMBO pendiente de decision =====
    if (_quienDecideTumbo != -1) {
      if (_quienDecideTumbo == _miAsiento) {
        // Me toca decidir.
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              const Text('🔥 ¡TUMBO! Decide:',
                  style: TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () => _decidirTumbo(true),
                    child: const Text('JUGAR (vale 3)'),
                  ),
                  ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                    onPressed: () => _decidirTumbo(false),
                    child: const Text('RETIRARSE'),
                  ),
                ],
              ),
            ],
          ),
        );
      } else {
        // El rival decide.
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('🔥 El rival decide el tumbo...',
              style: TextStyle(color: Colors.orangeAccent)),
        );
      }
    }

    // Nombres de los niveles para los textos de los botones.
    const nombres = ['Base', 'ENVIDO', 'SIETE', 'NUEVE', 'CHICO FUERA'];

    // CASO A: hay un envite cantado y yo NO fui quien cantó -> debo responder.
    if (_enviteCantado && _quienCanto != _miAsiento) {
      final puedeSubir = _nivelPropuesto < 4;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Text('El rival canta ${nombres[_nivelPropuesto]}',
                style: const TextStyle(
                    color: Colors.amber, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () => _responderEnvite('juego'),
                  child: const Text('JUEGO'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => _responderEnvite('paso'),
                  child: const Text('PASO'),
                ),
                if (puedeSubir)
                  ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    onPressed: () => _responderEnvite('subir'),
                    child: Text(nombres[_nivelPropuesto + 1]),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    // CASO B: hay un envite cantado y YO fui quien cantó -> espero.
    if (_enviteCantado && _quienCanto == _miAsiento) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text('Esperando respuesta del rival...',
            style: TextStyle(color: Colors.white70)),
      );
    }

    // CASO C: no hay envite pendiente -> puedo cantar (si no esta al maximo
    // y si tengo el turno de apuesta).
    final puedoCantar = _turnoApuesta == -1 || _turnoApuesta == _miAsiento;
    if (_nivelApuesta < 4 && puedoCantar) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEFAF1F),
            foregroundColor: const Color(0xFF3A2B12),
          ),
          onPressed: _cantarEnvite,
          child: Text(nombres[_nivelApuesta + 1]),
        ),
      );
    }

    return const SizedBox.shrink();
  }

}
