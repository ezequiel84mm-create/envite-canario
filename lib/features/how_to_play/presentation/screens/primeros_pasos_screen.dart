import 'package:flutter/material.dart';

/// Pantalla que muestra la infografía "Cómo empezar" (pergamino)
/// con una animación sencilla de desenrollado (revela de arriba a abajo).
class PrimerosPasosScreen extends StatefulWidget {
  const PrimerosPasosScreen({super.key});

  @override
  State<PrimerosPasosScreen> createState() => _PrimerosPasosScreenState();
}

class _PrimerosPasosScreenState extends State<PrimerosPasosScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _desenrollado;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _desenrollado = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    // Pequeño retardo para que se vea el gesto de despliegue al entrar
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2A1E0E),
      body: SafeArea(
        child: Stack(
          children: [
            // Pergamino centrado que se desenrolla de arriba a abajo
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 60),
                  child: AnimatedBuilder(
                    animation: _desenrollado,
                    builder: (context, child) {
                      return ClipRect(
                        child: Align(
                          alignment: Alignment.topCenter,
                          heightFactor: _desenrollado.value.clamp(0.001, 1.0),
                          child: child,
                        ),
                      );
                    },
                    child: Image.asset(
                      'assets/pergamino/como_empezar.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            // Botón de cerrar arriba a la izquierda (fijo, por encima del scroll)
            Positioned(
              top: 8,
              left: 8,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 26),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
