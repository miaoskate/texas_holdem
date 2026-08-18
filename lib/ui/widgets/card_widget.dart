import 'package:flutter/material.dart' hide Card;
import '../../models/card.dart';

/// 扑克牌组件
class CardWidget extends StatefulWidget {
  final Card? card;
  final bool faceUp;
  final double size;

  /// 赢家牌高亮：金色 #FFD700 边框（3.5px）+ 金色脉冲发光动画
  final bool highlight;

  const CardWidget({
    super.key,
    this.card,
    this.faceUp = true,
    this.size = 60,
    this.highlight = false,
  });

  @override
  State<CardWidget> createState() => _CardWidgetState();
}

class _CardWidgetState extends State<CardWidget>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant CardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlight != oldWidget.highlight) _syncPulse();
  }

  void _syncPulse() {
    if (widget.highlight) {
      _pulse ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      )..repeat(reverse: true);
    } else {
      _pulse?.stop();
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  static const _suitSymbols = {
    Suit.spades: '♠',
    Suit.hearts: '♥',
    Suit.diamonds: '♦',
    Suit.clubs: '♣',
  };

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final size = widget.size;
    final isRed = card != null &&
        (card.suit == Suit.hearts || card.suit == Suit.diamonds);

    final cardChild = Container(
      width: size * 0.72,
      height: size,
      decoration: BoxDecoration(
        color: (widget.faceUp && card != null) ? Colors.white : const Color(0xFF1e3a8a),
        borderRadius: BorderRadius.circular(size * 0.08),
        border: Border.all(
          color: widget.highlight
              ? const Color(0xFFFFD700) // 赢家高亮：金色边框
              : ((widget.faceUp && card != null) ? Colors.grey : Colors.white24),
          width: widget.highlight ? 3.5 : 1,
        ),
        gradient: (widget.faceUp && card != null)
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
      child: (widget.faceUp && card != null)
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  card.rank.toString(),
                  style: TextStyle(
                    fontSize: size * 0.32,
                    fontWeight: FontWeight.bold,
                    color: isRed ? Colors.red : Colors.black,
                    height: 1.0,
                  ),
                ),
                Text(
                  _suitSymbols[card.suit]!,
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

    final pulse = _pulse;
    if (!widget.highlight || pulse == null) return cardChild;

    // 赢家高亮：金色光晕脉冲（800ms 循环，透明度 0.35↔0.8，模糊 10↔20）
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.08),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withOpacity(0.35 + 0.45 * pulse.value),
              blurRadius: 10 + 10 * pulse.value,
              spreadRadius: 1 + 2 * pulse.value,
            ),
          ],
        ),
        child: child,
      ),
      child: cardChild,
    );
  }
}
