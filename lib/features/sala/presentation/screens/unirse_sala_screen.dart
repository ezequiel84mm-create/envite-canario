import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'sala_screen.dart';

/// Pantalla del INVITADO para unirse a una SALA: escanea el QR del
/// anfitrión o escribe su IP, y entra a la sala como invitado.
/// Funciona en iPhone y Android (usa mobile_scanner).
class UnirseSalaScreen extends StatefulWidget {
  const UnirseSalaScreen({super.key});

  @override
  State<UnirseSalaScreen> createState() => _UnirseSalaScreenState();
}

class _UnirseSalaScreenState extends State<UnirseSalaScreen> {
  final TextEditingController _controlador = TextEditingController();

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  void _entrarConIP(String ip) {
    ip = ip.trim();
    if (ip.isEmpty) return;
    // Abrimos la sala como invitado; ella se encarga de conectar.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SalaScreen(soyAnfitrion: false, ipAnfitrion: ip),
      ),
    );
  }

  Future<void> _escanearQR() async {
    final resultado = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _EscanerSalaScreen()),
    );
    if (resultado != null && resultado.isNotEmpty) {
      _entrarConIP(resultado);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      appBar: AppBar(
        title: const Text('Unirse a la sala'),
        backgroundColor: Colors.black54,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _escanearQR,
                icon: const Icon(Icons.qr_code_scanner, size: 24),
                label: const Text('Escanear QR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEFAF1F),
                  foregroundColor: const Color(0xFF3A2B12),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                  textStyle: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'o escribe el código (IP) del anfitrión:',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controlador,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Ej. 192.168.1.42',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black26,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFEFAF1F)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _entrarConIP(_controlador.text),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEFAF1F), Color(0xFFC8870F)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'ENTRAR',
                    style: TextStyle(
                      color: Color(0xFF3A2B12),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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

class _EscanerSalaScreen extends StatefulWidget {
  const _EscanerSalaScreen();

  @override
  State<_EscanerSalaScreen> createState() => _EscanerSalaScreenState();
}

class _EscanerSalaScreenState extends State<_EscanerSalaScreen> {
  bool _yaDetectado = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanea el QR'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: MobileScanner(
        onDetect: (captura) {
          if (_yaDetectado) return;
          final codigos = captura.barcodes;
          if (codigos.isNotEmpty) {
            final valor = codigos.first.rawValue;
            if (valor != null && valor.isNotEmpty) {
              _yaDetectado = true;
              Navigator.pop(context, valor);
            }
          }
        },
      ),
    );
  }
}
