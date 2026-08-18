import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../logic/game_controller.dart';
import '../logic/ai_player.dart';
import '../models/player.dart';
import '../network/network_manager.dart';
import 'widgets/card_widget.dart';
import 'widgets/player_seat.dart';
import 'widgets/action_button.dart';

class TableScreen extends StatefulWidget {
  final GameController? controller;
  final bool isNetworkGame;
  final int playerId;
  final NetworkManager? networkManager;

  const TableScreen({
    super.key,
    required this.controller,
    required this.isNetworkGame,
    required this.playerId,
    this.networkManager,
  });

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  GameController? _controller;
  bool _isProcessing = false;
  bool _gameOverShown = false;

  @override
  void initState() {
    super.initState();
    if (widget.isNetworkGame) {
      // 网络模式：客户端通过networkManager监听状态
      widget.networkManager?.client?.onGameStateUpdate = (state) {
        setState(() {});
      };
    } else {
      // 单机模式
      _controller = widget.controller;
      // 启动第一手牌（如果尚未开始）
      if (_controller != null && !_controller!.handOver) {
        // 先添加监听器，再启动游戏，确保初始状态变化能被捕获
        _controller!.addListener(_onControllerChanged);
        _controller!.startNewHand();
      }
    }
  }

  void _onControllerChanged() {
    setState(() {});
    // 整局游戏结束：弹出结算框，不再继续AI流程
    if (_controller != null && _controller!.gameOver) {
      if (!_gameOverShown) {
        _gameOverShown = true;
        _isProcessing = false;
        _showGameOverDialog();
      }
      return;
    }
    // 如果轮到AI且没有正在处理的AI行动，自动执行
    if (!widget.isNetworkGame && _controller != null && !_isProcessing) {
      final current = _controller!.currentPlayer;
      if (current != null && current.id != widget.playerId) {
        _isProcessing = true;
        _executeAIAction();
      }
    }
  }

  /// 执行AI行动，递归处理连续AI回合
  /// _isProcessing 在整个AI行动链中保持为true，防止竞态条件
  Future<void> _executeAIAction({int retryCount = 0}) async {
    if (_controller == null) return;
    // 延迟1秒模拟思考
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    // 再次确认当前玩家仍然是AI（可能已被用户操作改变）
    final current = _controller!.currentPlayer;
    if (current == null || current.id == widget.playerId || _controller!.handOver) {
      _isProcessing = false;
      if (mounted) setState(() {});
      return;
    }

    try {
      final (action, amount) = AIPlayer.decideAction(_controller!, current.id);
      _controller!.playerAction(current.id, action, amount: amount);
    } catch (e) {
      // 防止无限重试（连续3次出错则跳过AI）
      if (retryCount < 3) {
        _executeAIAction(retryCount: retryCount + 1);
        return;
      }
    }

    // AI行动后，检查是否还有AI需要继续行动
    // _isProcessing 保持true不重置，防止 _onControllerChanged 重复触发
    if (mounted) {
      final next = _controller!.currentPlayer;
      if (next != null && next.id != widget.playerId) {
        _executeAIAction();
      } else {
        _isProcessing = false;
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null && !widget.isNetworkGame) {
      return const Scaffold(body: Center(child: Text('游戏未初始化')));
    }
    if (_controller == null && widget.isNetworkGame) {
      // 网络模式：等待服务器状态
      return const Scaffold(body: Center(child: Text('等待游戏状态...')));
    }

    final controller = _controller!;
    final state = controller.getGameState();
    final currentPlayer = controller.currentPlayer;
    final isMyTurn = currentPlayer != null && currentPlayer.id == widget.playerId;
    final myPlayer = controller.players.firstWhere((p) => p.id == widget.playerId);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF1a4a2a), const Color(0xFF0d2618)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 顶部信息：阶段、底池
              _buildTopBar(controller),
              // 牌桌区域（玩家围绕公共牌）
              Expanded(child: _buildTableArea(controller)),
              // 操作按钮
              if (!widget.isNetworkGame || widget.playerId > 0)
                _buildActionButtons(controller, isMyTurn, myPlayer),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(GameController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // 返回按钮
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
            tooltip: '返回主菜单',
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text('阶段: ${controller.phase.name}', style: const TextStyle(fontSize: 18, color: Colors.white)),
                Text('底池: ${controller.pot.totalAmount}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.yellow)),
                Text('当前下注: ${controller.roundBet}', style: const TextStyle(fontSize: 16, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityCards(GameController controller) {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green[900]?.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: controller.communityCards.isEmpty
            ? [const Text('等待发牌...', style: TextStyle(color: Colors.white70))]
            : controller.communityCards
                .map((card) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: CardWidget(card: card, faceUp: true, size: 80),
                    ))
                .toList(),
      ),
    );
  }

  /// 牌桌区域：其他玩家在上方居中排列，人类玩家固定居中
  Widget _buildTableArea(GameController controller) {
    final players = controller.players;
    final humanIndex = players.indexWhere((p) => p.id == widget.playerId);
    final human = humanIndex >= 0 ? players[humanIndex] : players.first;
    final others = players.where((p) => p.id != human.id).toList();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 其他玩家：居中自动换行
        if (others.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              alignment: WrapAlignment.center,
              runSpacing: 8,
              children: others.map((p) => _buildSeat(controller, p)).toList(),
            ),
          ),
        const Spacer(),
        // 公共牌
        _buildCommunityCards(controller),
        const Spacer(),
        // 人类玩家居中
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildSeat(controller, human),
        ),
      ],
    );
  }

  /// 构建单个玩家座位
  Widget _buildSeat(GameController controller, Player p) {
    final isMe = p.id == widget.playerId;
    return PlayerSeat(
      player: p,
      isMe: isMe,
      isCurrent: controller.currentPlayer?.id == p.id,
      showCards: isMe || controller.phase == GamePhase.showdown,
    );
  }

  Widget _buildActionButtons(GameController controller, bool isMyTurn, Player myPlayer) {
    if (controller.handOver) {
      return const Text('本局结束', style: TextStyle(color: Colors.yellow, fontSize: 18));
    }
    if (!isMyTurn) {
      return const Text('等待其他玩家行动...', style: TextStyle(color: Colors.white70));
    }

    final callAmount = controller.roundBet - myPlayer.currentBet;
    final canCheck = callAmount == 0;
    final canCall = callAmount > 0 && myPlayer.chips >= callAmount;
    // 只有筹码足够最小加注（加注到 roundBet + minRaise）时才显示加注按钮，
    // 否则只能全下（避免加注对话框出现最小值大于最大值的非法区间）
    final canRaise = myPlayer.chips + myPlayer.currentBet > controller.roundBet + controller.minRaise;
    final canAllIn = myPlayer.chips > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ActionButton(
            label: '弃牌',
            onPressed: () => _doAction(controller, ActionType.fold),
            color: Colors.red,
          ),
          const SizedBox(width: 12),
          if (canCheck)
            ActionButton(
              label: '过牌',
              onPressed: () => _doAction(controller, ActionType.check),
              color: Colors.blue,
            ),
          if (canCall)
            ActionButton(
              label: '跟注 $callAmount',
              onPressed: () => _doAction(controller, ActionType.call, amount: callAmount),
              color: Colors.green,
            ),
          if (canRaise)
            ActionButton(
              label: '加注',
              onPressed: () => _showRaiseDialog(controller, myPlayer),
              color: Colors.orange,
            ),
          if (canAllIn)
            ActionButton(
              label: '全下',
              onPressed: () => _doAction(controller, ActionType.allIn),
              color: Colors.purple,
            ),
        ],
      ),
    );
  }

  void _doAction(GameController controller, ActionType action, {int amount = 0}) {
    try {
      controller.playerAction(widget.playerId, action, amount: amount);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// 整局游戏结束结算弹窗
  void _showGameOverDialog() {
    final controller = _controller!;
    final won = controller.gameWinner != null && controller.gameWinner!.id == widget.playerId;
    final winnerName = controller.gameWinner?.name ?? '无';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(won ? '🎉 游戏胜利' : '💸 游戏结束'),
        content: Text(won
            ? '你赢走了所有筹码，成为最后的赢家！'
            : '你的筹码已归零。最终赢家：$winnerName'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).popUntil((route) => route.isFirst),
            child: const Text('返回主菜单'),
          ),
        ],
      ),
    );
  }

  void _showRaiseDialog(GameController controller, Player player) {
    final minTotal = controller.roundBet + controller.minRaise;
    final maxTotal = player.chips + player.currentBet;
    int selected = minTotal;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          // 快捷加注预设按钮
          Widget preset(String label, int value) => ActionButton(
                label: label,
                color: Colors.blueGrey,
                onPressed: () => setDialogState(() {
                  selected = value.clamp(minTotal, maxTotal);
                }),
              );

          return AlertDialog(
            title: const Text('选择加注金额'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '加注到 $selected',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.green),
                ),
                const SizedBox(height: 4),
                Text(
                  '需投入 ${selected - player.currentBet} 筹码',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: selected.toDouble(),
                  min: minTotal.toDouble(),
                  max: maxTotal.toDouble(),
                  divisions: maxTotal - minTotal,
                  label: '$selected',
                  onChanged: (v) => setDialogState(() => selected = v.round()),
                ),
                Text(
                  '范围: $minTotal ~ $maxTotal',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    preset('最小 $minTotal', minTotal),
                    preset('半池', controller.roundBet + controller.pot.totalAmount ~/ 2),
                    preset('底池', controller.roundBet + controller.pot.totalAmount),
                    preset('全下 $maxTotal', maxTotal),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _doAction(controller, ActionType.raise, amount: selected);
                },
                child: const Text('确认加注'),
              ),
            ],
          );
        },
      ),
    );
  }
}
