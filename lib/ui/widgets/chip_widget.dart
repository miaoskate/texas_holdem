import 'dart:math';

import 'package:flutter/material.dart';

/// 筹码组件 - 使用 CustomPainter 绘制彩色筹码
class ChipWidget extends StatelessWidget {
  final int amount;
  final double size;
  final bool showValue;

  const ChipWidget({
    super.key,
    required this.amount,
    this.size = 40,
    this.showValue = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ChipPainter(amount: amount),
        child: showValue
            ? Center(
                child: Text(
                  _formatAmount(amount),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.25,
                    fontWeight: FontWeight.bold,
                    shadows: const [
                      Shadow(offset: Offset(1, 1), blurRadius: 2, color: Colors.black54),
                    ],
                  ),
                ),
              )
            : null,
      ),
    );
  }

  String _formatAmount(int amount) {
    if (amount >= 1000) return '${(amount / 1000).floor()}K';
    if (amount >= 100) return '${(amount / 100).floor()}00';
    return '$amount';
  }
}

/// 筹码绘制器
class _ChipPainter extends CustomPainter {
  final int amount;

  _ChipPainter({required this.amount});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. 绘制外圈（金属边框效果）
    final outerPaint = Paint()
      ..color = Colors.amber[700]!
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, outerPaint);

    // 2. 绘制主体（根据筹码面值颜色不同）
    final mainColor = _getChipColor(amount);
    final mainPaint = Paint()
      ..color = mainColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.85, mainPaint);

    // 3. 绘制内圈装饰环
    final innerRingPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.08;
    canvas.drawCircle(center, radius * 0.6, innerRingPaint);

    // 4. 绘制中心点装饰
    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.08, dotPaint);

    // 5. 绘制边缘纹理（小点）
    final dotCount = 12;
    for (int i = 0; i < dotCount; i++) {
      final angle = (i / dotCount) * 2 * 3.14159;
      final dotX = center.dx + radius * 0.85 * cos(angle);
      final dotY = center.dy + radius * 0.85 * sin(angle);
      final dotSize = radius * 0.04;
      final dotPaint2 = Paint()
        ..color = Colors.white.withOpacity(0.25)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(dotX, dotY), dotSize, dotPaint2);
    }

    // 6. 高光效果（左上角反光）
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(center.dx - radius * 0.25, center.dy - radius * 0.25),
      radius * 0.3,
      highlightPaint,
    );
  }

  Color _getChipColor(int amount) {
    // 根据面值分配不同颜色
    if (amount >= 5000) return Colors.purple[700]!;
    if (amount >= 1000) return Colors.red[700]!;
    if (amount >= 500) return Colors.blue[700]!;
    if (amount >= 100) return Colors.green[700]!;
    if (amount >= 50) return Colors.orange[700]!;
    if (amount >= 25) return Colors.pink[400]!;
    if (amount >= 10) return Colors.indigo[400]!;
    return Colors.grey[600]!;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

/// 筹码堆叠组件 - 显示多个筹码堆叠在一起
class ChipStack extends StatelessWidget {
  final int totalAmount;
  final int maxChips;
  final double chipSize;

  const ChipStack({
    super.key,
    required this.totalAmount,
    this.maxChips = 5,
    this.chipSize = 30,
  });

  @override
  Widget build(BuildContext context) {
    if (totalAmount == 0) return const SizedBox.shrink();

    // 计算面值分配：尽量使用大面值筹码
    final chips = _breakdownChips(totalAmount, maxChips);

    return SizedBox(
      width: chipSize * 1.5,
      height: chipSize * 1.2,
      child: Stack(
        children: chips.asMap().entries.map((entry) {
          final index = entry.key;
          final amount = entry.value;
          return Positioned(
            left: index * 2.0,
            bottom: index * 2.0,
            child: ChipWidget(
              amount: amount,
              size: chipSize - index * 2,
              showValue: index == chips.length - 1,
            ),
          );
        }).toList(),
      ),
    );
  }

  List<int> _breakdownChips(int amount, int maxCount) {
    final List<int> result = [];
    final denominations = [5000, 1000, 500, 100, 50, 25, 10, 5, 1];
    int remaining = amount;

    for (int denom in denominations) {
      while (remaining >= denom && result.length < maxCount) {
        result.add(denom);
        remaining -= denom;
      }
      if (result.length >= maxCount) break;
    }

    // 如果还有剩余，加到最后一个筹码上
    if (remaining > 0 && result.isNotEmpty) {
      result[result.length - 1] += remaining;
    }

    return result;
  }
}
