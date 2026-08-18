import 'player.dart';

class Pot {
  int totalAmount = 0;
  List<SidePot> sidePots = [];

  /// 记录每个玩家的下注（在每一轮下注结束后调用，用于计算边池）
  /// 输入：所有活跃玩家的下注额（currentBet）
  void calculateSidePots(List<Player> players) {
    // 过滤出还在牌局中的玩家（未弃牌）
    final activePlayers = players.where((p) => p.isInHand).toList();
    if (activePlayers.isEmpty) return;

    // 按照 currentBet 从小到大排序
    activePlayers.sort((a, b) => a.currentBet.compareTo(b.currentBet));

    List<SidePot> newSidePots = [];
    int totalChipsInPot = 0;

    // 遍历每个玩家，累积边池
    // 算法：每个玩家下注额不同，产生边池
    // 标准德州扑克边池计算：从最小下注开始，每个玩家贡献的筹码进入主池，然后次小下注减去上次的，进入下一个边池，等等。
    // 实现参考：https://www.pokernews.com/poker-rules/pot-calculation.htm
    // 思路：按下注额排序，从最小到最大，每次取差值 * 剩余玩家人数。
    int currentLevel = 0;
    int remainingPlayers = activePlayers.length;

    for (int i = 0; i < activePlayers.length; i++) {
      final player = activePlayers[i];
      final bet = player.currentBet;
      if (bet > currentLevel) {
        final diff = bet - currentLevel;
        final sidePotAmount = diff * remainingPlayers;
        if (sidePotAmount > 0) {
          final eligible = activePlayers.sublist(i); // 从当前玩家开始（包括）都参与了此边池
          newSidePots.add(SidePot(
            amount: sidePotAmount,
            eligiblePlayerIds: eligible.map((p) => p.id).toList(),
          ));
        }
        currentLevel = bet;
      }
      remainingPlayers--;
    }

    sidePots = newSidePots;
    // 总底池为所有边池之和
    totalAmount = sidePots.fold(0, (sum, pot) => sum + pot.amount);
  }

  /// 重置底池
  void reset() {
    totalAmount = 0;
    sidePots.clear();
  }
}

class SidePot {
  final int amount;
  final List<int> eligiblePlayerIds; // 有资格参与这个边池的玩家ID列表

  SidePot({required this.amount, required this.eligiblePlayerIds});
}
