import 'dart:io';
import 'dart:async';
import '../logic/game_controller.dart';
import '../models/game_config.dart';
import 'message.dart';

/// 客户端连接信息
class ClientConnection {
  final Socket socket;
  final int id;
  String name;
  bool isReady = false;

  ClientConnection({required this.socket, required this.id, required this.name});
}

/// 房主服务器
class RoomServer {
  ServerSocket? _serverSocket;
  final List<ClientConnection> _clients = [];
  int _nextClientId = 1;
  bool _gameStarted = false;
  GameController? _gameController;

  // 回调
  void Function(List<Map<String, dynamic>> players, int maxPlayers)? onRoomUpdate;
  void Function(GameController controller)? onGameStarted;
  void Function(Map<String, dynamic> state)? onGameStateUpdate;
  void Function(String error)? onError;
  void Function(ClientConnection client)? onClientDisconnected;

  /// 启动服务器
  Future<int> startServer({int port = 0}) async {
    try {
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      final boundPort = _serverSocket!.port;
      _serverSocket!.listen(_handleClient);
      return boundPort;
    } catch (e) {
      rethrow;
    }
  }

  /// 处理新客户端连接
  void _handleClient(Socket socket) {
    if (_clients.length >= 9) {
      socket.destroy();
      return;
    }

    final client = ClientConnection(
      socket: socket,
      id: _nextClientId++,
      name: '玩家$_nextClientId',
    );
    _clients.add(client);

    // 监听客户端消息
    _listenToClient(client);

    // 通知房间更新
    _broadcastRoomUpdate();

    // 如果游戏已开始，拒绝新连接
    if (_gameStarted) {
      _sendMessage(client.socket, NetworkMessage.error('游戏已开始，无法加入'));
      return;
    }
  }

  /// 监听单个客户端消息
  void _listenToClient(ClientConnection client) {
    String buffer = '';
    client.socket.listen(
      (data) {
        buffer += String.fromCharCodes(data);
        final lines = buffer.split('\n');
        buffer = lines.last;
        for (int i = 0; i < lines.length - 1; i++) {
          final line = lines[i];
          if (line.trim().isNotEmpty) {
            _handleMessage(client, line);
          }
        }
      },
      onError: (error) {
        _handleClientDisconnect(client);
      },
      onDone: () {
        _handleClientDisconnect(client);
      },
    );
  }

  /// 处理单条消息
  void _handleMessage(ClientConnection client, String raw) {
    final message = NetworkMessage.deserialize(raw);
    if (message == null) {
      _sendMessage(client.socket, NetworkMessage.error('无效消息格式'));
      return;
    }

    switch (message.type) {
      case MessageType.joinRoom:
        _handleJoinRoom(client, message.data);
        break;

      case MessageType.playerAction:
        _handlePlayerAction(client, message.data);
        break;

      default:
        _sendMessage(client.socket, NetworkMessage.error('不支持的消息类型: ${message.type}'));
    }
  }

  /// 处理加入房间
  void _handleJoinRoom(ClientConnection client, Map<String, dynamic> data) {
    if (_gameStarted) {
      _sendMessage(client.socket, NetworkMessage.error('游戏已开始，无法加入'));
      return;
    }

    final name = data['player_name'] as String? ?? '玩家${client.id}';
    client.name = name;

    final playersInfo = _getPlayersInfo();
    _sendMessage(client.socket, NetworkMessage.joinAck(client.id, playersInfo));
    _broadcastRoomUpdate();
  }

  /// 处理玩家动作
  void _handlePlayerAction(ClientConnection client, Map<String, dynamic> data) {
    if (_gameController == null) {
      _sendMessage(client.socket, NetworkMessage.error('游戏未开始'));
      return;
    }

    final playerId = data['player_id'] as int;
    final actionStr = data['action'] as String;
    final amount = data['amount'] as int? ?? 0;

    if (client.id != playerId) {
      _sendMessage(client.socket, NetworkMessage.error('无权操作其他玩家'));
      return;
    }

    ActionType action;
    switch (actionStr) {
      case 'fold':
        action = ActionType.fold;
        break;
      case 'check':
        action = ActionType.check;
        break;
      case 'call':
        action = ActionType.call;
        break;
      case 'raise':
        action = ActionType.raise;
        break;
      case 'allin':
        action = ActionType.allIn;
        break;
      default:
        _sendMessage(client.socket, NetworkMessage.error('无效动作: $actionStr'));
        return;
    }

    try {
      _gameController!.playerAction(playerId, action, amount: amount);
      _broadcastGameState();
    } catch (e) {
      _sendMessage(client.socket, NetworkMessage.error('执行动作失败: $e'));
    }
  }

  /// 客户端断开
  void _handleClientDisconnect(ClientConnection client) {
    if (!_clients.contains(client)) return;

    if (!_gameStarted) {
      _clients.remove(client);
      _broadcastRoomUpdate();
      onClientDisconnected?.call(client);
      return;
    }

    if (_gameController != null) {
      try {
        final player = _gameController!.players.firstWhere(
          (p) => p.id == client.id,
          orElse: () => throw Exception('玩家不存在'),
        );
        if (player.isInHand && !player.hasFolded) {
          _gameController!.playerAction(client.id, ActionType.fold);
          _broadcastGameState();
        }
      } catch (e) {
        // ignore
      }
    }

    _clients.remove(client);
    onClientDisconnected?.call(client);
  }

  /// 获取所有玩家信息
  List<Map<String, dynamic>> _getPlayersInfo() {
    return _clients.map((c) => {
      'id': c.id,
      'name': c.name,
      'is_ready': c.isReady,
    }).toList();
  }

  /// 广播房间更新
  void _broadcastRoomUpdate() {
    final playersInfo = _getPlayersInfo();
    final message = NetworkMessage.roomUpdate(playersInfo, 9);
    for (var client in _clients) {
      _sendMessage(client.socket, message);
    }
    onRoomUpdate?.call(playersInfo, 9);
  }

  /// 广播游戏状态
  void _broadcastGameState() {
    if (_gameController == null) return;
    final state = _gameController!.getGameState();
    final message = NetworkMessage.gameState(state);
    for (var client in _clients) {
      final playerCards = state['players'] as List<dynamic>?;
      if (playerCards != null) {
        for (var p in playerCards) {
          final pId = p['id'] as int;
          if (pId != client.id) {
            p['cards'] = [];
          }
        }
      }
      _sendMessage(client.socket, message);
    }
    onGameStateUpdate?.call(state);
  }

  /// 发送消息
  void _sendMessage(Socket socket, NetworkMessage message) {
    try {
      socket.write(message.serialize());
    } catch (e) {
      // ignore
    }
  }

  /// 开始游戏
  void startGame(GameConfig config) {
    if (_gameStarted) throw Exception('游戏已开始');
    if (_clients.length < 2) throw Exception('至少需要2名玩家');

    _gameStarted = true;

    final playerNames = _clients.map((c) => c.name).toList();
    _gameController = GameController(
      config: config,
      playerNames: playerNames,
    );

    _gameController!.addListener(_onControllerChanged);

    final configData = {
      'starting_chips': config.startingChips,
      'small_blind': config.smallBlind,
    };
    final startMsg = NetworkMessage.startGame(configData);
    for (var client in _clients) {
      _sendMessage(client.socket, startMsg);
    }

    _gameController!.startNewHand();
    _broadcastGameState();

    onGameStarted?.call(_gameController!);
  }

  void _onControllerChanged() {
    if (_gameController != null) {
      _broadcastGameState();
    }
  }

  List<ClientConnection> get clients => List.unmodifiable(_clients);
  bool get isGameStarted => _gameStarted;

  void close() {
    for (var client in _clients) {
      client.socket.destroy();
    }
    _clients.clear();
    _serverSocket?.close();
    _serverSocket = null;
    _gameController?.removeListener(_onControllerChanged);
    _gameController = null;
    _gameStarted = false;
  }
}
