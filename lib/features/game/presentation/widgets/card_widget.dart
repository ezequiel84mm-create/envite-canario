import 'package:flutter/material.dart';
import '../../data/models/card_model.dart';
import '../../../../core/settings/mazo_assets.dart';

class CardWidget extends StatelessWidget {
  final CardModel card;
  final bool faceDown;
  final double width;
  final double height;

  const CardWidget({
    super.key,
    required this.card,
    this.faceDown = false,
    this.width = 85,
    this.height = 135,
  });

  @override
  Widget build(BuildContext context) {
    // En tablet las cartas se dibujan un 25% más grandes.
    final esTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final w = esTablet ? width * 1.25 : width;
    final h = esTablet ? height * 1.25 : height;
    if (faceDown) {
      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          MazoAssets.trasera,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black26, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(1, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        MazoAssets.carta(card.assetName),
        fit: BoxFit.cover,
      ),
    );
  }
}
