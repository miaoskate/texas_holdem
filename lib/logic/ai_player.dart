import 'dart:math';

import '../models/player.dart';
import '../models/card.dart';
import 'game_controller.dart';
import 'hand_evaluator.dart';

/// 更主动、更具策略性的德州扑克 AI。
///
/// 特点：
/// - 更合理的 Preflop 起手牌评价
/// - Postflop 成牌评价
/// - 同花 / 顺子听牌判断
/// - Board Texture
/// - Pot Odds
/// - SPR
/// - Value Bet
/// - Semi-bluff
/// - Bluff
/// - 更主动的 Raise / Re-raise
/// - 合法下注金额保护
///
/// 注意：
/// 当前项目接口没有提供完整的 position / opponent history / betting history，
/// 因此本版本只使用当前 GameController 能够可靠取得的信息。
class AIPlayer {
  static final Random _random = Random();

  // ============================================================
  // AI 性格
  // ============================================================

  /// 总体攻击性。
  ///
  /// 0.30 = 保守
  /// 0.45 = 紧
  /// 0.55 = 标准
  /// 0.65 = 偏激进
  /// 0.72 = 激进
  /// 0.85 = 疯狂
  static const double aggression = 0.72;

  /// Bluff 频率。
  static const double bluffFrequency = 0.18;

  /// C-bet 倾向。
  static const double continuationBetFrequency = 0.68;

  /// 强牌主动下注倾向。
  static const double valueBetFrequency = 0.88;

  // ============================================================
  // 主入口
  // ============================================================

  static (ActionType action, int amount) decideAction(
    GameController controller,
    int playerId,
  ) {
    final player = controller.players.firstWhere((p) => p.id == playerId);

    if (!player.isInHand || player.isAllIn || player.chips <= 0) {
      throw Exception('AI玩家无法行动');
    }

    final int callAmount = max(0, controller.roundBet - player.currentBet);

    final int pot = max(0, controller.pot.totalAmount);

    final bool isPreflop = controller.phase == GamePhase.preflop;

    final int chips = player.chips;

    final int potAfterCall = pot + callAmount;

    final double potOdds = callAmount > 0
        ? callAmount / max(1, potAfterCall)
        : 0.0;

    final double strength = _evaluateStrength(
      player,
      controller.communityCards,
      isPreflop,
    );

    final _BoardInfo boardInfo = isPreflop
        ? const _BoardInfo.empty()
        : _analyzeBoard(player.handCards, controller.communityCards);

    final double spr = pot > 0 ? chips / pot : 99.0;

    final decision = _chooseAction(
      strength: strength,
      board: boardInfo,
      callAmount: callAmount,
      chips: chips,
      pot: pot,
      potOdds: potOdds,
      spr: spr,
      isPreflop: isPreflop,
      controller: controller,
    );

    return _sanitizeAction(decision, controller, player);
  }

  // ============================================================
  // 综合牌力
  // ============================================================

  static double _evaluateStrength(
    Player player,
    List<Card> community,
    bool preflop,
  ) {
    if (preflop) {
      return _preflopStrength(player.handCards);
    }

    final allCards = [...player.handCards, ...community];

    return _postflopStrength(player.handCards, community, allCards);
  }

  // ============================================================
  // Preflop
  // ============================================================

  static double _preflopStrength(List<Card> hand) {
    if (hand.length < 2) {
      return 0.0;
    }

    final int r1 = hand[0].rank.value;
    final int r2 = hand[1].rank.value;

    final int high = max(r1, r2);
    final int low = min(r1, r2);

    final bool pair = r1 == r2;
    final bool suited = hand[0].suit == hand[1].suit;

    final int gap = high - low;

    double score;

    if (pair) {
      // AA 接近 0.99
      // KK 接近 0.95
      // QQ 接近 0.92
      // JJ 接近 0.88
      // TT 接近 0.84
      // 22 接近 0.50
      score = 0.50 + ((high - 2) / 12.0) * 0.49;
    } else {
      score = 0.0;

      // 高牌
      score += ((high - 2) / 12.0) * 0.30;

      // 第二张牌
      score += ((low - 2) / 12.0) * 0.16;

      // A
      if (high == 14) {
        score += 0.12;
      }

      // Suited
      if (suited) {
        score += 0.09;
      }

      // Connector
      if (gap == 1) {
        score += 0.10;
      } else if (gap == 2) {
        score += 0.045;
      }

      // Broadway
      if (high >= 10 && low >= 10) {
        score += 0.08;
      }

      // AJ / AQ / AK
      if (high == 14 && low >= 10) {
        score += 0.12;
      }

      // Suited Ace
      if (high == 14 && suited) {
        score += 0.05;
      }

      // 小同花连牌
      if (suited && low >= 5 && gap <= 2) {
        score += 0.035;
      }
    }

    return score.clamp(0.02, 0.99);
  }

  // ============================================================
  // Postflop
  // ============================================================

  static double _postflopStrength(
    List<Card> holeCards,
    List<Card> community,
    List<Card> allCards,
  ) {
    final eval = HandEvaluator.evaluate(allCards);

    final int rankIndex = eval.rank.index;

    double madeHand;

    switch (rankIndex) {
      case 0:
        madeHand = 0.10;
        break;

      case 1:
        madeHand = 0.34;
        break;

      case 2:
        madeHand = 0.60;
        break;

      case 3:
        madeHand = 0.72;
        break;

      case 4:
        madeHand = 0.82;
        break;

      case 5:
        madeHand = 0.86;
        break;

      case 6:
        madeHand = 0.94;
        break;

      case 7:
        madeHand = 0.985;
        break;

      case 8:
        madeHand = 0.997;
        break;

      case 9:
        madeHand = 1.0;
        break;

      default:
        madeHand = 0.40;
    }

    // 高牌质量
    if (eval.rankValue.isNotEmpty) {
      final int topRank = eval.rankValue.first;

      if (rankIndex == 0 || rankIndex == 1) {
        madeHand += ((topRank - 2) / 12.0) * 0.10;
      }
    }

    final _BoardInfo board = _analyzeBoard(holeCards, community);

    double drawBonus = 0.0;

    if (board.flushDraw) {
      drawBonus += 0.10;
    }

    if (board.openEndedStraightDraw) {
      drawBonus += 0.09;
    }

    if (board.gutshotDraw) {
      drawBonus += 0.055;
    }

    if (board.doubleBackdoorPotential) {
      drawBonus += 0.025;
    }

    // 两张高牌
    if (board.overcards >= 2) {
      drawBonus += 0.055;
    } else if (board.overcards == 1) {
      drawBonus += 0.025;
    }

    double dangerPenalty = 0.0;

    if (board.flushPossible) {
      dangerPenalty += 0.025;
    }

    if (board.straightPossible) {
      dangerPenalty += 0.025;
    }

    if (board.pairedBoard) {
      dangerPenalty += 0.01;
    }

    return (madeHand + drawBonus - dangerPenalty).clamp(0.01, 1.0);
  }

  // ============================================================
  // Board 分析
  // ============================================================

  static _BoardInfo _analyzeBoard(List<Card> holeCards, List<Card> community) {
    if (community.isEmpty) {
      return const _BoardInfo.empty();
    }

    final List<int> ranks = [...community.map((c) => c.rank.value)];

    final List<int> allRanks = [
      ...ranks,
      ...holeCards.map((c) => c.rank.value),
    ];

    // ----------------------------------------------------------
    // 花色
    // ----------------------------------------------------------

    final Map<int, int> suitCounts = <int, int>{};

    for (final card in community) {
      final int key = card.suit.hashCode;

      suitCounts[key] = (suitCounts[key] ?? 0) + 1;
    }

    final Map<int, int> holeSuitCounts = <int, int>{};

    for (final card in holeCards) {
      final int key = card.suit.hashCode;

      holeSuitCounts[key] = (holeSuitCounts[key] ?? 0) + 1;
    }

    bool flushDraw = false;
    bool flushPossible = false;

    for (final entry in suitCounts.entries) {
      final int count = entry.value;

      if (count >= 3) {
        flushPossible = true;
      }

      if (count == 2) {
        final int holeCount = holeSuitCounts[entry.key] ?? 0;

        if (holeCount >= 1) {
          flushDraw = true;
        }
      }
    }

    if (suitCounts.values.any((value) => value >= 3)) {
      flushPossible = true;
    }

    // ----------------------------------------------------------
    // 顺子
    // ----------------------------------------------------------

    final List<int> uniqueRanks = allRanks.toSet().toList()..sort();

    // A 可以作为 1
    if (uniqueRanks.contains(14)) {
      uniqueRanks.add(1);
      uniqueRanks.sort();
    }

    int longestRun = 1;
    int currentRun = 1;

    for (int i = 1; i < uniqueRanks.length; i++) {
      if (uniqueRanks[i] == uniqueRanks[i - 1] + 1) {
        currentRun++;
        longestRun = max(longestRun, currentRun);
      } else {
        currentRun = 1;
      }
    }

    final bool straightPossible = longestRun >= 4;

    bool openEnded = false;
    bool gutshot = false;

    if (community.length >= 3) {
      final List<int> sorted = uniqueRanks;

      for (int start = 2; start <= 10; start++) {
        final List<int> window = [
          start,
          start + 1,
          start + 2,
          start + 3,
          start + 4,
        ];

        final int count = window.where(sorted.contains).length;

        if (count == 4) {
          final Iterable<int> missing = window.where(
            (x) => !sorted.contains(x),
          );

          if (missing.isNotEmpty) {
            final int missingRank = missing.first;

            if (missingRank == start || missingRank == start + 4) {
              openEnded = true;
            } else {
              gutshot = true;
            }
          }
        }
      }
    }

    // ----------------------------------------------------------
    // 公共牌对子
    // ----------------------------------------------------------

    final Map<int, int> pairCounts = <int, int>{};

    for (final int rank in ranks) {
      pairCounts[rank] = (pairCounts[rank] ?? 0) + 1;
    }

    final bool pairedBoard = pairCounts.values.any((value) => value >= 2);

    // ----------------------------------------------------------
    // Overcards
    // ----------------------------------------------------------

    final int boardHigh = community.map((c) => c.rank.value).reduce(max);

    final int overcards = holeCards
        .where((c) => c.rank.value > boardHigh)
        .length;

    // ----------------------------------------------------------
    // Backdoor
    // ----------------------------------------------------------

    final bool doubleBackdoorPotential =
        community.length == 3 &&
        !flushDraw &&
        !openEnded &&
        !gutshot &&
        holeCards.length >= 2 &&
        holeCards[0].suit == holeCards[1].suit;

    return _BoardInfo(
      flushDraw: flushDraw,
      flushPossible: flushPossible,
      straightPossible: straightPossible,
      openEndedStraightDraw: openEnded,
      gutshotDraw: gutshot,
      pairedBoard: pairedBoard,
      overcards: overcards,
      doubleBackdoorPotential: doubleBackdoorPotential,
    );
  }

  // ============================================================
  // 核心决策
  // ============================================================

  static (ActionType action, int amount) _chooseAction({
    required double strength,
    required _BoardInfo board,
    required int callAmount,
    required int chips,
    required int pot,
    required double potOdds,
    required double spr,
    required bool isPreflop,
    required GameController controller,
  }) {
    if (callAmount == 0) {
      return _whenNoBet(
        strength: strength,
        board: board,
        chips: chips,
        pot: pot,
        spr: spr,
        isPreflop: isPreflop,
        controller: controller,
      );
    }

    return _whenFacingBet(
      strength: strength,
      board: board,
      callAmount: callAmount,
      chips: chips,
      pot: pot,
      potOdds: potOdds,
      spr: spr,
      isPreflop: isPreflop,
      controller: controller,
    );
  }

  // ============================================================
  // 没人下注
  // ============================================================

  static (ActionType action, int amount) _whenNoBet({
    required double strength,
    required _BoardInfo board,
    required int chips,
    required int pot,
    required double spr,
    required bool isPreflop,
    required GameController controller,
  }) {
    // ----------------------------------------------------------
    // 怪兽牌
    // ----------------------------------------------------------

    if (strength >= 0.86) {
      if (_random.nextDouble() < valueBetFrequency) {
        return (
          ActionType.raise,
          _betSize(pot: pot, chips: chips, fraction: isPreflop ? 0.70 : 0.72),
        );
      }

      return (ActionType.check, 0);
    }

    // ----------------------------------------------------------
    // 强牌
    // ----------------------------------------------------------

    if (strength >= 0.68) {
      final double betChance = 0.68 + aggression * 0.18;

      if (_random.nextDouble() < betChance) {
        return (
          ActionType.raise,
          _betSize(pot: pot, chips: chips, fraction: 0.55),
        );
      }

      return (ActionType.check, 0);
    }

    // ----------------------------------------------------------
    // 中强牌
    // ----------------------------------------------------------

    if (strength >= 0.50) {
      double betChance = 0.38 + aggression * 0.25;

      if (board.flushDraw || board.openEndedStraightDraw || board.gutshotDraw) {
        betChance += 0.12;
      }

      if (_random.nextDouble() < betChance) {
        return (
          ActionType.raise,
          _betSize(
            pot: pot,
            chips: chips,
            fraction: board.flushDraw || board.openEndedStraightDraw
                ? 0.65
                : 0.50,
          ),
        );
      }

      return (ActionType.check, 0);
    }

    // ----------------------------------------------------------
    // 强听牌：Semi-bluff
    // ----------------------------------------------------------

    final bool strongDraw = board.flushDraw || board.openEndedStraightDraw;

    if (strongDraw) {
      final double semiBluffChance = 0.45 + aggression * 0.35;

      if (_random.nextDouble() < semiBluffChance) {
        return (
          ActionType.raise,
          _betSize(pot: pot, chips: chips, fraction: 0.60),
        );
      }
    }

    // ----------------------------------------------------------
    // Preflop 开池
    // ----------------------------------------------------------

    if (isPreflop) {
      if (strength >= 0.40) {
        if (_random.nextDouble() < 0.35 + aggression * 0.35) {
          return (ActionType.raise, _preflopBetSize(pot: pot, chips: chips));
        }
      }

      // 偷盲
      if (strength >= 0.27 && _random.nextDouble() < aggression * 0.18) {
        return (ActionType.raise, _preflopBetSize(pot: pot, chips: chips));
      }
    }

    // ----------------------------------------------------------
    // Bluff
    // ----------------------------------------------------------

    if (!isPreflop && _random.nextDouble() < bluffFrequency * aggression) {
      return (
        ActionType.raise,
        _betSize(pot: pot, chips: chips, fraction: 0.55),
      );
    }

    return (ActionType.check, 0);
  }

  // ============================================================
  // 面对下注
  // ============================================================

  static (ActionType action, int amount) _whenFacingBet({
    required double strength,
    required _BoardInfo board,
    required int callAmount,
    required int chips,
    required int pot,
    required double potOdds,
    required double spr,
    required bool isPreflop,
    required GameController controller,
  }) {
    // ----------------------------------------------------------
    // 无法完整跟注
    // ----------------------------------------------------------

    if (chips < callAmount) {
      if (strength >= 0.58 || board.flushDraw || board.openEndedStraightDraw) {
        return (ActionType.allIn, chips);
      }

      if (strength >= 0.28 && _random.nextDouble() < bluffFrequency * 0.25) {
        return (ActionType.allIn, chips);
      }

      return (ActionType.fold, 0);
    }

    // ----------------------------------------------------------
    // 超强牌
    // ----------------------------------------------------------

    if (strength >= 0.90) {
      if (spr <= 2.0 && _random.nextDouble() < 0.35 + aggression * 0.45) {
        return (ActionType.allIn, chips);
      }

      if (_random.nextDouble() < 0.82) {
        return (
          ActionType.raise,
          _raiseSize(
            pot: pot,
            callAmount: callAmount,
            chips: chips,
            fraction: 0.75,
          ),
        );
      }

      return (ActionType.call, callAmount);
    }

    // ----------------------------------------------------------
    // 强牌
    // ----------------------------------------------------------

    if (strength >= 0.75) {
      final double raiseChance = 0.48 + aggression * 0.35;

      if (_random.nextDouble() < raiseChance) {
        if (spr <= 1.5 && _random.nextDouble() < aggression * 0.65) {
          return (ActionType.allIn, chips);
        }

        return (
          ActionType.raise,
          _raiseSize(
            pot: pot,
            callAmount: callAmount,
            chips: chips,
            fraction: 0.65,
          ),
        );
      }

      return (ActionType.call, callAmount);
    }

    // ----------------------------------------------------------
    // 中强牌
    // ----------------------------------------------------------

    if (strength >= 0.58) {
      final bool draw = board.flushDraw || board.openEndedStraightDraw;

      if (draw && _random.nextDouble() < 0.25 + aggression * 0.45) {
        return (
          ActionType.raise,
          _raiseSize(
            pot: pot,
            callAmount: callAmount,
            chips: chips,
            fraction: 0.65,
          ),
        );
      }

      if (potOdds <= strength * 0.95) {
        return (ActionType.call, callAmount);
      }

      if (_random.nextDouble() < aggression * 0.16) {
        return (ActionType.call, callAmount);
      }

      return (ActionType.fold, 0);
    }

    // ----------------------------------------------------------
    // 中等牌
    // ----------------------------------------------------------

    if (strength >= 0.42) {
      final bool draw =
          board.flushDraw || board.openEndedStraightDraw || board.gutshotDraw;

      if (draw) {
        if (potOdds <= 0.40 || _random.nextDouble() < aggression * 0.25) {
          if (_random.nextDouble() < 0.25 + aggression * 0.30) {
            return (
              ActionType.raise,
              _raiseSize(
                pot: pot,
                callAmount: callAmount,
                chips: chips,
                fraction: 0.60,
              ),
            );
          }

          return (ActionType.call, callAmount);
        }
      }

      if (potOdds <= 0.28) {
        return (ActionType.call, callAmount);
      }

      final int cheapCallThreshold = max(1, pot ~/ 5);

      if (callAmount <= cheapCallThreshold && _random.nextDouble() < 0.82) {
        return (ActionType.call, callAmount);
      }

      // 偶尔反击
      if (!isPreflop && _random.nextDouble() < bluffFrequency * 0.45) {
        return (
          ActionType.raise,
          _raiseSize(
            pot: pot,
            callAmount: callAmount,
            chips: chips,
            fraction: 0.70,
          ),
        );
      }

      return (ActionType.fold, 0);
    }

    // ----------------------------------------------------------
    // Draw-only
    // ----------------------------------------------------------

    final bool strongDraw = board.flushDraw || board.openEndedStraightDraw;

    if (strongDraw) {
      if (potOdds <= 0.30) {
        if (_random.nextDouble() < 0.25 + aggression * 0.30) {
          return (
            ActionType.raise,
            _raiseSize(
              pot: pot,
              callAmount: callAmount,
              chips: chips,
              fraction: 0.65,
            ),
          );
        }

        return (ActionType.call, callAmount);
      }

      if (_random.nextDouble() < aggression * 0.20) {
        return (
          ActionType.raise,
          _raiseSize(
            pot: pot,
            callAmount: callAmount,
            chips: chips,
            fraction: 0.70,
          ),
        );
      }
    }

    // ----------------------------------------------------------
    // Gutshot
    // ----------------------------------------------------------

    if (board.gutshotDraw) {
      if (potOdds <= 0.18) {
        return (ActionType.call, callAmount);
      }

      if (_random.nextDouble() < bluffFrequency * aggression) {
        return (
          ActionType.raise,
          _raiseSize(
            pot: pot,
            callAmount: callAmount,
            chips: chips,
            fraction: 0.70,
          ),
        );
      }

      return (ActionType.fold, 0);
    }

    // ----------------------------------------------------------
    // 极弱牌
    // ----------------------------------------------------------

    final int tinyBetThreshold = max(1, pot ~/ 10);

    if (potOdds <= 0.10 && callAmount <= tinyBetThreshold) {
      return (ActionType.call, callAmount);
    }

    // Bluff
    if (!isPreflop &&
        _random.nextDouble() < bluffFrequency * aggression * 0.65) {
      return (
        ActionType.raise,
        _raiseSize(
          pot: pot,
          callAmount: callAmount,
          chips: chips,
          fraction: 0.75,
        ),
      );
    }

    return (ActionType.fold, 0);
  }

  // ============================================================
  // 普通下注
  // ============================================================

  static int _betSize({
    required int pot,
    required int chips,
    required double fraction,
  }) {
    if (chips <= 0) {
      return 0;
    }

    final int basePot = max(1, pot);

    int amount = (basePot * fraction).round();

    if (amount < 1) {
      amount = 1;
    }

    if (amount > chips) {
      amount = chips;
    }

    return amount;
  }

  // ============================================================
  // Preflop 开池
  // ============================================================

  static int _preflopBetSize({required int pot, required int chips}) {
    if (chips <= 0) {
      return 0;
    }

    final int base = max(1, pot);

    int amount = (base * 2.2).round();

    if (amount < 2) {
      amount = 2;
    }

    if (amount > chips) {
      amount = chips;
    }

    return amount;
  }

  // ============================================================
  // Raise
  // ============================================================

  static int _raiseSize({
    required int pot,
    required int callAmount,
    required int chips,
    required double fraction,
  }) {
    if (chips <= callAmount) {
      return chips;
    }

    final int basePot = max(1, pot + callAmount);

    int raiseBy = (basePot * fraction).round();

    if (raiseBy < callAmount) {
      raiseBy = callAmount;
    }

    int total = callAmount + raiseBy;

    if (total > chips) {
      total = chips;
    }

    return total;
  }

  // ============================================================
  // Action 安全处理
  // ============================================================

  static (ActionType action, int amount) _sanitizeAction(
    (ActionType action, int amount) decision,
    GameController controller,
    Player player,
  ) {
    final ActionType action = decision.$1;

    int amount = decision.$2;

    if (amount < 0) {
      amount = 0;
    }

    final int chips = player.chips;

    if (chips <= 0) {
      return (ActionType.check, 0);
    }

    // ----------------------------------------------------------
    // All-in
    // ----------------------------------------------------------

    if (action == ActionType.allIn) {
      return (ActionType.allIn, chips);
    }

    // ----------------------------------------------------------
    // Fold
    // ----------------------------------------------------------

    if (action == ActionType.fold) {
      return (ActionType.fold, 0);
    }

    // ----------------------------------------------------------
    // Check
    // ----------------------------------------------------------

    if (action == ActionType.check) {
      return (ActionType.check, 0);
    }

    final int callAmount = max(0, controller.roundBet - player.currentBet);

    // ----------------------------------------------------------
    // Call
    // ----------------------------------------------------------

    if (action == ActionType.call) {
      if (callAmount <= 0) {
        return (ActionType.check, 0);
      }

      if (chips <= callAmount) {
        return (ActionType.allIn, chips);
      }

      final int actualCall = callAmount < chips ? callAmount : chips;

      return (ActionType.call, actualCall);
    }

    // ----------------------------------------------------------
    // Raise
    // ----------------------------------------------------------

    if (action == ActionType.raise) {
      // 强制转换成 int，避免 Dart num/int 推断问题。
      final int minRaise = controller.minRaise.toInt();

      final int safeMinRaise = minRaise > 0 ? minRaise : 1;

      final int minTotal = controller.roundBet + safeMinRaise;

      final int maxTotal = player.currentBet + chips;

      // 无法完成合法最小加注
      if (maxTotal < minTotal) {
        if (callAmount >= chips) {
          return (ActionType.allIn, chips);
        }

        if (callAmount > 0) {
          return (ActionType.call, callAmount);
        }

        return (ActionType.check, 0);
      }

      // 明确使用 int 比较，避免 num 类型推断。
      if (amount < minTotal) {
        amount = minTotal;
      }

      if (amount > maxTotal) {
        amount = maxTotal;
      }

      // 接近全押
      if (amount >= maxTotal || maxTotal - amount <= safeMinRaise) {
        return (ActionType.allIn, chips);
      }

      return (ActionType.raise, amount);
    }

    return (ActionType.check, 0);
  }
}

// ============================================================
// Board 信息
// ============================================================

class _BoardInfo {
  final bool flushDraw;
  final bool flushPossible;
  final bool straightPossible;
  final bool openEndedStraightDraw;
  final bool gutshotDraw;
  final bool pairedBoard;
  final int overcards;
  final bool doubleBackdoorPotential;

  const _BoardInfo({
    required this.flushDraw,
    required this.flushPossible,
    required this.straightPossible,
    required this.openEndedStraightDraw,
    required this.gutshotDraw,
    required this.pairedBoard,
    required this.overcards,
    required this.doubleBackdoorPotential,
  });

  const _BoardInfo.empty()
    : flushDraw = false,
      flushPossible = false,
      straightPossible = false,
      openEndedStraightDraw = false,
      gutshotDraw = false,
      pairedBoard = false,
      overcards = 0,
      doubleBackdoorPotential = false;
}
