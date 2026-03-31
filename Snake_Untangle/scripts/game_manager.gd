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

# 设置选项（使用配置默认值）
var settings: Dictionary = {
	"sound_enabled": true,
	"sound_volume": GameConfig.AUDIO.default_volume,
	"vibration_enabled": true,
	"colorblind_mode": false,
	"start_level": 1,  # 起始关卡设置
}

# 关卡数据
var level_data: Dictionary = {}
var remaining_worms: int = 0

# 音效资源（在 _ready 中动态加载）
var collision_sound: AudioStream
var death_sound: AudioStream
var select_sound: AudioStream

# BGM
var bgm_player: AudioStreamPlayer
var bgm_tracks: Array[AudioStream] = []
var bgm_indices: Array[int] = []
var bgm_remaining_count: int = 0

# 背景图片
var bg_images: Array[Texture2D] = []
var bg_indices: Array[int] = []
var bg_remaining_count: int = 0

func _ready() -> void:
	randomize()
	_load_sound_effects()
	_load_settings()
	_init_bgm_player()
	_load_bgm_tracks()
	_load_bg_images()
	# 延迟一帧确保资源完全加载
	call_deferred("_play_bgm")

## 加载音效资源
func _load_sound_effects() -> void:
	collision_sound = load(GameConfig.RESOURCES.sound_effects.collision)
	death_sound = load(GameConfig.RESOURCES.sound_effects.death)
	select_sound = load(GameConfig.RESOURCES.sound_effects.select)

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
	# 移除震动效果，让玩家可以快速点击进入下一关
	level_completed.emit(current_level)
	save_progress()

## 保存进度
func save_progress() -> void:
	SaveManager.save_game({
		"current_level": current_level,
		"settings": settings,
	})

## 获取起始关卡设置
func get_start_level() -> int:
	return settings.get("start_level", 1)

## 设置起始关卡
func set_start_level(level: int) -> void:
	if level < 1:
		level = 1
	settings.start_level = level
	save_progress()
	print("起始关卡已设置为: ", level)

## 加载设置
func _load_settings() -> void:
	var data = SaveManager.load_game()
	if data.has("settings"):
		settings = data.settings
		# 验证音量值有效
		if settings.has("sound_volume"):
			var vol = settings.sound_volume
			if vol <= 0.0 or vol > 1.0:
				settings.sound_volume = GameConfig.AUDIO.default_volume
				print("音量值无效，重置为默认值: ", GameConfig.AUDIO.default_volume)
		# 验证起始关卡有效
		if settings.has("start_level"):
			var start_lvl = settings.start_level
			if start_lvl < 1 or start_lvl > 1000:
				settings.start_level = 1
		else:
			settings.start_level = 1
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
			player.stream = select_sound
		"move":
			player.stream = _generate_tone(
				GameConfig.AUDIO.frequencies.move,
				GameConfig.AUDIO.durations.move,
				GameConfig.AUDIO.volumes.move
			)
		"success":
			player.stream = _generate_tone(
				GameConfig.AUDIO.frequencies.success,
				GameConfig.AUDIO.durations.success,
				GameConfig.AUDIO.volumes.success
			)
		"fail":
			player.stream = _generate_tone(
				GameConfig.AUDIO.frequencies.fail,
				GameConfig.AUDIO.durations.fail,
				GameConfig.AUDIO.volumes.fail
			)
		"pop":
			player.stream = _generate_noise(
				GameConfig.AUDIO.durations.pop,
				GameConfig.AUDIO.volumes.pop
			)
		"collision":
			player.stream = collision_sound
		"death":
			player.stream = death_sound
	
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

## 初始化 BGM 播放器
func _init_bgm_player() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Master"
	# 防止 volume 为 0 时 linear_to_db 返回 -INF
	var vol = max(settings.sound_volume, GameConfig.AUDIO.min_volume_threshold)
	bgm_player.volume_db = linear_to_db(vol)
	bgm_player.finished.connect(_on_bgm_finished)
	add_child(bgm_player)
	print("BGM 播放器初始化完成，音量: ", bgm_player.volume_db, " dB")

## 动态加载 BGM 目录下的所有音频文件
func _load_bgm_tracks() -> void:
	# 使用配置中的文件列表
	var bgm_files: Array[String] = []
	bgm_files.assign(GameConfig.RESOURCES.bgm_tracks)
	
	for path in bgm_files:
		if ResourceLoader.exists(path):
			var stream = ResourceLoader.load(path, "AudioStream", ResourceLoader.CACHE_MODE_REUSE)
			if stream is AudioStream:
				bgm_tracks.append(stream)
				print("BGM 加载成功: ", path)
			else:
				push_warning("BGM 加载失败（类型不匹配）: " + path)
		else:
			push_warning("BGM 文件不存在: " + path)
	
	bgm_indices.resize(bgm_tracks.size())
	for i in range(bgm_tracks.size()):
		bgm_indices[i] = i
	bgm_remaining_count = bgm_tracks.size()
	print("BGM 总数: ", bgm_tracks.size())

## 播放 BGM
func _play_bgm() -> void:
	if not settings.sound_enabled:
		print("BGM 未播放：音效被禁用")
		return
	if bgm_remaining_count == 0:
		print("BGM 未播放：没有可用的曲目")
		return
	if bgm_player.playing:
		print("BGM 未播放：已经在播放中")
		return
	
	var idx := randi() % bgm_remaining_count
	var track_index: int = bgm_indices[idx]
	var stream = bgm_tracks[track_index]
	
	print("正在播放 BGM: 索引=", track_index, ", 剩余=", bgm_remaining_count)
	
	bgm_player.stream = stream
	bgm_player.set_meta("current_index", idx)
	bgm_player.play()

## BGM 播放完成回调
func _on_bgm_finished() -> void:
	var idx: int = bgm_player.get_meta("current_index", 0)
	# 将当前索引交换到未播放区的尾部
	var last_idx := bgm_remaining_count - 1
	var temp := bgm_indices[idx]
	bgm_indices[idx] = bgm_indices[last_idx]
	bgm_indices[last_idx] = temp
	bgm_remaining_count -= 1
	if bgm_remaining_count == 0:
		bgm_remaining_count = bgm_tracks.size()
	_play_bgm()

## 动态加载背景图片
func _load_bg_images() -> void:
	# 使用配置中的文件列表
	var bg_files: Array[String] = []
	bg_files.assign(GameConfig.RESOURCES.background_images)
	
	for path in bg_files:
		if ResourceLoader.exists(path):
			var texture = ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
			if texture is Texture2D:
				bg_images.append(texture)
				print("背景图片加载成功: ", path)
			else:
				push_warning("背景图片加载失败（类型不匹配）: " + path)
		else:
			push_warning("背景图片文件不存在: " + path)
	
	bg_indices.resize(bg_images.size())
	for i in range(bg_images.size()):
		bg_indices[i] = i
	bg_remaining_count = bg_images.size()
	print("背景图片总数: ", bg_images.size())

## 获取随机背景图片（不重复，全部用完一轮后重置）
func get_random_background() -> Texture2D:
	if bg_images.is_empty():
		return null
	if bg_remaining_count == 0:
		bg_remaining_count = bg_images.size()
	var idx := randi() % bg_remaining_count
	var image_index: int = bg_indices[idx]
	# 交换到尾部
	var last_idx := bg_remaining_count - 1
	var temp := bg_indices[idx]
	bg_indices[idx] = bg_indices[last_idx]
	bg_indices[last_idx] = temp
	bg_remaining_count -= 1
	return bg_images[image_index]
