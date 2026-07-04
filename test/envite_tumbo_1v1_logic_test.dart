import 'package:flutter_test/flutter_test.dart';
import 'package:envite_canario/features/multiplayer/domain/engine/envite_tumbo_1v1_logic.dart';

void main() {
  group('Envite/Tumbo 1v1 logic', () {
    test('permite cantar cuando no hay envite ni turno restringido', () {
      final logic = EnviteTumbo1v1Logic();
      expect(logic.puedeCantar(0), isTrue);
      expect(logic.puedeCantar(1), isTrue);
    });

    test('registra un canto y marca la propuesta correcta', () {
      final logic = EnviteTumbo1v1Logic().registrarCanto(0);
      expect(logic.hayEnvitePendiente, isTrue);
      expect(logic.quienCanto, 0);
      expect(logic.nivelPropuesto, 1);
    });

    test('aceptar envite actualiza el nivel y deja el turno de apuesta al rival', () {
      final logic = EnviteTumbo1v1Logic(
        enviteCantado: true,
        quienCanto: 0,
        nivelPropuesto: 2,
      ).responder('juego');

      expect(logic.nivelApuesta, 2);
      expect(logic.enviteCantado, isFalse);
      expect(logic.quienCanto, -1);
      expect(logic.turnoApuesta, 1);
    });

    test('subir envite cambia el turno de respuesta', () {
      final logic = EnviteTumbo1v1Logic(
        enviteCantado: true,
        quienCanto: 0,
        nivelPropuesto: 2,
      ).responder('subir');

      expect(logic.nivelPropuesto, 3);
      expect(logic.quienCanto, 1);
    });

    test('pasar envite deja el turno de apuesta en neutral', () {
      final logic = EnviteTumbo1v1Logic(
        enviteCantado: true,
        quienCanto: 0,
        nivelPropuesto: 2,
        turnoApuesta: 1,
      ).responder('paso');

      expect(logic.enviteCantado, isFalse);
      expect(logic.quienCanto, -1);
      expect(logic.turnoApuesta, -1);
    });

    test('decidir tumbo marca la mano como tumbo', () {
      final logic = EnviteTumbo1v1Logic(quienDecideTumbo: 0).decidirTumbo(true);
      expect(logic.hayDecisionTumbo, isFalse);
      expect(logic.manoEsDeTumbo, isTrue);
    });

    test('hidrata el estado desde un mapa de sincronización', () {
      final logic = EnviteTumbo1v1Logic.fromMap({
        'nivelApuesta': 2,
        'enviteCantado': true,
        'quienCanto': 1,
        'nivelPropuesto': 3,
        'turnoApuesta': 0,
        'manoEsDeTumbo': true,
        'quienDecideTumbo': -1,
      });

      expect(logic.nivelApuesta, 2);
      expect(logic.enviteCantado, isTrue);
      expect(logic.quienCanto, 1);
      expect(logic.nivelPropuesto, 3);
      expect(logic.turnoApuesta, 0);
      expect(logic.manoEsDeTumbo, isTrue);
      expect(logic.quienDecideTumbo, -1);
    });

    test('serializa el estado a un mapa de sincronización', () {
      final logic = const EnviteTumbo1v1Logic(
        nivelApuesta: 2,
        enviteCantado: true,
        quienCanto: 1,
        nivelPropuesto: 3,
        turnoApuesta: 0,
        manoEsDeTumbo: true,
        quienDecideTumbo: -1,
      );

      final mapa = logic.toMap();

      expect(mapa['nivelApuesta'], 2);
      expect(mapa['enviteCantado'], isTrue);
      expect(mapa['quienCanto'], 1);
      expect(mapa['nivelPropuesto'], 3);
      expect(mapa['turnoApuesta'], 0);
      expect(mapa['manoEsDeTumbo'], isTrue);
      expect(mapa['quienDecideTumbo'], -1);
    });
  });
}
