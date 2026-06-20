import 'package:flutter/material.dart';
import '../../data/models/card_model.dart';

class CardWidget extends StatelessWidget {
  final CardModel card;
  final bool faceDown;

  const CardWidget({
    super.key,
    required this.card,
    this.faceDown = false,
  });

  @override
  Widget build(BuildContext context) {
    if (faceDown) {
      return Container(
        width: 85,
        height: 135,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          'assets/cards/trasera.png',
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: 85,
      height: 135,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black26, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(1, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/cards/${card.assetName}',
        fit: BoxFit.cover,
      ),
    );
  }
}
