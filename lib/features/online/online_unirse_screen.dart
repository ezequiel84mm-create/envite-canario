import 'package:flutter/material.dart';
import '../sala/presentation/screens/sala_screen.dart';

/// Pantalla para unirse a una sala ONLINE tecleando el código del anfitrión.
class OnlineUnirseScreen extends StatefulWidget {
  const OnlineUnirseScreen({super.key});

  @override
  State<OnlineUnirseScreen> createState() => _OnlineUnirseScreenState();
}

class _OnlineUnirseScreenState extends State<OnlineUnirseScreen> {
  final TextEditingController _ctrl = TextEditingController();

  void _unirse() {
    final codigo = _ctrl.text.trim().toUpperCase();
    if (codigo.length < 4) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SalaScreen(
          soyAnfitrion: false,
          online: true,
          ipAnfitrion: codigo,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A120A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Escribe el codigo de la sala',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _ctrl,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                maxLength: 4,
                style: const TextStyle(
                    color: Color(0xFFEFAF1F),
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8),
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: 'ABCD',
                  hintStyle: TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.black38,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _unirse,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEFAF1F), Color(0xFFC8870F)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'UNIRSE',
                      style: TextStyle(
                          color: Color(0xFF3A2B12),
                          fontWeight: FontWeight.bold,
                          fontSize: 17),
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
