# Snake Grid（网格贪吃蛇）

一款基于网格的贪吃蛇式解谜游戏，玩家需要引导小虫移出屏幕，避免碰撞。

## 🎮 游戏玩法

### 核心循环
观察网格布局 → 点击发光小虫的箭头方向 → 小虫贪吃蛇式移动 → 碰撞后反弹 → 成功移出屏幕过关

### 操作方式
- **点击箭头**：点击小虫头部箭头方向，小虫会沿该方向直线移动
- **贪吃蛇移动**：头部前进一格，身体每段依次跟随前一段
- **碰撞反弹**：如果头部碰到其他小虫的身体，会立即反弹（尾巴变头，原路退回）
- **自由端判定**：只有头部和尾部都没有被其他小虫覆盖时才能移动

### 视觉提示
| 状态 | 视觉效果 |
|------|----------|
| 可移动（自由端） | 高亮发光，显示黄色箭头指示器 |
| 被压住（非自由端） | 轻微变暗，箭头隐藏 |
| 选中移动 | 平滑滑动，身体跟随 |
| 碰撞反弹 | 震动反馈，尾巴变头原路退回 |

### 游戏规则
1. **网格系统**：游戏基于不可见的网格，每个小虫占据连续的网格单元
2. **移动规则**：点击箭头方向后，小虫头部前进一格，身体跟随（类似贪吃蛇）
3. **碰撞反弹**：头部碰到其他小虫身体时，尾巴变成新头部，沿原路退回起点
4. **过关条件**：将所有小虫移出屏幕边界即过关
5. **关卡递进**：每过一关网格细化一格（10×10 → 11×11 → 12×12...）

## 🏗️ 项目结构

```
line_game/
├── project.godot              # Godot项目配置（竖屏Android适配）
├── README.md                  # 本文件
├── scenes/
│   └── main.tscn             # 主场景（包含GameScene和UILayer）
└── scripts/
    ├── game_manager.gd       # 全局游戏管理器（状态、音效、震动）
    ├── save_manager.gd       # 存档系统（JSON格式）
    ├── worm.gd               # 核心网格小虫类（贪吃蛇移动）
    ├── level_generator.gd    # 网格关卡生成器（随关卡增大网格）
    ├── game_scene.gd         # 游戏主逻辑（网格点击、相机控制）
    └── ui_layer.gd           # UI管理系统
```

## 📦 核心模块说明

### Worm（网格小虫）
```gdscript
class_name Worm
extends Area2D
```

核心功能：
- **网格移动**：基于 `Vector2i` 网格坐标，网格大小 40px
- **贪吃蛇跟随**：`move_one_step()` 实现头部牵引、身体跟随
- **碰撞反弹**：`start_reverse()` 尾巴变头、原路退回
- **三角形头部**：白色三角形箭头，指示移动方向

关键属性：
```gdscript
grid_positions: Array[Vector2i]      # 网格位置（头部在索引0）
move_direction: Vector2i             # 移动方向（四方向）
move_history: Array[Vector2i]        # 移动历史（用于反弹）
```

### LevelGenerator（网格关卡生成器）
```gdscript
class_name LevelGenerator
extends Node
```

生成算法：
1. **网格大小**：基础10×10，每关增加1（第N关为 (9+N)×(9+N)）
2. **路径生成**：随机蜿蜒路径，允许90度转弯，避免自交
3. **可解性验证**：确保至少有一个小虫的自由端未被覆盖

难度曲线：
| 关卡范围 | 网格大小 | 虫子数量 | 复杂度 |
|---------|---------|---------|--------|
| 1-5 | 10×10 ~ 14×14 | 3-4 条 | 0.2 |
| 6-15 | 15×15 ~ 24×24 | 4-6 条 | 0.4 |
| 16+ | 25×25+ | 6-10 条 | 0.6 |

### GameScene（游戏场景）
```gdscript
extends Node2D
```

核心逻辑：
- **相机自适应**：根据网格大小自动调整缩放和位置
- **箭头指示器**：在可移动小虫头部显示方向箭头
- **点击检测**：检测点击是否在箭头方向，触发移动
- **反弹处理**：碰撞后自动触发反弹动画

## 🛠️ 技术特性

### 零素材原则
- **无外部图片**：所有视觉元素程序化生成（Polygon2D绘制）
- **程序音效**：使用 `AudioStreamGenerator` 合成音效
- **动态着色**：霓虹色彩 + CanvasItem.modulate 发光效果

### 网格系统
```gdscript
const GRID_SIZE: float = 40.0

func _grid_to_world(grid_pos: Vector2i) -> Vector2:
    return Vector2(grid_pos.x * GRID_SIZE, grid_pos.y * GRID_SIZE)
```

### 贪吃蛇移动算法
```gdscript
func move_one_step(all_worms: Array[Worm]) -> bool:
    # 1. 检查碰撞
    if check_collision_ahead(all_worms):
        start_reverse()  # 碰撞则反弹
        return false
    
    # 2. 记录历史（用于反弹）
    move_history.append(grid_positions[-1])
    
    # 3. 身体跟随（从尾部开始）
    for i in range(grid_positions.size() - 1, 0, -1):
        grid_positions[i] = grid_positions[i - 1]
    
    # 4. 头部前进
    grid_positions[0] += move_direction
```

### 反弹机制
```gdscript
func start_reverse() -> void:
    grid_positions.reverse()  # 尾巴变头
    move_direction = grid_positions[0] - grid_positions[1]
    move_history.clear()
    # 自动沿原路退回...
```

### Android适配
- **竖屏锁定**：720x1280 分辨率，自适应拉伸
- **触摸热区**：检测半径 = 网格中心 ± 头部大小
- **震动反馈**：支持 `Input.vibrate_handheld()`

## 🚀 运行方式

### 开发环境
- **引擎**：Godot 4.4+
- **语言**：GDScript（严格类型）
- **平台**：Android 10+（API 29+）

### 本地运行
1. 安装 [Godot 4.4](https://godotengine.org/)
2. 打开项目文件夹 `line_game/`
3. 按 **F5** 或点击播放按钮运行

### Android导出
1. 项目 → 导出 → 添加 Android 预设
2. 配置 SDK 路径
3. 启用 `VIBRATE` 权限
4. 导出 APK

## 📝 存档格式

存档位置：`user://save.json`

```json
{
  "current_level": 5,
  "settings": {
    "sound_enabled": true,
    "sound_volume": 0.8,
    "vibration_enabled": true,
    "colorblind_mode": false
  },
  "level_stats": {
    "3": {
      "best_moves": 4,
      "last_played": {...}
    }
  }
}
```

## 🎨 颜色配置

霓虹色彩预设（`Worm.NEON_COLORS`）：
```gdscript
Color(1.0, 0.5, 0.0)   # 橙色
Color(0.0, 0.8, 1.0)   # 青色
Color(1.0, 0.2, 0.6)   # 粉色
Color(0.2, 1.0, 0.4)   # 绿色
Color(0.8, 0.3, 1.0)   # 紫色
Color(1.0, 0.9, 0.2)   # 黄色
```

## 🔧 调试技巧

启用调试输出：
```gdscript
# game_manager.gd
var remaining_worms: int = 0:
    set(value):
        remaining_worms = value
        print("DEBUG: remaining_worms = ", value)
```

常见问题：
1. **小虫不移动**：检查 `is_free_end` 是否正确计算
2. **碰撞检测失败**：确认 `is_grid_on_body` 排除头部判断
3. **箭头不显示**：检查 `_update_direction_arrows` 是否在 `_process` 中调用

## 📄 许可证

MIT License - 可自由使用和修改

## 🙏 致谢

- **玩法灵感**：Snake（贪吃蛇）、Slither Link（数线）
- **视觉参考**：Neon Drive、Mini Metro（极简线条）
- **技术参考**：拓扑排序（可解性验证）

---

**文档版本**：v2.0  
**最后更新**：2026-03-29  
**适用引擎**：Godot 4.4+  
**目标平台**：Android（竖屏）
