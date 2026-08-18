import 'package:flutter/material.dart' hide Card;
import '../../models/card.dart';

/// 扑克牌组件
class CardWidget extends StatelessWidget {
  final Card? card;
  final bool faceUp;
  final double size;

  const CardWidget({
    super.key,
    this.card,
    this.faceUp = true,
    this.size = 60,
  });

  static const _suitSymbols = {
    Suit.spades: '♠',
    Suit.hearts: '♥',
    Suit.diamonds: '♦',
    Suit.clubs: '♣',
  };

  @override
  Widget build(BuildContext context) {
    final isRed = card != null &&
        (card!.suit == Suit.hearts || card!.suit == Suit.diamonds);

    return Container(
      width: size * 0.72,
      height: size,
      decoration: BoxDecoration(
        color: (faceUp && card != null) ? Colors.white : const Color(0xFF1e3a8a),
        borderRadius: BorderRadius.circular(size * 0.08),
        border: Border.all(
          color: (faceUp && card != null) ? Colors.grey : Colors.white24,
          width: 1,
        ),
        gradient: (faceUp && card != null)
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1e3a8a), Color(0xFF172554)],
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 3,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: (faceUp && card != null)
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  card!.rank.toString(),
                  style: TextStyle(
                    fontSize: size * 0.32,
                    fontWeight: FontWeight.bold,
                    color: isRed ? Colors.red : Colors.black,
                    height: 1.0,
                  ),
                ),
                Text(
                  _suitSymbols[card!.suit]!,
                  style: TextStyle(
                    fontSize: size * 0.28,
                    color: isRed ? Colors.red : Colors.black,
                    height: 1.1,
                  ),
                ),
              ],
            )
          : Center(
              child: Icon(
                Icons.style,
                color: Colors.white.withOpacity(0.4),
                size: size * 0.4,
              ),
            ),
    );
  }
}
