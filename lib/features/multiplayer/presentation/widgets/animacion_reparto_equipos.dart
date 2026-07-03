import 'package:flutter/material.dart';

/// Animacion de reparto para los modos de equipo (2v2/3v3/4v4).
/// Reparte cartas boca abajo desde la posicion del barajador hacia cada
/// asiento (segun su posicion en el circulo) y una carta al centro (vira).
/// Es puramente visual; al terminar llama a onCompleta.
class AnimacionRepartoEquipos extends StatefulWidget {
  final int numJugadores;
  final int posBarajador; // posicion 0..(n-1) en el circulo del que reparte
  final VoidCallback onCompleta;

  const AnimacionRepartoEquipos({
    super.key,
    required this.numJugadores,
    required this.posBarajador,
    required this.onCompleta,
  });

  @override
  State<AnimacionRepartoEquipos> createState() =>
      _AnimacionRepartoEquiposState();
}

class _AnimacionRepartoEquiposState extends State<AnimacionRepartoEquipos>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  // Posiciones (Alignment x,y) de cada posicion del circulo, por modo.
  // Coinciden con el layout real de las cartas jugadas de cada pantalla.
  static const Map<int, List<Alignment>> _posicionesPorModo = {
    4: [ // 2v2: yo (abajo), izq, enfrente (arriba), der
      Alignment(0.0, 1.0),
      Alignment(-1.0, 0.0),
      Alignment(0.0, -1.0),
      Alignment(1.0, 0.0),
    ],
    6: [ // 3v3
      Alignment(0.0, 1.0),
      Alignment(-1.0, 0.55),
      Alignment(-1.0, -0.55),
      Alignment(0.0, -1.0),
      Alignment(1.0, -0.55),
      Alignment(1.0, 0.55),
    ],
    8: [ // 4v4
      Alignment(0.0, 1.0),
      Alignment(-1.0, 0.7),
      Alignment(-1.0, 0.0),
      Alignment(-1.0, -0.7),
      Alignment(0.0, -1.0),
      Alignment(1.0, -0.7),
      Alignment(1.0, 0.0),
      Alignment(1.0, 0.7),
    ],
  };

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
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
    final n = widget.numJugadores;
    final posiciones = _posicionesPorModo[n] ?? _posicionesPorModo[6]!;
    final origenAlign = posiciones[widget.posBarajador % posiciones.length];

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        Offset aOffset(Alignment a) => Offset(
              (a.x + 1) / 2 * w,
              (a.y + 1) / 2 * h,
            );
        final origen = aOffset(origenAlign);

        final destinos = <Offset>[];
        for (int c = 0; c < 3; c++) {
          for (int p = 0; p < n; p++) {
            destinos.add(aOffset(posiciones[p]));
          }
        }
        destinos.add(aOffset(const Alignment(0.0, 0.0))); // vira al centro
        final total = destinos.length;

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              children: List.generate(total, (i) {
                final inicio = i / total * 0.7;
                final fin = inicio + 0.3;
                final t = ((_controller.value - inicio) / (fin - inicio))
                    .clamp(0.0, 1.0);
                final pos =
                    Offset.lerp(origen, destinos[i], Curves.easeOut.transform(t))!;
                final visible = t > 0 && t < 1.0;
                return Positioned(
                  left: pos.dx - 16,
                  top: pos.dy - 23,
                  child: Opacity(
                    opacity: visible ? 1.0 : 0.0,
                    child: Container(
                      width: 32,
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
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
      },
    );
  }
}
