import 'card.dart';

class Player {
  final int id;
  final String name;
  int chips;
  List<Card> handCards = [];
  int currentBet = 0; // 当前下注轮次中已投入的筹码
  int totalBetThisRound = 0; // 整个下注轮累计下注（包括已投入）
  bool hasFolded = false;
  bool isAllIn = false;
  bool isDealer = false;
  bool isSmallBlind = false;
  bool isBigBlind = false;
  bool isActive = true; // 是否还在牌局中（未弃牌且未全下？实际由hasFolded和isAllIn综合判断，但保留）

  Player({required this.id, required this.name, required this.chips});

  /// 重置每手牌开始前的状态（保留筹码）
  void resetForNewHand() {
    handCards.clear();
    currentBet = 0;
    totalBetThisRound = 0;
    hasFolded = false;
    isAllIn = false;
    isDealer = false;
    isSmallBlind = false;
    isBigBlind = false;
    isActive = true;
  }

  /// 下注：从筹码中扣除，并增加本回合下注额
  void placeBet(int amount) {
    if (amount < 0) throw ArgumentError('Amount must be non-negative');
    if (amount > chips) throw Exception('Insufficient chips');
    chips -= amount;
    currentBet += amount;
    totalBetThisRound += amount;
  }

  /// 弃牌
  void fold() {
    hasFolded = true;
    isActive = false;
  }

  /// 全下：所有筹码下注
  int allIn() {
    final all = chips;
    placeBet(all);
    isAllIn = true;
    return all;
  }

  /// 是否仍在牌局中（未弃牌且未全下？全下也算在牌局中，但不再行动）
  bool get isStillInHand => !hasFolded && chips > 0; // 未弃牌且还有筹码（但全下后筹码为0，仍参与）
  // 更准确：未弃牌
  bool get isInHand => !hasFolded;
}
