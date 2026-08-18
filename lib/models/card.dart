/// 扑克牌点数：2~14 (A=14)
enum Rank {
  two(2),
  three(3),
  four(4),
  five(5),
  six(6),
  seven(7),
  eight(8),
  nine(9),
  ten(10),
  jack(11),
  queen(12),
  king(13),
  ace(14);

  final int value;
  const Rank(this.value);

  static Rank fromValue(int v) {
    return Rank.values.firstWhere((e) => e.value == v);
  }

  @override
  String toString() {
    switch (this) {
      case Rank.two:
        return '2';
      case Rank.three:
        return '3';
      case Rank.four:
        return '4';
      case Rank.five:
        return '5';
      case Rank.six:
        return '6';
      case Rank.seven:
        return '7';
      case Rank.eight:
        return '8';
      case Rank.nine:
        return '9';
      case Rank.ten:
        return '10';
      case Rank.jack:
        return 'J';
      case Rank.queen:
        return 'Q';
      case Rank.king:
        return 'K';
      case Rank.ace:
        return 'A';
    }
  }
}

/// 花色：0=♠, 1=♥, 2=♦, 3=♣
enum Suit {
  spades(0, 's'),
  hearts(1, 'h'),
  diamonds(2, 'd'),
  clubs(3, 'c');

  final int id;
  final String symbol;
  const Suit(this.id, this.symbol);

  static Suit fromId(int id) {
    return Suit.values.firstWhere((e) => e.id == id);
  }

  @override
  String toString() => symbol;
}

class Card {
  final Rank rank;
  final Suit suit;

  Card(this.rank, this.suit);

  /// 例如 "As", "Kd", "10h", "Ts"
  @override
  String toString() => '${rank.toString()}${suit.toString()}';

  /// 从字符串解析，支持 "10h" 和 "Th" 两种格式
  static Card fromString(String s) {
    if (s.length < 2) throw FormatException('Invalid card string: $s');

    String rankStr;
    String suitStr;

    // 处理两位数字的 rank（如 "10"）或缩写 "T"
    if (s.length >= 3 && s.substring(0, 2) == '10') {
      rankStr = '10';
      suitStr = s.substring(2);
    } else {
      rankStr = s.substring(0, 1);
      suitStr = s.substring(1);
    }

    Rank rank;
    switch (rankStr) {
      case '2':
        rank = Rank.two;
        break;
      case '3':
        rank = Rank.three;
        break;
      case '4':
        rank = Rank.four;
        break;
      case '5':
        rank = Rank.five;
        break;
      case '6':
        rank = Rank.six;
        break;
      case '7':
        rank = Rank.seven;
        break;
      case '8':
        rank = Rank.eight;
        break;
      case '9':
        rank = Rank.nine;
        break;
      case '10':
      case 'T':
        rank = Rank.ten;
        break;
      case 'J':
        rank = Rank.jack;
        break;
      case 'Q':
        rank = Rank.queen;
        break;
      case 'K':
        rank = Rank.king;
        break;
      case 'A':
        rank = Rank.ace;
        break;
      default:
        throw FormatException('Invalid rank in card string: $s');
    }

    Suit suit;
    switch (suitStr) {
      case 's':
        suit = Suit.spades;
        break;
      case 'h':
        suit = Suit.hearts;
        break;
      case 'd':
        suit = Suit.diamonds;
        break;
      case 'c':
        suit = Suit.clubs;
        break;
      default:
        throw FormatException('Invalid suit in card string: $s');
    }
    return Card(rank, suit);
  }
}
