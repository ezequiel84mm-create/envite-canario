import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/models/senas.dart';

/// Botón redondo de señas que, al pulsarlo, despliega los 10 iconos en una
/// rueda radial alrededor. Al tocar un icono se envía esa seña.
///
/// El orden de la rueda (empezando ARRIBA y girando a la derecha) es:
/// full, tresbastos(nariz), caballo, perica, malilla, rey, mordido, menores,
/// ciego, envido, silbido. Las señas que no aplican al modo se muestran como
/// hueco vacío (invisibles) para no descolocar la rueda.
class RuedaSenas extends StatefulWidget {
  final int numJugadores;              // 4=2v2, 6=3v3, 8=4v4
  final void Function(Sena sena) onEnviar;

  const RuedaSenas({
    super.key,
    required this.numJugadores,
    required this.onEnviar,
  });

  @override
  State<RuedaSenas> createState() => _RuedaSenasState();
}

class _RuedaSenasState extends State<RuedaSenas>
    with SingleTickerProviderStateMixin {
  bool _abierta = false;
  late final AnimationController _ctrl;

  // Orden de la rueda pedido por el usuario (12 en punto, hacia la derecha).
  static const List<String> _ordenRueda = [
    'flus',       // Full (pez) - arriba
    'tresbastos', // nariz
    'caballo',
    'perica',
    'malilla',
    'rey',
    'mordido',    // dos triunfos menores (morderse el labio)
    'menores',    // triunfos menores (chasquido)
    'ciego',
    'envido',
    'silbido',    // último
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _abierta = !_abierta);
    if (_abierta) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  void _elegir(Sena s) {
    widget.onEnviar(s);
    _toggle(); // cerrar tras enviar
  }

  @override
  Widget build(BuildContext context) {
    // Señas en orden, resolviendo cada id.
    final senas = _ordenRueda.map((id) => senaPorId(id)).toList();
    const radio = 96.0; // distancia del centro a cada icono

    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Los 10 iconos en círculo (solo cuando está abierta).
          for (int i = 0; i < senas.length; i++)
            _iconoEnCirculo(senas[i], i, senas.length, radio),
          // Botón central.
          _botonCentral(),
        ],
      ),
    );
  }

  Widget _iconoEnCirculo(Sena? s, int i, int total, double radio) {
    // Ángulo: empezamos ARRIBA (-90º) y giramos a la derecha (horario).
    final ang = (-math.pi / 2) + (2 * math.pi * i / total);
    final aplica = s != null && s.aplicaEn(widget.numJugadores);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = Curves.easeOutBack.transform(_ctrl.value.clamp(0.0, 1.0));
        final dx = math.cos(ang) * radio * t;
        final dy = math.sin(ang) * radio * t;
        return Transform.translate(
          offset: Offset(dx, dy),
          child: Opacity(
            opacity: _ctrl.value,
            child: child,
          ),
        );
      },
      // Si no aplica al modo, hueco invisible (mantiene el espacio).
      child: aplica
          ? _fichaIcono(s)
          : const SizedBox(width: 46, height: 46),
    );
  }

  Widget _fichaIcono(Sena s) {
    return GestureDetector(
      onTap: _abierta ? () => _elegir(s) : null,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(s.emoji, style: const TextStyle(fontSize: 26)),
      ),
    );
  }

  Widget _botonCentral() {
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: _abierta ? Colors.red.shade700 : Colors.green.shade800,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          _abierta ? Icons.close : Icons.emoji_emotions,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}
