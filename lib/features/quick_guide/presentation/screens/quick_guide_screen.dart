import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../core/settings/music_controller.dart';
import '../../../../core/settings/app_settings.dart';

class QuickGuideScreen extends StatefulWidget {
  const QuickGuideScreen({super.key});

  @override
  State<QuickGuideScreen> createState() => _QuickGuideScreenState();
}

class _QuickGuideScreenState extends State<QuickGuideScreen> {
  final AudioPlayer _player = AudioPlayer();
  static const int totalPaginas = 7;

  int _indice = 0;
  bool _secuenciaTerminada = false; // cuando termina la reproducción automática

  @override
  void initState() {
    super.initState();
    MusicController.instance.pausar();
    // Cuando termina un audio durante la secuencia automática, pasa al siguiente
    _player.onPlayerComplete.listen((_) {
      if (!_secuenciaTerminada) {
        _avanzarEnSecuencia();
      }
    });
    _reproducirActual();
  }

  @override
  void dispose() {
    _player.stop();
    _player.dispose();
    MusicController.instance.reanudar();
    super.dispose();
  }

  void _reproducirActual() {
    _player.stop();
    if (AppSettings.audioBloqueadoEnPlataforma) return; // audio off en Windows
    _player.play(AssetSource('guia/manologuiapag$_indice.mp3'));
  }

  void _avanzarEnSecuencia() {
    if (_indice < totalPaginas - 1) {
      setState(() => _indice++);
      _reproducirActual();
    } else {
      // Era la última: termina la secuencia automática
      setState(() => _secuenciaTerminada = true);
    }
  }

  void _irAtras() {
    _secuenciaTerminada = true; // navegación manual: corta la reproducción automática
    _player.stop();
    if (_indice > 0) {
      setState(() => _indice--);
    } else {
      // En la primera imagen, atrás vuelve a la pantalla anterior (Cómo jugar)
      Navigator.pop(context);
    }
  }

  void _irAdelante() {
    _secuenciaTerminada = true; // navegación manual: corta la reproducción automática
    _player.stop();
    if (_indice < totalPaginas - 1) {
      setState(() => _indice++);
    }
  }

  void _reproducirManual() {
    _secuenciaTerminada = true; // al reproducir a mano, ya no avanza sola
    _player.stop();
    if (AppSettings.audioBloqueadoEnPlataforma) return; // audio off en Windows
    _player.play(AssetSource('guia/manologuiapag$_indice.mp3'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Imagen actual a pantalla completa
          Positioned.fill(
            child: Image.asset(
              'assets/guia/guia${_indice + 1}.png',
              fit: BoxFit.contain,
            ),
          ),
          // Botón volver siempre visible arriba a la izquierda
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Align(
                alignment: Alignment.topLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          ),
          // Indicador de página (puntitos) abajo
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Controles siempre visibles: se puede navegar adelante y
                    // atrás desde que se abre la guía, sin tener que escucharla
                    // entera. La reproducción automática se corta al navegar.
                    Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _BotonCircular(
                              icono: Icons.chevron_left,
                              onTap: _irAtras,
                            ),
                            const SizedBox(width: 20),
                            _BotonCircular(
                              icono: Icons.play_arrow,
                              onTap: _reproducirManual,
                              destacado: true,
                            ),
                            const SizedBox(width: 20),
                            _BotonCircular(
                              icono: Icons.chevron_right,
                              onTap: _indice < totalPaginas - 1 ? _irAdelante : null,
                            ),
                          ],
                        ),
                      ),
                    // Puntitos indicadores
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(totalPaginas, (i) {
                        final activo = i == _indice;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: activo ? 11 : 8,
                          height: activo ? 11 : 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: activo
                                ? const Color(0xFFEFAF1F)
                                : Colors.white54,
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonCircular extends StatelessWidget {
  final IconData icono;
  final VoidCallback? onTap;
  final bool destacado;

  const _BotonCircular({
    required this.icono,
    required this.onTap,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    final habilitado = onTap != null;
    return Opacity(
      opacity: habilitado ? 1.0 : 0.35,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: destacado ? 58 : 48,
          height: destacado ? 58 : 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: destacado
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFEFAF1F), Color(0xFFC8870F)],
                  )
                : null,
            color: destacado ? null : Colors.black54,
            border: Border.all(
              color: const Color(0xFF8A6A35),
              width: 1.5,
            ),
          ),
          child: Icon(
            icono,
            color: destacado ? const Color(0xFF3A2B12) : Colors.white,
            size: destacado ? 32 : 28,
          ),
        ),
      ),
    );
  }
}
