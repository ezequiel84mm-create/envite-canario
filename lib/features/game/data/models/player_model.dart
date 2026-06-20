import 'card_model.dart';

class PlayerModel {
  final String id;
  final String name;
  final bool isAI;
  List<CardModel> hand;

  PlayerModel({
    required this.id,
    required this.name,
    this.isAI = false,
    List<CardModel>? hand,
  }) : hand = hand ?? [];

  @override
  String toString() => '$name (${hand.length} cartas)';
}
