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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('单机模式设置')),
      body: Padding(
        padding: const EdgeInsets.all(20),
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
            const Spacer(),
            ElevatedButton(
              onPressed: _startGame,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 50),
                backgroundColor: Colors.green[700],
              ),
              child: const Text('开始游戏', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 30),
          ],
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 16)),
              Text('$value $suffix', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: ((max - min) / step).round(),
            onChanged: onChanged,
            activeColor: Colors.green[400],
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
    final names = ['玩家1', ...List.generate(playerCount - 1, (i) => 'AI${i + 2}')];
    final controller = GameController(config: config, playerNames: names, humanPlayerId: 1);

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
