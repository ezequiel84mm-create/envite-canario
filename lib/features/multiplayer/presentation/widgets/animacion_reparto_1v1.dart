import 'package:flutter/material.dart';

/// Animación visual simple para el reparto en 1vs1.
/// Recorre cartas desde el centro hacia la zona del rival, la zona propia y
/// la vira central.
class AnimacionReparto1v1 extends StatefulWidget {
  final VoidCallback onCompleta;

  const AnimacionReparto1v1({
    super.key,
    required this.onCompleta,
  });

  @override
  State<AnimacionReparto1v1> createState() => _AnimacionReparto1v1State();
}

class _AnimacionReparto1v1State extends State<AnimacionReparto1v1>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

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
    final origen = Offset(size.width / 2, size.height / 2);
    final destinos = <Offset>[
      Offset(size.width * 0.5, size.height * 0.18),
      Offset(size.width * 0.5, size.height * 0.18),
      Offset(size.width * 0.5, size.height * 0.18),
      Offset(size.width * 0.5, size.height * 0.82),
      Offset(size.width * 0.5, size.height * 0.82),
      Offset(size.width * 0.5, size.height * 0.82),
      Offset(size.width * 0.5, size.height * 0.5),
    ];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: List.generate(destinos.length, (i) {
            final inicio = i / destinos.length * 0.7;
            final fin = inicio + 0.3;
            final t = ((_controller.value - inicio) / (fin - inicio))
                .clamp(0.0, 1.0);

            final pos = Offset.lerp(origen, destinos[i], Curves.easeOut.transform(t))!;
            final visible = t > 0 && t < 1.0;

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
