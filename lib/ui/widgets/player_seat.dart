import 'package:flutter/material.dart';
import '../../models/player.dart';
import 'card_widget.dart';

class PlayerSeat extends StatelessWidget {
  final Player player;
  final bool isMe;
  final bool isCurrent;
  final bool showCards;

  /// 本手牌赢家：座位金色描边 + 手牌金色高亮
  final bool isWinner;

  const PlayerSeat({
    super.key,
    required this.player,
    required this.isMe,
    required this.isCurrent,
    required this.showCards,
    this.isWinner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isWinner
            ? const Color(0xFFFFD700).withOpacity(0.15)
            : (isCurrent ? Colors.yellow.withOpacity(0.3) : Colors.transparent),
        borderRadius: BorderRadius.circular(8),
        border: isWinner
            ? Border.all(color: const Color(0xFFFFD700), width: 3)
            : (isCurrent ? Border.all(color: Colors.yellow, width: 2) : null),
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
                  fontSize: 16,
                ),
              ),
              if (player.isDealer) ...[
                const SizedBox(width: 4),
                const Text('👑', style: TextStyle(fontSize: 14)),
              ],
              if (isWinner) ...[
                const SizedBox(width: 4),
                const Text('🏆', style: TextStyle(fontSize: 14)),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (player.isSmallBlind) const Text('SB ', style: TextStyle(color: Colors.green, fontSize: 12)),
              if (player.isBigBlind) const Text('BB ', style: TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CardWidget(card: player.handCards.isNotEmpty ? player.handCards[0] : null, faceUp: showCards && player.handCards.isNotEmpty, size: 112, highlight: isWinner),
              const SizedBox(width: 4),
              CardWidget(card: player.handCards.length > 1 ? player.handCards[1] : null, faceUp: showCards && player.handCards.length > 1, size: 112, highlight: isWinner),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '筹码: ${player.chips}',
            style: const TextStyle(color: Colors.yellow, fontSize: 16),
          ),
          if (player.currentBet > 0)
            Text(
              '下注: ${player.currentBet}',
              style: const TextStyle(color: Colors.orange, fontSize: 14),
            ),
          if (player.hasFolded)
            const Text('已弃牌', style: TextStyle(color: Colors.red, fontSize: 14)),
          if (player.isAllIn)
            const Text('ALL-IN', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}
