import '../../../../core/enums/suit.dart';
import '../../../../core/utils/deck_generator.dart';
import '../../data/models/card_model.dart';
import '../../data/models/player_model.dart';

class DealResult {
  final List<PlayerModel> players;
  final CardModel cartaVirada;
  final Suit paloDeLaMano;
  final List<CardModel> mazoRestante;

  DealResult({
    required this.players,
    required this.cartaVirada,
    required this.paloDeLaMano,
    required this.mazoRestante,
  });
}

class DealEngine {
  static const int cartasPorJugador = 3;

  /// Reparte 3 cartas a cada jugador y vira la siguiente carta del mazo
  /// para definir el palo de la mano.
  static DealResult repartir(List<PlayerModel> players) {
    final mazo = DeckGenerator.generateShuffledDeck();
    int indice = 0;

    // Reparto: 3 cartas a cada jugador, en orden
    for (final player in players) {
      player.hand = mazo.sublist(indice, indice + cartasPorJugador);
      indice += cartasPorJugador;
    }

    // La siguiente carta del mazo es la que se "vira"
    final cartaVirada = mazo[indice];
    indice += 1;

    final mazoRestante = mazo.sublist(indice);

    return DealResult(
      players: players,
      cartaVirada: cartaVirada,
      paloDeLaMano: cartaVirada.suit,
      mazoRestante: mazoRestante,
    );
  }
}
