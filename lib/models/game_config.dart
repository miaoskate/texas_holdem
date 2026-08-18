class GameConfig {
  final int startingChips;
  final int smallBlind;
  final int playerCount; // 总人数（包括玩家）
  final int maxPlayers;

  GameConfig({
    required this.startingChips,
    required this.smallBlind,
    required this.playerCount,
    this.maxPlayers = 9,
  });

  int get bigBlind => smallBlind * 2;
}
