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

  final int? humanPlayerId;    // 人类玩家ID（单机模式）
  bool gameOver = false;       // 整局游戏是否结束
  Player? gameWinner;          // 游戏结束时获胜/筹码领先的玩家

  GameController({required this.config, required List<String> playerNames, this.humanPlayerId}) {
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
    if (gameOver) return;
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
        // 加注后的总下注额必须至少为：当前最高下注 + 最小加注额
        if (total < roundBet + minRaise) throw Exception('加注至少到 ${roundBet + minRaise}');
        if (total > player.chips + player.currentBet) throw Exception('筹码不足');
        final raiseAmount = total - player.currentBet;
        final raiseSize = total - roundBet; // 本次加注增量，作为新的最小加注额
        player.placeBet(raiseAmount);
        pot.totalAmount += raiseAmount;
        roundBet = total;
        minRaise = raiseSize;
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

    player.hasActedThisRound = true;
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

  /// 检查本轮是否结束：所有可行动玩家都已行动且下注相等
  void _checkRoundComplete() {
    if (handOver) return;

    // 如果只剩一位未弃牌玩家，直接获胜
    final active = players.where((p) => p.isInHand).toList();
    if (active.length <= 1) {
      _endHandWithWinner(active.isNotEmpty ? active.first : null);
      return;
    }

    // 没有可行动的玩家（全部全下），直接推进阶段
    final canActPlayers = players.where(_canAct).toList();
    if (canActPlayers.isEmpty) {
      _advancePhase();
      return;
    }

    // 本轮结束条件：所有可行动玩家都已行动，且下注额都与当前最高下注相等。
    // 翻牌前大盲因 hasActedThisRound 尚为 false，自然获得最后的行动权（过牌或加注）；
    // 有人加注后，其他玩家 currentBet < roundBet，需要重新行动。
    final roundComplete = canActPlayers
        .every((p) => p.hasActedThisRound && p.currentBet == roundBet);
    if (roundComplete) {
      _advancePhase();
    }
  }

  /// 进入下一阶段，循环推进直到有可行动的玩家或游戏结束
  void _advancePhase() {
    while (!handOver) {
      switch (phase) {
        case GamePhase.preflop:
          communityCards = [deck.deal(), deck.deal(), deck.deal()];
          phase = GamePhase.flop;
          break;
        case GamePhase.flop:
          communityCards.add(deck.deal());
          phase = GamePhase.turn;
          break;
        case GamePhase.turn:
          communityCards.add(deck.deal());
          phase = GamePhase.river;
          break;
        case GamePhase.river:
          phase = GamePhase.showdown;
          _showdown();
          return; // _showdown 会调用 notifyListeners
        default:
          return;
      }

      // 重置本轮下注状态，从庄家下家（小盲位）开始新一轮行动
      for (var p in players) {
        p.currentBet = 0;
        p.hasActedThisRound = false;
      }
      roundBet = 0;
      minRaise = config.bigBlind;
      currentPlayerIndex = (dealerIndex + 1) % players.length;
      _skipToNextActivePlayer();

      // 可下注玩家不足2人（其余全下或弃牌）时无法再下注，
      // 继续发完剩余公共牌直到摊牌
      if (players.where(_canAct).length >= 2) {
        notifyListeners();
        return;
      }
    }
  }

  void _skipToNextActivePlayer() {
    int attempts = 0;
    while (currentPlayerIndex >= 0 && !_canAct(players[currentPlayerIndex])) {
      currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
      attempts++;
      if (attempts > players.length) {
        currentPlayerIndex = -1;
        break;
      }
    }
    // 不再在此处调用 _advancePhase，避免递归级联
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
      winAmounts![p.id] = p.chips;
    }
    notifyListeners();
    _autoStartNextHand();
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
    _autoStartNextHand();
  }

  /// 自动开始下一手牌；玩家破产或分出胜负时结束整局游戏
  void _autoStartNextHand() {
    final playersWithChips = players.where((p) => p.chips > 0).toList();

    // 人类玩家筹码归零，游戏结束（失败）
    if (humanPlayerId != null) {
      final human = players.where((p) => p.id == humanPlayerId).toList();
      if (human.isNotEmpty && human.first.chips == 0) {
        gameOver = true;
        gameWinner = playersWithChips.isNotEmpty
            ? playersWithChips.reduce((a, b) => a.chips >= b.chips ? a : b)
            : null;
        notifyListeners();
        return;
      }
    }

    // 只剩一位玩家有筹码，游戏结束（分出胜负）
    if (playersWithChips.length < 2) {
      gameOver = true;
      gameWinner = playersWithChips.length == 1 ? playersWithChips.first : null;
      notifyListeners();
      return;
    }

    // 延迟启动下一手牌：保留 3 秒展示赢家高亮（金色边框）后再开始
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (!hasListeners || gameOver) return;
      startNewHand();
    });
  }
}
