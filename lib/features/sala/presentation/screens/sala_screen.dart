import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../domain/models/estado_sala.dart';
import '../../domain/models/asiento.dart';
import '../../domain/models/jugador_sala.dart';
import '../../network/conexion_sala.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../multiplayer/presentation/screens/game_multi_screen.dart';

/// Pantalla de SALA (lobby) del modo multijugador.
/// El anfitrión abre la red y muestra el QR; los invitados se conectan.
class SalaScreen extends StatefulWidget {
  final bool soyAnfitrion;
  const SalaScreen({super.key, this.soyAnfitrion = true});

  @override
  State<SalaScreen> createState() => _SalaScreenState();
}

class _SalaScreenState extends State<SalaScreen> {
  late EstadoSala _sala;
  final ConexionSala _conexion = ConexionSala();
  String? _ip; // IP del anfitrión (para el QR)
  String _estado = '';

  @override
  void initState() {
    super.initState();
    _sala = EstadoSala.vacia('anfitrion');
    if (widget.soyAnfitrion) {
      _iniciarComoAnfitrion();
    }
  }

  Future<void> _iniciarComoAnfitrion() async {
    // El anfitrión se sienta en el asiento 0 con su alias.
    _sala.asientos[0].ocupante = JugadorSala(
      id: 'anfitrion',
      apodo: AppSettings.instance.alias,
    );
    setState(() => _estado = 'Abriendo sala...');

    final ip = await _conexion.crearSala();
    if (!mounted) return;
    setState(() {
      if (ip != null) {
        _ip = ip;
        _estado = 'Esperando jugadores...';
      } else {
        _estado = 'No se pudo abrir la sala.\n¿Estás en una red wifi?';
      }
    });
  }

  @override
  void dispose() {
    _conexion.cerrar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1208),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/ui/mesa_sala.png', fit: BoxFit.cover),
          ),
          SafeArea(
            child: Column(
              children: [
                _barraSuperior(context),
                Expanded(child: _mesaConAsientos()),
                _barraInferior(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _barraSuperior(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Center(
            child: Text(
              'SALA',
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
                child: const Icon(Icons.chevron_left,
                    color: Colors.white, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mesaConAsientos() {
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        final w = c.maxWidth;
        final asientosIzq = [0, 2, 4, 6];
        final asientosDer = [1, 3, 5, 7];

        return Stack(
          children: [
            Center(child: _qrCentral()),
            for (int i = 0; i < 4; i++)
              Positioned(
                left: w * 0.04,
                top: h * (0.10 + i * 0.21),
                child: _fichaAsiento(_sala.asientos[asientosIzq[i]]),
              ),
            for (int i = 0; i < 4; i++)
              Positioned(
                right: w * 0.04,
                top: h * (0.10 + i * 0.21),
                child: _fichaAsiento(_sala.asientos[asientosDer[i]]),
              ),
          ],
        );
      },
    );
  }

  Widget _fichaAsiento(Asiento asiento) {
    final vacio = asiento.estaVacio;
    final esEquipoA = asiento.equipo == 0;
    final colorEquipo =
        esEquipoA ? const Color(0xFF1565C0) : const Color(0xFFB71C1C);

    return Container(
      width: 92,
      height: 64,
      decoration: BoxDecoration(
        color: vacio ? const Color(0x55000000) : const Color(0xCC2A1A0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: vacio ? const Color(0x55E3C28A) : colorEquipo,
          width: 2,
        ),
      ),
      child: Center(
        child: vacio
            ? const Icon(Icons.event_seat,
                color: Color(0x88E3C28A), size: 26)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    asiento.esIA ? Icons.smart_toy : Icons.person,
                    color: esEquipoA
                        ? const Color(0xFF64B5F6)
                        : const Color(0xFFEF9A9A),
                    size: 22,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    asiento.ocupante!.apodo,
                    style: const TextStyle(
                      color: Color(0xFFF5E6C8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _qrCentral() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5E6C8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF8A6A35), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 130,
            height: 130,
            color: Colors.white,
            child: _ip != null
                ? QrImageView(
                    data: _ip!,
                    size: 130,
                    backgroundColor: Colors.white,
                  )
                : const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'Abriendo\nsala...',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Escanea para unirte',
            style: TextStyle(
              color: Color(0xFF3A2B12),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_ip != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2A1A0A),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _ip!,
                style: const TextStyle(
                  color: Color(0xFFEFAF1F),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _barraInferior() {
    final puede = _sala.sePuedeEmpezar;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_estado.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _estado,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFF5E6C8),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: Colors.black, offset: Offset(0, 1), blurRadius: 3),
                  ],
                ),
              ),
            ),
          GestureDetector(
            onTap: puede
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const GameMultiScreen()),
                    );
                  }
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 40),
              decoration: BoxDecoration(
                gradient: puede
                    ? const LinearGradient(
                        colors: [Color(0xFFEFAF1F), Color(0xFFC8870F)],
                      )
                    : null,
                color: puede ? null : const Color(0x55000000),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF8A6A35), width: 1.5),
              ),
              child: Text(
                puede ? 'EMPEZAR' : 'Faltan jugadores',
                style: TextStyle(
                  color:
                      puede ? const Color(0xFF3A2B12) : const Color(0x88F5E6C8),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
