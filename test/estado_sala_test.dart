import 'package:flutter_test/flutter_test.dart';
import 'package:envite_canario/features/sala/domain/models/estado_sala.dart';
import 'package:envite_canario/features/sala/domain/models/jugador_sala.dart';

void main() {
  group('EstadoSala listo', () {
    test('no permite empezar si un jugador humano no está listo', () {
      final sala = EstadoSala.vacia('anfitrion');
      sala.asientos[0].ocupante = const JugadorSala(id: 'a', apodo: 'Ana', listo: true);
      sala.asientos[2].ocupante = const JugadorSala(id: 'b', apodo: 'Berto', listo: false);

      expect(sala.sePuedeEmpezar, isFalse);
    });

    test('permite empezar con mesa completa (4), equipos equilibrados y humanos listos', () {
      final sala = EstadoSala.vacia('anfitrion');
      sala.asientos[0].ocupante = const JugadorSala(id: 'a', apodo: 'Ana', listo: true);
      sala.asientos[1].ocupante = const JugadorSala(id: 'b', apodo: 'Berto', listo: true);
      sala.asientos[2].ocupante = JugadorSala.ia(1);
      sala.asientos[3].ocupante = JugadorSala.ia(2);

      expect(sala.sePuedeEmpezar, isTrue);
    });

    test('no permite empezar con solo 2 jugadores (para eso está el 1v1)', () {
      final sala = EstadoSala.vacia('anfitrion');
      sala.asientos[0].ocupante = const JugadorSala(id: 'a', apodo: 'Ana', listo: true);
      sala.asientos[1].ocupante = const JugadorSala(id: 'b', apodo: 'Berto', listo: true);

      expect(sala.sePuedeEmpezar, isFalse);
    });
  });
}
