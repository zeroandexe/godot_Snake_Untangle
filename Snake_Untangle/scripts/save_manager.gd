## SaveManager - 存档管理器
## 处理游戏数据的保存和加载

extends Node

const SAVE_PATH: String = "user://save.json"
const BACKUP_PATH: String = "user://save_backup.json"

## 保存游戏数据
func save_game(data: Dictionary) -> bool:
	var json_string = JSON.stringify(data, "\t")
	
	# 先备份现有存档
	if FileAccess.file_exists(SAVE_PATH):
		var old_data = FileAccess.get_file_as_string(SAVE_PATH)
		var backup_file = FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
		if backup_file:
			backup_file.store_string(old_data)
			backup_file.close()
	
	# 写入新存档
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("无法保存游戏: " + str(FileAccess.get_open_error()))
		return false
	
	file.store_string(json_string)
	file.close()
	return true

## 加载游戏数据
func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return _get_default_data()
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("无法加载游戏: " + str(FileAccess.get_open_error()))
		return _get_default_data()
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		push_error("JSON解析错误: " + str(error))
		return _get_default_data()
	
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return _get_default_data()
	
	return data

## 获取默认数据
func _get_default_data() -> Dictionary:
	return {
		"current_level": 1,
		"settings": {
			"sound_enabled": true,
			"sound_volume": 0.8,
			"vibration_enabled": true,
			"colorblind_mode": false,
		},
		"level_stats": {},
	}

## 重置存档
func reset_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(BACKUP_PATH)

## 保存关卡统计
func save_level_stats(level: int, moves: int, time_seconds: float) -> void:
	var data = load_game()
	
	if not data.has("level_stats"):
		data.level_stats = {}
	
	var level_key = str(level)
	var best_moves = moves
	var best_time = time_seconds
	
	if data.level_stats.has(level_key):
		var old_stats = data.level_stats[level_key]
		if old_stats.has("best_moves"):
			best_moves = min(moves, old_stats.best_moves)
		if old_stats.has("best_time"):
			best_time = min(time_seconds, old_stats.best_time)
	
	data.level_stats[level_key] = {
		"best_moves": best_moves,
		"best_time": best_time,
		"last_played": Time.get_datetime_dict_from_system(),
	}
	
	save_game(data)
