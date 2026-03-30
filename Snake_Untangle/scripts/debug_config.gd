## DebugConfig - 调试配置全局文件
## 集中管理所有调试开关和开发选项
## 注意：发布生产版本前，应将所有 DEBUG_* 开关设为 false

extends Node

# ============================================
# 视觉调试开关
# ============================================

## 显示网格线（调试用）
static var SHOW_GRID_LINES: bool = true

## 显示游戏区域边界框
static var SHOW_GAME_AREA_BORDER: bool = true

## 显示虫子碰撞形状
static var SHOW_COLLISION_SHAPES: bool = false

## 显示移动方向箭头
static var SHOW_DIRECTION_ARROWS: bool = false

## 禁用背景图片（显示黑色背景，便于查看网格线）
static var DISABLE_BACKGROUND_IMAGES: bool = true

# ============================================
# 日志调试开关
# ============================================

## 打印详细的移动日志
static var LOG_WORM_MOVEMENT: bool = false

## 打印关卡生成信息
static var LOG_LEVEL_GENERATION: bool = false

## 打印性能统计
static var LOG_PERFORMANCE: bool = false

# ============================================
# 游戏机制调试
# ============================================

## 启用上帝模式（虫子不会死亡）
static var GOD_MODE: bool = false

## 显示关卡解法提示
static var SHOW_LEVEL_SOLUTION: bool = false

## 快速过关模式（点击任意虫子即可过关）
static var QUICK_CLEAR_MODE: bool = false

# ============================================
# 测试数据
# ============================================

## 使用固定随机种子（便于复现问题）
static var USE_FIXED_SEED: bool = false
static var FIXED_SEED: int = 12345

# ============================================
# 辅助方法
# ============================================

## 重置所有调试开关为默认值（发布前调用）
static func reset_to_production() -> void:
	SHOW_GRID_LINES = false
	SHOW_GAME_AREA_BORDER = false
	SHOW_COLLISION_SHAPES = false
	SHOW_DIRECTION_ARROWS = false
	DISABLE_BACKGROUND_IMAGES = false
	LOG_WORM_MOVEMENT = false
	LOG_LEVEL_GENERATION = false
	LOG_PERFORMANCE = false
	GOD_MODE = false
	SHOW_LEVEL_SOLUTION = false
	QUICK_CLEAR_MODE = false
	USE_FIXED_SEED = false

## 启用所有调试功能（开发调试时调用）
static func enable_all_debug() -> void:
	SHOW_GRID_LINES = true
	SHOW_GAME_AREA_BORDER = true
	SHOW_COLLISION_SHAPES = true
	SHOW_DIRECTION_ARROWS = true
	DISABLE_BACKGROUND_IMAGES = true
	LOG_WORM_MOVEMENT = true
	LOG_LEVEL_GENERATION = true

## 打印当前配置状态
static func print_status() -> void:
	print("=== DebugConfig 当前状态 ===")
	print("SHOW_GRID_LINES: ", SHOW_GRID_LINES)
	print("SHOW_GAME_AREA_BORDER: ", SHOW_GAME_AREA_BORDER)
	print("SHOW_COLLISION_SHAPES: ", SHOW_COLLISION_SHAPES)
	print("SHOW_DIRECTION_ARROWS: ", SHOW_DIRECTION_ARROWS)
	print("DISABLE_BACKGROUND_IMAGES: ", DISABLE_BACKGROUND_IMAGES)
	print("LOG_WORM_MOVEMENT: ", LOG_WORM_MOVEMENT)
	print("GOD_MODE: ", GOD_MODE)
	print("===========================")
