import 'package:flutter/material.dart';
import '../../models/player.dart';
import 'card_widget.dart';

class PlayerSeat extends StatelessWidget {
  final Player player;
  final bool isMe;
  final bool isCurrent;
  final bool showCards;

  const PlayerSeat({
    super.key,
    required this.player,
    required this.isMe,
    required this.isCurrent,
    required this.showCards,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isCurrent ? Colors.yellow.withOpacity(0.3) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isCurrent ? Border.all(color: Colors.yellow, width: 2) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                player.name,
                style: TextStyle(
                  color: isMe ? Colors.cyan : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (player.isDealer) ...[
                const SizedBox(width: 4),
                const Text('👑', style: TextStyle(fontSize: 12)),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (player.isSmallBlind) const Text('SB ', style: TextStyle(color: Colors.green, fontSize: 10)),
              if (player.isBigBlind) const Text('BB ', style: TextStyle(color: Colors.red, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CardWidget(card: player.handCards.isNotEmpty ? player.handCards[0] : null, faceUp: showCards && player.handCards.isNotEmpty, size: 80),
              const SizedBox(width: 4),
              CardWidget(card: player.handCards.length > 1 ? player.handCards[1] : null, faceUp: showCards && player.handCards.length > 1, size: 80),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '筹码: ${player.chips}',
            style: const TextStyle(color: Colors.yellow, fontSize: 14),
          ),
          if (player.currentBet > 0)
            Text(
              '下注: ${player.currentBet}',
              style: const TextStyle(color: Colors.orange, fontSize: 12),
            ),
          if (player.hasFolded)
            const Text('已弃牌', style: TextStyle(color: Colors.red, fontSize: 12)),
          if (player.isAllIn)
            const Text('ALL-IN', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}
