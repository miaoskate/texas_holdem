import 'dart:convert';

/// 所有消息类型的枚举
enum MessageType {
  joinRoom,
  joinAck,
  roomUpdate,
  startGame,
  gameState,
  playerAction,
  actionResult,
  roundResult,
  error,
}

/// 网络消息基类
class NetworkMessage {
  final MessageType type;
  final Map<String, dynamic> data;

  NetworkMessage({required this.type, required this.data});

  /// 序列化为JSON字符串（以换行符结尾）
  String serialize() {
    final json = {
      'type': type.name,
      'data': data,
    };
    return '${jsonEncode(json)}\n';
  }

  /// 从字符串反序列化
  static NetworkMessage? deserialize(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final typeStr = json['type'] as String;
      final data = json['data'] as Map<String, dynamic>? ?? {};
      final type = MessageType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () => throw Exception('Unknown message type: $typeStr'),
      );
      return NetworkMessage(type: type, data: data);
    } catch (e) {
      return null;
    }
  }

  /// 工厂方法：创建加入房间请求
  static NetworkMessage joinRoom(String playerName) {
    return NetworkMessage(
      type: MessageType.joinRoom,
      data: {'player_name': playerName},
    );
  }

  /// 工厂方法：创建加入成功回复
  static NetworkMessage joinAck(int playerId, List<Map<String, dynamic>> players) {
    return NetworkMessage(
      type: MessageType.joinAck,
      data: {
        'player_id': playerId,
        'players': players,
      },
    );
  }

  /// 工厂方法：创建房间更新
  static NetworkMessage roomUpdate(List<Map<String, dynamic>> players, int maxPlayers) {
    return NetworkMessage(
      type: MessageType.roomUpdate,
      data: {
        'players': players,
        'max_players': maxPlayers,
      },
    );
  }

  /// 工厂方法：创建开始游戏
  static NetworkMessage startGame(Map<String, dynamic> config) {
    return NetworkMessage(
      type: MessageType.startGame,
      data: {'config': config},
    );
  }

  /// 工厂方法：创建游戏状态更新
  static NetworkMessage gameState(Map<String, dynamic> state) {
    return NetworkMessage(
      type: MessageType.gameState,
      data: state,
    );
  }

  /// 工厂方法：创建玩家操作
  static NetworkMessage playerAction(int playerId, String action, {int amount = 0}) {
    return NetworkMessage(
      type: MessageType.playerAction,
      data: {
        'player_id': playerId,
        'action': action,
        'amount': amount,
      },
    );
  }

  /// 工厂方法：创建操作结果
  static NetworkMessage actionResult(Map<String, dynamic> state) {
    return NetworkMessage(
      type: MessageType.actionResult,
      data: state,
    );
  }

  /// 工厂方法：创建回合结果
  static NetworkMessage roundResult(List<Map<String, dynamic>> winners, int potAmount) {
    return NetworkMessage(
      type: MessageType.roundResult,
      data: {
        'winners': winners,
        'pot_amount': potAmount,
      },
    );
  }

  /// 工厂方法：创建错误消息
  static NetworkMessage error(String message) {
    return NetworkMessage(
      type: MessageType.error,
      data: {'message': message},
    );
  }
}
