import 'package:flutter/material.dart';

/// 游戏操作按钮（独立元素，非弹出式集群）
///
/// 状态样式：
/// - 默认（未按下）：高亮色背景 + 白色描边 + 同色发光阴影
/// - 按下中：灰色（背景 #8E8E8E、文字 #424242、描边 #6E6E6E）
/// - 按下后（操作执行中）：保持灰色，直至操作完成（或取消/重置）后恢复高亮
///
/// 尺寸：相比旧版翻倍（内边距 16x10 → 32x20，字号 14 → 28）
class ActionButton extends StatefulWidget {
  final String label;
  final Future<void> Function()? onPressed;
  final Color color;

  /// 紧凑尺寸（用于加注对话框等空间受限场景，保持旧版大小）
  final bool compact;

  /// 按下/执行中状态的灰色背景
  static const Color kPressedColor = Color(0xFF8E8E8E);
  /// 按下/执行中状态的文字颜色
  static const Color kPressedTextColor = Color(0xFF424242);
  /// 按下/执行中状态的描边颜色
  static const Color kPressedBorderColor = Color(0xFF6E6E6E);

  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = const Color(0xFF81C784),
    this.compact = false,
  });

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool _pointerDown = false; // 手指按压中
  bool _running = false;     // 操作执行中（如加注对话框未关闭）

  bool get _gray => _pointerDown || _running;

  Future<void> _handlePress() async {
    if (_running || widget.onPressed == null) return; // 防重复点击
    setState(() => _running = true);
    try {
      await widget.onPressed!();
    } finally {
      // 操作完成（或失败/取消）后重置为高亮状态
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gray = _gray;
    final bgColor = gray ? ActionButton.kPressedColor : widget.color;
    final fgColor = gray ? ActionButton.kPressedTextColor : Colors.white;
    final borderColor = gray ? ActionButton.kPressedBorderColor : Colors.white;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pointerDown = true),
      onTapCancel: () => setState(() => _pointerDown = false),
      onTap: () {
        setState(() => _pointerDown = false);
        _handlePress();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: widget.compact
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
            : const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: gray
              ? const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 2))]
              : [
                  // 默认高亮：同色发光效果
                  BoxShadow(
                    color: widget.color.withOpacity(0.65),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: widget.compact ? 14 : 28,
            fontWeight: FontWeight.bold,
            color: fgColor,
          ),
        ),
      ),
    );
  }
}
