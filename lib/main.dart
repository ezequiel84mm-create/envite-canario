import 'dart:math';
import 'core/settings/voces.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'core/settings/app_settings.dart';
import 'core/enums/suit.dart';
import 'features/game/data/models/player_model.dart';
import 'features/game/data/models/card_model.dart';
import 'features/game/data/models/score_model.dart';
import 'features/game/data/models/bet_model.dart';
import 'features/game/domain/engine/deal_engine.dart';
import 'features/game/domain/engine/trick_engine.dart';
import 'features/game/domain/ai/ai_player.dart';
import 'features/game/presentation/widgets/card_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.cargar();
  runApp(const EnviteApp());
}

class EnviteApp extends StatelessWidget {
  const EnviteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Envite Canario',
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}

class _Garbanzos extends StatelessWidget {
  final int piedras;
  final Color color;

  const _Garbanzos({required this.piedras, required this.color});

  Widget _garbanzo() {
    return Container(
      width: 12,
      height: 9.5,
      decoration: BoxDecoration(
        color: const Color(0xFFE3C28A),
        border: Border.all(color: const Color(0xFF8A6A35), width: 1),
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sistema tradicional canario:
    // 1-6: un garbanzo por punto, en fila.
    // 7: uno solo.
    // 8: dos separados (extremos).
    // 9: los mismos dos + uno en el medio.
    // 10: uno solo (igual que el 7, el contexto indica el valor).
    if (piedras <= 0) {
      return const SizedBox(height: 9.5);
    }

    if (piedras <= 6) {
      return Wrap(
        spacing: 3,
        alignment: WrapAlignment.center,
        children: List.generate(piedras, (_) => _garbanzo()),
      );
    }

    if (piedras == 7 || piedras == 10) {
      return _garbanzo();
    }

    if (piedras == 8) {
      return SizedBox(
        width: 46,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [_garbanzo(), _garbanzo()],
        ),
      );
    }

    // piedras == 9
    return SizedBox(
      width: 46,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [_garbanzo(), _garbanzo(), _garbanzo()],
      ),
    );
  }
}

class _AbanicoCartas extends StatelessWidget {
  final List<Widget> cartas;
  final double anchoCarta;
  final double altoCarta;
  final double solapamiento;

  const _AbanicoCartas({
    required this.cartas,
    this.anchoCarta = 85,
    this.altoCarta = 135,
    this.solapamiento = 45,
  });

  @override
  Widget build(BuildContext context) {
    final n = cartas.length;
    if (n == 0) {
      return SizedBox(width: anchoCarta, height: altoCarta);
    }

    final anchoTotal = anchoCarta + (n - 1) * solapamiento;
    final anguloMax = 6.0; // grados de inclinación en los extremos

    return SizedBox(
      width: anchoTotal,
      height: altoCarta + 16,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(n, (i) {
          final centro = (n - 1) / 2;
          final distancia = i - centro;
          final angulo = n > 1 ? (distancia / centro) * anguloMax : 0.0;
          final offsetY = distancia.abs() * 4; // las del centro un poco más arriba

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

class _PilaGanada extends StatelessWidget {
  final int cantidad;
  final String label;

  const _PilaGanada({required this.cantidad, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 115,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: cantidad == 0
            ? [
                Container(
                  width: 60,
                  height: 85,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white12, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ]
            : List.generate(cantidad.clamp(0, 6), (i) {
                final angulo = ((i * 37) % 25 - 12) * 3.14159 / 180;
                final offsetX = ((i * 17) % 13 - 6).toDouble();
                final offsetY = -i * 2.5;
                return Transform.translate(
                  offset: Offset(offsetX, offsetY),
                  child: Transform.rotate(
                    angle: angulo,
                    child: Container(
                      width: 60,
                      height: 85,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white24, width: 1),
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 2, offset: Offset(1, 1)),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/cards/trasera.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              }),
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late PlayerModel tu;
  late PlayerModel ia;
  late Suit paloDeLaMano;
  late CardModel cartaVirada;

  String quienReparte = 'ia';
  late String quienSaca;

  List<PlayedCard> bazaActual = [];
  bool _resolviendoBaza = false; // bloquea jugar mientras se resuelve/recoge
  int bazasGanadasTu = 0;
  int bazasGanadasIA = 0;
  String? mensaje;
  final ScoreModel score = ScoreModel();
  final ApuestaModel apuesta = ApuestaModel();
  List<CardModel> pilaGanadaTu = [];
  List<CardModel> pilaGanadaIA = [];
  bool manoEsDeTumbo = false;
  String? equipoDecidiendoTumbo;
  bool envitePropuestoPorIA = false;
  final AudioPlayer _sfxPlayer = AudioPlayer();

  void _reproducirSonido(String archivo) {
    if (!AppSettings.instance.efectosActivados) return;
    _sfxPlayer.play(AssetSource('audio/$archivo'));
  }
  /// Reproduce el canto de voz según el nivel de apuesta alcanzado.
  /// nivel 1=Envite, 2=Siete, 3=Nueve, 4=Chico Fuera. (nivel 0 no suena)
  void _sonidoApuesta(int nivel, {bool esIA = false}) {
    const nombres = {
      1: 'envido',
      2: 'siete',
      3: 'nueve',
      4: 'chico_fuera',
    };
    final nombre = nombres[nivel];
    if (nombre == null) return;
    final idVoz = esIA
        ? AppSettings.instance.vozRival
        : AppSettings.instance.vozPropia;
    final voz = Voces.porId(idVoz);
    _reproducirSonido(voz.rutaNivel(nombre));
  }
  
  String? turnoDeApuesta;
  bool _repartiendo = false;

  @override
  void initState() {
    super.initState();
    _repartirNuevaMano();
  }

  void _pedirRenuncio() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B3D2E),
        title: const Text('Renunciar a la mano',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'Se anula esta mano y se reparte de nuevo. Nadie suma piedras. Seguro?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _renunciarMano();
            },
            child: const Text('Renunciar', style: TextStyle(color: Colors.orangeAccent)),
          ),
        ],
      ),
    );
  }

  void _renunciarMano() {
    _resolviendoBaza = false; // por si renuncia a mitad de resolucion
    _repartirNuevaMano();     // reparte de nuevo sin tocar score (piedras intactas)
    setState(() {
      mensaje = 'Mano anulada. Se reparte de nuevo.';
    });
  }

  void _repartirNuevaMano() {
    final players = [
      PlayerModel(id: 'tu', name: 'Tú'),
      PlayerModel(id: 'ia', name: 'IA', isAI: true),
    ];
    final resultado = DealEngine.repartir(players);

    final saca = quienReparte == 'ia' ? 'tu' : 'ia';

    apuesta.reset();
    _repartiendo = true;
    _reproducirSonido('sonido_reparto.mp3');

    final enTumbo = score.equipoEnTumbo;
    final forzoso = score.tumboForzoso;

    setState(() {
      tu = resultado.players[0];
      ia = resultado.players[1];
      paloDeLaMano = resultado.paloDeLaMano;
      cartaVirada = resultado.cartaVirada;
      bazaActual = [];
      bazasGanadasTu = 0;
      bazasGanadasIA = 0;
      mensaje = forzoso ? '\u{1F525} ¡Tumbo forzoso! Hay que jugar.' : null;
      quienSaca = saca;
      pilaGanadaTu = [];
      pilaGanadaIA = [];
      manoEsDeTumbo = forzoso;
      equipoDecidiendoTumbo = forzoso ? null : enTumbo;
      turnoDeApuesta = null;
    });

    if (!forzoso && enTumbo != null) {
      if (enTumbo == 'ia') {
        Future.delayed(const Duration(seconds: 2), _iaDecideTumbo);
      }
      return;
    }

    if (quienSaca == 'ia') {
      Future.delayed(const Duration(milliseconds: 600), _iaSacaPrimera);
    }
  }

  void _iaDecideTumbo() {
    final juega = Random().nextDouble() < 0.7;
    _decidirTumbo(juega);
  }

  void _decidirTumbo(bool juega) {
    final equipo = equipoDecidiendoTumbo;
    if (equipo == null) return;

    if (juega) {
      setState(() {
        manoEsDeTumbo = true;
        equipoDecidiendoTumbo = null;
        mensaje = equipo == 'tu'
            ? 'Decidiste jugar el Tumbo -> esta mano vale 3 piedras'
            : 'La IA decide jugar el Tumbo -> esta mano vale 3 piedras';
      });

      if (quienSaca == 'ia') {
        Future.delayed(const Duration(milliseconds: 600), _iaSacaPrimera);
      }
    } else {
      final rival = equipo == 'tu' ? 'ia' : 'tu';
      final huboChico = score.sumarPiedras(rival, 1);
      final ganadorPartida = score.ganadorPartida;

      setState(() {
        equipoDecidiendoTumbo = null;
        final base = equipo == 'tu'
            ? 'Te retiraste del Tumbo. La IA gana 1 piedra.'
            : 'La IA se retira del Tumbo. Ganas 1 piedra.';
        mensaje = huboChico ? '$base 🏆 ¡Chico completado!' : base;
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        if (ganadorPartida != null) {
          _mostrarFinPartida(ganadorPartida);
        } else {
          _repartirNuevaMano();
        }
      });
    }
  }

  List<CardModel> get _cartasValidasParaTi {
    final paloInicial = bazaActual.isEmpty ? null : bazaActual.first.card.suit;
    return TrickEngine.cartasValidas(
      mano: tu.hand,
      paloInicialBaza: paloInicial,
      paloDeLaMano: paloDeLaMano,
      baza: bazaActual,
    );
  }

  void _jugarCartaTu(CardModel carta) {
    if (_resolviendoBaza) return; // baza en proceso: ignora toques
    if (envitePropuestoPorIA) return;
    if (quienSaca != 'tu' && bazaActual.isEmpty) return;
    if (bazaActual.length >= 2) return; // ya hay dos cartas en mesa
    if (!_cartasValidasParaTi.contains(carta)) return;

    setState(() {
      tu.hand.remove(carta);
      bazaActual.add(PlayedCard(playerId: 'tu', card: carta));
    });

    if (bazaActual.length < 2) {
      Future.delayed(const Duration(milliseconds: 500), _jugarCartaIA);
    } else {
      _resolverBazaSiCompleta();
    }
  }

  void _iaSacaPrimera() {
    if (ia.hand.isEmpty) return;
    if (envitePropuestoPorIA) return;
    final cartaElegida = AiPlayer.elegirCarta(
      validas: ia.hand,
      bazaActual: bazaActual,
      paloDeLaMano: paloDeLaMano,
      bazasGanadasIA: bazasGanadasIA,
      bazasGanadasTu: bazasGanadasTu,
      margen: AiPlayer.margenPara(AppSettings.instance.dificultadIA),
    );
    setState(() {
      ia.hand.remove(cartaElegida);
      bazaActual.add(PlayedCard(playerId: 'ia', card: cartaElegida));
    });
    _iaConsideraEnvite();
  }

  void _jugarCartaIA() {
    if (envitePropuestoPorIA) return;
    final paloInicial = bazaActual.first.card.suit;
    final validas = TrickEngine.cartasValidas(
      mano: ia.hand,
      paloInicialBaza: paloInicial,
      paloDeLaMano: paloDeLaMano,
      baza: bazaActual,
    );

    final cartaElegida = AiPlayer.elegirCarta(
      validas: validas,
      bazaActual: bazaActual,
      paloDeLaMano: paloDeLaMano,
      bazasGanadasIA: bazasGanadasIA,
      bazasGanadasTu: bazasGanadasTu,
      margen: AiPlayer.margenPara(AppSettings.instance.dificultadIA),
    );

    setState(() {
      ia.hand.remove(cartaElegida);
      bazaActual.add(PlayedCard(playerId: 'ia', card: cartaElegida));
    });

    _resolverBazaSiCompleta();
  }

  void _resolverBazaSiCompleta() {
    if (bazaActual.length < 2) return;
    _resolviendoBaza = true; // bloquea jugar hasta recoger

    final ganador = TrickEngine.determinarGanador(
      jugadas: bazaActual,
      paloDeLaMano: paloDeLaMano,
    );

    final cartasDeEstaBaza = bazaActual.map((j) => j.card).toList();

    setState(() {
      if (ganador.playerId == 'tu') {
        bazasGanadasTu++;
        mensaje = 'Ganaste la mano con ${ganador.card.displayName}';
        pilaGanadaTu.addAll(cartasDeEstaBaza);
      } else {
        bazasGanadasIA++;
        mensaje = 'La IA ganó la mano con ${ganador.card.displayName}';
        pilaGanadaIA.addAll(cartasDeEstaBaza);
      }
      quienSaca = ganador.playerId;
    });

    _reproducirSonido('sonido_recoger_baraja.mp3');

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        bazaActual = [];
        _resolviendoBaza = false;
      });

      if (bazasGanadasTu == 2 || bazasGanadasIA == 2 || (tu.hand.isEmpty && ia.hand.isEmpty)) {
        _finDeMano();
        return;
      }

      if (quienSaca == 'ia') {
        _iaSacaPrimera();
      }
    });
  }

  void _finDeMano() {
    final ganadorId = bazasGanadasTu > bazasGanadasIA ? 'tu' : 'ia';
    final valorMano = manoEsDeTumbo ? 3 : apuesta.valorActual;
    final huboChico = score.sumarPiedras(ganadorId, valorMano);
    final ganadorPartida = score.ganadorPartida;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoFinMano(
        gano: ganadorId == 'tu',
        huboChico: huboChico && ganadorPartida == null,
        finPartida: ganadorPartida != null,
        piedrasSumadas: valorMano,
        chicosTu: score.chicosTu,
        chicosIA: score.chicosIA,
        ganadorEsTu: ganadorId == 'tu',
        onContinuar: () {
          Navigator.pop(context);
          if (ganadorPartida != null) {
            setState(() {
              score.piedrasTu = 0;
              score.piedrasIA = 0;
              score.chicosTu = 0;
              score.chicosIA = 0;
            });
          }
          quienReparte = quienReparte == 'ia' ? 'tu' : 'ia';
          _repartirNuevaMano();
        },
        onSalir: ganadorPartida != null
            ? () => Navigator.of(context).popUntil((ruta) => ruta.isFirst)
            : null,
      ),
    );
  }

  void _mostrarFinPartida(String ganadorPartida) {
    // Sonido de fin de partida: victoria o derrota.
    _reproducirSonido(
        ganadorPartida == 'tu' ? 'chacaras.mp3' : 'se_me_fue_el_baifo.mp3');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoFinMano(
        gano: ganadorPartida == 'tu',
        huboChico: false,
        finPartida: true,
        piedrasSumadas: 0,
        chicosTu: score.chicosTu,
        chicosIA: score.chicosIA,
        ganadorEsTu: ganadorPartida == 'tu',
        onContinuar: () {
          Navigator.pop(context);
          setState(() {
            score.piedrasTu = 0;
            score.piedrasIA = 0;
            score.chicosTu = 0;
            score.chicosIA = 0;
          });
          quienReparte = quienReparte == 'ia' ? 'tu' : 'ia';
          _repartirNuevaMano();
        },
        onSalir: () {
          Navigator.of(context).popUntil((ruta) => ruta.isFirst);
        },
      ),
    );
  }

  void _iaConsideraEnvite() {
    if (apuesta.esMaximo) return;
    if (envitePropuestoPorIA) return;
    if (manoEsDeTumbo) return;
    if (turnoDeApuesta != null && turnoDeApuesta != 'ia') return;
    if (tu.hand.isEmpty && ia.hand.isEmpty) return;
    if (bazasGanadasTu == 2 || bazasGanadasIA == 2) return;

    final iaTieneTriunfoFuerte = ia.hand.any(
      (c) => c.suit == paloDeLaMano && c.value.fuerza >= 8,
    );

    final probabilidad = iaTieneTriunfoFuerte ? 0.5 : 0.15;
    final tira = Random().nextDouble();

    if (tira < probabilidad) {
      setState(() {
        envitePropuestoPorIA = true;
        mensaje = 'La IA propone ${apuesta.proximoNombre}';
      });
      _sonidoApuesta(apuesta.nivelIndex + 1, esIA: true);
    }
  }

  void _responderEnviteIA(bool aceptar, {bool subir = false}) {
    final valorSiRechaza = apuesta.valorSiRechaza;

    if (aceptar) {
      setState(() {
        apuesta.nivelIndex++;
        envitePropuestoPorIA = false;
        turnoDeApuesta = subir ? 'ia' : 'tu';
        mensaje = 'Aceptaste';
      });
      if (subir && !apuesta.esMaximo) {
        Future.delayed(const Duration(milliseconds: 400), _lanzarEnvite);
      }
    } else {
      final huboChico = score.sumarPiedras('ia', valorSiRechaza);
      final ganadorPartida = score.ganadorPartida;

      setState(() {
        envitePropuestoPorIA = false;
        mensaje = huboChico
            ? 'Pasaste -> ¡Chico completado!'
            : 'Pasaste';
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        if (ganadorPartida != null) {
          _mostrarFinPartida(ganadorPartida);
        } else {
          quienReparte = quienReparte == 'ia' ? 'tu' : 'ia';
          _repartirNuevaMano();
        }
      });
    }
  }

  void _lanzarEnvite() {
    if (apuesta.esMaximo) return;
    if (manoEsDeTumbo) return;
    _sonidoApuesta(apuesta.nivelIndex + 1);

    final valorProximo = apuesta.proximoValor;
    final valorSiRechaza = apuesta.valorSiRechaza;

    final iaTieneTriunfo = ia.hand.any((c) => c.suit == paloDeLaMano);
    final iaAcepta = iaTieneTriunfo || valorProximo <= 7;

    if (iaAcepta) {
      setState(() {
        apuesta.nivelIndex++;
        turnoDeApuesta = 'ia';
        mensaje = 'La IA juega';
      });
    } else {
      final huboChico = score.sumarPiedras('tu', valorSiRechaza);
      final ganadorPartida = score.ganadorPartida;

      setState(() {
        mensaje = huboChico
            ? 'La IA pasa -> ¡Chico completado!'
            : 'La IA pasa';
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        if (ganadorPartida != null) {
          _mostrarFinPartida(ganadorPartida);
        } else {
          quienReparte = quienReparte == 'ia' ? 'tu' : 'ia';
          _repartirNuevaMano();
        }
      });
    }
  }

  CardModel? _cartaDe(String playerId) {
    for (final j in bazaActual) {
      if (j.playerId == playerId) return j.card;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cartasValidas = _cartasValidasParaTi;
    final enTumbo = manoEsDeTumbo || equipoDecidiendoTumbo != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0B3D2E),
      body: Stack(
        children: [
          SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          children: [
            SizedBox(
              height: 36,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Center(
                    child: Text(
                      'ENVITE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: 2,
                        fontFamily: 'Georgia',
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () {
                        // Cierra cualquier dialogo emergente abierto y vuelve al menu.
                        Navigator.of(context).popUntil((ruta) => ruta.isFirst);
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.chevron_left, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
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
                child: const Text(
                  '🔥 TUMBO',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
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
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('IA', style: TextStyle(fontSize: 11, letterSpacing: 0.5, color: Color(0xFFFCEBEB))),
                        const SizedBox(height: 6),
                        _Garbanzos(piedras: score.piedrasIA, color: const Color(0xFFE3C28A)),
                        const SizedBox(height: 6),
                        Text('${score.piedrasIA} piedras', style: const TextStyle(fontSize: 9, color: Color(0xFFF7C1C1))),
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
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${score.chicosIA} - ${score.chicosTu}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 2),
                      const Text('chicos', style: TextStyle(fontSize: 8, color: Color(0xFFB4B2A9))),
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
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('TÚ', style: TextStyle(fontSize: 11, letterSpacing: 0.5, color: Color(0xFFE6F1FB))),
                        const SizedBox(height: 6),
                        _Garbanzos(piedras: score.piedrasTu, color: const Color(0xFFE3C28A)),
                        const SizedBox(height: 6),
                        Text('${score.piedrasTu} piedras', style: const TextStyle(fontSize: 9, color: Color(0xFFB5D4F4))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('IA ${quienReparte == "ia" ? "🃏" : ""}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _PilaGanada(cantidad: pilaGanadaIA.length, label: 'IA ganó'),
                const SizedBox(width: 50),
                _AbanicoCartas(
                  anchoCarta: 78,
                  altoCarta: 108,
                  solapamiento: 35,
                  cartas: ia.hand
                      .map((c) => CardWidget(card: c, faceDown: true))
                      .toList(),
                ),
              ],
            ),
            const SizedBox(height: 36),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  children: [
                    const SizedBox(height: 6),
                    CardWidget(card: cartaVirada, width: 102, height: 162),
                  ],
                ),
                const SizedBox(width: 10),
                Column(
                  children: [
                    const SizedBox(height: 6),
                    _cartaDe('ia') != null
                        ? CardWidget(card: _cartaDe('ia')!, width: 102, height: 162)
                        : const SizedBox(width: 102, height: 162),
                  ],
                ),
                const SizedBox(width: 10),
                Column(
                  children: [
                    const SizedBox(height: 6),
                    _cartaDe('tu') != null
                        ? CardWidget(card: _cartaDe('tu')!, width: 102, height: 162)
                        : const SizedBox(width: 102, height: 162),
                  ],
                ),
              ],
            ),

            if (equipoDecidiendoTumbo == 'tu') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade900,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      '🔥 ¡TUMBO! Decide:',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          onPressed: () => _decidirTumbo(true),
                          child: const Text('JUGAR (vale 3)'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                          onPressed: () => _decidirTumbo(false),
                          child: const Text('RETIRARSE'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],


            const SizedBox(height: 12),
            Text(
              '${apuesta.valorActual} piedras',
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 14),
            ),

            if (!enTumbo) ...[
              if (envitePropuestoPorIA) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: () => _responderEnviteIA(true),
                      child: const Text('JUEGA'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => _responderEnviteIA(false),
                      child: const Text('PASO'),
                    ),
                    if (apuesta.nivelIndex + 2 < ApuestaModel.nombres.length)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                        onPressed: () => _responderEnviteIA(true, subir: true),
                        child: Text(ApuestaModel.nombres[apuesta.nivelIndex + 2].toUpperCase()),
                      ),
                  ],
                ),
              ] else if (!apuesta.esMaximo && (turnoDeApuesta == null || turnoDeApuesta == 'tu')) ...[
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _lanzarEnvite,
                  child: Text(apuesta.proximoNombre.toUpperCase()),
                ),
              ],
            ],

            if (mensaje != null) ...[
              const SizedBox(height: 12),
              Text(mensaje!, style: const TextStyle(color: Colors.greenAccent)),
            ],

            const SizedBox(height: 24),
            Text('Tú ${quienReparte == "tu" ? "🃏" : ""}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _AbanicoCartas(
                  anchoCarta: 78,
                  altoCarta: 108,
                  solapamiento: 35,
                  cartas: tu.hand.map((c) {
                    final esValida = !envitePropuestoPorIA &&
                        cartasValidas.contains(c) &&
                        (quienSaca == 'tu' || bazaActual.length == 1);
                    return GestureDetector(
                      onTap: esValida ? () => _jugarCartaTu(c) : null,
                      child: Opacity(
                        opacity: esValida ? 1.0 : 0.4,
                        child: CardWidget(card: c),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(width: 50),
                _PilaGanada(cantidad: pilaGanadaTu.length, label: 'Ganaste'),
              ],
            ),
          ],
        ),
        ),
          ),
          if (_repartiendo)
            _AnimacionReparto(
              quienReparte: quienReparte,
              onCompleta: () {
                if (mounted) setState(() => _repartiendo = false);
              },
            ),
        ],
      ),
    );
  }
}

class _AnimacionReparto extends StatefulWidget {
  final String quienReparte; // 'tu' o 'ia'
  final VoidCallback onCompleta;

  const _AnimacionReparto({
    required this.quienReparte,
    required this.onCompleta,
  });

  @override
  State<_AnimacionReparto> createState() => _AnimacionRepartoState();
}

class _AnimacionRepartoState extends State<_AnimacionReparto>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  // 7 cartas: 3 a la IA, 3 a ti, 1 virada
  static const int totalCartas = 7;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _controller.forward().whenComplete(widget.onCompleta);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Punto de origen (mazo): lado del que reparte.
    final origen = widget.quienReparte == 'ia'
        ? Offset(size.width / 2, size.height * 0.18)
        : Offset(size.width / 2, size.height * 0.82);

    // Destinos: zona IA (arriba), zona tú (abajo), centro (virada).
    final destinos = <Offset>[
      Offset(size.width * 0.5, size.height * 0.20), // IA 1
      Offset(size.width * 0.5, size.height * 0.20), // IA 2
      Offset(size.width * 0.5, size.height * 0.20), // IA 3
      Offset(size.width * 0.5, size.height * 0.80), // Tú 1
      Offset(size.width * 0.5, size.height * 0.80), // Tú 2
      Offset(size.width * 0.5, size.height * 0.80), // Tú 3
      Offset(size.width * 0.5, size.height * 0.50), // Virada (centro)
    ];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: List.generate(totalCartas, (i) {
            // Cada carta arranca su viaje un poco después que la anterior.
            final inicio = i / totalCartas * 0.6;
            final fin = inicio + 0.4;
            final t = ((_controller.value - inicio) / (fin - inicio)).clamp(0.0, 1.0);

            final pos = Offset.lerp(origen, destinos[i], Curves.easeOut.transform(t))!;
            final visible = t > 0;

            return Positioned(
              left: pos.dx - 28,
              top: pos.dy - 40,
              child: Opacity(
                opacity: visible ? 1.0 : 0.0,
                child: Container(
                  width: 56,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white24, width: 1),
                    image: const DecorationImage(
                      image: AssetImage('assets/cards/trasera.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class DialogoFinMano extends StatelessWidget {
  final bool gano;
  final bool huboChico;
  final bool finPartida;
  final int piedrasSumadas;
  final int chicosTu;
  final int chicosIA;
  final bool ganadorEsTu;
  final VoidCallback onContinuar;
  final VoidCallback? onSalir;

  const DialogoFinMano({
    super.key,
    required this.gano,
    required this.huboChico,
    required this.finPartida,
    required this.piedrasSumadas,
    required this.chicosTu,
    required this.chicosIA,
    required this.ganadorEsTu,
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
            if (finPartida) ..._contenidoPartida() else if (huboChico) ..._contenidoChico() else ..._contenidoMano(),
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
        gano ? '¡GANASTE LA MANO!' : 'LA IA GANÓ LA MANO',
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
        gano ? 'Sumas' : 'La IA suma',
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
        ganadorEsTu ? 'Te llevas el chico completo' : 'La IA se lleva el chico',
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
        'Tú $chicosTu  ·  IA $chicosIA',
        style: const TextStyle(fontSize: 12, color: Color(0xFF6B5424)),
      ),
    ];
  }

  List<Widget> _contenidoPartida() {
    return [
      const Text('🏅', style: TextStyle(fontSize: 38)),
      const SizedBox(height: 6),
      Text(
        ganadorEsTu ? '¡GANASTE LA PARTIDA!' : 'LA IA GANÓ LA PARTIDA',
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
        'Chicos -> Tú $chicosTu  ·  IA $chicosIA',
        style: const TextStyle(fontSize: 13, color: Color(0xFF6B5424)),
      ),
    ];
  }
}
