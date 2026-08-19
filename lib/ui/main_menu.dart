import 'package:flutter/material.dart';
import 'single_player_setup.dart';

class MainMenu extends StatelessWidget {
  const MainMenu({super.key});

  static const _backgroundTop = Color(0xFF123B25);
  static const _backgroundBottom = Color(0xFF071810);
  static const _primary = Color(0xFF2E8B57);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_backgroundTop, _backgroundBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    _buildBrandHeader(theme),
                    const SizedBox(height: 48),
                    _buildMenuButton(
                      context,
                      label: '🎯 单机模式',
                      subtitle: '与 AI 对战',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SinglePlayerSetup(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildMenuButton(
                      context,
                      label: '🌐 联机模式',
                      subtitle: '敬请期待',
                      enabled: false,
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'TEXAS HOLD’EM',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white38,
                        letterSpacing: 3.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader(ThemeData theme) {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.08),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
            ),
          ),
          child: const Icon(
            Icons.style_rounded,
            size: 42,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '德州扑克',
          style: theme.textTheme.displaySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '选择游戏模式开始对局',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required String label,
    required String subtitle,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final backgroundColor = enabled
        ? Color.alphaBlend(
            primaryColor.withOpacity(0.18),
            const Color(0xFF10291B),
          )
        : Colors.white.withOpacity(0.045);

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: enabled
                ? _primary.withOpacity(0.45)
                : Colors.white.withOpacity(0.08),
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(enabled ? 0.1 : 0.04),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    label.startsWith('🎯')
                        ? Icons.smart_toy_rounded
                        : Icons.public_rounded,
                    color: enabled ? Colors.white : Colors.white30,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label.replaceFirst(RegExp(r'^[^\u0000-\u007F]+ '), ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: enabled ? Colors.white : Colors.white38,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: enabled ? Colors.white60 : Colors.white30,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  enabled
                      ? Icons.chevron_right_rounded
                      : Icons.lock_outline_rounded,
                  color: enabled ? Colors.white70 : Colors.white24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
