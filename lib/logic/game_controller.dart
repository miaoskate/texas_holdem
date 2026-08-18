import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/card.dart';
import '../models/deck.dart';
import '../models/player.dart';
import '../models/pot.dart';
import '../models/game_config.dart';
import 'hand_evaluator.dart';

/// 游戏阶段
enum GamePhase { preflop, flop, turn, river, showdown }

/// 玩家动作类型
enum ActionType { fold, check, call, raise, allIn }

/// 动作记录
class ActionRecord {
  final int playerId;
  final ActionType action;
  final int amount;
  final String description;
  ActionRecord({required this.playerId, required this.action, required this.amount, required this.description});
}

/// 游戏控制器 - 核心状态机
class GameController extends ChangeNotifier {
  final GameConfig config;
  List<Player> players = [];
  Deck deck = Deck();
  Pot pot = Pot();

  GamePhase phase = GamePhase.preflop;
  List<Card> communityCards = [];
  int dealerIndex = 0;
  int currentPlayerIndex = 0;
  int roundBet = 0;          // 当前轮次最高下注额
  int minRaise = 0;          // 最小加注额
  List<ActionRecord> actionHistory = [];
  bool handOver = false;

  // 结果信息（可为空）
  List<Player>? winners;
  Map<int, int>? winAmounts;   // 可空，使用时需判空或初始化

  GameController({required this.config, required List<String> playerNames}) {
    _initPlayers(playerNames);
  }

  void _initPlayers(List<String> names) {
    if (names.length < 2 || names.length > config.maxPlayers) {
      throw ArgumentError('玩家数量必须在2~${config.maxPlayers}之间');
    }
    players = List.generate(
      names.length,
      (i) => Player(id: i + 1, name: names[i], chips: config.startingChips),
    );
  }

  Player? get currentPlayer =>
      (currentPlayerIndex >= 0 && currentPlayerIndex < players.length)
          ? players[currentPlayerIndex]
          : null;

  /// 获取游戏状态（用于UI/网络）
  Map<String, dynamic> getGameState() => {
    'phase': phase.name,
    'community_cards': communityCards.map((c) => c.toString()).toList(),
    'players': players.map((p) => {
      'id': p.id,
      'name': p.name,
      'chips': p.chips,
      'bet': p.currentBet,
      'total_bet': p.totalBetThisRound,
      'has_folded': p.hasFolded,
      'is_all_in': p.isAllIn,
      'is_dealer': p.isDealer,
      'is_small_blind': p.isSmallBlind,
      'is_big_blind': p.isBigBlind,
      'is_active': p.isInHand,
      'cards': p.handCards.map((c) => c.toString()).toList(),
    }).toList(),
    'pot': pot.totalAmount,
    'side_pots': pot.sidePots.map((sp) => {
      'amount': sp.amount,
      'eligible_players': sp.eligiblePlayerIds,
    }).toList(),
    'current_player_id': currentPlayer?.id,
    'current_bet': roundBet,
    'min_raise': minRaise,
    'action_history': actionHistory.map((a) => a.description).toList(),
  };

  /// 开始一手新牌
  void startNewHand() {
    // 重置玩家状态（保留筹码）
    for (var p in players) p.resetForNewHand();
    deck = Deck()..shuffle();
    pot.reset();
    communityCards.clear();
    actionHistory.clear();
    handOver = false;
    winners = null;
    winAmounts = null;
    roundBet = 0;
    minRaise = config.bigBlind;
    phase = GamePhase.preflop;

    // 移动庄家
    dealerIndex = (dealerIndex + 1) % players.length;
    players[dealerIndex].isDealer = true;

    // 设置盲注
    final smallIdx = (dealerIndex + 1) % players.length;
    final bigIdx = (dealerIndex + 2) % players.length;
    players[smallIdx].isSmallBlind = true;
    players[bigIdx].isBigBlind = true;

    _postBlind(smallIdx, config.smallBlind);
    _postBlind(bigIdx, config.bigBlind);

    // 发底牌
    for (var p in players) {
      p.handCards = [deck.deal(), deck.deal()];
    }

    // 翻牌前从大盲下家开始行动
    currentPlayerIndex = (bigIdx + 1) % players.length;
    roundBet = config.bigBlind;
    minRaise = config.bigBlind;

    // 跳过全下或弃牌的玩家（但刚开局没有）
    _skipToNextActivePlayer();

    notifyListeners();
  }

  void _postBlind(int idx, int amount) {
    final p = players[idx];
    final actual = amount > p.chips ? p.chips : amount;
    p.placeBet(actual);
    pot.totalAmount += actual;
    if (p.chips == 0) p.isAllIn = true;
  }

  /// 处理玩家动作
  void playerAction(int playerId, ActionType action, {int amount = 0}) {
    if (handOver) throw StateError('本手牌已结束');
    final player = players.firstWhere((p) => p.id == playerId);
    if (player != currentPlayer) throw Exception('不是该玩家的行动回合');
    if (player.hasFolded || player.isAllIn) throw Exception('玩家无法行动');

    String desc;
    switch (action) {
      case ActionType.fold:
        player.fold();
        desc = '${player.name} 弃牌';
        actionHistory.add(ActionRecord(playerId: playerId, action: action, amount: 0, description: desc));
        _advanceToNextPlayer();
        break;

      case ActionType.check:
        if (player.currentBet != roundBet) throw Exception('必须跟注或加注');
        desc = '${player.name} 过牌';
        actionHistory.add(ActionRecord(playerId: playerId, action: action, amount: 0, description: desc));
        _advanceToNextPlayer();
        break;

      case ActionType.call:
        final callAmount = roundBet - player.currentBet;
        if (callAmount > player.chips) throw Exception('筹码不足，请选择全下');
        player.placeBet(callAmount);
        pot.totalAmount += callAmount;
        desc = '${player.name} 跟注 $callAmount';
        actionHistory.add(ActionRecord(playerId: playerId, action: action, amount: callAmount, description: desc));
        _advanceToNextPlayer();
        break;

      case ActionType.raise:
        final total = amount;
        if (total <= player.currentBet + minRaise) throw Exception('加注至少为 ${player.currentBet + minRaise}');
        if (total > player.chips + player.currentBet) throw Exception('筹码不足');
        final raiseAmount = total - player.currentBet;
        player.placeBet(raiseAmount);
        pot.totalAmount += raiseAmount;
        roundBet = total;
        minRaise = total - player.currentBet;
        desc = '${player.name} 加注到 $total';
        actionHistory.add(ActionRecord(playerId: playerId, action: action, amount: raiseAmount, description: desc));
        _advanceToNextPlayer();
        break;

      case ActionType.allIn:
        final allAmount = player.chips;
        player.allIn();
        pot.totalAmount += allAmount;
        if (player.currentBet > roundBet) {
          roundBet = player.currentBet;
        }
        desc = '${player.name} 全下 $allAmount';
        actionHistory.add(ActionRecord(playerId: playerId, action: action, amount: allAmount, description: desc));
        _advanceToNextPlayer();
        break;
    }

    _checkRoundComplete();
    notifyListeners();
  }

  /// 跳到下一个可行动的玩家
  void _advanceToNextPlayer() {
    if (handOver) return;
    int nextIdx = currentPlayerIndex;
    int attempts = 0;
    do {
      nextIdx = (nextIdx + 1) % players.length;
      attempts++;
      if (attempts > players.length) {
        currentPlayerIndex = -1;
        return;
      }
    } while (!_canAct(players[nextIdx]));
    currentPlayerIndex = nextIdx;
  }

  bool _canAct(Player p) => p.isInHand && !p.isAllIn && p.chips > 0;

  /// 检查本轮是否结束
  void _checkRoundComplete() {
    if (handOver) return;

    // 如果只剩一位活跃玩家，直接获胜
    final active = players.where((p) => p.isInHand).toList();
    if (active.length <= 1) {
      _endHandWithWinner(active.isNotEmpty ? active.first : null);
      return;
    }

    // 检查是否所有可行动的玩家都已行动且下注相等
    final canActPlayers = players.where(_canAct).toList();
    if (canActPlayers.isEmpty) {
      // 没有可行动的玩家（全部全下或弃牌），进入摊牌
      _advancePhase();
      return;
    }

    // 如果所有可行动玩家都已行动（即 actionCount 已达到可行动人数），并且下注相等，则阶段结束
    // 我们维护一个简单的计数器：每次 action 后递增，但加注会重置
    // 更可靠的方法：检查是否每个人都已行动且下注相等
    final allActed = canActPlayers.every((p) => p.currentBet == roundBet);
    if (allActed) {
      _advancePhase();
    }
  }

  /// 进入下一阶段
  void _advancePhase() {
    switch (phase) {
      case GamePhase.preflop:
        // 发翻牌
        communityCards = [deck.deal(), deck.deal(), deck.deal()];
        phase = GamePhase.flop;
        _resetForNewRound();
        break;
      case GamePhase.flop:
        communityCards.add(deck.deal());
        phase = GamePhase.turn;
        _resetForNewRound();
        break;
      case GamePhase.turn:
        communityCards.add(deck.deal());
        phase = GamePhase.river;
        _resetForNewRound();
        break;
      case GamePhase.river:
        phase = GamePhase.showdown;
        _showdown();
        break;
      default:
        break;
    }
    notifyListeners();
  }

  /// 重置一轮（清除下注，更新盲注等）
  void _resetForNewRound() {
    // 重置所有玩家当前下注
    for (var p in players) p.currentBet = 0;
    roundBet = 0;
    minRaise = config.bigBlind;
    // 从庄家下家开始
    currentPlayerIndex = (dealerIndex + 1) % players.length;
    _skipToNextActivePlayer();
  }

  void _skipToNextActivePlayer() {
    int start = currentPlayerIndex;
    int attempts = 0;
    while (!_canAct(players[currentPlayerIndex])) {
      currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
      attempts++;
      if (attempts > players.length) {
        currentPlayerIndex = -1;
        break;
      }
    }
    if (currentPlayerIndex == -1) {
      // 没有可行动的玩家，直接摊牌
      _advancePhase();
    }
  }

  /// 摊牌
  void _showdown() {
    final active = players.where((p) => p.isInHand).toList();
    if (active.length <= 1) {
      _endHandWithWinner(active.isNotEmpty ? active.first : null);
      return;
    }

    final evaluations = <int, HandEvaluation>{};
    for (var p in active) {
      final allCards = [...p.handCards, ...communityCards];
      evaluations[p.id] = HandEvaluator.evaluate(allCards);
    }

    // 排序找出最高牌型
    active.sort((a, b) => HandEvaluation.compare(evaluations[b.id]!, evaluations[a.id]!));
    final best = active.first;
    final winnersList = <Player>[];
    for (var p in active) {
      if (HandEvaluation.compare(evaluations[p.id]!, evaluations[best.id]!) == 0) {
        winnersList.add(p);
      }
    }

    // 分配底池
    _distributePot(winnersList);

    handOver = true;
    winners = winnersList;
    winAmounts = {};
    for (var p in winnersList) {
      winAmounts![p.id] = p.chips; // 注意：这里 winAmounts! 是安全的，因为刚赋值
    }
    notifyListeners();
  }

  /// 分配底池（含边池）
  void _distributePot(List<Player> winners) {
    // 计算边池（只针对未弃牌玩家）
    final activePlayers = players.where((p) => p.isInHand).toList();
    pot.calculateSidePots(activePlayers);

    for (var sidePot in pot.sidePots) {
      final eligibleWinners = winners.where((w) => sidePot.eligiblePlayerIds.contains(w.id)).toList();
      if (eligibleWinners.isNotEmpty) {
        final share = sidePot.amount ~/ eligibleWinners.length;
        for (var w in eligibleWinners) {
          w.chips += share;
        }
      }
    }
  }

  /// 因弃牌结束
  void _endHandWithWinner(Player? winner) {
    if (winner != null) {
      winner.chips += pot.totalAmount;
      handOver = true;
      winners = [winner];
      winAmounts = {winner.id: pot.totalAmount};
      actionHistory.add(ActionRecord(
        playerId: winner.id,
        action: ActionType.fold,
        amount: 0,
        description: '${winner.name} 赢得底池 ${pot.totalAmount}',
      ));
    } else {
      handOver = true;
    }
    notifyListeners();
  }
}
