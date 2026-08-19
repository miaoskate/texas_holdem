import 'package:flutter/material.dart';
import '../models/game_config.dart';
import '../logic/game_controller.dart';
import 'table_screen.dart';

class SinglePlayerSetup extends StatefulWidget {
  const SinglePlayerSetup({super.key});

  @override
  State<SinglePlayerSetup> createState() => _SinglePlayerSetupState();
}

class _SinglePlayerSetupState extends State<SinglePlayerSetup> {
  int playerCount = 6;
  int startingChips = 1000;
  int smallBlind = 10;

  static const _backgroundTop = Color(0xFF123B25);
  static const _backgroundBottom = Color(0xFF071810);
  static const _cardColor = Color(0xFF11261A);
  static const _accent = Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundBottom,
      appBar: AppBar(
        title: const Text(
          '单机模式设置',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_backgroundTop, _backgroundBottom],
          ),
        ),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildIntroCard(context),
                        const SizedBox(height: 16),
                        _buildSettingsCard(context),
                        const SizedBox(height: 20),
                        _buildStartButton(context),
                        if (constraints.maxHeight > 680)
                          const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildIntroCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor.withOpacity(0.86),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.tune_rounded,
            color: Colors.white,
            size: 28,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '牌局设置',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '调整人数、筹码与盲注，创建你的单机牌局。',
                  style: TextStyle(
                    color: Colors.white60,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      decoration: BoxDecoration(
        color: _cardColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        children: [
          _buildSliderRow(
            label: '总人数（含玩家）',
            value: playerCount,
            min: 2,
            max: 9,
            onChanged: (v) => setState(() => playerCount = v.round()),
          ),
          _buildSliderRow(
            label: '起始筹码',
            value: startingChips,
            min: 100,
            max: 10000,
            step: 100,
            onChanged: (v) => setState(() => startingChips = v.round()),
            suffix: '💰',
          ),
          _buildSliderRow(
            label: '小盲注',
            value: smallBlind,
            min: 5,
            max: 100,
            step: 5,
            onChanged: (v) => setState(() => smallBlind = v.round()),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ElevatedButton.icon(
        onPressed: _startGame,
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text(
          '开始游戏',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<double> onChanged,
    int step = 1,
    String suffix = '',
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$value $suffix',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _accent,
              inactiveTrackColor: Colors.white12,
              thumbColor: Colors.white,
              overlayColor: _accent.withOpacity(0.16),
              trackHeight: 4,
            ),
            child: Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: ((max - min) / step).round(),
              onChanged: onChanged,
              semanticFormatterCallback: (v) => '${v.round()}',
            ),
          ),
        ],
      ),
    );
  }

  void _startGame() {
    final config = GameConfig(
      startingChips: startingChips,
      smallBlind: smallBlind,
      playerCount: playerCount,
    );

    // 生成玩家名称：玩家1（人类），AI2, AI3, ...
    final names = [
      '玩家1',
      ...List.generate(playerCount - 1, (i) => 'AI${i + 2}'),
    ];
    final controller = GameController(
      config: config,
      playerNames: names,
      humanPlayerId: 1,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TableScreen(
          controller: controller,
          isNetworkGame: false,
          playerId: 1, // 玩家1是人类
        ),
      ),
    );
  }
}
