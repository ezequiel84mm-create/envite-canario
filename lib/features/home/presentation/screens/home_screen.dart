import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../game/presentation/screens/game_screen_wrapper.dart';
import '../../../how_to_play/presentation/screens/how_to_play_screen.dart';
import '../../../options/presentation/screens/options_screen.dart';
import '../../../multiplayer/presentation/screens/game_2v2_screen.dart';
import '../../../multiplayer/presentation/screens/online_1v1_lobby_screen.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/settings/music_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _silenciado = false;

  @override
  void initState() {
    super.initState();
    _player.setReleaseMode(ReleaseMode.loop);
    MusicController.instance.registrar(
      _player,
      () => AppSettings.instance.musicaActivada && !_silenciado,
    );
    if (AppSettings.instance.musicaActivada) {
      _player.play(AssetSource('audio/musica_inicio.mp3'));
      _silenciado = false;
    } else {
      _silenciado = true;
    }
  }

  @override
  void dispose() {
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  void _toggleSilencio() {
    setState(() {
      _silenciado = !_silenciado;
    });
    if (_silenciado) {
      _player.pause();
    } else {
      _player.resume();
    }
  }

  void _reanudarMusica() {
    if (!mounted) return;
    if (AppSettings.instance.musicaActivada && !_silenciado) {
      _player.resume();
    }
  }

  // Abre el juego clasico contra la IA (lo que antes hacia JUGAR).
  Future<void> _irA1vsIA() async {
    Navigator.pop(context); // cierra el panel flotante
    await _player.stop();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GameScreenWrapper()),
    );
    _reanudarMusica();
  }

  // Abre la pantalla (provisional) del 1vs1 por wifi.
  void _irA1vs1() {
    Navigator.pop(context); // cierra el panel flotante
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const Online1v1LobbyScreen()),
    );
  }

  // Muestra el panel flotante con las dos opciones de juego.
  void _mostrarPanelJugar() {
    showDialog(
      context: context,
      barrierColor: Colors.black54, // fondo atenuado
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context), // tocar fuera cierra
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: GestureDetector(
              onTap: () {}, // evita que tocar el panel lo cierre
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 50),
                padding: const EdgeInsets.all(20),
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
                      'ELIGE MODO',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9A3A0A),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _BotonPanelImg(
                        asset: 'assets/ui/boton_1vsia.jpg', onTap: _irA1vsIA),
                    const SizedBox(height: 12),
                    _BotonPanelImg(
                        asset: 'assets/ui/boton_1vs1.jpg', onTap: _irA1vs1),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/ui/fondo_inicio.jpg',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: GestureDetector(
                onTap: _toggleSilencio,
                child: Container(
                  margin: const EdgeInsets.only(left: 4, top: 4),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _silenciado ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(58, 4, 58, 20),
              child: Column(
                children: [
                  const Spacer(flex: 7),
                  _ImageButton(
                    asset: 'assets/ui/boton_jugar.jpg',
                    onTap: _mostrarPanelJugar,
                  ),
                  const SizedBox(height: 14),
                  _ImageButton(
                    asset: 'assets/ui/boton_multijugador.jpg',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const Game2v2Screen()),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _ImageButton(
                    asset: 'assets/ui/boton_como_jugar.jpg',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HowToPlayScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _ImageButton(
                    asset: 'assets/ui/boton_opciones.jpg',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OptionsScreen()),
                      ).then((_) => setState(() {}));
                    },
                  ),
                  const SizedBox(height: 14),
                  _ImageButton(
                    asset: 'assets/ui/boton_salir.jpg',
                    onTap: () {
                      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
                        exit(0);
                      } else {
                        SystemNavigator.pop();
                      }
                    },
                  ),
                  const Spacer(flex: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonPanelImg extends StatelessWidget {
  final String asset;
  final VoidCallback onTap;

  const _BotonPanelImg({required this.asset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(asset, fit: BoxFit.fill),
        ),
      ),
    );
  }
}

class _ImageButton extends StatelessWidget {
  final String asset;
  final VoidCallback? onTap;

  const _ImageButton({required this.asset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final habilitado = onTap != null;

    return Opacity(
      opacity: habilitado ? 1.0 : 0.45,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          height: 53,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(asset, fit: BoxFit.fill),
          ),
        ),
      ),
    );
  }
}
