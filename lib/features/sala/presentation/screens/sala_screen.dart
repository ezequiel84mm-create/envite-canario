import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../domain/models/estado_sala.dart';
import '../../domain/models/config_partida.dart';
import '../../domain/models/asiento.dart';
import '../../domain/models/jugador_sala.dart';
import '../../network/conexion_sala.dart';
import '../../network/transporte_sala.dart';
import '../../../online/conexion_sala_online.dart';
import '../../network/mensajes_sala.dart';
import '../../../multiplayer/network/mensajes_red.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../multiplayer/presentation/screens/game_2v2_screen.dart';
import '../../../multiplayer/presentation/screens/game_3v3_screen.dart';
import '../../../multiplayer/presentation/screens/game_4v4_screen.dart';

/// Pantalla de SALA (lobby) del modo multijugador.
/// El anfitrión abre la red y muestra el QR; los invitados se conectan.
class SalaScreen extends StatefulWidget {
  final bool soyAnfitrion;
  final String? ipAnfitrion; // solo para invitado: IP a la que conectarse
  final bool online; // true = internet (Firebase); false = wifi
  const SalaScreen({super.key, this.soyAnfitrion = true, this.ipAnfitrion, this.online = false});

  @override
  State<SalaScreen> createState() => _SalaScreenState();
}

class _SalaScreenState extends State<SalaScreen> {
  late EstadoSala _sala;
  late final TransporteSala _conexion = widget.online ? ConexionSalaOnline() : ConexionSala();
  String? _ip; // IP del anfitrión (para el QR)
  String _miIdInvitado = ''; // solo invitado: su id asignado por el anfitrión
  bool _yendoAlJuego = false; // si true, el dispose NO cierra la conexión
  String _estado = '';
  int? _asientoSeleccionado; // anfitrión: asiento "cogido" para intercambiar

  @override
  void initState() {
    super.initState();
    _sala = EstadoSala.vacia('anfitrion');
    if (widget.soyAnfitrion) {
      _configurarCallbacksAnfitrion();
      _iniciarComoAnfitrion();
    } else {
      _configurarCallbacksInvitado();
      _iniciarComoInvitado();
    }
  }

  // ===== ANFITRIÓN: callbacks de red =====
  void _configurarCallbacksAnfitrion() {
    _conexion.alConectarInvitado = (idInvitado) {};
    _conexion.alRecibirDeInvitado = (idInvitado, texto) {
      final msg = MensajeRed.decodificar(texto);
      if (msg == null) return;
      if (msg.tipo == TipoMensajeSala.hola) {
        final alias = msg.datos['alias'] ?? 'Jugador';
        _sentarInvitado(idInvitado, alias);
      } else if (msg.tipo == TipoMensajeSala.elegirAsiento) {
        final numero = msg.datos['asiento'] ?? -1;
        _moverInvitado(idInvitado, numero);
      } else if (msg.tipo == TipoMensajeSala.toggleListo) {
        final idJugador = msg.datos['id'] ?? '';
        _cambiarListo(idJugador);
      }
    };
    _conexion.alDesconectarInvitado = (idInvitado) {
      _quitarJugador(idInvitado);
    };
  }

  // Devuelve un alias que no choque con los ya sentados. Si 'Juan' existe,
  // prueba 'Juan 2', 'Juan 3', etc.
  String _aliasUnico(String base) {
    final ocupados = _sala.asientos
        .where((a) => !a.estaVacio)
        .map((a) => a.ocupante!.apodo)
        .toSet();
    if (!ocupados.contains(base)) return base;
    int n = 2;
    while (ocupados.contains('$base $n')) {
      n++;
    }
    return '$base $n';
  }

  void _sentarInvitado(String idInvitado, String alias) {
    if (_sala.asientoDe(idInvitado) != null) return;
    // Orden obligatorio: siempre al primer asiento libre (el más bajo).
    final numeroLibre = _primerAsientoLibre();
    if (numeroLibre == null) return; // mesa llena
    final libre = _sala.asientos[numeroLibre];
    libre.ocupante = JugadorSala(
      id: idInvitado,
      apodo: _aliasUnico(alias),
      listo: true, // listo automatico al sentarse (sin paso manual)
    );
    // Le decimos al invitado cuál es su id (para que sepa quién es).
    _conexion.enviarA(idInvitado, MensajeRed(
      TipoMensajeSala.tuId,
      {'id': idInvitado},
    ).codificar());
    setState(() => _estado = 'Esperando jugadores...');
    _repartirEstadoSala();
  }

  // El orden de asientos es obligatorio (relleno automático en zigzag), así
  // que ya no se permite que un invitado se mueva a mano. Se ignora para no
  // dejar huecos que rompan la mesa. Se conserva por compatibilidad con
  // clientes que aún manden el mensaje 'elegirAsiento'.
  void _moverInvitado(String idInvitado, int numero) {
    return;
  }

  void _quitarJugador(String idInvitado) {
    final a = _sala.asientoDe(idInvitado);
    if (a != null) {
      a.ocupante = null;
      _asientoSeleccionado = null; // la disposición cambia: cancela selección
      _compactarAsientos(); // cierra el hueco: la mesa nunca queda rota
      setState(() {});
      _repartirEstadoSala();
    }
  }

  void _cambiarListo(String idJugador) {
    final asiento = _sala.asientoDe(idJugador);
    if (asiento == null || asiento.ocupante == null || asiento.ocupante!.esIA) {
      return;
    }
    final anterior = asiento.ocupante!;
    asiento.ocupante = JugadorSala(
      id: anterior.id,
      apodo: anterior.apodo,
      esIA: anterior.esIA,
      listo: !anterior.listo,
    );
    setState(() {});
    _repartirEstadoSala();
  }

  void _repartirEstadoSala() {
    final msg = MensajeRed(
      TipoMensajeSala.estadoSala,
      _sala.aMapa(),
    ).codificar();
    _conexion.enviarATodos(msg);
  }

  // ===== ORDEN OBLIGATORIO DE ASIENTOS =====
  // Los asientos SIEMPRE se rellenan en orden (0,1,2,3...), es decir en
  // zigzag: arriba-izquierda, arriba-derecha, debajo del 1º, debajo del 2º,
  // etc. Esto evita huecos que descuadran los equipos y rompen la mesa,
  // porque el equipo va ligado al número de asiento.

  // Devuelve el número del primer asiento libre (el más bajo), o null si la
  // mesa está llena.
  int? _primerAsientoLibre() {
    for (final a in _sala.asientos) {
      if (a.estaVacio) return a.numero;
    }
    return null;
  }

  // Reempaqueta a todos los ocupantes en los asientos 0..n-1, en su orden
  // actual, sin dejar huecos. Se llama tras cualquier cambio (poner/quitar
  // IA, desconexión...) para garantizar que la mesa nunca quede rota.
  void _compactarAsientos() {
    final ocupantes = _sala.asientos
        .where((a) => !a.estaVacio)
        .map((a) => a.ocupante!)
        .toList(); // ya vienen en orden de asiento (0..7)
    for (int i = 0; i < _sala.asientos.length; i++) {
      _sala.asientos[i].ocupante = i < ocupantes.length ? ocupantes[i] : null;
    }
  }

  // Elige un número de IA que no choque con las IA ya sentadas, para que su
  // id ('ia_N') sea siempre único aunque se compacte la mesa.
  int _siguienteNumeroIA() {
    final usados = _sala.asientos
        .where((a) => a.esIA)
        .map((a) => a.ocupante!.id)
        .toSet();
    int n = 1;
    while (usados.contains('ia_$n')) {
      n++;
    }
    return n;
  }

  // ===== INVITADO: callbacks de red =====
  void _configurarCallbacksInvitado() {
    _conexion.alRecibirDeAnfitrion = (texto) {
      final msg = MensajeRed.decodificar(texto);
      if (msg == null) return;
      if (msg.tipo == TipoMensajeSala.estadoSala) {
        setState(() {
          _sala = EstadoSala.desdeMapa(msg.datos);
          _estado = _sala.sePuedeEmpezar
              ? '¡Todos listos! El anfitrión puede empezar.'
              : 'En la sala. Esperando al anfitrión...';
        });
      } else if (msg.tipo == TipoMensajeSala.tuId) {
        _miIdInvitado = msg.datos['id'] ?? '';
      } else if (msg.tipo == TipoMensajeSala.empezar) {
        _irAlJuego();
      }
    };
    _conexion.alPerderAnfitrion = () {
      if (!mounted) return;
      setState(() => _estado = 'Se perdió la conexión con el anfitrión.');
    };
  }

  // El anfitrión añade una IA. Orden obligatorio: SIEMPRE va al primer
  // asiento libre (el más bajo), sin importar dónde se pulse.
  void _ponerIA(int numero) {
    if (!widget.soyAnfitrion) return;
    final libre = _primerAsientoLibre();
    if (libre == null) return; // mesa llena
    // id único basado en las IA ya presentes (no en el asiento), para evitar
    // choques de id al compactar la mesa.
    _sala.asientos[libre].ocupante = JugadorSala.ia(_siguienteNumeroIA());
    setState(() {});
    _repartirEstadoSala();
  }

  // El anfitrión quita una IA de un asiento.
  void _quitarIA(int numero) {
    if (!widget.soyAnfitrion) return;
    final asiento = _sala.asientos[numero];
    if (asiento.estaVacio || !asiento.esIA) return;
    asiento.ocupante = null;
    _asientoSeleccionado = null; // la disposición cambia: cancela selección
    _compactarAsientos(); // cierra el hueco: reparto siempre contiguo
    setState(() {});
    _repartirEstadoSala();
  }

  // ===== INTERCAMBIO DE JUGADORES (solo anfitrión) =====
  // El anfitrión puede reordenar a la gente para armar los equipos que
  // quiera. Toca a un jugador (se resalta) y luego toca a otro: intercambian
  // asiento. Nunca puede moverse a sí mismo (asiento 0 = cerebro), y como es
  // un intercambio no se crean huecos: la mesa sigue contigua.
  void _tapAnfitrionAsiento(Asiento asiento) {
    if (!widget.soyAnfitrion) return;
    if (asiento.numero == 0) return; // el anfitrión no se mueve
    final sel = _asientoSeleccionado;
    if (sel == null) {
      if (asiento.estaVacio) return; // no hay nadie a quien coger
      setState(() => _asientoSeleccionado = asiento.numero);
    } else if (sel == asiento.numero) {
      setState(() => _asientoSeleccionado = null); // toca el mismo: cancelar
    } else {
      _intercambiarAsientos(sel, asiento.numero);
      setState(() => _asientoSeleccionado = null);
    }
  }

  // Intercambia los ocupantes de dos asientos (el anfitrión, asiento 0, nunca
  // se mueve). Compacta por seguridad para no dejar huecos.
  void _intercambiarAsientos(int a, int b) {
    if (a == 0 || b == 0) return;
    if (a < 0 ||
        b < 0 ||
        a >= EstadoSala.totalAsientos ||
        b >= EstadoSala.totalAsientos) {
      return;
    }
    final asA = _sala.asientos[a];
    final asB = _sala.asientos[b];
    final tmp = asA.ocupante;
    asA.ocupante = asB.ocupante;
    asB.ocupante = tmp;
    _compactarAsientos(); // mantiene la mesa contigua
    setState(() {});
    _repartirEstadoSala();
  }

  String? _miIdLocal() {
    if (widget.soyAnfitrion) return 'anfitrion';
    return _miIdInvitado.isEmpty ? null : _miIdInvitado;
  }

  bool _esMiJugador(Asiento asiento) {
    final miId = _miIdLocal();
    return miId != null && asiento.ocupante?.id == miId;
  }

  void _toggleListoLocal() {
    final miId = _miIdLocal();
    if (miId == null) return;
    if (widget.soyAnfitrion) {
      _cambiarListo(miId);
    } else {
      _conexion.enviarAlAnfitrion(MensajeRed(
        TipoMensajeSala.toggleListo,
        {'id': miId},
      ).codificar());
    }
  }

  // Navega a la pantalla de juego.
  void _irAlJuego() {
    if (!mounted) return;
    final idLocal = widget.soyAnfitrion ? 'anfitrion' : _miIdInvitado;
    final config = ConfigPartida.desdeSala(_sala, idLocal);
    final n = config.numJugadores;
    _yendoAlJuego = true; // la conexión sigue viva en el juego
    Widget pantalla;
    if (n <= 4) {
      pantalla = Game2v2Screen(config: config, conexion: _conexion);
    } else if (n == 6) {
      pantalla = Game3v3Screen(config: config, conexion: _conexion);
    } else {
      pantalla = Game4v4Screen(config: config, conexion: _conexion);
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => pantalla),
    );
  }

  // El anfitrión pulsa EMPEZAR: avisa a todos y va al juego.
  void _empezarPartida() {
    _conexion.enviarATodos(
      MensajeRed(TipoMensajeSala.empezar, {}).codificar(),
    );
    _irAlJuego();
  }

  // El reparto de asientos es automático y en orden obligatorio (zigzag),
  // así que tocar un asiento vacío no hace nada: nadie elige sitio a mano.
  // - El anfitrión se sienta siempre en el 0 y los demás se sientan al
  //   conectarse en el primer hueco.
  // - Para quitar/poner IA el anfitrión usa el botón propio de la ficha.
  void _pedirAsiento(int numero) {
    return;
  }

  Future<void> _iniciarComoInvitado() async {
    setState(() => _estado = 'Conectando...');
    final ip = widget.ipAnfitrion;
    if (ip == null) {
      setState(() => _estado = 'No hay dirección del anfitrión.');
      return;
    }
    final ok = await _conexion.unirseASala(ip);
    if (!mounted) return;
    if (ok) {
      _conexion.enviarAlAnfitrion(MensajeRed(
        TipoMensajeSala.hola,
        {'alias': AppSettings.instance.alias},
      ).codificar());
      setState(() => _estado = 'Conectado. Esperando sala...');
    } else {
      setState(() => _estado = 'No se pudo conectar a la sala.');
    }
  }

  Future<void> _iniciarComoAnfitrion() async {
    // El anfitrión se sienta en el asiento 0 con su alias.
    _sala.asientos[0].ocupante = JugadorSala(
      id: 'anfitrion',
      apodo: AppSettings.instance.alias,
      listo: true,
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
    if (!_yendoAlJuego) _conexion.cerrar();
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
                child: GestureDetector(
                  onTap: () => _pedirAsiento(asientosIzq[i]),
                  child: _fichaAsientoConBoton(_sala.asientos[asientosIzq[i]]),
                ),
              ),
            for (int i = 0; i < 4; i++)
              Positioned(
                right: w * 0.04,
                top: h * (0.10 + i * 0.21),
                child: GestureDetector(
                  onTap: () => _pedirAsiento(asientosDer[i]),
                  child: _fichaAsientoConBoton(_sala.asientos[asientosDer[i]]),
                ),
              ),
          ],
        );
      },
    );
  }

  // Envuelve la ficha del asiento y, si soy anfitrion, anade un boton
  // pequeno en la esquina: '+IA' si esta vacio, 'x' si tiene una IA.
  // El boton consume su propio toque (no dispara el 'sentarme' de fuera).
  Widget _fichaAsientoConBoton(Asiento asiento) {
    final ficha = _fichaAsiento(asiento);
    if (!widget.soyAnfitrion) {
      // El asiento se asigna automáticamente en orden; el invitado solo puede
      // marcar/desmarcar 'listo' tocando su propio asiento.
      return GestureDetector(
        onTap: () {
          if (_esMiJugador(asiento)) {
            _toggleListoLocal();
          }
        },
        child: ficha,
      );
    }
    // El botón '+IA' solo aparece en el PRIMER asiento libre (orden
    // obligatorio); la 'x' de quitar aparece en cualquier asiento con IA.
    final esVacio = asiento.estaVacio;
    final esPrimerLibre = esVacio && asiento.numero == _primerAsientoLibre();
    final mostrarBoton = esPrimerLibre || asiento.esIA;

    // Resalta el asiento si está "cogido" para intercambiar.
    Widget contenido = _resaltarSiSeleccionado(
      ficha,
      _asientoSeleccionado == asiento.numero,
    );

    if (mostrarBoton) {
      contenido = Stack(
        clipBehavior: Clip.none,
        children: [
          contenido,
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (esVacio) {
                  _ponerIA(asiento.numero);
                } else {
                  _quitarIA(asiento.numero);
                }
              },
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: esVacio
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFB71C1C),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: const Color(0xFFE3C28A), width: 1.5),
                ),
                child: Icon(
                  esVacio ? Icons.smart_toy : Icons.close,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // El anfitrión (asiento 0) no se puede coger ni mover. El resto de
    // asientos son tocables para seleccionarlos e intercambiarlos.
    if (asiento.numero == 0) return contenido;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _tapAnfitrionAsiento(asiento),
      child: contenido,
    );
  }

  // Envuelve una ficha con un borde/brillo dorado cuando está seleccionada
  // para intercambiar.
  Widget _resaltarSiSeleccionado(Widget ficha, bool seleccionado) {
    if (!seleccionado) return ficha;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFAF1F), width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0xAAEFAF1F), blurRadius: 12, spreadRadius: 1),
        ],
      ),
      child: ficha,
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
                  const SizedBox(height: 2),
                  Text(
                    asiento.ocupante!.listo ? 'LISTO' : 'PENDIENTE',
                    style: TextStyle(
                      color: asiento.ocupante!.listo
                          ? const Color(0xFF8BC34A)
                          : const Color(0xFFE3C28A),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _qrCentral() {
    if (widget.online) {
      if (!widget.soyAnfitrion) return const SizedBox.shrink();
      return _codigoOnline();
    }
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

  // Tarjeta del codigo en modo ONLINE (sin QR: los jugadores no estan cerca).
  Widget _codigoOnline() {
    final codigo = _ip;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF5E6C8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8A6A35), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Codigo de la sala',
            style: TextStyle(
              color: Color(0xFF3A2B12),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          GestureDetector(
            onTap: codigo == null ? null : _copiarCodigo,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2A1A0A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    codigo ?? '****',
                    style: const TextStyle(
                      color: Color(0xFFEFAF1F),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.copy, color: Color(0xFFEFAF1F), size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Toca el codigo para copiarlo',
            style: TextStyle(color: Color(0xFF6A5330), fontSize: 10),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: codigo == null ? null : _compartirCodigo,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.share, color: Colors.white, size: 16),
                  SizedBox(width: 7),
                  Text(
                    'Compartir',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copiarCodigo() {
    final codigo = _ip;
    if (codigo == null) return;
    Clipboard.setData(ClipboardData(text: codigo));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Codigo copiado'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _compartirCodigo() async {
    final codigo = _ip;
    if (codigo == null) return;
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Unete a mi partida de Envite Canario. Codigo de sala: $codigo',
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
          if (widget.soyAnfitrion)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _asientoSeleccionado == null
                    ? 'Toca a dos jugadores para intercambiar sus sitios y armar los equipos.'
                    : 'Toca otro asiento para intercambiar (o el mismo para cancelar).',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _asientoSeleccionado == null
                      ? const Color(0xCCF5E6C8)
                      : const Color(0xFFEFAF1F),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  shadows: const [
                    Shadow(
                        color: Colors.black,
                        offset: Offset(0, 1),
                        blurRadius: 3),
                  ],
                ),
              ),
            ),
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
          if (widget.soyAnfitrion)
            GestureDetector(
              onTap: puede ? _empezarPartida : null,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 40),
                decoration: BoxDecoration(
                  gradient: puede
                      ? const LinearGradient(
                          colors: [Color(0xFFEFAF1F), Color(0xFFC8870F)],
                        )
                      : null,
                  color: puede ? null : const Color(0x55000000),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: const Color(0xFF8A6A35), width: 1.5),
                ),
                child: Text(
                  puede ? 'EMPEZAR' : 'Faltan jugadores',
                  style: TextStyle(
                    color: puede
                        ? const Color(0xFF3A2B12)
                        : const Color(0x88F5E6C8),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
              decoration: BoxDecoration(
                color: const Color(0x55000000),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x55E3C28A), width: 1),
              ),
              child: const Text(
                'Esperando al anfitrión...',
                style: TextStyle(
                  color: Color(0xCCF5E6C8),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
