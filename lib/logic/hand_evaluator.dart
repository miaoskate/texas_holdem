import '../models/card.dart';

/// 牌型等级（从低到高）
enum HandRank {
  highCard,
  onePair,
  twoPair,
  threeOfAKind,
  straight,
  flush,
  fullHouse,
  fourOfAKind,
  straightFlush,
  royalFlush,
}

/// 评估结果
class HandEvaluation {
  final HandRank rank;
  final List<Card> bestCards; // 正好 5 张
  final List<int> rankValue; // 用于同牌型比较的关键值（从最重要到次重要）

  HandEvaluation({
    required this.rank,
    required this.bestCards,
    required this.rankValue,
  });

  /// 比较两个牌型，返回 -1（a < b），0（相等），1（a > b）
  static int compare(HandEvaluation a, HandEvaluation b) {
    if (a.rank.index != b.rank.index) {
      return a.rank.index.compareTo(b.rank.index);
    }
    // 牌型相同，比较 rankValue 列表（逐个比较）
    for (int i = 0; i < a.rankValue.length && i < b.rankValue.length; i++) {
      if (a.rankValue[i] != b.rankValue[i]) {
        return a.rankValue[i].compareTo(b.rankValue[i]);
      }
    }
    return 0; // 完全相同（平分）
  }
}

class HandEvaluator {
  /// 从 7 张牌中选出最佳 5 张牌并评估牌型
  static HandEvaluation evaluate(List<Card> cards) {
    if (cards.length < 5) {
      throw ArgumentError('At least 5 cards required');
    }
    // 取前 7 张（如果传入超过 7 张则截断，但通常传入 7 张）
    final List<Card> sevenCards = cards.take(7).toList();

    // 生成所有 C(7,5) = 21 种组合
    final combinations = _getCombinations(sevenCards, 5);

    HandEvaluation? best;
    for (var combo in combinations) {
      final eval = _evaluateFive(combo);
      if (best == null || HandEvaluation.compare(eval, best) > 0) {
        best = eval;
      }
    }
    return best!;
  }

  /// 从 n 个元素中选取 k 个的所有组合
  static List<List<Card>> _getCombinations(List<Card> items, int k) {
    if (k == 0) return [[]];
    if (items.isEmpty) return [];
    final first = items[0];
    final rest = items.sublist(1);
    final withFirst = _getCombinations(rest, k - 1).map((c) => [first, ...c]).toList();
    final withoutFirst = _getCombinations(rest, k);
    return [...withFirst, ...withoutFirst];
  }

  /// 评估正好 5 张牌的牌型（核心逻辑）
  static HandEvaluation _evaluateFive(List<Card> cards) {
    if (cards.length != 5) {
      throw ArgumentError('Must be exactly 5 cards');
    }

    // 按点数从大到小排序
    final sorted = List<Card>.from(cards)
      ..sort((a, b) => b.rank.value.compareTo(a.rank.value));

    final ranks = sorted.map((c) => c.rank.value).toList();
    final suits = sorted.map((c) => c.suit).toList();

    final isFlush = suits.toSet().length == 1;

    // 判断顺子 (使用去重后的点数，避免重复点数的干扰)
    bool isStraight = false;
    List<int> straightRanks = [];

    // 获取所有不同的点数，并降序排列
    final uniqueRanks = ranks.toSet().toList()..sort((a, b) => b.compareTo(a));

    // 检查是否存在连续 5 个不同点数
    for (int i = 0; i <= uniqueRanks.length - 5; i++) {
      if (uniqueRanks[i] - uniqueRanks[i + 4] == 4) {
        isStraight = true;
        straightRanks = uniqueRanks.sublist(i, i + 5);
        break;
      }
    }

    // 特殊顺子 A-2-3-4-5 (A=14 当作 1)
    if (!isStraight &&
        uniqueRanks.contains(14) &&
        uniqueRanks.contains(2) &&
        uniqueRanks.contains(3) &&
        uniqueRanks.contains(4) &&
        uniqueRanks.contains(5)) {
      isStraight = true;
      straightRanks = [5, 4, 3, 2, 1]; // 最小顺子，比较值用 5
    }

    // 统计点数出现次数
    Map<int, int> rankCount = {};
    for (var r in ranks) {
      rankCount[r] = (rankCount[r] ?? 0) + 1;
    }
    final counts = rankCount.values.toList()..sort((a, b) => b.compareTo(a));

    // 重新整理唯一点数列表（已降序）
    final uniqueRanksSorted = rankCount.keys.toList()..sort((a, b) => b.compareTo(a));

    // 1. 皇家同花顺 & 同花顺
    if (isFlush && isStraight) {
      if (straightRanks.first == 14) {
        // A-high 同花顺 = 皇家同花顺
        return HandEvaluation(
          rank: HandRank.royalFlush,
          bestCards: sorted,
          rankValue: [14],
        );
      } else {
        return HandEvaluation(
          rank: HandRank.straightFlush,
          bestCards: sorted,
          rankValue: [straightRanks.first],
        );
      }
    }

    // 2. 四条
    if (counts.contains(4)) {
      final fourRank = rankCount.entries.firstWhere((e) => e.value == 4).key;
      final kicker = uniqueRanksSorted.firstWhere((r) => r != fourRank);
      final bestCards = sorted.where((c) => c.rank.value == fourRank).toList()
        ..addAll(sorted.where((c) => c.rank.value == kicker).take(1));
      return HandEvaluation(
        rank: HandRank.fourOfAKind,
        bestCards: bestCards,
        rankValue: [fourRank, kicker],
      );
    }

    // 3. 葫芦
    if (counts.contains(3) && counts.contains(2)) {
      final threeRank = rankCount.entries.firstWhere((e) => e.value == 3).key;
      final pairRank = rankCount.entries.firstWhere((e) => e.value == 2).key;
      final bestCards = sorted.where((c) => c.rank.value == threeRank).toList()
        ..addAll(sorted.where((c) => c.rank.value == pairRank).take(2));
      return HandEvaluation(
        rank: HandRank.fullHouse,
        bestCards: bestCards,
        rankValue: [threeRank, pairRank],
      );
    }

    // 4. 同花
    if (isFlush) {
      return HandEvaluation(
        rank: HandRank.flush,
        bestCards: sorted.take(5).toList(),
        rankValue: ranks.take(5).toList(),
      );
    }

    // 5. 顺子
    if (isStraight) {
      // 特殊顺子 A-2-3-4-5 的最高牌是 5
      final high = straightRanks.first;
      return HandEvaluation(
        rank: HandRank.straight,
        bestCards: sorted,
        rankValue: [high],
      );
    }

    // 6. 三条
    if (counts.contains(3)) {
      final threeRank = rankCount.entries.firstWhere((e) => e.value == 3).key;
      final kickers = uniqueRanksSorted.where((r) => r != threeRank).take(2).toList();
      final bestCards = sorted.where((c) => c.rank.value == threeRank).toList()
        ..addAll(sorted.where((c) => c.rank.value == kickers[0]).take(1))
        ..addAll(sorted.where((c) => c.rank.value == kickers[1]).take(1));
      return HandEvaluation(
        rank: HandRank.threeOfAKind,
        bestCards: bestCards,
        rankValue: [threeRank, ...kickers],
      );
    }

    // 7. 两对
    if (counts.where((c) => c == 2).length == 2) {
      final pairs = rankCount.entries
          .where((e) => e.value == 2)
          .map((e) => e.key)
          .toList()
        ..sort((a, b) => b.compareTo(a));
      final kicker = uniqueRanksSorted.firstWhere((r) => !pairs.contains(r));
      final bestCards = sorted.where((c) => pairs.contains(c.rank.value)).toList()
        ..addAll(sorted.where((c) => c.rank.value == kicker).take(1));
      return HandEvaluation(
        rank: HandRank.twoPair,
        bestCards: bestCards,
        rankValue: [...pairs, kicker],
      );
    }

    // 8. 一对
    if (counts.contains(2)) {
      final pairRank = rankCount.entries.firstWhere((e) => e.value == 2).key;
      final kickers = uniqueRanksSorted.where((r) => r != pairRank).take(3).toList();
      final bestCards = sorted.where((c) => c.rank.value == pairRank).toList()
        ..addAll(sorted.where((c) => c.rank.value == kickers[0]).take(1))
        ..addAll(sorted.where((c) => c.rank.value == kickers[1]).take(1))
        ..addAll(sorted.where((c) => c.rank.value == kickers[2]).take(1));
      return HandEvaluation(
        rank: HandRank.onePair,
        bestCards: bestCards,
        rankValue: [pairRank, ...kickers],
      );
    }

    // 9. 高牌
    return HandEvaluation(
      rank: HandRank.highCard,
      bestCards: sorted.take(5).toList(),
      rankValue: ranks.take(5).toList(),
    );
  }
}
