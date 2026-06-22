import 'package:flutter/material.dart';

/// Pantalla provisional para el 1vs1 por wifi.
/// Aquí construiremos "Crear partida" / "Unirse a partida".
class Online1v1LobbyScreen extends StatelessWidget {
  const Online1v1LobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      appBar: AppBar(
        title: const Text('1 vs 1 (en construcción)'),
        backgroundColor: Colors.black54,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aquí irá "Crear partida" y "Unirse a partida".\n\nLo construiremos en los próximos pasos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      ),
    );
  }
}
