import '../../../../core/enums/suit.dart';
import '../../../../core/enums/card_value.dart';

class CardModel {
  final Suit suit;
  final CardValue value;

  const CardModel({
    required this.suit,
    required this.value,
  });

  String get displayName => '${value.displayName} de ${suit.displayName}';

  /// Nombre del archivo de imagen, ej: "oros_01.png"
  String get assetName {
    final numero = value.numero.toString().padLeft(2, '0');
    return '${suit.name}_$numero.png';
  }

  @override
  String toString() => displayName;

  @override
  bool operator ==(Object other) =>
      other is CardModel && other.suit == suit && other.value == value;

  @override
  int get hashCode => Object.hash(suit, value);
}
