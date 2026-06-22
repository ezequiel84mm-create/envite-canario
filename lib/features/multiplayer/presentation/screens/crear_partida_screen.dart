import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../network/conexion_p2p.dart';

/// Pantalla del ANFITRIÓN: crea la partida, muestra el código (IP local)
/// como texto y como QR, y espera a que el invitado se conecte.
class CrearPartidaScreen extends StatefulWidget {
  const CrearPartidaScreen({super.key});

  @override
  State<CrearPartidaScreen> createState() => _CrearPartidaScreenState();
}

class _CrearPartidaScreenState extends State<CrearPartidaScreen> {
  final ConexionP2P _conexion = ConexionP2P();
  String? _codigo;
  bool _conectado = false;
  String _estado = 'Preparando...';

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    _conexion.alConectar = () {
      if (!mounted) return;
      setState(() {
        _conectado = true;
        _estado = '¡Jugador conectado!';
      });
    };
    _conexion.alDesconectar = () {
      if (!mounted) return;
      setState(() {
        _conectado = false;
        _estado = 'El otro jugador se desconectó.';
      });
    };

    final ip = await _conexion.crearComoAnfitrion();
    if (!mounted) return;
    setState(() {
      if (ip != null) {
        _codigo = ip;
        _estado = 'Esperando al otro jugador...';
      } else {
        _estado = 'No se pudo crear la partida.\n¿Estás conectado a una red wifi?';
      }
    });
  }

  void _copiarCodigo() {
    if (_codigo == null) return;
    Clipboard.setData(ClipboardData(text: _codigo!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código copiado'), duration: Duration(seconds: 1)),
    );
  }

  @override
  void dispose() {
    _conexion.cerrar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      appBar: AppBar(
        title: const Text('Crear partida'),
        backgroundColor: Colors.black54,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'El otro jugador puede escanear este QR\no escribir el código:',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 20),
              // El QR (solo si hay código)
              if (_codigo != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: QrImageView(
                    data: _codigo!,
                    size: 180,
                    backgroundColor: Colors.white,
                  ),
                ),
              const SizedBox(height: 20),
              // El código en texto
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEFAF1F), width: 1.5),
                ),
                child: Text(
                  _codigo ?? '...',
                  style: const TextStyle(
                    color: Color(0xFFEFAF1F),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_codigo != null)
                ElevatedButton.icon(
                  onPressed: _copiarCodigo,
                  icon: const Icon(Icons.copy, size: 18),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEFAF1F),
                    foregroundColor: const Color(0xFF3A2B12),
                  ),
                  label: const Text('Copiar código'),
                ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_conectado)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                    ),
                  if (!_conectado) const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      _estado,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _conectado ? Colors.lightGreenAccent : Colors.white,
                        fontSize: 16,
                        fontWeight: _conectado ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_conectado)
                ElevatedButton(
                  onPressed: () {
                    // TODO: empezar la partida 1vs1
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  ),
                  child: const Text('Empezar partida'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
