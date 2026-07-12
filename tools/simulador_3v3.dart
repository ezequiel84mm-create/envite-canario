// Simulador de partidas 3v3 todo-IA para detectar anomalías de lógica.
// Uso:  cd ~/dev/envite_canario && dart run tools/simulador_3v3.dart
//
// Juega 50 partidas completas (4 chicos) con 6 IA y verifica:
//  - que nadie juegue cartas no válidas,
//  - que no haya bazas empatadas (imposible en 2 de 3),
//  - que ninguna partida entre en bucle infinito,
//  - el equilibrio entre equipos y el reparto de bazas por asiento.
//
// NOTA: no incluye envites ni tumbo (dependen de la UI); cubre la lógica
// central de reparto, jerarquía, validación, IA y conteo.

// Script de diagnóstico por consola: el print y el toggle 'verbose' (apagado
// por defecto, se pone a true para ver la traza) son intencionados.
// ignore_for_file: avoid_print, dead_code

import 'package:envite_canario/features/game/data/models/card_model.dart';
import 'package:envite_canario/features/multiplayer/domain/engine/deal_engine_2v2.dart';
import 'package:envite_canario/features/multiplayer/domain/engine/trick_engine_3v3.dart';
import 'package:envite_canario/features/multiplayer/domain/engine/trick_engine_2v2.dart' show CartaJugada2v2;
import 'package:envite_canario/features/multiplayer/domain/ai/ai_player_3v3.dart';

// Equipos reales 3v3: A={0,3,4}, B={1,2,5}.
int equipoDe(int a) => (a == 0 || a == 3 || a == 4) ? 0 : 1;

const ordenCircular = [0, 1, 3, 2, 4, 5];
int siguiente(int asiento) {
  final i = ordenCircular.indexOf(asiento);
  return ordenCircular[(i + 1) % 6];
}

String nombreCarta(CardModel c) => '${c.value.numero}-${c.suit.name}';

int anomalias = 0;
void anomalia(String msg) {
  print('  ⚠️  ANOMALIA: $msg');
  anomalias++;
}

void main() {
  bool verbose = false; // pon true para ver jugada a jugada
  int partidasInfinitas = 0;
  int ganaA = 0, ganaB = 0;
  final bazasPorAsiento = List<int>.filled(6, 0);
  int totalManos = 0;

  for (int partida = 0; partida < 50; partida++) {
    int piedras0 = 0, piedras1 = 0;
    int chicos0 = 0, chicos1 = 0;
    int barajador = 0;
    int manosJugadas = 0;
    int guardaPartida = 0;

    while (chicos0 < 4 && chicos1 < 4) {
      guardaPartida++;
      if (guardaPartida > 1000) {
        anomalia('partida $partida no termina tras 1000 manos (bucle infinito)');
        partidasInfinitas++;
        break;
      }

      final reparto = DealEngine2v2.repartirPara(6);
      final manos = reparto.manos;
      final virado = reparto.paloVirado;
      int turno = siguiente(barajador);

      int bazasEq0 = 0, bazasEq1 = 0;

      for (int numBaza = 0; numBaza < 3; numBaza++) {
        final baza = <CartaJugada2v2>[];
        for (int paso = 0; paso < 6; paso++) {
          final asiento = turno;
          final paloInicial = baza.isEmpty ? null : baza.first.carta.suit;
          final validas = TrickEngine3v3.cartasValidas(
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
          final carta = AiPlayer3v3.elegirCarta(
            miAsiento: asiento,
            validas: validas,
            bazaActual: baza,
            paloVirado: virado,
            equipoDe: equipoDe,
          );
          if (!validas.any((c) => c.suit == carta.suit && c.value == carta.value)) {
            anomalia('asiento $asiento jugo carta NO valida: ${nombreCarta(carta)}');
          }
          manos[asiento].remove(carta);
          baza.add(CartaJugada2v2(asiento: asiento, carta: carta));
          if (verbose) print('    asiento $asiento (eq${equipoDe(asiento)}) juega ${nombreCarta(carta)}');
          turno = siguiente(turno);
        }
        final ganador = TrickEngine3v3.determinarGanador(
          jugadas: baza,
          paloVirado: virado,
        );
        if (equipoDe(ganador.asiento) == 0) {
          bazasEq0++;
        } else {
          bazasEq1++;
        }
        bazasPorAsiento[ganador.asiento]++;
        if (verbose) print('   -> gana baza asiento ${ganador.asiento} con ${nombreCarta(ganador.carta)}');
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
    if (verbose || partida < 3) {
      print('Partida $partida: chicos $chicos0-$chicos1 en $manosJugadas manos');
    }
  }

  print('');
  print('=== RESUMEN ===');
  print('Partidas infinitas: $partidasInfinitas');
  print('Anomalias totales: $anomalias');
  if (anomalias == 0 && partidasInfinitas == 0) {
    print('✅ Sin anomalias en 50 partidas completas.');
  }
  print('Gana equipo A: $ganaA  |  Gana equipo B: $ganaB  (de 50)');
  print('Media de manos por partida: ${(totalManos / 50).toStringAsFixed(1)}');
  print('Bazas ganadas por asiento (0..5): $bazasPorAsiento');
  final totalA = bazasPorAsiento[0] + bazasPorAsiento[3] + bazasPorAsiento[4];
  final totalB = bazasPorAsiento[1] + bazasPorAsiento[2] + bazasPorAsiento[5];
  print('Bazas totales equipo A: $totalA  |  equipo B: $totalB');
}
