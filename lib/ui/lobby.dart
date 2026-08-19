import 'dart:io';

import 'package:flutter/material.dart';
import '../network/network_manager.dart';
import '../models/game_config.dart';
import 'table_screen.dart';

/// 获取本机局域网 IPv4 地址。
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

  static const _backgroundTop = Color(0xFF123B25);
  static const _backgroundBottom = Color(0xFF071810);
  static const _cardColor = Color(0xFF11261A);
  static const _primary = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    _setupCallbacks();
  }

  void _setupCallbacks() {
    _networkManager.server?.onRoomUpdate = (
      updatedPlayers,
      max,
    ) {
      if (!mounted) return;

      setState(() {
        players = updatedPlayers;
        maxPlayers = max;
        status = '房间人数: ${players.length}/$maxPlayers';
      });
    };

    _networkManager.server?.onError = (error) {
      if (!mounted) return;
      setState(() => status = '错误: $error');
    };

    _networkManager.client?.onJoined = (id, playerList) {
      if (!mounted) return;

      setState(() {
        players = playerList;
        status = '已加入房间，玩家ID: $id';
      });
    };

    _networkManager.client?.onRoomUpdate = (
      playerList,
      max,
    ) {
      if (!mounted) return;

      setState(() {
        players = playerList;
        maxPlayers = max;
        status = '房间人数: ${players.length}/$maxPlayers';
      });
    };

    _networkManager.client?.onGameStarted = (config) {
      if (!mounted) return;

      // 保留原有配置解析，供现有网络回调流程兼容使用。
      final configObj = GameConfig(
        startingChips: config['starting_chips'] ?? 1000,
        smallBlind: config['small_blind'] ?? 10,
        playerCount: players.length,
      );
      if (configObj.playerCount < 1) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TableScreen(
            controller: null,
            isNetworkGame: true,
            playerId:
                _networkManager.client?.playerId ?? 0,
            networkManager: _networkManager,
          ),
        ),
      );
    };

    _networkManager.client?.onError = (error) {
      if (!mounted) return;
      setState(() => status = '错误: $error');
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundBottom,
      appBar: AppBar(
        title: const Text(
          '联机大厅',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_backgroundTop, _backgroundBottom],
          ),
        ),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  28,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 720,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 16),
                        if (!isCreating && !isJoining)
                          _buildModeSelection(),
                        if (isCreating)
                          _buildCreateRoomWidget(),
                        if (isJoining)
                          _buildJoinRoomWidget(),
                        const SizedBox(height: 16),
                        _buildStatusPanel(),
                        if (constraints.maxHeight > 760)
                          const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.public_rounded,
            color: Colors.white,
            size: 28,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '联机大厅',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '创建或加入局域网牌局。',
                  style: TextStyle(
                    color: Colors.white60,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelection() {
    return Column(
      children: [
        _buildActionButton(
          '创建房间',
          Icons.add_home_work_rounded,
          _primary,
          () => setState(() => isCreating = true),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          '加入房间',
          Icons.login_rounded,
          Colors.blueGrey,
          () => setState(() => isJoining = true),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateRoomWidget() {
    return _buildSectionCard(
      icon: Icons.add_home_work_rounded,
      title: '创建房间',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildConfigRow(
            '起始筹码',
            startingChips,
            (v) => setState(
              () => startingChips = v.round(),
            ),
          ),
          _buildConfigRow(
            '小盲注',
            smallBlind,
            (v) => setState(
              () => smallBlind = v.round(),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () async {
                try {
                  final port =
                      await _networkManager.createRoom(
                    port: 0,
                  );
                  final ips = await getLocalIPs();

                  if (!mounted) return;

                  setState(() {
                    this.port = port;
                    ipAddress = ips.isNotEmpty
                        ? ips.first
                        : '127.0.0.1';
                    status =
                        '房间已创建，等待玩家加入。';
                  });
                } catch (e) {
                  if (!mounted) return;
                  setState(
                    () => status = '创建房间失败: $e',
                  );
                }
              },
              icon: const Icon(Icons.wifi_tethering_rounded),
              label: const Text('创建房间'),
            ),
          ),
          if (ipAddress != null) ...[
            const SizedBox(height: 16),
            _buildConnectionInfo(),
            const SizedBox(height: 14),
            if (players.isNotEmpty)
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (players.length < 2) {
                      setState(
                        () => status =
                            '至少需要 2 名玩家才能开始',
                      );
                      return;
                    }

                    final config = GameConfig(
                      startingChips: startingChips,
                      smallBlind: smallBlind,
                      playerCount: players.length,
                    );

                    _networkManager.startGame(config);

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TableScreen(
                          controller: _networkManager
                              .server
                              ?.gameController,
                          isNetworkGame: true,
                          playerId: 1,
                          networkManager:
                              _networkManager,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.play_arrow_rounded,
                  ),
                  label: Text(
                    '开始游戏 (${players.length}/$maxPlayers)',
                  ),
                ),
              ),
          ],
          const SizedBox(height: 8),
          _buildBackButton(
            () => setState(() => isCreating = false),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '连接信息',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            'IP      $ipAddress',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            '端口   $port',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            players.isEmpty
                ? '等待玩家加入…'
                : '当前玩家 ${players.length}/$maxPlayers',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigRow(
    String label,
    int value,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$value',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _primary,
              inactiveTrackColor: Colors.white12,
              thumbColor: Colors.white,
              overlayColor: _primary.withOpacity(0.14),
              trackHeight: 4,
            ),
            child: Slider(
              value: value.toDouble(),
              min: label == '小盲注' ? 5 : 100,
              max: label == '小盲注' ? 100 : 10000,
              divisions: label == '小盲注' ? 19 : 99,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinRoomWidget() {
    return _buildSectionCard(
      icon: Icons.login_rounded,
      title: '加入房间',
      child: Column(
        children: [
          TextField(
            decoration: _inputDecoration(
              label: 'IP 地址',
              icon: Icons.dns_rounded,
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            onChanged: (v) => joinIp = v.trim(),
          ),
          const SizedBox(height: 10),
          TextField(
            decoration: _inputDecoration(
              label: '端口',
              icon: Icons.numbers_rounded,
            ),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            onChanged: (v) => joinPort = v.trim(),
          ),
          const SizedBox(height: 10),
          TextField(
            decoration: _inputDecoration(
              label: '你的名字',
              icon: Icons.person_outline_rounded,
            ),
            textInputAction: TextInputAction.done,
            onChanged: (v) => playerName = v.trim(),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () async {
                if (joinIp.isEmpty || joinPort.isEmpty) {
                  setState(
                    () => status = '请填写完整信息',
                  );
                  return;
                }

                final port = int.tryParse(joinPort);
                if (port == null || port <= 0 || port > 65535) {
                  setState(
                    () => status = '端口无效，应为 1~65535',
                  );
                  return;
                }

                try {
                  await _networkManager.joinRoom(
                    joinIp,
                    port,
                    playerName.isNotEmpty
                        ? playerName
                        : '玩家',
                  );

                  if (!mounted) return;

                  setState(
                    () => status =
                        '连接成功，等待房主开始游戏…',
                  );
                } catch (e) {
                  if (!mounted) return;

                  setState(
                    () => status = '加入失败: $e',
                  );
                }
              },
              icon: const Icon(Icons.login_rounded),
              label: const Text('加入房间'),
            ),
          ),
          const SizedBox(height: 8),
          _buildBackButton(
            () => setState(() => isJoining = false),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: _cardColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildStatusPanel() {
    if (status.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          Icon(
            status.startsWith('错误') || status.contains('失败')
                ? Icons.error_outline_rounded
                : Icons.info_outline_rounded,
            color:
                status.startsWith('错误') || status.contains('失败')
                    ? Colors.redAccent
                    : Colors.white60,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              status,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.black.withOpacity(0.12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: _primary,
          width: 1.4,
        ),
      ),
    );
  }

  Widget _buildBackButton(VoidCallback onPressed) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_back_rounded, size: 18),
      label: const Text('返回'),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white60,
      ),
    );
  }
}
