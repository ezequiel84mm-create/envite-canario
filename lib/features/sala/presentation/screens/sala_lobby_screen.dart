import 'package:flutter/material.dart';
import 'sala_screen.dart';
import 'unirse_sala_screen.dart';

/// Lobby del modo multijugador (sala): elegir Crear o Unirse.
/// Mismo estilo que el lobby del 1vs1.
class SalaLobbyScreen extends StatelessWidget {
  const SalaLobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/ui/fondo_1v1_lobby.png', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x88000000)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Align(
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
                        child: const Icon(Icons.chevron_left, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 30),
                  child: Column(
                    children: [
                      _BotonLobby(
                        texto: 'CREAR SALA',
                        icono: Icons.add_circle_outline,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SalaScreen(soyAnfitrion: true)),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _BotonLobby(
                        texto: 'UNIRSE A SALA',
                        icono: Icons.login,
                        onTap: () {
                          // Lleva a escanear QR / meter codigo (reusa la del 1v1
                          // por ahora; tendra su propia version con la red).
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const UnirseSalaScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.wifi, color: Colors.amber, size: 16),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Todos los jugadores deben estar en la misma red wifi',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonLobby extends StatelessWidget {
  final String texto;
  final IconData icono;
  final VoidCallback onTap;

  const _BotonLobby({
    required this.texto,
    required this.icono,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEFAF1F), Color(0xFFC8870F)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF8A6A35), width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, color: const Color(0xFF3A2B12), size: 22),
            const SizedBox(width: 10),
            Text(
              texto,
              style: const TextStyle(
                color: Color(0xFF3A2B12),
                fontWeight: FontWeight.bold,
                fontSize: 17,
                fontFamily: 'Georgia',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
