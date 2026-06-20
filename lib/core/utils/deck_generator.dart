import '../enums/suit.dart';
import '../enums/card_value.dart';
import '../../features/game/data/models/card_model.dart';

class DeckGenerator {
  /// Genera la baraja española completa de 40 cartas (sin 8 y 9)
  static List<CardModel> generateDeck() {
    final List<CardModel> deck = [];

    for (final suit in Suit.values) {
      for (final value in CardValue.values) {
        deck.add(CardModel(suit: suit, value: value));
      }
    }

    return deck;
  }

  /// Devuelve una baraja ya mezclada (shuffle)
  static List<CardModel> generateShuffledDeck() {
    final deck = generateDeck();
    deck.shuffle();
    return deck;
  }
}
