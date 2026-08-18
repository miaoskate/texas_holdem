import 'dart:io';
import 'dart:async';
import 'message.dart';

/// 客户端房间连接
class RoomClient {
  Socket? _socket;
  int _playerId = -1;
  bool _connected = false;
  bool _gameStarted = false;
  String _buffer = '';

  // 回调
  void Function(int playerId, List<Map<String, dynamic>> players)? onJoined;
  void Function(List<Map<String, dynamic>> players, int maxPlayers)? onRoomUpdate;
  void Function(Map<String, dynamic> config)? onGameStarted;
  void Function(Map<String, dynamic> state)? onGameStateUpdate;
  void Function(List<Map<String, dynamic>> winners, int potAmount)? onRoundResult;
  void Function(String error)? onError;
  void Function()? onDisconnected;

  int get playerId => _playerId;
  bool get isConnected => _connected;
  bool get isGameStarted => _gameStarted;

  /// 连接服务器
  Future<void> connect(String host, int port, String playerName) async {
    try {
      _socket = await Socket.connect(host, port);
      _connected = true;
      _listenToServer();

      final joinMsg = NetworkMessage.joinRoom(playerName);
      _socket!.write(joinMsg.serialize());
    } catch (e) {
      throw Exception('连接失败: $e');
    }
  }

  /// 监听服务器消息
  void _listenToServer() {
    _socket!.listen(
      (data) {
        _buffer += String.fromCharCodes(data);
        final lines = _buffer.split('\n');
        _buffer = lines.last;
        for (int i = 0; i < lines.length - 1; i++) {
          final line = lines[i];
          if (line.trim().isNotEmpty) {
            _handleMessage(line);
          }
        }
      },
      onError: (error) {
        _handleDisconnect();
      },
      onDone: () {
        _handleDisconnect();
      },
    );
  }

  /// 处理服务器消息
  void _handleMessage(String raw) {
    final message = NetworkMessage.deserialize(raw);
    if (message == null) {
      onError?.call('无效消息格式');
      return;
    }

    switch (message.type) {
      case MessageType.joinAck:
        _handleJoinAck(message.data);
        break;

      case MessageType.roomUpdate:
        _handleRoomUpdate(message.data);
        break;

      case MessageType.startGame:
        _handleStartGame(message.data);
        break;

      case MessageType.gameState:
        _handleGameState(message.data);
        break;

      case MessageType.actionResult:
        _handleActionResult(message.data);
        break;

      case MessageType.roundResult:
        _handleRoundResult(message.data);
        break;

      case MessageType.error:
        onError?.call(message.data['message'] as String? ?? '未知错误');
        break;

      default:
        break;
    }
  }

  void _handleJoinAck(Map<String, dynamic> data) {
    _playerId = data['player_id'] as int;
    final players = (data['players'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    onJoined?.call(_playerId, players);
  }

  void _handleRoomUpdate(Map<String, dynamic> data) {
    final players = (data['players'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final maxPlayers = data['max_players'] as int? ?? 9;
    onRoomUpdate?.call(players, maxPlayers);
  }

  void _handleStartGame(Map<String, dynamic> data) {
    _gameStarted = true;
    final config = data['config'] as Map<String, dynamic>? ?? {};
    onGameStarted?.call(config);
  }

  void _handleGameState(Map<String, dynamic> data) {
    onGameStateUpdate?.call(data);
  }

  void _handleActionResult(Map<String, dynamic> data) {
    onGameStateUpdate?.call(data);
  }

  void _handleRoundResult(Map<String, dynamic> data) {
    final winners = (data['winners'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final potAmount = data['pot_amount'] as int? ?? 0;
    onRoundResult?.call(winners, potAmount);
  }

  void _handleDisconnect() {
    _connected = false;
    _socket = null;
    onDisconnected?.call();
  }

  /// 发送玩家动作
  void sendAction(String action, {int amount = 0}) {
    if (!_connected || _socket == null) {
      throw Exception('未连接到服务器');
    }
    final msg = NetworkMessage.playerAction(_playerId, action, amount: amount);
    _socket!.write(msg.serialize());
  }

  /// 断开连接
  void disconnect() {
    _socket?.destroy();
    _socket = null;
    _connected = false;
    _gameStarted = false;
    _playerId = -1;
  }
}
