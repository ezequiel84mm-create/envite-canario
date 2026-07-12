// Simulador de partidas 2v2 todo-IA para detectar anomalías de lógica.
// Uso:  cd ~/dev/envite_canario && dart run tools/simulador_2v2.dart

// Script de diagnóstico por consola: el uso de print es intencionado.
// ignore_for_file: avoid_print

import 'package:envite_canario/features/game/data/models/card_model.dart';
import 'package:envite_canario/features/multiplayer/domain/engine/deal_engine_2v2.dart';
import 'package:envite_canario/features/multiplayer/domain/engine/trick_engine_2v2.dart';
import 'package:envite_canario/features/multiplayer/domain/ai/ai_player_2v2.dart';

// Equipos reales 2v2: A={0,3}, B={1,2}.
int equipoDe(int a) => (a == 0 || a == 3) ? 0 : 1;

const ordenCircular = [0, 1, 3, 2];
int siguiente(int asiento) {
  final i = ordenCircular.indexOf(asiento);
  return ordenCircular[(i + 1) % 4];
}

String nombreCarta(CardModel c) => '${c.value.numero}-${c.suit.name}';

int anomalias = 0;
void anomalia(String msg) {
  print('  ⚠️  ANOMALIA: $msg');
  anomalias++;
}

void main() {
  int partidasInfinitas = 0;
  int ganaA = 0, ganaB = 0;
  final bazasPorAsiento = List<int>.filled(4, 0);
  int totalManos = 0;

  for (int partida = 0; partida < 50; partida++) {
    int piedras0 = 0, piedras1 = 0;
    int chicos0 = 0, chicos1 = 0;
    int barajador = 0;
    int manosJugadas = 0;
    int guarda = 0;

    while (chicos0 < 4 && chicos1 < 4) {
      guarda++;
      if (guarda > 1000) {
        anomalia('partida $partida no termina (bucle infinito)');
        partidasInfinitas++;
        break;
      }

      final reparto = DealEngine2v2.repartirPara(4);
      final manos = reparto.manos;
      final virado = reparto.paloVirado;
      int turno = siguiente(barajador);
      int bazasEq0 = 0, bazasEq1 = 0;

      for (int numBaza = 0; numBaza < 3; numBaza++) {
        final baza = <CartaJugada2v2>[];
        for (int paso = 0; paso < 4; paso++) {
          final asiento = turno;
          final paloInicial = baza.isEmpty ? null : baza.first.carta.suit;
          final validas = TrickEngine2v2.cartasValidas(
            mano: manos[asiento],
            paloInicialBaza: paloInicial,
            paloVirado: virado,
            baza: baza,
            asiento: asiento,
            equipoDe: equipoDe,
          );
          if (validas.isEmpty) {
            anomalia('asiento $asiento sin cartas validas');
            break;
          }
          final carta = AiPlayer2v2.elegirCarta(
            miAsiento: asiento,
            validas: validas,
            bazaActual: baza,
            paloVirado: virado,
            equipoDe: equipoDe,
          );
          if (!validas.any((cc) => cc.suit == carta.suit && cc.value == carta.value)) {
            anomalia('asiento $asiento jugo carta NO valida: ${nombreCarta(carta)}');
          }
          manos[asiento].remove(carta);
          baza.add(CartaJugada2v2(asiento: asiento, carta: carta));
          turno = siguiente(turno);
        }
        final ganador = TrickEngine2v2.determinarGanador(
          jugadas: baza,
          paloVirado: virado,
        );
        if (equipoDe(ganador.asiento) == 0) {
          bazasEq0++;
        } else {
          bazasEq1++;
        }
        bazasPorAsiento[ganador.asiento]++;
        turno = ganador.asiento;
        if (bazasEq0 >= 2 || bazasEq1 >= 2) break;
      }

      if (bazasEq0 == bazasEq1) {
        anomalia('mano con bazas empatadas $bazasEq0-$bazasEq1');
      }

      final gana0 = bazasEq0 > bazasEq1;
      if (gana0) {
        piedras0 += 2;
      } else {
        piedras1 += 2;
      }
      if (piedras0 >= 12) { chicos0++; piedras0 = 0; piedras1 = 0; }
      if (piedras1 >= 12) { chicos1++; piedras0 = 0; piedras1 = 0; }

      manosJugadas++;
      barajador = siguiente(barajador);
    }

    totalManos += manosJugadas;
    if (chicos0 >= 4) {
      ganaA++;
    } else {
      ganaB++;
    }
    if (partida < 3) {
      print('Partida $partida: chicos $chicos0-$chicos1 en $manosJugadas manos');
    }
  }

  print('');
  print('=== RESUMEN 2v2 ===');
  print('Partidas infinitas: $partidasInfinitas');
  print('Anomalias totales: $anomalias');
  if (anomalias == 0 && partidasInfinitas == 0) {
    print('✅ Sin anomalias en 50 partidas completas.');
  }
  print('Gana equipo A: $ganaA  |  Gana equipo B: $ganaB  (de 50)');
  print('Media de manos por partida: ${(totalManos / 50).toStringAsFixed(1)}');
  print('Bazas ganadas por asiento (0..3): $bazasPorAsiento');
  final totalA = bazasPorAsiento[0] + bazasPorAsiento[3];
  final totalB = bazasPorAsiento[1] + bazasPorAsiento[2];
  print('Bazas totales equipo A: $totalA  |  equipo B: $totalB');
}
