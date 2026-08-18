import 'package:flutter_test/flutter_test.dart';
import '../lib/models/card.dart';
import '../lib/logic/hand_evaluator.dart';

void main() {
  group('HandEvaluator', () {
    // 辅助：从字符串列表创建 Card 列表
    List<Card> parseCards(List<String> strs) {
      return strs.map((s) => Card.fromString(s)).toList();
    }

    test('Royal Flush', () {
      final cards = parseCards(['As', 'Ks', 'Qs', 'Js', 'Ts', '2h', '3d']);
      final eval = HandEvaluator.evaluate(cards);
      expect(eval.rank, HandRank.royalFlush);
      expect(eval.rankValue, [14]);
    });

    test('Straight Flush', () {
      final cards = parseCards(['9h', '8h', '7h', '6h', '5h', '2d', '3c']);
      final eval = HandEvaluator.evaluate(cards);
      expect(eval.rank, HandRank.straightFlush);
      expect(eval.rankValue, [9]);
    });

    test('Four of a Kind', () {
      final cards = parseCards(['As', 'Ad', 'Ac', 'Ah', 'Ks', 'Qd', 'Jc']);
      final eval = HandEvaluator.evaluate(cards);
      expect(eval.rank, HandRank.fourOfAKind);
      expect(eval.rankValue, [14, 13]); // A 四条，K 踢脚
      expect(eval.bestCards.map((c) => c.toString()).toSet().contains('Ks'), true);
    });

    test('Full House', () {
      final cards = parseCards(['As', 'Ad', 'Ac', 'Ks', 'Kd', 'Qh', 'Jc']);
      final eval = HandEvaluator.evaluate(cards);
      expect(eval.rank, HandRank.fullHouse);
      expect(eval.rankValue, [14, 13]); // A 三条，K 一对
    });

    test('Flush', () {
      final cards = parseCards(['As', 'Ks', 'Qs', 'Js', '9s', '2h', '3d']);
      final eval = HandEvaluator.evaluate(cards);
      expect(eval.rank, HandRank.flush);
      expect(eval.rankValue, [14, 13, 12, 11, 9]);
      final bestRanks = eval.bestCards.map((c) => c.rank.value).toList();
      expect(bestRanks, [14, 13, 12, 11, 9]);
    });

    test('Straight (A-2-3-4-5 min)', () {
      final cards = parseCards(['Ah', '2d', '3c', '4s', '5h', 'Ks', 'Qd']);
      final eval = HandEvaluator.evaluate(cards);
      expect(eval.rank, HandRank.straight);
      expect(eval.rankValue, [5]);
    });

    test('Straight (10-J-Q-K-A max)', () {
      final cards = parseCards(['Ah', 'Kd', 'Qs', 'Jc', 'Th', '2s', '3d']);
      final eval = HandEvaluator.evaluate(cards);
      expect(eval.rank, HandRank.straight);
      expect(eval.rankValue, [14]);
    });

    test('Three of a Kind', () {
      final cards = parseCards(['As', 'Ad', 'Ac', 'Ks', 'Qd', 'Jh', '9c']);
      final eval = HandEvaluator.evaluate(cards);
      expect(eval.rank, HandRank.threeOfAKind);
      expect(eval.rankValue, [14, 13, 12]); // A 三条，K Q 踢脚
    });

    test('Two Pair', () {
      final cards = parseCards(['As', 'Ad', 'Ks', 'Kd', 'Qh', 'Jc', '9s']);
      final eval = HandEvaluator.evaluate(cards);
      expect(eval.rank, HandRank.twoPair);
      expect(eval.rankValue, [14, 13, 12]); // A 对，K 对，Q 踢脚
    });

    test('One Pair (no straight possible)', () {
      // 修改为不包含顺子的牌型，确保最佳是一对
      final cards = parseCards(['As', 'Ad', 'Ks', 'Qd', 'Jh', '8c', '9s']);
      final eval = HandEvaluator.evaluate(cards);
      expect(eval.rank, HandRank.onePair);
      expect(eval.rankValue, [14, 13, 12, 11]); // A 对，K Q J 踢脚
    });

    test('High Card', () {
      final cards = parseCards(['As', 'Kd', 'Qs', 'Jc', '9h', '7d', '5s']);
      final eval = HandEvaluator.evaluate(cards);
      expect(eval.rank, HandRank.highCard);
      expect(eval.rankValue, [14, 13, 12, 11, 9]);
    });

    test('Compare same rank: One Pair kicker wins', () {
      final eval1 = HandEvaluator.evaluate(parseCards(['As', 'Ad', 'Ks', 'Qd', 'Jh']));
      final eval2 = HandEvaluator.evaluate(parseCards(['As', 'Ad', 'Ks', 'Qd', 'Th']));
      expect(HandEvaluation.compare(eval1, eval2), 1);
      expect(HandEvaluation.compare(eval2, eval1), -1);
    });

    test('Compare same rank: Two Pair kicker wins', () {
      final eval1 = HandEvaluator.evaluate(parseCards(['As', 'Ad', 'Ks', 'Kd', 'Qh']));
      final eval2 = HandEvaluator.evaluate(parseCards(['As', 'Ad', 'Ks', 'Kd', 'Jh']));
      expect(HandEvaluation.compare(eval1, eval2), 1);
    });

    test('Compare different ranks: Flush beats Straight', () {
      final eval1 = HandEvaluator.evaluate(parseCards(['As', 'Ks', 'Qs', 'Js', '9s'])); // Flush
      final eval2 = HandEvaluator.evaluate(parseCards(['Ah', 'Kd', 'Qs', 'Jc', 'Th'])); // Straight
      expect(HandEvaluation.compare(eval1, eval2), 1);
    });

    test('Select best 5 from 7: 6 cards flush (not royal)', () {
      // 修改为不含皇家同花顺，确保是普通同花
      final cards = parseCards(['As', 'Ks', 'Qs', 'Js', '9s', '2s', '3d']);
      final eval = HandEvaluator.evaluate(cards);
      expect(eval.rank, HandRank.flush);
      expect(eval.rankValue, [14, 13, 12, 11, 9]);
    });

    test('Select best 5 from 7: Two pairs with overlapping kicker', () {
      final cards = parseCards(['As', 'Ad', 'Ks', 'Kd', 'Qh', 'Qc', '3s']);
      final eval = HandEvaluator.evaluate(cards);
      expect(eval.rank, HandRank.twoPair);
      expect(eval.rankValue, [14, 13, 12]);
    });
  });
}
