import '../models/game_config.dart';
import 'room_server.dart';
import 'room_client.dart';

/// 网络管理器 - 统一管理服务器和客户端
class NetworkManager {
  RoomServer? server;
  RoomClient? client;

  bool get isServer => server != null;
  bool get isClient => client != null;

  /// 创建房间（作为服务器）
  Future<int> createRoom({int port = 0}) async {
    server = RoomServer();
    final boundPort = await server!.startServer(port: port);
    return boundPort;
  }

  /// 加入房间（作为客户端）
  Future<void> joinRoom(String host, int port, String playerName) async {
    client = RoomClient();
    await client!.connect(host, port, playerName);
  }

  /// 开始游戏（仅服务器）
  void startGame(GameConfig config) {
    if (server == null) throw Exception('不是房主');
    server!.startGame(config);
  }

  /// 关闭所有连接
  void close() {
    server?.close();
    server = null;
    client?.disconnect();
    client = null;
  }
}
