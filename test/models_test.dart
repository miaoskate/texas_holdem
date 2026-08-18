import 'package:flutter_test/flutter_test.dart';
import '../lib/models/card.dart';
import '../lib/models/deck.dart';
import '../lib/models/player.dart';
import '../lib/models/pot.dart';
import '../lib/models/game_config.dart';

void main() {
  group('Card', () {
    test('toString and fromString', () {
      final card = Card(Rank.ace, Suit.spades);
      expect(card.toString(), 'As');
      expect(Card.fromString('As').rank, Rank.ace);
      expect(Card.fromString('As').suit, Suit.spades);
      expect(Card.fromString('10h').rank, Rank.ten);
      expect(Card.fromString('10h').suit, Suit.hearts);
    });
  });

  group('Deck', () {
    test('shuffle and deal', () {
      final deck = Deck();
      expect(deck.remaining, 52);
      final card1 = deck.deal();
      expect(deck.remaining, 51);
      // 检查是否有重复
      final allCards = <String>[];
      final tempDeck = Deck();
      while (tempDeck.remaining > 0) {
        final c = tempDeck.deal();
        allCards.add(c.toString());
      }
      expect(allCards.toSet().length, 52);
    });
  });

  group('Player', () {
    test('placeBet and allIn', () {
      final p = Player(id: 1, name: 'Test', chips: 1000);
      p.placeBet(200);
      expect(p.chips, 800);
      expect(p.currentBet, 200);
      expect(p.totalBetThisRound, 200);
      p.placeBet(50);
      expect(p.chips, 750);
      expect(p.currentBet, 250);
      expect(p.totalBetThisRound, 250);
      p.resetForNewHand();
      expect(p.chips, 750);
      expect(p.currentBet, 0);
      expect(p.totalBetThisRound, 0);
      expect(p.hasFolded, false);
      expect(p.isAllIn, false);

      final p2 = Player(id: 2, name: 'AllIn', chips: 300);
      final allinAmount = p2.allIn();
      expect(allinAmount, 300);
      expect(p2.chips, 0);
      expect(p2.isAllIn, true);
    });
  });

  group('Pot', () {
    test('calculate side pots', () {
      final p1 = Player(id: 1, name: 'A', chips: 1000);
      final p2 = Player(id: 2, name: 'B', chips: 1000);
      final p3 = Player(id: 3, name: 'C', chips: 1000);

      p1.placeBet(100);
      p2.placeBet(200);
      p3.placeBet(300);

      final pot = Pot();
      pot.calculateSidePots([p1, p2, p3]);

      // 预期：
      // 主池：100 * 3 = 300，符合玩家1
      // 边池1：100 * 2 = 200，符合玩家2和3 (200-100=100差值，2人)
      // 边池2：100 * 1 = 100，符合玩家3 (300-200=100差值，1人)
      expect(pot.sidePots.length, 3);
      expect(pot.sidePots[0].amount, 300);
      expect(pot.sidePots[0].eligiblePlayerIds, [1, 2, 3]);
      expect(pot.sidePots[1].amount, 200);
      expect(pot.sidePots[1].eligiblePlayerIds, [2, 3]);
      expect(pot.sidePots[2].amount, 100);
      expect(pot.sidePots[2].eligiblePlayerIds, [3]);

      // 测试部分玩家全下
      final p4 = Player(id: 4, name: 'D', chips: 100);
      p4.placeBet(100);
      final p5 = Player(id: 5, name: 'E', chips: 200);
      p5.placeBet(200);
      final p6 = Player(id: 6, name: 'F', chips: 300);
      p6.placeBet(300);

      final pot2 = Pot();
      pot2.calculateSidePots([p4, p5, p6]);
      expect(pot2.sidePots.length, 3);
      expect(pot2.sidePots[0].amount, 300); // 100*3
      expect(pot2.sidePots[0].eligiblePlayerIds, [4, 5, 6]);
      expect(pot2.sidePots[1].amount, 200); // (200-100)*2
      expect(pot2.sidePots[1].eligiblePlayerIds, [5, 6]);
      expect(pot2.sidePots[2].amount, 100); // (300-200)*1
      expect(pot2.sidePots[2].eligiblePlayerIds, [6]);
    });
  });

  group('GameConfig', () {
    test('default values', () {
      final config = GameConfig(
        startingChips: 1000,
        smallBlind: 10,
        playerCount: 6,
      );
      expect(config.bigBlind, 20);
      expect(config.maxPlayers, 9);
    });
  });
}
