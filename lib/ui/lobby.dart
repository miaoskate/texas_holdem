import 'dart:io';

import 'package:flutter/material.dart';
import '../network/network_manager.dart';
import '../models/game_config.dart';
import 'table_screen.dart';

/// 获取本机局域网 IPv4 地址
Future<List<String>> getLocalIPs() async {
  try {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    return interfaces
        .expand((i) => i.addresses.map((a) => a.address))
        .toList();
  } catch (_) {
    return ['127.0.0.1'];
  }
}

class Lobby extends StatefulWidget {
  const Lobby({super.key});

  @override
  State<Lobby> createState() => _LobbyState();
}

class _LobbyState extends State<Lobby> {
  final NetworkManager _networkManager = NetworkManager();
  bool isCreating = false;
  bool isJoining = false;
  String? ipAddress;
  int? port;
  String playerName = '';
  String joinIp = '';
  String joinPort = '';
  List<Map<String, dynamic>> players = [];
  int maxPlayers = 9;
  int startingChips = 1000;
  int smallBlind = 10;
  String status = '';

  @override
  void initState() {
    super.initState();
    _setupCallbacks();
  }

  void _setupCallbacks() {
    // 如果是服务器
    _networkManager.server?.onRoomUpdate = (updatedPlayers, max) {
      setState(() {
        players = updatedPlayers;
        maxPlayers = max;
        status = '房间人数: ${players.length}/$maxPlayers';
      });
    };
    _networkManager.server?.onError = (error) {
      setState(() => status = '错误: $error');
    };

    // 如果是客户端
    _networkManager.client?.onJoined = (id, playerList) {
      setState(() {
        players = playerList;
        status = '已加入房间，玩家ID: $id';
      });
    };
    _networkManager.client?.onRoomUpdate = (playerList, max) {
      setState(() {
        players = playerList;
        maxPlayers = max;
        status = '房间人数: ${players.length}/$maxPlayers';
      });
    };
    _networkManager.client?.onGameStarted = (config) {
      // 游戏开始，跳转到牌桌
      final configObj = GameConfig(
        startingChips: config['starting_chips'] ?? 1000,
        smallBlind: config['small_blind'] ?? 10,
        playerCount: players.length,
      );
      // 客户端需要等待gameState，但这里无法直接获取controller，所以跳转时传入网络模式
      // 在TableScreen中会通过客户端监听状态
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TableScreen(
            controller: null, // 客户端没有controller，由网络同步
            isNetworkGame: true,
            playerId: _networkManager.client?.playerId ?? 0,
            networkManager: _networkManager,
          ),
        ),
      );
    };
    _networkManager.client?.onError = (error) {
      setState(() => status = '错误: $error');
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('联机大厅')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!isCreating && !isJoining) ...[
              const Text('选择操作', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 20),
              _buildActionButton('创建房间', Icons.create, Colors.blue, () {
                setState(() => isCreating = true);
              }),
              const SizedBox(height: 12),
              _buildActionButton('加入房间', Icons.login, Colors.green, () {
                setState(() => isJoining = true);
              }),
            ],

            if (isCreating) _buildCreateRoomWidget(),
            if (isJoining) _buildJoinRoomWidget(),

            const Spacer(),
            Text(status, style: const TextStyle(fontSize: 16, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: 200,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          minimumSize: const Size(200, 50),
        ),
      ),
    );
  }

  Widget _buildCreateRoomWidget() {
    return Column(
      children: [
        const Text('创建房间', style: TextStyle(fontSize: 18)),
        const SizedBox(height: 12),
        _buildConfigRow('起始筹码', startingChips, (v) => setState(() => startingChips = v.round())),
        _buildConfigRow('小盲注', smallBlind, (v) => setState(() => smallBlind = v.round())),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () async {
            try {
              final port = await _networkManager.createRoom(port: 0);
              final ips = await getLocalIPs();
              setState(() {
                this.port = port;
                ipAddress = ips.isNotEmpty ? ips.first : '127.0.0.1';
                status = '房间已创建，IP: $ipAddress, 端口: $port';
              });
              // 开始监听玩家加入，并可以开始游戏
            } catch (e) {
              setState(() => status = '创建房间失败: $e');
            }
          },
          child: const Text('创建房间'),
        ),
        if (ipAddress != null) ...[
          const SizedBox(height: 12),
          Text('连接信息:', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('IP: $ipAddress', style: const TextStyle(color: Colors.green)),
          Text('端口: $port', style: const TextStyle(color: Colors.green)),
          const SizedBox(height: 12),
          if (players.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                if (players.length < 2) {
                  setState(() => status = '至少需要2名玩家才能开始');
                  return;
                }
                final config = GameConfig(
                  startingChips: startingChips,
                  smallBlind: smallBlind,
                  playerCount: players.length,
                );
                _networkManager.startGame(config);
                // 房主跳转牌桌
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TableScreen(
                      controller: _networkManager.server?.gameController,
                      isNetworkGame: true,
                      playerId: 1, // 房主ID固定为1
                      networkManager: _networkManager,
                    ),
                  ),
                );
              },
              child: Text('开始游戏 (${players.length}/2+)'),
            ),
        ],
      ],
    );
  }

  Widget _buildConfigRow(String label, int value, ValueChanged<double> onChanged) {
    return Row(
      children: [
        Text('$label:'),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 100,
            max: 10000,
            divisions: 99,
            onChanged: onChanged,
          ),
        ),
        Text('$value'),
      ],
    );
  }

  Widget _buildJoinRoomWidget() {
    return Column(
      children: [
        const Text('加入房间', style: TextStyle(fontSize: 18)),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(labelText: 'IP地址', border: OutlineInputBorder()),
          onChanged: (v) => joinIp = v,
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(labelText: '端口', border: OutlineInputBorder()),
          keyboardType: TextInputType.number,
          onChanged: (v) => joinPort = v,
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(labelText: '你的名字', border: OutlineInputBorder()),
          onChanged: (v) => playerName = v,
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () async {
            if (joinIp.isEmpty || joinPort.isEmpty) {
              setState(() => status = '请填写完整信息');
              return;
            }
            final port = int.tryParse(joinPort);
            if (port == null) {
              setState(() => status = '端口无效');
              return;
            }
            try {
              await _networkManager.joinRoom(joinIp, port, playerName.isNotEmpty ? playerName : '玩家');
              setState(() => status = '连接成功，等待房主开始游戏...');
            } catch (e) {
              setState(() => status = '加入失败: $e');
            }
          },
          child: const Text('加入'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => isJoining = false),
          child: const Text('返回'),
        ),
      ],
    );
  }
}

