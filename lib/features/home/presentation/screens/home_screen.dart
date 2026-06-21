import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../game/presentation/screens/game_screen_wrapper.dart';
import '../../../how_to_play/presentation/screens/how_to_play_screen.dart';
import '../../../options/presentation/screens/options_screen.dart';
import '../../../../core/settings/app_settings.dart';

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

  Future<void> _irAJugar() async {
    await _player.stop();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GameScreenWrapper()),
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
                    onTap: _irAJugar,
                  ),
                  const SizedBox(height: 14),
                  _ImageButton(
                    asset: 'assets/ui/boton_multijugador.jpg',
                    onTap: null,
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
