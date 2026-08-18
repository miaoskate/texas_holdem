import 'dart:math';
import '../models/player.dart';
import '../models/card.dart';
import 'game_controller.dart';
import 'hand_evaluator.dart';

/// AI 决策器
class AIPlayer {
  static final Random _random = Random();

  /// 主决策方法，返回 (action, amount)
  static (ActionType action, int amount) decideAction(
    GameController controller,
    int playerId,
  ) {
    final player = controller.players.firstWhere((p) => p.id == playerId);
    if (!player.isInHand || player.isAllIn || player.chips == 0) {
      throw Exception('AI玩家无法行动');
    }

    final callAmount = controller.roundBet - player.currentBet;
    final potTotal = controller.pot.totalAmount;
    final isPreflop = controller.phase == GamePhase.preflop;

    // 1. 评估手牌强度
    final strength = _evaluateHandStrength(player, controller.communityCards, isPreflop);

    // 2. 计算底池赔率
    final potOdds = callAmount > 0 ? callAmount / (potTotal + callAmount) : 0.0;

    // 3. 根据强度决定行动
    return _chooseAction(strength, callAmount, player.chips, potOdds, isPreflop);
  }

  static double _evaluateHandStrength(Player player, List<Card> community, bool preflop) {
    if (preflop) {
      return _preflopStrength(player.handCards);
    } else {
      final allCards = [...player.handCards, ...community];
      return _postflopStrength(allCards);
    }
  }

  static double _preflopStrength(List<Card> hand) {
    final r1 = hand[0].rank.value;
    final r2 = hand[1].rank.value;
    final high = max(r1, r2);
    final low = min(r1, r2);
    final isPair = r1 == r2;
    final isSuited = hand[0].suit == hand[1].suit;
    final isConnector = (high - low) <= 2;
    final isAce = high == 14;

    double score = 0.0;
    if (isPair) {
      score += 0.6 + (high - 2) / 12 * 0.4;
    } else {
      score += (high - 2) / 12 * 0.3;
      score += (low - 2) / 12 * 0.15;
      if (isSuited) score += 0.1;
      if (isConnector) score += 0.05;
      if (isAce) score += 0.05;
    }
    return score.clamp(0.0, 1.0);
  }

  static double _postflopStrength(List<Card> allCards) {
    final eval = HandEvaluator.evaluate(allCards);
    final rankIndex = eval.rank.index;
    double base = 0.0;
    switch (rankIndex) {
      case 0: // high card
        base = 0.15 + (eval.rankValue.first - 2) / 14 * 0.15;
        break;
      case 1: // pair
        base = 0.35 + (eval.rankValue.first - 2) / 14 * 0.25;
        break;
      case 2: // two pair
        base = 0.60 + (eval.rankValue[0] - 2) / 14 * 0.15;
        break;
      case 3: // three of a kind
        base = 0.70 + (eval.rankValue.first - 2) / 14 * 0.15;
        break;
      case 4: // straight
        base = 0.80 + (eval.rankValue.first - 5) / 10 * 0.1;
        break;
      case 5: // flush
        base = 0.80 + (eval.rankValue.first - 2) / 14 * 0.1;
        break;
      case 6: // full house
        base = 0.88 + (eval.rankValue[0] - 2) / 14 * 0.1;
        break;
      case 7: // four of a kind
        base = 0.95;
        break;
      case 8: // straight flush
        base = 0.98;
        break;
      case 9: // royal flush
        base = 1.0;
        break;
      default: base = 0.5;
    }
    return base.clamp(0.0, 1.0);
  }

  static (ActionType action, int amount) _chooseAction(
    double strength,
    int callAmount,
    int chips,
    double potOdds,
    bool preflop,
  ) {
    // 如果筹码不足且必须行动（callAmount > 0）
    if (callAmount > 0 && chips < callAmount) {
      // 如果牌力不太弱（>0.25），全下；否则弃牌（偶尔诈唬全下）
      if (strength > 0.25 || _random.nextDouble() < 0.05) {
        return (ActionType.allIn, chips);
      } else {
        return (ActionType.fold, 0);
      }
    }

    // 强牌（>0.75）：加注或全下
    if (strength > 0.75) {
      final raiseSize = (0.5 + 0.5 * _random.nextDouble()) * (callAmount + 50);
      final amount = (callAmount + raiseSize).floor();
      if (amount > chips) return (ActionType.allIn, chips);
      return (ActionType.raise, amount);
    }

    // 中等牌（0.35~0.75）
    if (strength >= 0.35) {
      if (callAmount > 0 && potOdds > strength * 0.8) {
        if (_random.nextDouble() < 0.1) {
          if (_random.nextDouble() < 0.3) {
            final raiseAmount = (callAmount + 20 + _random.nextInt(60)).floor();
            if (raiseAmount > chips) return (ActionType.allIn, chips);
            return (ActionType.raise, raiseAmount);
          } else {
            return (ActionType.call, callAmount);
          }
        }
        return (ActionType.fold, 0);
      }
      if (callAmount == 0) {
        return (ActionType.check, 0);
      } else {
        return (ActionType.call, callAmount);
      }
    }

    // 弱牌（<0.35）
    if (callAmount > 0) {
      if (potOdds > 0.5 && _random.nextDouble() < 0.2) {
        final raiseAmount = (callAmount + 50).floor();
        if (raiseAmount > chips) return (ActionType.allIn, chips);
        return (ActionType.raise, raiseAmount);
      }
      if (callAmount < 20 && _random.nextDouble() < 0.3) {
        return (ActionType.call, callAmount);
      }
      return (ActionType.fold, 0);
    } else {
      return (ActionType.check, 0);
    }
  }
}
