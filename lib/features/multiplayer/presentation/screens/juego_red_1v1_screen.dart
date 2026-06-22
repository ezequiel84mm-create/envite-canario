import 'package:flutter/material.dart';
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

  // Solo el anfitrión usa esto:
  List<CardModel> _manoAnfitrion = [];
  List<CardModel> _manoInvitado = [];

  int get _miAsiento => widget.soyAnfitrion ? 0 : 1;

  @override
  void initState() {
    super.initState();
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
    });
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

    // ¿Se acabaron las cartas?
    if (_manoAnfitrion.isEmpty && _manoInvitado.isEmpty) {
      _rondaTerminada = true;
      _mensaje = _manosAnfitrion > _manosInvitado
          ? '¡Ganaste la ronda! ($_manosAnfitrion-$_manosInvitado)'
          : 'El rival gana la ronda ($_manosAnfitrion-$_manosInvitado)';
    }
  }

  @override
  void dispose() {
    widget.conexion.cerrar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esMiTurno = _turno == _miAsiento && !_rondaTerminada;
    final misManos = widget.soyAnfitrion ? _manosAnfitrion : _manosInvitado;
    final manosRival = widget.soyAnfitrion ? _manosInvitado : _manosAnfitrion;

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
