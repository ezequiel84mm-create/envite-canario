import 'package:flutter/material.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/settings/voces.dart';

class OptionsScreen extends StatefulWidget {
  const OptionsScreen({super.key});

  @override
  State<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends State<OptionsScreen> {
  final settings = AppSettings.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/ui/fondo_opciones.png', fit: BoxFit.cover),
          ),
          // Capa oscura suave para mejorar legibilidad
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.15)),
          ),
          SafeArea(
            child: Column(
              children: [
                // Barra superior: volver + título
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Center(
                        child: Text(
                          'OPCIONES',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: Color(0xFFF5E6C8),
                            shadows: [
                              Shadow(color: Colors.black, offset: Offset(0, 2), blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.chevron_left, color: Colors.white, size: 26),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                // Paneles de opciones
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      _PanelToggle(
                        icono: Icons.music_note,
                        titulo: 'Música',
                        valor: settings.musicaActivada,
                        onCambio: (v) => setState(() => settings.setMusica(v)),
                      ),
                      const SizedBox(height: 14),
                      _PanelToggle(
                        icono: Icons.volume_up,
                        titulo: 'Efectos de sonido',
                        valor: settings.efectosActivados,
                        onCambio: (v) => setState(() => settings.setEfectos(v)),
                      ),
                      const SizedBox(height: 14),
                      _PanelDificultad(
                        valorActual: settings.dificultadIA,
                        onCambio: (v) => setState(() => settings.setDificultad(v)),
                      ),
                      const SizedBox(height: 14),
                      _PanelVoz(
                        titulo: 'Mi voz',
                        icono: Icons.record_voice_over,
                        idActual: settings.vozPropia,
                        onCambio: (id) =>
                            setState(() => settings.setVozPropia(id)),
                      ),
                      const SizedBox(height: 14),
                      _PanelVoz(
                        titulo: 'Voz del rival',
                        icono: Icons.group,
                        idActual: settings.vozRival,
                        onCambio: (id) =>
                            setState(() => settings.setVozRival(id)),
                      ),
                      const SizedBox(height: 14),
                      _PanelBoton(
                        icono: Icons.favorite,
                        titulo: 'Créditos',
                        onTap: () => _mostrarCreditos(context),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarCreditos(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE8D4A8), Color(0xFFDCC290)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF8A6A35), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ENVITE CANARIO',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF9A3A0A),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Un juego tradicional canario\nhecho con cariño.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF3A2B12), height: 1.4),
              ),
              const SizedBox(height: 12),
              const Text(
                'Desarrollo: Ezequiel Mejías',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF6B5424)),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFEFAF1F), Color(0xFFC8870F)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF8A6A35), width: 1.5),
                  ),
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(
                      color: Color(0xFF3A2B12),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelToggle extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final bool valor;
  final ValueChanged<bool> onCambio;

  const _PanelToggle({
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.onCambio,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xCC2A1A0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x66E3C28A), width: 1),
      ),
      child: Row(
        children: [
          Icon(icono, color: const Color(0xFFE3C28A), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              titulo,
              style: const TextStyle(color: Color(0xFFF5E6C8), fontSize: 16),
            ),
          ),
          Switch(
            value: valor,
            onChanged: onCambio,
            activeColor: const Color(0xFFEFAF1F),
            activeTrackColor: const Color(0xFF8A6A35),
          ),
        ],
      ),
    );
  }
}

class _PanelDificultad extends StatelessWidget {
  final int valorActual;
  final ValueChanged<int> onCambio;

  const _PanelDificultad({required this.valorActual, required this.onCambio});

  @override
  Widget build(BuildContext context) {
    final opciones = ['Fácil', 'Normal', 'Difícil'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xCC2A1A0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x66E3C28A), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: Color(0xFFE3C28A), size: 22),
              const SizedBox(width: 12),
              const Text(
                'Dificultad de la IA',
                style: TextStyle(color: Color(0xFFF5E6C8), fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(opciones.length, (i) {
              final seleccionado = i == valorActual;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onCambio(i),
                  child: Container(
                    margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      gradient: seleccionado
                          ? const LinearGradient(
                              colors: [Color(0xFFEFAF1F), Color(0xFFC8870F)],
                            )
                          : null,
                      color: seleccionado ? null : const Color(0x33FFFFFF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: seleccionado
                            ? const Color(0xFF8A6A35)
                            : const Color(0x33E3C28A),
                      ),
                    ),
                    child: Text(
                      opciones[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: seleccionado
                            ? const Color(0xFF3A2B12)
                            : const Color(0xFFF5E6C8),
                        fontWeight:
                            seleccionado ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _PanelBoton extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final VoidCallback onTap;

  const _PanelBoton({
    required this.icono,
    required this.titulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xCC2A1A0A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x66E3C28A), width: 1),
        ),
        child: Row(
          children: [
            Icon(icono, color: const Color(0xFFE3C28A), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(color: Color(0xFFF5E6C8), fontSize: 16),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFE3C28A), size: 22),
          ],
        ),
      ),
    );
  }
}

class _PanelVoz extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final String idActual;
  final ValueChanged<String> onCambio;

  const _PanelVoz({
    required this.titulo,
    required this.icono,
    required this.idActual,
    required this.onCambio,
  });

  @override
  Widget build(BuildContext context) {
    final voces = Voces.disponibles;
    // Indice de la voz actual dentro de la lista.
    var indice = voces.indexWhere((v) => v.id == idActual);
    if (indice < 0) indice = 0;
    final vozActual = voces[indice];

    void cambiar(int paso) {
      final n = voces.length;
      final nuevo = (indice + paso + n) % n; // rota circular
      onCambio(voces[nuevo].id);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xCC2A1A0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x66E3C28A), width: 1),
      ),
      child: Row(
        children: [
          Icon(icono, color: const Color(0xFFE3C28A), size: 22),
          const SizedBox(width: 12),
          Text(
            titulo,
            style: const TextStyle(color: Color(0xFFF5E6C8), fontSize: 16),
          ),
          const Spacer(),
          // Selector con flechas: ‹ Nombre ›
          _Flecha(icono: Icons.chevron_left, onTap: () => cambiar(-1)),
          Container(
            constraints: const BoxConstraints(minWidth: 84),
            alignment: Alignment.center,
            child: Text(
              vozActual.nombre,
              style: const TextStyle(
                color: Color(0xFFEFAF1F),
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _Flecha(icono: Icons.chevron_right, onTap: () => cambiar(1)),
        ],
      ),
    );
  }
}

class _Flecha extends StatelessWidget {
  final IconData icono;
  final VoidCallback onTap;

  const _Flecha({required this.icono, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0x33FFFFFF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x55E3C28A)),
        ),
        child: Icon(icono, color: const Color(0xFFF5E6C8), size: 22),
      ),
    );
  }
}
