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
              // 底部区域：状态提示（左下）+ 独立操作按钮（右下角）
              if (!widget.isNetworkGame || widget.playerId > 0)
                _buildBottomArea(controller, isMyTurn, myPlayer),
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
            // FittedBox 防止窄窗口下信息行水平溢出
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text('阶段: ${controller.phase.name}', style: const TextStyle(fontSize: 18, color: Colors.white)),
                  const SizedBox(width: 24),
                  Text('底池: ${controller.pot.totalAmount}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.yellow)),
                  const SizedBox(width: 24),
                  Text('当前下注: ${controller.roundBet}', style: const TextStyle(fontSize: 16, color: Colors.white70)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityCards(GameController controller) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green[900]?.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: controller.communityCards.isEmpty
          ? const Text('等待发牌...', style: TextStyle(color: Colors.white70))
          : Wrap(
              // 使用 Wrap 防止窄屏溢出
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final card in controller.communityCards)
                  CardWidget(card: card, faceUp: true, size: 112), // 原 80 放大 40%
              ],
            ),
    );
  }

  /// 牌桌区域：其他玩家在上方居中排列，人类玩家固定底部，公共牌居中。
  /// 空间充足时垂直均布；不足时（如翻牌阶段公共牌出现后）自动变为可滚动，
  /// 避免 RenderFlex 溢出（界面出现黄黑斜条纹）。
  Widget _buildTableArea(GameController controller) {
    final players = controller.players;
    final humanIndex = players.indexWhere((p) => p.id == widget.playerId);
    final human = humanIndex >= 0 ? players[humanIndex] : players.first;
    final others = players.where((p) => p.id != human.id).toList();

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              // 公共牌
              _buildCommunityCards(controller),
              // 人类玩家
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildSeat(controller, human),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建单个玩家座位
  Widget _buildSeat(GameController controller, Player p) {
    final isMe = p.id == widget.playerId;
    // 本手牌赢家：高亮其手牌（持续至新一手开始）
    final isWinner =
        controller.handOver && (controller.winners?.any((w) => w.id == p.id) ?? false);
    return PlayerSeat(
      player: p,
      isMe: isMe,
      isCurrent: controller.currentPlayer?.id == p.id,
      showCards: isMe || controller.phase == GamePhase.showdown,
      isWinner: isWinner,
    );
  }

  // 操作按钮默认高亮色（未按下状态）
  static const _foldColor = Color(0xFFFF5252);  // 弃牌：亮红
  static const _checkColor = Color(0xFF4FC3F7); // 过牌：亮蓝
  static const _callColor = Color(0xFF81C784);  // 跟注：亮绿
  static const _raiseColor = Color(0xFFFFB74D); // 加注：亮橙
  static const _allInColor = Color(0xFFBA68C8); // 全下：亮紫

  /// 底部区域：状态提示在左下角，操作按钮（独立元素）靠右下角排列
  Widget _buildBottomArea(GameController controller, bool isMyTurn, Player myPlayer) {
    // 左下角状态提示
    Widget status;
    if (controller.handOver) {
      status = const Text('本局结束', style: TextStyle(color: Colors.yellow, fontSize: 18));
    } else if (isMyTurn) {
      status = const Text('轮到你行动', style: TextStyle(color: Colors.cyan, fontSize: 16));
    } else {
      status = const Text('等待其他玩家行动...', style: TextStyle(color: Colors.white70, fontSize: 16));
    }

    // 右下角操作按钮：每个按钮为独立元素（无集群容器）
    final List<Widget> buttons = [];
    if (!controller.handOver && isMyTurn) {
      final callAmount = controller.roundBet - myPlayer.currentBet;
      final canCheck = callAmount == 0;
      final canCall = callAmount > 0 && myPlayer.chips >= callAmount;
      // 只有筹码足够最小加注（加注到 roundBet + minRaise）时才显示加注按钮，
      // 否则只能全下（避免加注对话框出现最小值大于最大值的非法区间）
      final canRaise = myPlayer.chips + myPlayer.currentBet > controller.roundBet + controller.minRaise;
      final canAllIn = myPlayer.chips > 0;

      buttons.add(ActionButton(
        label: '弃牌',
        onPressed: () async => _doAction(controller, ActionType.fold),
        color: _foldColor,
      ));
      if (canCheck) {
        buttons.add(ActionButton(
          label: '过牌',
          onPressed: () async => _doAction(controller, ActionType.check),
          color: _checkColor,
        ));
      }
      if (canCall) {
        buttons.add(ActionButton(
          label: '跟注 $callAmount',
          onPressed: () async => _doAction(controller, ActionType.call, amount: callAmount),
          color: _callColor,
        ));
      }
      if (canRaise) {
        buttons.add(ActionButton(
          label: '加注',
          // 对话框关闭（确认/取消）前按钮保持变灰
          onPressed: () => _showRaiseDialog(controller, myPlayer),
          color: _raiseColor,
        ));
      }
      if (canAllIn) {
        buttons.add(ActionButton(
          label: '全下',
          onPressed: () async => _doAction(controller, ActionType.allIn),
          color: _allInColor,
        ));
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: status,
            ),
          ),
          Flexible(
            child: buttons.isEmpty
                ? const SizedBox.shrink()
                : Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 10,
                    children: buttons,
                  ),
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

  /// 加注对话框：返回的 Future 在对话框关闭（确认/取消）时完成，
  /// 期间"加注"按钮保持变灰状态
  Future<void> _showRaiseDialog(GameController controller, Player player) async {
    final minTotal = controller.roundBet + controller.minRaise;
    final maxTotal = player.chips + player.currentBet;
    int selected = minTotal;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          // 快捷加注预设按钮（对话框内使用紧凑尺寸）
          Widget preset(String label, int value) => ActionButton(
                label: label,
                color: Colors.blueGrey,
                compact: true,
                onPressed: () async => setDialogState(() {
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
