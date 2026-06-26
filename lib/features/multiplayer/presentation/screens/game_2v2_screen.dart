import 'package:flutter/material.dart';
import '../../../sala/domain/models/config_partida.dart';
import '../../../../core/enums/suit.dart';
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
  const Game2v2Screen({super.key, this.config});

  @override
  State<Game2v2Screen> createState() => _Game2v2ScreenState();
}

class _Game2v2ScreenState extends State<Game2v2Screen> {
  late List<List<CardModel>> _manos;
  late Suit _paloVirado;
  late CardModel _vira;

  List<CartaJugada2v2> _baza = [];
  int _turno = 0;
  int _manosEquipo0 = 0;
  int _manosEquipo1 = 0;
  String _mensaje = '';
  bool _rondaTerminada = false;
  int _numJug = 4; // jugadores en la partida (4, 6 u 8); 4 por defecto

  @override
  void initState() {
    super.initState();
    MusicController.instance.pausar();
    if (widget.config != null) {
      _numJug = widget.config!.numJugadores;
    }
    _repartirNuevaRonda();
  }

  @override
  void dispose() {
    MusicController.instance.reanudar();
    super.dispose();
  }

  void _repartirNuevaRonda() {
    final reparto = DealEngine2v2.repartirPara(_numJug);
    _manos = reparto.manos;
    _paloVirado = reparto.paloVirado;
    _vira = reparto.vira;
    _baza = [];
    _turno = 0;
    _manosEquipo0 = 0;
    _manosEquipo1 = 0;
    _rondaTerminada = false;
    _mensaje = '¡Tu turno!';
    setState(() {});
    _continuarSiTocaIA();
  }

  List<CardModel> _validasDe(int asiento) {
    final paloInicial = _baza.isEmpty ? null : _baza.first.carta.suit;
    return TrickEngine2v2.cartasValidas(
      mano: _manos[asiento],
      paloInicialBaza: paloInicial,
      paloVirado: _paloVirado,
    );
  }

  void _jugarCartaHumano(CardModel carta) {
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
      setState(() {});
      _continuarSiTocaIA();
    }
  }

  void _continuarSiTocaIA() {
    if (_rondaTerminada) return;
    if (_turno == 0) return;
    if (_baza.length == _numJug) return;

    Future.delayed(const Duration(milliseconds: 700), () {
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
    _mensaje = '${_nombreAsiento(ganador.asiento)} gana la mano';
    _turno = ganador.asiento;

    setState(() {});

    // Pausa para que se vea la baza completa antes de limpiarla.
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      _baza = [];
      final cartasRestantes = _manos.fold<int>(0, (s, m) => s + m.length);
      if (cartasRestantes == 0) {
        _rondaTerminada = true;
        _mensaje = _manosEquipo0 > _manosEquipo1
            ? '¡TU EQUIPO gana la ronda! ($_manosEquipo0 - $_manosEquipo1)'
            : 'Equipo rival gana la ronda ($_manosEquipo0 - $_manosEquipo1)';
      }
      setState(() {});
      if (!_rondaTerminada) _continuarSiTocaIA();
    });
  }

  String _nombreAsiento(int asiento) {
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
  CardModel? _cartaEnMesaDe(int asiento) {
    for (final j in _baza) {
      if (j.asiento == asiento) return j.carta;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final misCartas = _manos.isNotEmpty ? _manos[0] : <CardModel>[];
    final validas =
        _turno == 0 && !_rondaTerminada ? _validasDe(0) : <CardModel>[];

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
                _jugadorRival(asiento: 2, etiqueta: 'Compañero', esCompanero: true),

                // Zona central: rivales a los lados + cartas jugadas
                Expanded(
                  child: Row(
                    children: [
                      _jugadorRivalLateral(asiento: 1, etiqueta: 'Rival'),
                      Expanded(child: _zonaCentral()),
                      _jugadorRivalLateral(asiento: 3, etiqueta: 'Rival'),
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
  Widget _jugadorRival({
    required int asiento,
    required String etiqueta,
    bool esCompanero = false,
  }) {
    final numCartas = _manos.isNotEmpty ? _manos[asiento].length : 0;
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
    final numCartas = _manos.isNotEmpty ? _manos[asiento].length : 0;
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
        // Compañero (arriba)
        Align(alignment: Alignment.topCenter, child: _cartaJugadaMini(2)),
        // Rival izq
        Align(alignment: Alignment.centerLeft, child: _cartaJugadaMini(1)),
        // Rival der
        Align(alignment: Alignment.centerRight, child: _cartaJugadaMini(3)),
        // Tú (abajo)
        Align(alignment: Alignment.bottomCenter, child: _cartaJugadaMini(0)),
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