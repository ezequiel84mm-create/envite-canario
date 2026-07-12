// Script de diagnóstico por consola: el uso de print es intencionado.
// ignore_for_file: avoid_print

import 'package:envite_canario/features/multiplayer/network/conexion_p2p.dart';

Future<void> main() async {
  final anfitrion = ConexionP2P();
  final invitado = ConexionP2P();
  String? ip;
  bool conectado = false;
  anfitrion.alConectar = () {
    conectado = true;
    print('anfitrion: conectado');
  };
  invitado.alConectar = () => print('invitado: conectado');
  anfitrion.alRecibir = (m) => print('anfitrion recibe: $m');
  invitado.alRecibir = (m) => print('invitado recibe: $m');
  ip = await anfitrion.crearComoAnfitrion();
  print('ip local: $ip');
  await Future<void>.delayed(const Duration(seconds: 1));
  final ok = await invitado.unirseComoInvitado(ip ?? '127.0.0.1');
  print('unirse: $ok');
  await Future<void>.delayed(const Duration(seconds: 2));
  if (conectado) {
    anfitrion.enviar('hola');
    invitado.enviar('adios');
  }
  await Future<void>.delayed(const Duration(seconds: 1));
  anfitrion.cerrar();
  invitado.cerrar();
}
