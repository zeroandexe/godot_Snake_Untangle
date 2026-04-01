## GameConfig - 游戏配置中心
## 集中管理所有游戏参数，避免硬编码
## 修改此文件即可调整游戏平衡和表现

extends Node

# ============================================
# 视觉配置 (Visual)
# ============================================

const VISUAL = {
	# 虫子颜色主题（霓虹色）
	"neon_colors": [
		Color(1.0, 0.5, 0.0),   # 橙色
		Color(0.0, 0.8, 1.0),   # 青色
		Color(1.0, 0.2, 0.6),   # 粉色
		Color(0.2, 1.0, 0.4),   # 绿色
		Color(0.8, 0.3, 1.0),   # 紫色
		Color(1.0, 0.9, 0.2),   # 黄色
	],
	
	# 状态颜色
	"free_end_highlight": Color(1.5, 1.5, 1.5, 1.0),
	"free_end_normal": Color(1.0, 1.0, 1.0, 1.0),
	"blocked_dim": Color(0.8, 0.8, 0.8, 1.0),
	"blocked_hint": Color(1.5, 0.3, 0.3, 0.8),
	"direction_hint": Color(1.5, 1.5, 0.5, 1.0),
	
	# 身体段大小比例（相对于网格尺寸）
	"head_size_ratio": 0.8,
	"body_size_ratio": 0.6,
	"tail_size_ratio": 0.4,
	"touch_padding_ratio": 0.3,
	
	# 头部三角形
	"head_arrow_size_ratio": 0.6,
	
	# 网格线颜色
	"grid_line_color": Color(0.2, 0.2, 0.2, 0.3),
	"grid_line_width": 1.0,
	"game_area_border_color": Color(0.5, 0.5, 0.5, 0.5),
	"game_area_border_width": 3.0,
}

# ============================================
# 游戏机制配置 (Gameplay)
# ============================================

const GAMEPLAY = {
	# 关卡生成
	"base_grid_size": 10,           # 第一关网格宽度
	"grid_size_increment": 1,       # 每关宽度增加
	"min_worm_segments": 5,         # 虫子最小长度
	"max_worm_segments": 15,        # 虫子最大长度
	"min_grid_coverage": 0.7,       # 最小网格覆盖率 (0.0-1.0)
	
	# 移动参数
	"move_interval": 0.15,          # 每格移动间隔（秒）
	"move_reverse_interval": 0.1,   # 反弹移动间隔（秒，可选）
	
	# 难度曲线
	"difficulty": {
		"easy_levels": 5,           # 简单关卡数 (complexity = 0.3)
		"medium_levels": 15,        # 中等关卡数 (complexity = 0.5)
		"hard_complexity": 0.7,     # 困难复杂度
		"easy_complexity": 0.3,
		"medium_complexity": 0.5,
	},
	
	# 路径生成
	"path_generation": {
		"turn_probability": 0.3,    # 转弯概率 (0.0-1.0)
		"max_generation_attempts": 100,  # 关卡生成最大尝试次数
		"max_placement_attempts": 100,   # 位置寻找最大尝试次数
	},
	
	# 碰撞与检测
	"direction_dot_threshold": 0.7,  # 方向判断阈值（点积）
}

# ============================================
# 音频配置 (Audio)
# ============================================

const AUDIO = {
	# 默认音量
	"default_volume": 0.8,
	"min_volume_threshold": 0.001,  # 最小有效音量（防止log计算错误）
	
	# 程序生成音效频率 (Hz)
	"frequencies": {
		"move": 523.0,      # C5
		"success": 880.0,   # A5
		"fail": 200.0,      # 低频
	},
	
	# 音效持续时间 (秒)
	"durations": {
		"select": 0.0,      # 使用音频文件
		"move": 0.15,
		"success": 0.3,
		"fail": 0.2,
		"pop": 0.1,
		"collision": 0.0,   # 使用音频文件
		"death": 0.0,       # 使用音频文件
	},
	
	# 音效音量
	"volumes": {
		"move": 0.2,
		"success": 0.4,
		"fail": 0.3,
		"pop": 0.3,
	},
	
	# 震动时长 (毫秒)
	"vibration": {
		"short": 10,
		"medium": 20,
		"long": 30,
		"extra_long": 50,
		"double_interval": 0.1,  # 双震动间隔（秒）
	},
}

# ============================================
# 时间配置 (Timing)
# ============================================

const TIMING = {
	# 游戏流程
	"level_complete_delay": 2.0,    # 关卡完成到下一关延迟（秒）
	"level_complete_flash": 0.5,    # 闪光效果持续时间（秒）
	
	# 动画
	"remove_animation_duration": 0.3,   # 虫子移除动画（秒）
	"blocked_hint_duration": 0.15,      # 阻挡提示闪烁（秒）
	"blocked_hint_loops": 2,            # 阻挡提示闪烁次数
	"direction_hint_loops": 3,          # 方向提示闪烁次数
	"direction_hint_duration": 0.1,     # 方向提示闪烁（秒）
	
	# 输入
	"input_cooldown": 0.1,          # 输入冷却时间（秒，可选）
}

# ============================================
# 资源路径配置 (Resources)
# ============================================

const RESOURCES = {
	# 音效文件
	"sound_effects": {
		"collision": "res://source/sound/effects/worm_collision.wav",
		"death": "res://source/sound/effects/worm_death.wav",
		"select": "res://source/sound/effects/worm_select.wav",
	},
	
	# BGM 文件
	"bgm_tracks": [
		"res://source/sound/bgm/bg_1.wav",
		"res://source/sound/bgm/bg_2.wav",
	],
	
	# 背景图片
	"background_images": [
		"res://source/images/backgroup/bg_1.png",
		"res://source/images/backgroup/bg_2.png",
		"res://source/images/backgroup/bg_3.png",
		"res://source/images/backgroup/bg_4.png",
	],
}

# ============================================
# UI 配置 (UI)
# ============================================

const UI = {
	# 设置菜单
	"settings_menu": {
		"min_size": Vector2(400, 400),
		"button_min_size": Vector2(60, 60),
		"back_button_min_size": Vector2(200, 50),
		"title_font_size": 36,
		"subtitle_font_size": 28,
		"value_font_size": 48,
		"button_font_size": 32,
		"desc_font_size": 20,
		"element_separation": 20,
		"button_separation": 20,
	},
	
	# 关卡限制
	"max_start_level": 999,
	"min_start_level": 1,
	
	# HUD
	"hud": {
		"level_label_format": "Level %d",
		"remaining_label_format": "🐍 × %d",
		"score_label_format": "分数: %d",
		"score_label_with_multiplier_format": "分数: %d (x%d)",
	},
}

# ============================================
# 存档配置 (Save)
# ============================================

const SAVE = {
	"save_path": "user://save.json",
	"backup_path": "user://save_backup.json",
}

# ============================================
# 调试配置 (Debug)
# ============================================

const DEBUG = {
	"default_seed": 12345,
}

# ============================================
# 辅助方法
# ============================================

## 获取指定数量的颜色（循环使用）
static func get_colors(count: int) -> Array[Color]:
	var result: Array[Color] = []
	var colors: Array[Color] = VISUAL.neon_colors
	for i in range(count):
		result.append(colors[i % colors.size()])
	return result

## 获取随机颜色
static func get_random_color() -> Color:
	var colors = VISUAL.neon_colors
	return colors[randi() % colors.size()]

## 获取指定难度的复杂度
func get_complexity(level: int) -> float:
	var diff = GAMEPLAY.difficulty
	if level <= diff.easy_levels:
		return diff.easy_complexity
	elif level <= diff.medium_levels:
		return diff.medium_complexity
	else:
		return diff.hard_complexity

## 获取震动时长
static func get_vibration_duration(type: String) -> int:
	match type:
		"short": return AUDIO.vibration.short
		"medium": return AUDIO.vibration.medium
		"long": return AUDIO.vibration.long
		"extra_long": return AUDIO.vibration.extra_long
		_: return AUDIO.vibration.medium

## 获取音效频率
static func get_sound_frequency(type: String) -> float:
	return AUDIO.frequencies.get(type, 440.0)

## 获取音效持续时间
static func get_sound_duration(type: String) -> float:
	return AUDIO.durations.get(type, 0.2)
