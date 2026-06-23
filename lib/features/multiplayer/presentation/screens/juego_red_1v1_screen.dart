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

    _miMano = _manoAnfitrion;
    _mensaje = 'Tu turno';
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
    if (_turno != _miAsiento) return; // no es mi turno

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
    final valorMano = valores[_nivelApuesta];
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
      _nivelApuesta = _nivelPropuesto;
      _enviteCantado = false;
      _quienCanto = -1;
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

  @override
  Widget build(BuildContext context) {
    final esMiTurno = _turno == _miAsiento && !_rondaTerminada;
    final misManos = widget.soyAnfitrion ? _manosAnfitrion : _manosInvitado;
    final manosRival = widget.soyAnfitrion ? _manosInvitado : _manosAnfitrion;
    final misPiedras = widget.soyAnfitrion ? _piedrasAnfitrion : _piedrasInvitado;
    final piedrasRival = widget.soyAnfitrion ? _piedrasInvitado : _piedrasAnfitrion;
    final misChicos = widget.soyAnfitrion ? _chicosAnfitrion : _chicosInvitado;
    final chicosRival = widget.soyAnfitrion ? _chicosInvitado : _chicosAnfitrion;

    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      body: SafeArea(
        child: Column(
          children: [
            // Barra superior: volver + marcador
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
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
                        _marcador('TÚ', misManos, Colors.lightBlueAccent),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              const Text('Triunfo',
                                  style: TextStyle(
                                      color: Colors.white60, fontSize: 10)),
                              Text(_vira?.suit.displayName ?? '—',
                                  style: const TextStyle(
                                      color: Colors.amber,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                        _marcador('RIVAL', manosRival, Colors.redAccent),
                      ],
                    ),
                  ),
                  const SizedBox(width: 38),
                ],
              ),
            ),
            // Linea provisional de piedras y chicos (envite)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 30),
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Piedras  Tu $misPiedras - $piedrasRival Rival     '
                'Chicos  $misChicos - $chicosRival',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.amber, fontSize: 12),
              ),
            ),

            // Carta del rival (arriba)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  const Text('Rival',
                      style: TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 6),
                  _cartaRival != null
                      ? SizedBox(
                          width: 70,
                          height: 110,
                          child: FittedBox(child: CardWidget(card: _cartaRival!)))
                      : const SizedBox(width: 70, height: 110),
                ],
              ),
            ),

            // Centro: tu carta jugada
            Expanded(
              child: Center(
                child: _cartaMia != null
                    ? SizedBox(
                        width: 80,
                        height: 125,
                        child: FittedBox(child: CardWidget(card: _cartaMia!)))
                    : Text(
                        esMiTurno ? 'Juega una carta' : '',
                        style: const TextStyle(color: Colors.white54),
                      ),
              ),
            ),

            // Mensaje
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 6),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),

            // ===== Controles del envite =====
            _controlesEnvite(),

            // Tus cartas (abajo)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 14),
              child: Wrap(
                spacing: 8,
                children: _miMano.map((c) {
                  return GestureDetector(
                    onTap: esMiTurno ? () => _jugarCarta(c) : null,
                    child: Opacity(
                      opacity: esMiTurno ? 1.0 : 0.6,
                      child: SizedBox(
                        width: 75,
                        height: 120,
                        child: FittedBox(child: CardWidget(card: c)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            if (_rondaTerminada && widget.soyAnfitrion)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: ElevatedButton(
                  onPressed: _repartirComoAnfitrion,
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
    );
  }

  // Construye los botones del envite segun la situacion.
  Widget _controlesEnvite() {
    if (_rondaTerminada) return const SizedBox.shrink();

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

    // CASO C: no hay envite pendiente -> puedo cantar (si no esta al maximo).
    if (_nivelApuesta < 4) {
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

  Widget _marcador(String titulo, int valor, Color color) {
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
}
