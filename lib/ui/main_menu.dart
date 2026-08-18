import 'package:flutter/material.dart';
import 'single_player_setup.dart';

class MainMenu extends StatelessWidget {
  const MainMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('德州扑克'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '选择游戏模式',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 60),
            _buildMenuButton(
              context,
              label: '🎯 单机模式',
              subtitle: '与 AI 对战',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SinglePlayerSetup()),
                );
              },
            ),
            const SizedBox(height: 20),
            _buildMenuButton(
              context,
              label: '🌐 联机模式',
              subtitle: '敬请期待',
              enabled: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context,
      {required String label, required String subtitle, VoidCallback? onTap, bool enabled = true}) {
    return SizedBox(
      width: 300,
      child: Card(
        color: enabled ? Colors.green[800] : Colors.blueGrey[700]?.withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: enabled ? Colors.white : Colors.white38,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: enabled ? Colors.white70 : Colors.white38,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
