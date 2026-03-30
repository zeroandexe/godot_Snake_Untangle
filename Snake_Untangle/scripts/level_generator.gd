## LevelGenerator - 网格关卡生成器
## 生成基于网格的可解关卡

class_name LevelGenerator
extends Node

# 配置参数
const BASE_GRID_SIZE: int = 10  # 基础网格大小（第一关）
const MIN_WORM_SEGMENTS: int = 5  # 最小长度增加，让小虫更长
const MAX_WORM_SEGMENTS: int = 15  # 最大长度增加，让小虫更长
const MIN_COVERAGE: float = 0.7  # 最小覆盖率（70%的网格被占用）

# 难度参数
var grid_width: int = 10
var grid_height: int = 10
var worm_count: int = 0
var complexity: float = 0.5

# 生成结果
var generated_worms: Array[Dictionary] = []
var solution_order: Array[int] = []

func _init(level: int = 1) -> void:
	_set_difficulty(level)

## 设置难度
## 每过一关网格大小增加1（10x10 -> 11x11 -> 12x12...）
func _set_difficulty(level: int) -> void:
	# 网格大小随关卡增加
	var grid_size = BASE_GRID_SIZE + (level - 1)
	grid_width = grid_size
	grid_height = grid_size
	
	# 根据关卡数设置复杂度（影响交叉程度）
	if level <= 5:
		complexity = 0.3
	elif level <= 15:
		complexity = 0.5
	else:
		complexity = 0.7
	
	# 小虫数量不再固定，而是根据覆盖率动态生成
	worm_count = 0  # 将在生成时动态计算

## 生成关卡数据
func generate_level(screen_size: Vector2) -> Array[Dictionary]:
	generated_worms.clear()
	solution_order.clear()
	
	# 步骤1: 生成解开状态（所有虫子不交叉）
	var solved_state = _generate_solved_state()
	
	# 步骤2: 添加一些随机交叉（根据复杂度）
	var stacked_state = _add_crossings(solved_state)
	
	# 步骤3: 验证可解性
	if not _verify_solvability(stacked_state):
		# 如果不可解，重新生成
		return generate_level(screen_size)
	
	return stacked_state

## 生成解开状态（铺满整个界面，避开最外层）
func _generate_solved_state() -> Array[Dictionary]:
	var worms: Array[Dictionary] = []
	var occupied_grids: Array[Vector2i] = []
	
	# 计算可用网格数量（避开最外层）
	var available_width = grid_width - 2
	var available_height = grid_height - 2
	var available_grids = available_width * available_height
	var target_coverage = available_grids * MIN_COVERAGE  # 目标覆盖的网格数
	
	var attempts = 0
	var max_attempts = available_grids * 10  # 最大尝试次数
	
	# 持续生成小虫，直到达到目标覆盖率或无法继续
	while occupied_grids.size() < target_coverage and attempts < max_attempts:
		attempts += 1
		
		# 随机选择一个起始位置（不在已占用的网格上）
		var start_pos = _find_random_free_position(occupied_grids)
		if start_pos == Vector2i(-1, -1):
			break  # 没有可用位置了
		
		# 生成虫子路径
		var path = _generate_worm_path_random(start_pos, occupied_grids)
		
		if path.size() >= MIN_WORM_SEGMENTS:
			var worm_data: Dictionary = {
				"grid_positions": path,
				"color_index": worms.size() % Worm.NEON_COLORS.size(),
				"id": worms.size(),
				"original_order": worms.size(),
			}
			
			worms.append(worm_data)
			
			# 标记这些网格为已占用
			for pos in path:
				occupied_grids.append(pos)
	
	print("生成了 ", worms.size(), " 条小虫，覆盖了 ", occupied_grids.size(), " / ", available_grids, " 个可用网格（避开最外层）")
	
	return worms

## 随机寻找一个空闲位置（避开最外层）
func _find_random_free_position(occupied: Array[Vector2i]) -> Vector2i:
	var attempts = 0
	var max_attempts = 100
	
	while attempts < max_attempts:
		attempts += 1
		
		# 避开最外层，从第1格到倒数第1格
		var x = randi() % (grid_width - 2) + 1
		var y = randi() % (grid_height - 2) + 1
		var pos = Vector2i(x, y)
		
		if not pos in occupied:
			return pos
	
	return Vector2i(-1, -1)

## 生成单条虫子的路径（随机方向和长度，避开最外层）
func _generate_worm_path_random(start: Vector2i, occupied: Array[Vector2i]) -> Array[Vector2i]:
	var path: Array[Vector2i] = [start]
	var current = start
	
	# 随机选择初始方向
	var current_dir = _get_random_direction()
	
	# 随机长度
	var target_length = randi_range(MIN_WORM_SEGMENTS, MAX_WORM_SEGMENTS)
	var attempts = 0
	var max_attempts = target_length * 50
	
	while path.size() < target_length and attempts < max_attempts:
		attempts += 1
		
		# 30%概率转弯
		if randf() < 0.3:
			current_dir = _get_turn_direction(current_dir)
		
		var next = current + current_dir
		
		# 检查边界（避开最外层）
		if next.x < 1 or next.x >= grid_width - 1 or next.y < 1 or next.y >= grid_height - 1:
			continue
		
		# 检查是否与其他虫子重叠
		if next in occupied:
			continue
		
		# 检查是否自交
		if next in path:
			continue
		
		path.append(next)
		current = next
	
	return path

## 获取随机方向
func _get_random_direction() -> Vector2i:
	var dirs = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
	return dirs[randi() % dirs.size()]

## 获取转弯方向（90度）
func _get_turn_direction(current: Vector2i) -> Vector2i:
	if current.x != 0:  # 水平移动，返回垂直方向
		return Vector2i.UP if randf() < 0.5 else Vector2i.DOWN
	else:  # 垂直移动，返回水平方向
		return Vector2i.RIGHT if randf() < 0.5 else Vector2i.LEFT

## 添加交叉（模拟堆叠）
func _add_crossings(worms_data: Array[Dictionary]) -> Array[Dictionary]:
	var result = worms_data.duplicate(true)
	
	# 根据复杂度随机交换一些虫子的层级顺序
	var num_swaps = int(worms_data.size() * complexity * 2)
	
	for i in range(num_swaps):
		if result.size() < 2:
			break
		
		var idx1 = randi() % result.size()
		var idx2 = (idx1 + 1 + randi() % (result.size() - 1)) % result.size()
		
		# 交换顺序
		var temp = result[idx1]
		result[idx1] = result[idx2]
		result[idx2] = temp
	
	return result

## 验证可解性
func _verify_solvability(worms_data: Array[Dictionary]) -> bool:
	# 创建临时Worm对象进行验证
	var temp_worms: Array[Worm] = []
	
	for data in worms_data:
		var worm = Worm.new()
		worm.worm_id = data["id"]
		worm.worm_color = Worm.NEON_COLORS[data["color_index"]]
		worm.create_from_grid_positions(data["grid_positions"])
		temp_worms.append(worm)
	
	# 使用拓扑排序检查是否存在解
	var remaining = temp_worms.duplicate()
	var removal_order: Array[int] = []
	var max_iterations = worms_data.size() * 2
	
	while not remaining.is_empty() and max_iterations > 0:
		max_iterations -= 1
		var found_free = false
		
		for worm in remaining:
			if _is_worm_free(worm, remaining):
				removal_order.append(worm.worm_id)
				remaining.erase(worm)
				found_free = true
				break
		
		if not found_free:
			_cleanup_temp_worms(temp_worms)
			return false
	
	_cleanup_temp_worms(temp_worms)
	solution_order = removal_order
	return true

## 检查虫子是否是自由端
func _is_worm_free(worm: Worm, all_worms: Array[Worm]) -> bool:
	var head = worm.get_head_grid()
	var tail = worm.get_tail_grid()
	
	for other in all_worms:
		if other == worm:
			continue
		
		# 检查头部或尾部是否被其他虫子的身体覆盖
		if other.is_grid_on_body(head, true):  # true: 不包括其他虫子的头部
			return false
		if other.is_grid_on_body(tail, true):
			return false
	
	return true

## 清理临时虫子
func _cleanup_temp_worms(worms: Array[Worm]) -> void:
	for worm in worms:
		worm.queue_free()

## 获取网格大小
func get_grid_size() -> Dictionary:
	return {
		"width": grid_width,
		"height": grid_height,
	}

## 获取生成配置
func get_generation_config() -> Dictionary:
	return {
		"grid_width": grid_width,
		"grid_height": grid_height,
		"worm_count": worm_count,
		"complexity": complexity,
		"solution_order": solution_order,
	}
