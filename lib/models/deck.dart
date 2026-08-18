import 'dart:math';
import 'card.dart';

class Deck {
  List<Card> _cards = [];

  Deck() {
    reset();
  }

  /// 生成一副新牌（52张）并洗牌
  void reset() {
    _cards = [];
    for (var rank in Rank.values) {
      for (var suit in Suit.values) {
        _cards.add(Card(rank, suit));
      }
    }
    shuffle();
  }

  /// Fisher-Yates 洗牌
  void shuffle() {
    final random = Random();
    for (int i = _cards.length - 1; i > 0; i--) {
      int j = random.nextInt(i + 1);
      final temp = _cards[i];
      _cards[i] = _cards[j];
      _cards[j] = temp;
    }
  }

  /// 发牌：移除并返回顶部一张
  Card deal() {
    if (_cards.isEmpty) throw Exception('Deck is empty');
    return _cards.removeLast();
  }

  /// 返回剩余牌数
  int get remaining => _cards.length;

  /// 用于测试：直接查看牌堆（不推荐生产使用）
  List<Card> get cards => List.unmodifiable(_cards);
}
