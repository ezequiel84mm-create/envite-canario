import 'package:flutter/material.dart';

/// Garbanzos: representación tradicional canaria de las piedras.
class Garbanzos extends StatelessWidget {
  final int piedras;
  final Color color;

  const Garbanzos({super.key, required this.piedras, required this.color});

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
    return SizedBox(
      width: 46,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [_garbanzo(), _garbanzo(), _garbanzo()],
      ),
    );
  }
}

/// Abanico de cartas (las cartas en mano, en forma de abanico).
class AbanicoCartas extends StatelessWidget {
  final List<Widget> cartas;
  final double anchoCarta;
  final double altoCarta;
  final double solapamiento;

  const AbanicoCartas({
    super.key,
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
    final anguloMax = 6.0;
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

/// Pila de cartas ganadas (montón boca abajo).
class PilaGanada extends StatelessWidget {
  final int cantidad;
  final String label;

  const PilaGanada({super.key, required this.cantidad, required this.label});

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
