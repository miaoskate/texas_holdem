# lib 目录结构说明

> 德州扑克 Flutter 项目，按 MVC 分层组织

```
lib/
├── main.dart                        # 入口
├── 1.txt                            # 游戏规则文档
├── logic/                           # 游戏逻辑层
│   ├── ai_player.dart               # AI 决策器（当前版本）
│   ├── ai_player.txt                # AI 决策器（旧版/简化版，疑似废弃）
│   ├── game_controller.dart         # 游戏控制器（核心状态机）
│   └── hand_evaluator.dart          # 牌型评估器
├── models/                          # 数据模型层
│   ├── card.dart                    # 扑克牌模型
│   ├── deck.dart                    # 牌堆
│   ├── game_config.dart             # 游戏配置
│   ├── player.dart                  # 玩家
│   └── pot.dart                     # 底池（含边池）
├── network/                         # 网络通信层
│   ├── message.dart                 # 网络消息协议
│   ├── network_manager.dart         # 网络管理器
│   ├── room_client.dart             # 房间客户端
│   └── room_server.dart             # 房间服务器
└── ui/                              # 界面层
    ├── lobby.dart                   # 联机大厅
    ├── main_menu.dart               # 主菜单
    ├── single_player_setup.dart     # 单机模式设置
    ├── table_screen.dart            # 牌桌主界面
    └── widgets/                     # 通用组件
        ├── action_button.dart       # 操作按钮
        ├── card_widget.dart         # 扑克牌组件
        ├── chip_widget.dart         # 筹码组件
        └── player_seat.dart         # 玩家座位
```

## 各文件职责

### 入口

| 文件 | 职责 |
| --- | --- |
| `main.dart` | 应用入口，启动 `TexasHoldemApp`（MaterialApp），设置深绿主题，首页为主菜单 |
| `1.txt` | 德州扑克一局牌的完整规则说明（盲注 → 发牌 → 四轮下注 → 摊牌），参考资料 |

### logic/ 游戏逻辑层

| 文件 | 职责 |
| --- | --- |
| `game_controller.dart` | **核心状态机**。定义 `GamePhase`（preflop/flop/turn/river/showdown）、`ActionType`、`ActionRecord`；管理玩家、牌堆、底池、公共牌、下注轮转、发牌、胜负结算、AI 行动触发 |
| `hand_evaluator.dart` | 牌型评估器。`HandRank` 枚举（高牌→皇家同花顺）+ `evaluate()` 从 7 张牌穷举 C(7,5)=21 种组合取最优，`compare()` 比较大小 |
| `ai_player.dart` | AI 决策器（当前版本）。带性格参数（激进、bluff、c-bet、价值下注频率），综合起手牌评价、听牌、底池赔率、SPR 等做决策，返回 `(action, amount)` |
| `ai_player.txt` | AI 决策器的旧版/简化版副本，功能相似但更简单，疑似废弃 |

### models/ 数据模型层

| 文件 | 职责 |
| --- | --- |
| `card.dart` | 扑克牌模型：`Rank`（2~A=14）、`Suit`（♠♥♦♣）枚举及显示字符 |
| `deck.dart` | 牌堆：52 张生成、Fisher-Yates 洗牌、`deal()` 发牌 |
| `player.dart` | 玩家：筹码、手牌、当前下注、盲注/庄家标记、弃牌/全下状态，含 `placeBet`/`fold`/`allIn` 方法 |
| `pot.dart` | 底池：总额 + `SidePot`（边池）计算，处理 all-in 时多人下注不等额的情况 |
| `game_config.dart` | 游戏配置：起始筹码、小盲注、人数上限（默认 9），`bigBlind = smallBlind * 2` |

### network/ 网络通信层（联机模式）

| 文件 | 职责 |
| --- | --- |
| `message.dart` | 消息协议：`MessageType` 枚举（joinRoom/joinAck/roomUpdate/gameState/playerAction 等）+ `NetworkMessage` 的 JSON 序列化/反序列化及工厂方法 |
| `room_server.dart` | 房主服务器：TCP 监听、管理客户端连接、转发房间/游戏状态、驱动 `GameController` |
| `room_client.dart` | 客户端连接：连接服务器、发送加入请求、按行解析并回调各类状态消息 |
| `network_manager.dart` | 网络统一入口：封装 `RoomServer`/`RoomClient`，提供 createRoom/joinRoom/startGame/close |

### ui/ 界面层

| 文件 | 职责 |
| --- | --- |
| `main_menu.dart` | 主菜单：选择单机模式（可用）/联机模式（已禁用"敬请期待"） |
| `single_player_setup.dart` | 单机设置页：滑杆配置人数/起始筹码/小盲注，创建 `GameConfig` 和 `GameController` |
| `lobby.dart` | 联机大厅：获取本机 IP、创建/加入房间、显示房间人数、设置筹码盲注后开局 |
| `table_screen.dart` | 牌桌主界面：渲染公共牌、玩家座位、操作按钮；单机模式监听控制器自动驱动 AI 行动，处理游戏结束弹窗；联机模式监听网络状态 |
| `widgets/action_button.dart` | 圆角操作按钮（跟注/加注/弃牌等） |
| `widgets/card_widget.dart` | 扑克牌组件：红黑花色、明牌/暗牌（背面） |
| `widgets/chip_widget.dart` | 筹码组件：`CustomPainter` 绘制彩色筹码并显示数值 |
| `widgets/player_seat.dart` | 玩家座位组件：姓名、筹码、手牌、行动中高亮 |

## 小结

- `models` 为纯数据层，`logic` 负责规则与 AI，`network` 支持联机对战，`ui` 提供四个页面和四个可复用组件。
- 当前主菜单中联机入口被禁用，实际可玩的是**单机模式**（人对 AI）。
