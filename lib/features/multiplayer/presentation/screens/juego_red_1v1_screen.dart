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
import '../../../../core/settings/app_settings.dart';
import '../../../../core/settings/voces.dart';
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
  int _abreBaza = -1; // asiento de quien echo la primera carta de la baza
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
  String _pendienteDialogo = 'ninguno';
  int _piedrasSumadasDialogo = 0;
  int _ganadorDialogoAsiento = -1;
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
  int _numCartasRivalRecibidas = 3;

  int get _miAsiento => widget.soyAnfitrion ? 0 : 1;
  // Voz elegida por cada asiento (0=anfitrion, 1=invitado).
  String _vozAsiento0 = AppSettings.instance.vozPropia;
  String _vozAsiento1 = AppSettings.instance.vozPropia;

  // Reproductor de efectos (voz de los envites).
  final AudioPlayer _sfxPlayer = AudioPlayer();

  // Reproduce el canto de voz segun el nivel de apuesta.
  // nivel 1=Envido, 2=Siete, 3=Nueve, 4=Chico Fuera.
  void _sonidoApuesta(int nivel, {required int asientoCanta}) {
    if (!AppSettings.instance.efectosActivados) return;
    const nombres = {
      1: 'envido',
      2: 'siete',
      3: 'nueve',
      4: 'chico_fuera',
    };
    final nombre = nombres[nivel];
    if (nombre == null) return;
    // Usa la voz del asiento que canta (0=anfitrion, 1=invitado).
    final idVoz = asientoCanta == 0 ? _vozAsiento0 : _vozAsiento1;
    final voz = Voces.porId(idVoz);
    _sfxPlayer.play(AssetSource('audio/${voz.rutaNivel(nombre)}'));
  }

  // Reproduce un efecto de sonido simple (reparto, recoger baraja).
  void _reproducirEfecto(String archivo) {
    if (!AppSettings.instance.efectosActivados) return;
    _sfxPlayer.play(AssetSource('audio/$archivo'));
  }

  @override
  void initState() {
    super.initState();
    if (widget.soyAnfitrion) {
      _vozAsiento0 = AppSettings.instance.vozPropia;
    } else {
      _vozAsiento1 = AppSettings.instance.vozPropia;
    }
    MusicController.instance.pausar();
    // Escuchar mensajes del otro jugador.
    widget.conexion.alRecibir = _alRecibirMensaje;
    widget.conexion.alDesconectar = () {
      if (!mounted) return;
      _mostrarOtroDesconectado();
    };

    if (widget.soyAnfitrion) {
      _repartirComoAnfitrion();
    } else {
      _mensaje = 'Esperando al anfitrión...';
      // Pide el estado actual por si el anfitrion ya repartio.
      widget.conexion.enviar(MensajeRed(TipoMensaje.hola,
          {'voz': AppSettings.instance.vozPropia}).codificar());
    }
  }

  // ===== ANFITRIÓN: reparte y manda el estado =====
  // ===== Renuncio (anular la mano y repartir de nuevo, sin puntuar) =====

  // Pulsar el boton RENUNCIO: pide confirmacion y, si acepta, propone al rival.
  void _pedirRenuncio() {
    if (_rondaTerminada) return; // no tiene sentido renunciar sin mano en juego
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B3D2E),
        title: const Text('Renunciar a la mano',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'Se propone anular esta mano y repartir de nuevo. Nadie suma piedras. El rival debe aceptar. Seguro?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _proponerRenuncioAlRival();
            },
            child: const Text('Proponer', style: TextStyle(color: Colors.orangeAccent)),
          ),
        ],
      ),
    );
  }

  // Envia la propuesta de renuncio al otro jugador y espera su respuesta.
  void _proponerRenuncioAlRival() {
    widget.conexion.enviar(
        MensajeRed(TipoMensaje.proponerRenuncio, {}).codificar());
    setState(() {
      _mensaje = 'Renuncio propuesto. Esperando al rival...';
    });
  }

  // Muestra el dialogo de voto cuando el rival propone renuncio.
  void _mostrarPropuestaRenuncio() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B3D2E),
        title: const Text('El rival propone renunciar',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'El rival quiere anular esta mano y repartir de nuevo. Nadie suma piedras. Aceptas?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _responderRenuncio(false);
            },
            child: const Text('No', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _responderRenuncio(true);
            },
            child: const Text('Si, renunciar',
                style: TextStyle(color: Colors.orangeAccent)),
          ),
        ],
      ),
    );
  }

  // Responde a la propuesta del rival (acepta o rechaza).
  void _responderRenuncio(bool acepta) {
    if (widget.soyAnfitrion) {
      // El anfitrion resuelve directamente.
      _resolverRenuncio(acepta);
    } else {
      // El invitado manda su respuesta al anfitrion, que ejecuta.
      widget.conexion.enviar(
          MensajeRed(TipoMensaje.respuestaRenuncio, {'acepta': acepta})
              .codificar());
      if (!acepta) {
        setState(() {
          _mensaje = 'Has rechazado el renuncio. Seguid jugando.';
        });
      }
    }
  }

  // Solo el anfitrion ejecuta: si se acepta, reparte de nuevo sin puntuar.
  void _resolverRenuncio(bool acepta) {
    if (!acepta) {
      setState(() {
        _mensaje = 'Renuncio rechazado. Seguid jugando.';
      });
      _enviarEstado();
      return;
    }
    _repartirComoAnfitrion(); // reparte sin tocar piedras y envia estado
  }

  void _repartirComoAnfitrion() {
    _reproducirEfecto('sonido_reparto.mp3');
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
      'numCartasAnfitrion': _manoAnfitrion.length,
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
      'vozAsiento0': _vozAsiento0,
      'vozAsiento1': _vozAsiento1,
      'pendienteDialogo': _pendienteDialogo,
      'piedrasSumadasDialogo': _piedrasSumadasDialogo,
      'ganadorDialogoAsiento': _ganadorDialogoAsiento,
    };
    widget.conexion.enviar(MensajeRed(TipoMensaje.estado, datos).codificar());
  }

  // ===== Recepción de mensajes =====
  void _alRecibirMensaje(String texto) {
    if (!mounted) return; // la pantalla ya no existe: ignorar mensajes tardios
    final msg = MensajeRed.decodificar(texto);
    if (msg == null) return;

    if (widget.soyAnfitrion) {
      // El anfitrión recibe la jugada del invitado.
      if (msg.tipo == TipoMensaje.jugarCarta) {
        final carta = TraductorCartas.desdeTexto(msg.datos['carta']);
        if (carta != null) _anfitrionRecibeJugada(carta);
      } else if (msg.tipo == TipoMensaje.proponerEnvite) {
        // El invitado (asiento 1) canta un envite.
        _vozAsiento1 = msg.datos['voz'] ?? _vozAsiento1;
        _anfitrionRegistraCanto(1);
      } else if (msg.tipo == TipoMensaje.respuestaEnvite) {
        // El invitado responde a un envite.
        _vozAsiento1 = msg.datos['voz'] ?? _vozAsiento1;
        _anfitrionResuelveRespuesta(msg.datos['accion']);
      } else if (msg.tipo == TipoMensaje.hola) {
        _vozAsiento1 = msg.datos['voz'] ?? _vozAsiento1;
        // El invitado pide el estado actual: se lo reenviamos.
        _enviarEstado();
      } else if (msg.tipo == TipoMensaje.decisionTumbo) {
        _anfitrionResuelveTumbo(msg.datos['juega'] == true);
      } else if (msg.tipo == TipoMensaje.proponerRenuncio) {
        // El invitado propone renuncio: el anfitrion decide.
        _mostrarPropuestaRenuncio();
      } else if (msg.tipo == TipoMensaje.respuestaRenuncio) {
        // El invitado respondio a una propuesta del anfitrion.
        _resolverRenuncio(msg.datos['acepta'] == true);
      }
    } else {
      // El invitado recibe el estado del anfitrión.
      if (msg.tipo == TipoMensaje.estado) {
        _invitadoRecibeEstado(msg.datos);
      } else if (msg.tipo == TipoMensaje.proponerRenuncio) {
        // El anfitrion propone renuncio: el invitado decide.
        _mostrarPropuestaRenuncio();
      }
    }
  }

  // El invitado actualiza su pantalla con el estado recibido.
  void _invitadoRecibeEstado(Map<String, dynamic> d) {
    final huboEnviteAntes = _enviteCantado;
    final nivelPropAntes = _nivelPropuesto;
    final anteriorDialogo = _pendienteDialogo;
    final manosAntes = _manosAnfitrion + _manosInvitado;
    final teniaCartas = _miMano.isNotEmpty;
    setState(() {
      _vira = d['vira'] != null ? TraductorCartas.desdeTexto(d['vira']) : null;
      _paloVirado = _vira?.suit;
      _miMano = TraductorCartas.listaDesdeTexto(d['manoInvitado'] ?? []);
        _numCartasRivalRecibidas = d['numCartasAnfitrion'] ?? 3;
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
      _vozAsiento0 = d['vozAsiento0'] ?? _vozAsiento0;
      _vozAsiento1 = d['vozAsiento1'] ?? _vozAsiento1;
      _pendienteDialogo = d['pendienteDialogo'] ?? 'ninguno';
      _piedrasSumadasDialogo = d['piedrasSumadasDialogo'] ?? 0;
      _ganadorDialogoAsiento = d['ganadorDialogoAsiento'] ?? -1;
    });
    if (_pendienteDialogo != 'ninguno' && anteriorDialogo == 'ninguno') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mostrarDialogoFinRed();
      });
    }
    // Reparto nuevo: mano llena, sin cartas en mesa, contador de bazas a 0.
    final esRepartoNuevo = _miMano.length == 3 &&
        _cartaMia == null &&
        _cartaRival == null &&
        (_manosAnfitrion + _manosInvitado) == 0 &&
        (manosAntes > 0 || !teniaCartas);
    if (esRepartoNuevo) {
      _reproducirEfecto('sonido_reparto.mp3');
    }
    // Si apareció un envite nuevo (o subió de nivel), suena el canto.
    final hayEnviteNuevo = _enviteCantado &&
        (!huboEnviteAntes || _nivelPropuesto != nivelPropAntes);
    if (hayEnviteNuevo) {
      _sonidoApuesta(_nivelPropuesto, asientoCanta: _quienCanto);
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
    if (_cartaMia == null && _cartaRival == null) {
      _abreBaza = asiento; // primera carta de la baza
    }
    if (asiento == 0) {
      _manoAnfitrion.remove(carta);
      _cartaMia = carta;
    } else {
      _manoInvitado.remove(carta);
      _cartaRival = carta;
    }

    // ¿Están las dos cartas en mesa?
    if (_cartaMia != null && _cartaRival != null) {
      // Mostramos las dos cartas un momento ANTES de resolver,
      // para que de tiempo a verlas en ambos dispositivos.
      _mensaje = 'Baza completa';
      _miMano = _manoAnfitrion;
      setState(() {});
      _enviarEstado();
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        _resolverBaza();
        setState(() {});
        _enviarEstado();
      });
      return;
    } else {
      _turno = asiento == 0 ? 1 : 0;
      _mensaje = _turno == 0 ? 'Tu turno' : 'Turno del rival';
    }
    _miMano = _manoAnfitrion;
    setState(() {});
    _enviarEstado();
  }

  void _resolverBaza() {
    final jugadaAnfitrion =
        PlayedCard(playerId: 'anfitrion', card: _cartaMia!);
    final jugadaInvitado =
        PlayedCard(playerId: 'invitado', card: _cartaRival!);
    // El que abrio la baza va primero (define el palo inicial).
    final jugadas = _abreBaza == 1
        ? [jugadaInvitado, jugadaAnfitrion]
        : [jugadaAnfitrion, jugadaInvitado];
    final ganador = TrickEngine.determinarGanador(
      jugadas: jugadas,
      paloDeLaMano: _paloVirado!,
    );
    final ganoAnfitrion = ganador.playerId == 'anfitrion';
    if (ganoAnfitrion) {
      _manosAnfitrion++;
      _turno = 0;
      _mensaje = 'Mano para el anfitrión';
    } else {
      _manosInvitado++;
      _turno = 1;
      _mensaje = 'Mano para el invitado';
    }

    _cartaMia = null;
    _cartaRival = null;
    _abreBaza = -1; // baza cerrada, la siguiente la abre quien gano
    _reproducirEfecto('sonido_recoger_baraja.mp3');

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

    _ganadorDialogoAsiento = ganaAnfitrion ? 0 : 1;
    _piedrasSumadasDialogo = valorMano;
    _mensaje = ganaAnfitrion
        ? 'Ronda para el anfitrión (+$valorMano)'
        : 'Ronda para el invitado (+$valorMano)';

    _comprobarChicoYMostrarDialogo();
  }

  bool _dialogoDesconexionAbierto = false;
  void _mostrarOtroDesconectado() {
    if (_dialogoDesconexionAbierto) return;
    _dialogoDesconexionAbierto = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE8D4A8), Color(0xFFDCC290)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF8A6A35), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🔌 Jugador desconectado',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9A3A0A)),
              ),
              const SizedBox(height: 12),
              const Text(
                'El otro jugador se ha desconectado.\nLa partida ha terminado.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF3A2B12), height: 1.4),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFEFAF1F), Color(0xFFC8870F)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF8A6A35), width: 1.5),
                  ),
                  child: const Text(
                    'Volver al menú',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3A2B12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.conexion.alRecibir = null; // dejar de escuchar antes de cerrar
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
        MensajeRed(TipoMensaje.proponerEnvite,
            {'voz': AppSettings.instance.vozPropia}).codificar(),
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
    _sonidoApuesta(_nivelPropuesto, asientoCanta: asiento);
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
        MensajeRed(TipoMensaje.respuestaEnvite,
            {'accion': accion, 'voz': AppSettings.instance.vozPropia})
            .codificar(),
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
      // NO QUIERO = juega con lo que tenemos: se queda en el ultimo nivel
      // aceptado (_nivelApuesta sin tocar) y la mano sigue. Se cobra al ganar.
      _enviteCantado = false;
      _quienCanto = -1;
      _turnoApuesta = -1;
      _mensaje = 'Juegan con lo apostado.';
    } else if (accion == 'subir') {
      // Subir: reenvida al siguiente nivel; ahora responde el otro.
      _nivelPropuesto = _nivelPropuesto + 1;
      _sonidoApuesta(_nivelPropuesto, asientoCanta: _quienCanto);
      _quienCanto = _quienCanto == 0 ? 1 : 0; // cambia quien espera respuesta
      _mensaje = 'Envite subido. ¡Responde!';
    }
    setState(() {});
    _enviarEstado();
  }

  // Comprueba chico/partida y muestra el dialogo de fin de mano.
  void _comprobarChicoYMostrarDialogo() {
    const chicosParaGanar = 2;
    bool huboChico = false;

    if (_piedrasAnfitrion >= 12) {
      _chicosAnfitrion++;
      _piedrasAnfitrion = 0;
      _piedrasInvitado = 0;
      _ganadorDialogoAsiento = 0;
      huboChico = true;
    } else if (_piedrasInvitado >= 12) {
      _chicosInvitado++;
      _piedrasAnfitrion = 0;
      _piedrasInvitado = 0;
      _ganadorDialogoAsiento = 1;
      huboChico = true;
    }

    final finPartida = _chicosAnfitrion >= chicosParaGanar ||
        _chicosInvitado >= chicosParaGanar;

    if (finPartida) {
      _pendienteDialogo = 'partida';
    } else if (huboChico) {
      _pendienteDialogo = 'chico';
    } else {
      _pendienteDialogo = 'mano';
    }

    _rondaTerminada = true;
    setState(() {});
    _enviarEstado();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mostrarDialogoFinRed();
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
          ? 'El anfitrión juega el tumbo (vale 3)'
          : 'El invitado juega el tumbo (vale 3)';
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
          ? 'El anfitrión se retira. Invitado gana 1.'
          : 'El invitado se retira. Anfitrión gana 1.';
      _ganadorDialogoAsiento = rival;
      _piedrasSumadasDialogo = 1;
      _comprobarChicoYMostrarDialogo();
    }
  }

  void _mostrarDialogoFinRed() {
    if (!mounted || _pendienteDialogo == 'ninguno') return;
    final ganoAnfitrion = _ganadorDialogoAsiento == 0;
    final ganaMiJugador =
        widget.soyAnfitrion ? ganoAnfitrion : !ganoAnfitrion;
    final esChico = _pendienteDialogo == 'chico';
    final esPartida = _pendienteDialogo == 'partida';
    // Sonido de fin de partida: victoria o derrota.
    if (esPartida) {
      _reproducirEfecto(
          ganaMiJugador ? 'chacaras.mp3' : 'se_me_fue_el_baifo.mp3');
    }
    final misChicos =
        widget.soyAnfitrion ? _chicosAnfitrion : _chicosInvitado;
    final chicosRival =
        widget.soyAnfitrion ? _chicosInvitado : _chicosAnfitrion;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoFinManoRed(
        gano: ganaMiJugador,
        huboChico: esChico,
        finPartida: esPartida,
        piedrasSumadas: _piedrasSumadasDialogo,
        chicosYo: misChicos,
        chicosRival: chicosRival,
        ganadorEsYo: ganaMiJugador,
        onContinuar: () {
          Navigator.pop(context);
          _pendienteDialogo = 'ninguno';
          if (widget.soyAnfitrion) {
            if (esPartida) {
              setState(() {
                _chicosAnfitrion = 0;
                _chicosInvitado = 0;
              });
            }
            _nivelApuesta = 0;
            _repartirComoAnfitrion();
          }
        },
        onSalir: esPartida
            ? () => Navigator.of(context).popUntil((r) => r.isFirst)
            : null,
      ),
    );
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
        widget.soyAnfitrion ? _manoInvitado.length : _numCartasRivalRecibidas;

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
                    if (!_rondaTerminada)
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: _pedirRenuncio,
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              widthFactor: 1,
                              child: Text('RENUNCIO',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    letterSpacing: 1,
                                  )),
                            ),
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
                    anchoCarta: 78,
                    altoCarta: 108,
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
                        ? CardWidget(card: _vira!, width: 102, height: 162)
                        : const SizedBox(width: 102, height: 162),
                  ]),
                  const SizedBox(width: 10),
                  Column(children: [
                    const SizedBox(height: 6),
                    _cartaRival != null
                        ? CardWidget(card: _cartaRival!, width: 102, height: 162)
                        : const SizedBox(width: 102, height: 162),
                  ]),
                  const SizedBox(width: 10),
                  Column(children: [
                    const SizedBox(height: 6),
                    _cartaMia != null
                        ? CardWidget(card: _cartaMia!, width: 102, height: 162)
                        : const SizedBox(width: 102, height: 162),
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
                    anchoCarta: 78,
                    altoCarta: 108,
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

class DialogoFinManoRed extends StatelessWidget {
  final bool gano;
  final bool huboChico;
  final bool finPartida;
  final int piedrasSumadas;
  final int chicosYo;
  final int chicosRival;
  final bool ganadorEsYo;
  final VoidCallback onContinuar;
  final VoidCallback? onSalir;

  const DialogoFinManoRed({
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
            color: huboChico
                ? const Color(0xFFC8870F)
                : const Color(0xFF8A6A35),
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
        gano ? '¡GANASTE LA MANO!' : 'EL RIVAL GANÓ LA MANO',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Georgia',
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Color(0xFF3A2B12),
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 16),
      Container(width: 160, height: 1, color: const Color(0x808A6A35)),
      const SizedBox(height: 14),
      Text(
        gano ? 'Sumas' : 'El rival suma',
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
        ganadorEsYo ? 'Te llevas el chico' : 'El rival se lleva el chico',
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
        'Tú $chicosYo  ·  Rival $chicosRival',
        style: const TextStyle(fontSize: 12, color: Color(0xFF6B5424)),
      ),
    ];
  }

  List<Widget> _contenidoPartida() {
    return [
      const Text('🏅', style: TextStyle(fontSize: 38)),
      const SizedBox(height: 6),
      Text(
        ganadorEsYo ? '¡GANASTE LA PARTIDA!' : 'EL RIVAL GANÓ LA PARTIDA',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Georgia',
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF9A3A0A),
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Tú $chicosYo  ·  Rival $chicosRival',
        style: const TextStyle(fontSize: 13, color: Color(0xFF6B5424)),
      ),
    ];
  }
}
