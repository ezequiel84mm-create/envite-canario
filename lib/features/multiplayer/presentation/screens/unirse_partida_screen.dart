import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../network/conexion_p2p.dart';

/// Pantalla del INVITADO: escanea el QR del anfitrión o escribe el código.
class UnirsePartidaScreen extends StatefulWidget {
  const UnirsePartidaScreen({super.key});

  @override
  State<UnirsePartidaScreen> createState() => _UnirsePartidaScreenState();
}

class _UnirsePartidaScreenState extends State<UnirsePartidaScreen> {
  final ConexionP2P _conexion = ConexionP2P();
  final TextEditingController _controlador = TextEditingController();
  bool _conectando = false;
  bool _conectado = false;
  String _estado = '';

  @override
  void dispose() {
    _controlador.dispose();
    if (!_conectado) _conexion.cerrar();
    super.dispose();
  }

  Future<void> _conectarCon(String codigo) async {
    codigo = codigo.trim();
    if (codigo.isEmpty) {
      setState(() => _estado = 'Escribe o escanea el código primero.');
      return;
    }

    setState(() {
      _conectando = true;
      _estado = 'Conectando...';
    });

    _conexion.alDesconectar = () {
      if (!mounted) return;
      setState(() {
        _conectado = false;
        _estado = 'Se perdió la conexión.';
      });
    };

    final ok = await _conexion.unirseComoInvitado(codigo);
    if (!mounted) return;

    setState(() {
      _conectando = false;
      if (ok) {
        _conectado = true;
        _estado = '¡Conectado con el anfitrión!';
      } else {
        _estado = 'No se pudo conectar.\nRevisa el código y que estéis en la misma wifi.';
      }
    });
  }

  Future<void> _escanearQR() async {
    final resultado = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _EscanerQRScreen()),
    );
    if (resultado != null && resultado.isNotEmpty) {
      _controlador.text = resultado;
      _conectarCon(resultado);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      appBar: AppBar(
        title: const Text('Unirse a partida'),
        backgroundColor: Colors.black54,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Botón escanear QR (lo principal)
              if (!_conectado)
                ElevatedButton.icon(
                  onPressed: _conectando ? null : _escanearQR,
                  icon: const Icon(Icons.qr_code_scanner, size: 24),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEFAF1F),
                    foregroundColor: const Color(0xFF3A2B12),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                  ),
                  label: const Text('Escanear QR', style: TextStyle(fontSize: 17)),
                ),
              const SizedBox(height: 24),
              if (!_conectado)
                const Text('— o escribe el código —',
                    style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 16),
              if (!_conectado)
                TextField(
                  controller: _controlador,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'Ej: 192.168.1.42',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 15),
                    filled: true,
                    fillColor: Colors.black38,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEFAF1F), width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEFAF1F), width: 2),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              if (!_conectado)
                ElevatedButton(
                  onPressed: _conectando ? null : () => _conectarCon(_controlador.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black38,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
                  ),
                  child: Text(_conectando ? 'Conectando...' : 'Conectar con código'),
                ),
              const SizedBox(height: 24),
              if (_estado.isNotEmpty)
                Text(
                  _estado,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _conectado ? Colors.lightGreenAccent : Colors.white,
                    fontSize: 16,
                    fontWeight: _conectado ? FontWeight.bold : FontWeight.normal,
                  ),
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
                  child: const Text('Esperando al anfitrión...'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pantalla de escaneo de QR con la cámara.
class _EscanerQRScreen extends StatefulWidget {
  const _EscanerQRScreen();

  @override
  State<_EscanerQRScreen> createState() => _EscanerQRScreenState();
}

class _EscanerQRScreenState extends State<_EscanerQRScreen> {
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
