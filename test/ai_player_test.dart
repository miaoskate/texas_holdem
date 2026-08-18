import 'package:flutter_test/flutter_test.dart';
import '../lib/models/game_config.dart';
import '../lib/models/card.dart';
import '../lib/logic/game_controller.dart';
import '../lib/logic/ai_player.dart';

void main() {
  group('AIPlayer', () {
    final config = GameConfig(
      startingChips: 1000,
      smallBlind: 10,
      playerCount: 3,
    );
    final names = ['AI1', 'AI2', 'AI3'];

    test('AI 在可行动时返回合法动作', () {
      final controller = GameController(config: config, playerNames: names);
      controller.startNewHand();
      final aiPlayer = controller.players.firstWhere((p) => p.id == 1);
      final (action, amount) = AIPlayer.decideAction(controller, aiPlayer.id);
      expect(action, isIn([ActionType.fold, ActionType.check, ActionType.call, ActionType.raise, ActionType.allIn]));
      expect(amount >= 0, true);
      if (action == ActionType.raise) {
        final minRaise = controller.roundBet + controller.minRaise - aiPlayer.currentBet;
        expect(amount >= minRaise, true);
      }
    });

    test('AI 在强牌时倾向于加注', () {
      final controller = GameController(config: config, playerNames: names);
      controller.startNewHand();
      final ai = controller.players[0];
      ai.handCards = [Card.fromString('As'), Card.fromString('Ah')];
      controller.communityCards = [Card.fromString('Kd'), Card.fromString('Qd'), Card.fromString('Jd')];
      final (action, _) = AIPlayer.decideAction(controller, ai.id);
      expect(action, anyOf(ActionType.raise, ActionType.allIn));
    });

    test('AI 弱牌时倾向于弃牌', () {
      final controller = GameController(config: config, playerNames: names);
      controller.startNewHand();
      final ai = controller.players[0];
      ai.handCards = [Card.fromString('2c'), Card.fromString('7d')];
      controller.communityCards = [Card.fromString('3h'), Card.fromString('5s'), Card.fromString('9c')];
      final (action, _) = AIPlayer.decideAction(controller, ai.id);
      expect(action, anyOf(ActionType.fold, ActionType.check));
    });

    test('AI 全下场景（筹码不足但牌力不弱）', () {
      final controller = GameController(config: config, playerNames: names);
      controller.startNewHand();
      final ai = controller.players[0];
      ai.chips = 5;
      ai.handCards = [Card.fromString('2h'), Card.fromString('2d')]; // 对子，牌力>0.25
      controller.roundBet = 20;
      ai.currentBet = 0;
      final (action, amount) = AIPlayer.decideAction(controller, ai.id);
      expect(action, ActionType.allIn);
      expect(amount, 5);
    });
  });
}
