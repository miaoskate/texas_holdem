import 'package:flutter/material.dart';
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

  static const _tableTop = Color(0xFF16562F);
  static const _tableBottom = Color(0xFF061A10);
  static const _panelColor = Color(0xCC0A2316);

  static const _foldColor = Color(0xFFFF5252);
  static const _checkColor = Color(0xFF4FC3F7);
  static const _callColor = Color(0xFF81C784);
  static const _raiseColor = Color(0xFFFFB74D);
  static const _allInColor = Color(0xFFBA68C8);

  @override
  void initState() {
    super.initState();

    if (widget.isNetworkGame) {
      // 网络模式：客户端通过 networkManager 监听状态。
      widget.networkManager?.client?.onGameStateUpdate = (state) {
        if (!mounted) return;
        setState(() {});
      };
    } else {
      _controller = widget.controller;

      if (_controller != null && !_controller!.handOver) {
        _controller!.addListener(_onControllerChanged);
        _controller!.startNewHand();
      }
    }
  }

  void _onControllerChanged() {
    if (!mounted || _controller == null) return;

    setState(() {});

    // 整局游戏结束：弹出结算框，不再继续 AI 流程。
    if (_controller!.gameOver) {
      if (!_gameOverShown) {
        _gameOverShown = true;
        _isProcessing = false;
        _showGameOverDialog();
      }
      return;
    }

    // 如果轮到 AI 且没有正在处理的 AI 行动，自动执行。
    if (!widget.isNetworkGame && !_isProcessing) {
      final current = _controller!.currentPlayer;
      if (current != null && current.id != widget.playerId) {
        _isProcessing = true;
        _executeAIAction();
      }
    }
  }

  /// 执行 AI 行动，递归处理连续 AI 回合。
  /// _isProcessing 在整个 AI 行动链中保持为 true，防止竞态条件。
  Future<void> _executeAIAction({int retryCount = 0}) async {
    final controller = _controller;
    if (!mounted || controller == null) return;

    // 延迟一段时间模拟思考。
    await Future.delayed(const Duration(milliseconds: 850));
    if (!mounted || _controller == null) return;

    final current = _controller!.currentPlayer;
    if (current == null ||
        current.id == widget.playerId ||
        _controller!.handOver) {
      _isProcessing = false;
      if (mounted) setState(() {});
      return;
    }

    try {
      final (action, amount) =
          AIPlayer.decideAction(_controller!, current.id);
      _controller!.playerAction(
        current.id,
        action,
        amount: amount,
      );
    } catch (e) {
      // 防止无限重试（连续 3 次出错则停止本次 AI 链）。
      if (retryCount < 3 && mounted) {
        await _executeAIAction(retryCount: retryCount + 1);
        return;
      }

      _isProcessing = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI 行动失败，本回合已停止自动处理。'),
          ),
        );
        setState(() {});
      }
      return;
    }

    if (!mounted || _controller == null) return;

    // AI 行动后，检查是否还有 AI 需要继续行动。
    // _isProcessing 保持 true，防止 _onControllerChanged 重复触发。
    final next = _controller!.currentPlayer;
    if (next != null &&
        next.id != widget.playerId &&
        !_controller!.handOver) {
      await _executeAIAction();
    } else {
      _isProcessing = false;
      if (mounted) setState(() {});
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
      return const Scaffold(
        body: Center(
          child: Text('游戏未初始化'),
        ),
      );
    }

    if (_controller == null && widget.isNetworkGame) {
      return Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_tableTop, _tableBottom],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final controller = _controller!;
    controller.getGameState();
    final currentPlayer = controller.currentPlayer;
    final isMyTurn =
        currentPlayer != null && currentPlayer.id == widget.playerId;
    final myPlayer = controller.players.firstWhere(
      (p) => p.id == widget.playerId,
    );

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_tableTop, _tableBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(controller),
              Expanded(
                child: _buildTableArea(controller),
              ),
              if (!widget.isNetworkGame || widget.playerId > 0)
                _buildBottomArea(
                  controller,
                  isMyTurn,
                  myPlayer,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(GameController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: _panelColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withOpacity(0.07),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: '返回主菜单',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 6,
                children: [
                  _buildInfoChip(
                    icon: Icons.layers_rounded,
                    label: _phaseLabel(controller.phase),
                  ),
                  _buildInfoChip(
                    icon: Icons.account_balance_wallet_rounded,
                    label: '底池 ${controller.pot.totalAmount}',
                    highlighted: true,
                  ),
                  _buildInfoChip(
                    icon: Icons.payments_rounded,
                    label: '当前下注 ${controller.roundBet}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    bool highlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: highlighted
            ? Colors.amber.withOpacity(0.12)
            : Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: highlighted ? Colors.amberAccent : Colors.white60,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: highlighted ? 15 : 14,
              fontWeight:
                  highlighted ? FontWeight.w800 : FontWeight.w600,
              color: highlighted ? Colors.amberAccent : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _phaseLabel(GamePhase phase) {
    switch (phase) {
      case GamePhase.preflop:
        return '翻牌前';
      case GamePhase.flop:
        return '翻牌';
      case GamePhase.turn:
        return '转牌';
      case GamePhase.river:
        return '河牌';
      case GamePhase.showdown:
        return '摊牌';
    }
  }

  Widget _buildCommunityCards(GameController controller) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '公共牌',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          controller.communityCards.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    '等待发牌…',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 15,
                    ),
                  ),
                )
              : Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final card in controller.communityCards)
                      CardWidget(
                        card: card,
                        faceUp: true,
                        size: 118,
                      ),
                  ],
                ),
        ],
      ),
    );
  }

  /// 牌桌区域：其他玩家在上方居中排列，人类玩家固定底部，公共牌居中。
  /// 空间不足时自动滚动，避免 RenderFlex 溢出。
  Widget _buildTableArea(GameController controller) {
    final players = controller.players;
    final humanIndex =
        players.indexWhere((p) => p.id == widget.playerId);
    final human =
        humanIndex >= 0 ? players[humanIndex] : players.first;
    final others =
        players.where((p) => p.id != human.id).toList();

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight - 8,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (others.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: others
                        .map((p) => _buildSeat(controller, p))
                        .toList(),
                  ),
                ),
              _buildCommunityCards(controller),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _buildSeat(controller, human),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeat(GameController controller, Player p) {
    final isMe = p.id == widget.playerId;
    final isWinner = controller.handOver &&
        (controller.winners?.any((w) => w.id == p.id) ?? false);

    return PlayerSeat(
      player: p,
      isMe: isMe,
      isCurrent: controller.currentPlayer?.id == p.id,
      showCards:
          isMe || controller.phase == GamePhase.showdown,
      isWinner: isWinner,
    );
  }

  /// 底部区域：状态提示在左下角，操作按钮靠右下角排列。
  Widget _buildBottomArea(
    GameController controller,
    bool isMyTurn,
    Player myPlayer,
  ) {
    Widget status;
    if (controller.handOver) {
      status = _buildStatusBadge(
        text: '本局结束',
        icon: Icons.flag_rounded,
        color: Colors.amber,
      );
    } else if (isMyTurn) {
      status = _buildStatusBadge(
        text: _isProcessing ? '正在处理…' : '轮到你行动',
        icon: Icons.touch_app_rounded,
        color: Colors.cyanAccent,
      );
    } else {
      status = _buildStatusBadge(
        text: _isProcessing ? 'AI 正在思考…' : '等待其他玩家行动…',
        icon: Icons.hourglass_top_rounded,
        color: Colors.white70,
      );
    }

    final List<Widget> buttons = [];
    if (!controller.handOver && isMyTurn && !_isProcessing) {
      final callAmount =
          controller.roundBet - myPlayer.currentBet;
      final canCheck = callAmount == 0;
      final canCall =
          callAmount > 0 && myPlayer.chips >= callAmount;
      final canRaise = myPlayer.chips + myPlayer.currentBet >
          controller.roundBet + controller.minRaise;
      final canAllIn = myPlayer.chips > 0;

      buttons.add(
        ActionButton(
          label: '弃牌',
          onPressed: () async =>
              _doAction(controller, ActionType.fold),
          color: _foldColor,
        ),
      );

      if (canCheck) {
        buttons.add(
          ActionButton(
            label: '过牌',
            onPressed: () async =>
                _doAction(controller, ActionType.check),
            color: _checkColor,
          ),
        );
      }

      if (canCall) {
        buttons.add(
          ActionButton(
            label: '跟注 $callAmount',
            onPressed: () async => _doAction(
              controller,
              ActionType.call,
              amount: callAmount,
            ),
            color: _callColor,
          ),
        );
      }

      if (canRaise) {
        buttons.add(
          ActionButton(
            label: '加注',
            onPressed: () =>
                _showRaiseDialog(controller, myPlayer),
            color: _raiseColor,
          ),
        );
      }

      if (canAllIn) {
        buttons.add(
          ActionButton(
            label: '全下',
            onPressed: () async =>
                _doAction(controller, ActionType.allIn),
            color: _allInColor,
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: _panelColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.07),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 760;

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  status,
                  if (buttons.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 10,
                        runSpacing: 8,
                        children: buttons,
                      ),
                    ),
                  ],
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: status),
                if (buttons.isNotEmpty) ...[
                  const SizedBox(width: 14),
                  Flexible(
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 10,
                      runSpacing: 8,
                      children: buttons,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusBadge({
    required String text,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _doAction(
    GameController controller,
    ActionType action, {
    int amount = 0,
  }) {
    try {
      controller.playerAction(
        widget.playerId,
        action,
        amount: amount,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('操作失败: $e'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  /// 整局游戏结束结算弹窗。
  void _showGameOverDialog() {
    final controller = _controller!;
    final won = controller.gameWinner != null &&
        controller.gameWinner!.id == widget.playerId;
    final winnerName = controller.gameWinner?.name ?? '无';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
        title: Row(
          children: [
            Icon(
              won
                  ? Icons.emoji_events_rounded
                  : Icons.sports_score_rounded,
              color: won ? Colors.amber : Colors.blueGrey,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(won ? '游戏胜利' : '游戏结束'),
            ),
          ],
        ),
        content: Text(
          won
              ? '你赢走了所有筹码，成为最后的赢家！'
              : '你的筹码已归零。\n最终赢家：$winnerName',
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(dialogContext)
                  .popUntil((route) => route.isFirst),
              child: const Text('返回主菜单'),
            ),
          ),
        ],
      ),
    );
  }

  /// 加注对话框：Future 在对话框关闭后完成。
  Future<void> _showRaiseDialog(
    GameController controller,
    Player player,
  ) async {
    final minTotal =
        controller.roundBet + controller.minRaise;
    final maxTotal =
        player.chips + player.currentBet;
    int selected = minTotal;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          int safeValue(int value) {
            return value.clamp(minTotal, maxTotal);
          }

          Widget preset(String label, int value) {
            return ActionButton(
              label: label,
              color: Colors.blueGrey,
              compact: true,
              onPressed: () async {
                setDialogState(
                  () => selected = safeValue(value),
                );
              },
            );
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text('选择加注金额'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 520,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '加注到 $selected',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '需投入 ${selected - player.currentBet} 筹码',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.green,
                      thumbColor: Colors.green,
                      overlayColor:
                          Colors.green.withOpacity(0.12),
                    ),
                    child: Slider(
                      value: selected.toDouble(),
                      min: minTotal.toDouble(),
                      max: maxTotal.toDouble(),
                      divisions: maxTotal - minTotal,
                      label: '$selected',
                      onChanged: (v) => setDialogState(
                        () => selected = v.round(),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '范围: $minTotal ~ $maxTotal',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      preset('最小 $minTotal', minTotal),
                      preset(
                        '半池',
                        controller.roundBet +
                            controller.pot.totalAmount ~/ 2,
                      ),
                      preset(
                        '底池',
                        controller.roundBet +
                            controller.pot.totalAmount,
                      ),
                      preset('全下 $maxTotal', maxTotal),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _doAction(
                    controller,
                    ActionType.raise,
                    amount: selected,
                  );
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
