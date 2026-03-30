## GameManager - 游戏全局管理器
## 负责游戏状态管理、关卡控制、音效播放等

extends Node

# 信号
signal level_started(level: int)
signal level_completed(level: int)
@warning_ignore("unused_signal")
signal worm_selected(worm: Worm)
@warning_ignore("unused_signal")
signal worm_moved(worm: Worm, success: bool)
@warning_ignore("unused_signal")
signal worm_removed(worm: Worm)

# 游戏状态
enum GameState { MENU, PLAYING, GAME_OVER, LEVEL_COMPLETE }
var current_state: GameState = GameState.MENU
var current_level: int = 1

# 设置选项
var settings: Dictionary = {
	"sound_enabled": true,
	"sound_volume": 0.8,
	"vibration_enabled": true,
	"colorblind_mode": false,
}

# 关卡数据
var level_data: Dictionary = {}
var remaining_worms: int = 0

func _ready() -> void:
	_load_settings()

## 震动反馈
func vibrate(duration_ms: int) -> void:
	if not settings.vibration_enabled:
		return
	# 使用Godot内置震动（支持Android和iOS）
	if OS.has_feature("android") or OS.has_feature("ios"):
		Input.vibrate_handheld(duration_ms)

## 开始新关卡
func start_level(level: int) -> void:
	current_level = level
	current_state = GameState.PLAYING
	level_started.emit(level)

## 关卡完成
func complete_level() -> void:
	current_state = GameState.LEVEL_COMPLETE
	vibrate(30)
	await get_tree().create_timer(0.1).timeout
	vibrate(30)
	level_completed.emit(current_level)
	_save_progress()

## 保存进度
func _save_progress() -> void:
	SaveManager.save_game({
		"current_level": current_level,
		"settings": settings,
	})

## 加载设置
func _load_settings() -> void:
	var data = SaveManager.load_game()
	if data.has("settings"):
		settings = data.settings
	if data.has("current_level"):
		current_level = data.current_level

## 播放音效（程序生成）
func play_sound(type: String) -> void:
	if not settings.sound_enabled:
		return
	
	var player = AudioStreamPlayer.new()
	add_child(player)
	
	match type:
		"select":
			player.stream = _generate_tone(440.0, 0.1, 0.3)
		"move":
			player.stream = _generate_tone(523.0, 0.15, 0.2)
		"success":
			player.stream = _generate_tone(880.0, 0.3, 0.4)
		"fail":
			player.stream = _generate_tone(200.0, 0.2, 0.3)
		"pop":
			player.stream = _generate_noise(0.1, 0.3)
	
	player.play()
	await player.finished
	player.queue_free()

## 生成正弦波音效
func _generate_tone(frequency: float, duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate := 44100
	var samples := int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t := float(i) / sample_rate
		var envelope := 1.0 - (float(i) / samples)
		var value := sin(t * frequency * TAU) * envelope * volume * 32767
		data.encode_s16(i * 2, int(value))
	
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

## 生成噪声音效
func _generate_noise(duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate := 44100
	var samples := int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var envelope := 1.0 - (float(i) / samples)
		var value := (randf() * 2.0 - 1.0) * envelope * volume * 32767
		data.encode_s16(i * 2, int(value))
	
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false
	stream.mix_rate = sample_rate
	stream.data = data
	return stream
