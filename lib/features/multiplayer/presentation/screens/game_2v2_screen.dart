import 'package:flutter/material.dart';
import '../../../../core/enums/suit.dart';
import '../../../game/data/models/card_model.dart';
import '../../domain/engine/deal_engine_2v2.dart';
import '../../domain/engine/trick_engine_2v2.dart';
import '../../domain/ai/ai_player_2v2.dart';

/// Pantalla funcional simple del 2vs2 (Etapa A).
/// Objetivo: probar que la lógica funciona jugando. Diseño básico.
///
/// Asientos: 0 = tú (abajo), 1 = rival izq, 2 = compañero (arriba), 3 = rival der.
/// Equipo A (tú): asientos 0 y 2. Equipo B (rivales): asientos 1 y 3.
class Game2v2Screen extends StatefulWidget {
  const Game2v2Screen({super.key});

  @override
  State<Game2v2Screen> createState() => _Game2v2ScreenState();
}

class _Game2v2ScreenState extends State<Game2v2Screen> {
  late List<List<CardModel>> _manos;
  late Suit _paloVirado;
  late CardModel _vira;

  // Cartas jugadas en la baza actual.
  List<CartaJugada2v2> _baza = [];

  // De quién es el turno (asiento).
  int _turno = 0;

  // Manos ganadas por cada equipo (0 = tu equipo, 1 = rival).
  int _manosEquipo0 = 0;
  int _manosEquipo1 = 0;

  // Mensaje de estado para mostrar qué pasa.
  String _mensaje = '';

  bool _rondaTerminada = false;

  @override
  void initState() {
    super.initState();
    _repartirNuevaRonda();
  }

  void _repartirNuevaRonda() {
    final reparto = DealEngine2v2.repartir();
    _manos = reparto.manos;
    _paloVirado = reparto.paloVirado;
    _vira = reparto.vira;
    _baza = [];
    _turno = 0;
    _manosEquipo0 = 0;
    _manosEquipo1 = 0;
    _rondaTerminada = false;
    _mensaje = 'Triunfo: ${_vira.displayName}. ¡Tu turno!';
    setState(() {});

    // Si por alguna razón el turno no es tuyo, que jueguen las IAs.
    _continuarSiTocaIA();
  }

  // Devuelve las cartas válidas para el jugador de turno.
  List<CardModel> _validasDe(int asiento) {
    final paloInicial = _baza.isEmpty ? null : _baza.first.carta.suit;
    return TrickEngine2v2.cartasValidas(
      mano: _manos[asiento],
      paloInicialBaza: paloInicial,
      paloVirado: _paloVirado,
    );
  }

  // El humano (asiento 0) juega una carta.
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

    if (_baza.length == 4) {
      // Baza completa: resolver.
      _resolverBaza();
    } else {
      // Pasar al siguiente jugador.
      _turno = (_turno + 1) % 4;
      setState(() {});
      _continuarSiTocaIA();
    }
  }

  void _continuarSiTocaIA() {
    // Si el turno es de una IA (asientos 1, 2, 3) y la ronda no terminó,
    // que juegue tras una pequeña pausa para que se vea.
    if (_rondaTerminada) return;
    if (_turno == 0) return;
    if (_baza.length == 4) return;

    Future.delayed(const Duration(milliseconds: 600), () {
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

    final quien = _nombreAsiento(ganador.asiento);
    _mensaje = '$quien gana la mano con ${ganador.carta.displayName}.';

    // El ganador abre la siguiente baza.
    _turno = ganador.asiento;
    _baza = [];

    // ¿Se acabaron las cartas? (3 manos jugadas)
    final cartasRestantes = _manos.fold<int>(0, (s, m) => s + m.length);
    if (cartasRestantes == 0) {
      _rondaTerminada = true;
      final ganadorRonda = _manosEquipo0 > _manosEquipo1
          ? 'TU EQUIPO gana la ronda'
          : 'EQUIPO RIVAL gana la ronda';
      _mensaje = '$ganadorRonda  ($_manosEquipo0 - $_manosEquipo1)';
    }

    setState(() {});

    if (!_rondaTerminada) {
      _continuarSiTocaIA();
    }
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

  @override
  Widget build(BuildContext context) {
    final misCartas = _manos.isNotEmpty ? _manos[0] : <CardModel>[];
    final validas = _turno == 0 && !_rondaTerminada ? _validasDe(0) : <CardModel>[];

    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      appBar: AppBar(
        title: const Text('2vs2 (prueba)'),
        backgroundColor: Colors.black54,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Marcador por equipos
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _marcador('TU EQUIPO', _manosEquipo0, Colors.lightBlueAccent),
                  Column(
                    children: [
                      const Text('Triunfo',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(_vira.displayName,
                          style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ],
                  ),
                  _marcador('RIVAL', _manosEquipo1, Colors.redAccent),
                ],
              ),
              const SizedBox(height: 16),

              // Cartas jugadas en la baza actual
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Mesa:',
                          style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _baza
                            .map((j) => Column(
                                  children: [
                                    Text(_nombreAsiento(j.asiento),
                                        style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 11)),
                                    _cartaChip(j.carta),
                                  ],
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),

              // Mensaje de estado
              Container(
                padding: const EdgeInsets.all(8),
                width: double.infinity,
                color: Colors.black38,
                child: Text(
                  _mensaje,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const SizedBox(height: 12),

              // Tus cartas
              const Text('Tus cartas:',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: misCartas.map((c) {
                  final jugable = validas.contains(c);
                  return GestureDetector(
                    onTap: jugable ? () => _jugarCartaHumano(c) : null,
                    child: Opacity(
                      opacity: jugable ? 1.0 : 0.4,
                      child: _cartaChip(c),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              if (_rondaTerminada)
                ElevatedButton(
                  onPressed: _repartirNuevaRonda,
                  child: const Text('Nueva ronda'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _marcador(String titulo, int valor, Color color) {
    return Column(
      children: [
        Text(titulo,
            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        Text('$valor',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        const Text('manos', style: TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _cartaChip(CardModel carta) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black26),
      ),
      child: Text(
        carta.displayName,
        style: const TextStyle(color: Colors.black, fontSize: 13),
      ),
    );
  }
}