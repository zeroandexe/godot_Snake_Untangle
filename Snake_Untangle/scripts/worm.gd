## Worm - 网格蛇形线段类
## 核心游戏实体，基于网格移动，支持贪吃蛇式身体跟随

class_name Worm
extends Area2D

# 信号
signal clicked(worm: Worm)
signal move_started(worm: Worm)
signal move_failed(worm: Worm)
signal move_completed(worm: Worm)
signal removed(worm: Worm)
signal move_reversed(worm: Worm)  # 新增：反弹信号

# 常量
static var GRID_SIZE_X: float = 40.0  # 网格单元X方向大小（动态计算，覆盖整个屏幕）
static var GRID_SIZE_Y: float = 40.0  # 网格单元Y方向大小（动态计算，覆盖整个屏幕）
const MIN_SEGMENTS: int = 5  # 最小长度
const MAX_SEGMENTS: int = 15  # 最大长度

# 小虫身体段大小（相对于框格尺寸的比例）
const HEAD_SIZE_RATIO: float = 0.8  # 头部大小占框格的80%
const BODY_SIZE_RATIO: float = 0.6  # 身体大小占框格的60%
const TAIL_SIZE_RATIO: float = 0.4  # 尾部大小占框格的40%
const TOUCH_PADDING_RATIO: float = 0.3  # 触摸边距占框格的30%

# 动态计算的身体段大小（根据框格尺寸）
var HEAD_SIZE: float = 32.0
var BODY_SIZE: float = 24.0
var TAIL_SIZE: float = 16.0
var TOUCH_PADDING: float = 15.0

# 颜色预设（霓虹色）
static var NEON_COLORS: Array[Color] = [
	Color(1.0, 0.5, 0.0),   # 橙色
	Color(0.0, 0.8, 1.0),   # 青色
	Color(1.0, 0.2, 0.6),   # 粉色
	Color(0.2, 1.0, 0.4),   # 绿色
	Color(0.8, 0.3, 1.0),   # 紫色
	Color(1.0, 0.9, 0.2),   # 黄色
]

# 状态
enum State { IDLE, MOVING, REVERSING, REMOVED }
var current_state: State = State.IDLE

# 网格身体数据 - 存储的是网格坐标 (grid_x, grid_y)
var grid_positions: Array[Vector2i] = []
var segment_count: int = 0

# 移动方向（单位向量，四个基本方向）
var move_direction: Vector2i = Vector2i.RIGHT

# 视觉节点
var body_segments: Array[Polygon2D] = []  # 身体段（包括头）
var head_triangle: Polygon2D = null  # 三角形头部

# 属性
var worm_color: Color = NEON_COLORS[0]
var worm_id: int = 0
var is_free_end: bool = false
var is_highlighted: bool = false

# 移动相关
var is_moving: bool = false
var move_timer: float = 0.0
const MOVE_INTERVAL: float = 0.15  # 每格移动间隔（秒）
var move_history: Array[Vector2i] = []  # 移动历史记录（用于反弹）

# 包围盒缓存
var bounding_box: Rect2 = Rect2()

func _init() -> void:
	z_index = 0
	# 动态计算身体段大小
	_calculate_body_sizes()

func _ready() -> void:
	# 创建视觉组件
	_create_visuals()
	_update_bounding_box()

## 动态计算身体段大小（根据框格尺寸）
func _calculate_body_sizes() -> void:
	# 使用较小的框格尺寸作为基准，确保小虫在两个方向都能完整显示
	var base_grid_size = min(GRID_SIZE_X, GRID_SIZE_Y)
	
	HEAD_SIZE = base_grid_size * HEAD_SIZE_RATIO
	BODY_SIZE = base_grid_size * BODY_SIZE_RATIO
	TAIL_SIZE = base_grid_size * TAIL_SIZE_RATIO
	TOUCH_PADDING = base_grid_size * TOUCH_PADDING_RATIO

## 更新身体段大小并重新绘制（当框格尺寸改变时调用）
func update_body_sizes() -> void:
	_calculate_body_sizes()
	_update_visuals()
	_update_bounding_box()

## 创建视觉组件
func _create_visuals() -> void:
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	_update_visuals()

## 更新所有视觉组件
func _update_visuals() -> void:
	# 清除旧的视觉组件
	for child in get_children():
		child.queue_free()
	body_segments.clear()
	head_triangle = null
	
	if grid_positions.is_empty():
		return
	
	# 创建连续的身体线条（使用Line2D）
	var body_line = Line2D.new()
	body_line.name = "BodyLine"
	
	# 将网格位置转换为世界坐标
	var world_points: PackedVector2Array = []
	for grid_pos in grid_positions:
		world_points.append(_grid_to_world(grid_pos))
	body_line.points = world_points
	
	# 设置线条样式
	body_line.default_color = worm_color
	body_line.width = BODY_SIZE
	body_line.joint_mode = Line2D.LINE_JOINT_ROUND
	body_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	body_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	body_line.antialiased = true
	
	# 设置渐变宽度（头部粗，尾部细）
	var widths: PackedFloat32Array = PackedFloat32Array()
	widths.resize(grid_positions.size())
	for i in range(grid_positions.size()):
		var t = float(i) / max(1, grid_positions.size() - 1)
		widths[i] = lerp(HEAD_SIZE, TAIL_SIZE, t)
	body_line.width_curve = _create_width_curve(widths)
	
	add_child(body_line)
	body_segments.append(body_line)
	
	# 创建三角形头部（在最上层）
	head_triangle = Polygon2D.new()
	head_triangle.name = "HeadTriangle"
	head_triangle.color = Color.WHITE  # 头部用白色突出
	_update_head_triangle()
	add_child(head_triangle)
	
	# 创建碰撞形状（用于输入检测）
	_update_collision_shape()

## 创建宽度曲线
func _create_width_curve(widths: PackedFloat32Array) -> Curve:
	var curve = Curve.new()
	for i in range(widths.size()):
		var t = float(i) / max(1, widths.size() - 1)
		curve.add_point(Vector2(t, widths[i] / BODY_SIZE))
	return curve

## 更新头部三角形
func _update_head_triangle() -> void:
	if grid_positions.size() < 2 or not head_triangle:
		return
	
	var head_pos = _grid_to_world(grid_positions[0])
	var neck_pos = _grid_to_world(grid_positions[1])
	var dir = Vector2(move_direction.x, move_direction.y).normalized()
	
	# 创建三角形箭头，指向移动方向
	var arrow_size = HEAD_SIZE * 0.6
	var perp = Vector2(-dir.y, dir.x)  # 垂直方向
	
	var triangle_points: PackedVector2Array = [
		head_pos + dir * arrow_size,  # 顶点
		head_pos - dir * arrow_size * 0.5 + perp * arrow_size * 0.6,  # 左下
		head_pos - dir * arrow_size * 0.5 - perp * arrow_size * 0.6,  # 右下
	]
	
	head_triangle.polygon = triangle_points

## 更新碰撞形状
func _update_collision_shape() -> void:
	var collision = get_node_or_null("CollisionShape")
	if collision:
		collision.queue_free()
	
	if grid_positions.is_empty():
		return
	
	var collision_shape = CollisionPolygon2D.new()
	collision_shape.name = "CollisionShape"
	
	# 创建覆盖连续身体的碰撞区域
	var collision_points: PackedVector2Array = []
	
	# 沿身体线段创建碰撞多边形（上半部分）
	for i in range(grid_positions.size()):
		var grid_pos = grid_positions[i]
		var center = _grid_to_world(grid_pos)
		var radius = lerp(HEAD_SIZE * 0.5, TAIL_SIZE * 0.5, float(i) / max(1, grid_positions.size() - 1))
		
		# 获取线段方向
		var dir: Vector2
		if i == 0:
			dir = (_grid_to_world(grid_positions[0]) - _grid_to_world(grid_positions[1])).normalized()
		elif i == grid_positions.size() - 1:
			dir = (_grid_to_world(grid_positions[i]) - _grid_to_world(grid_positions[i - 1])).normalized()
		else:
			dir = (_grid_to_world(grid_positions[i + 1]) - _grid_to_world(grid_positions[i - 1])).normalized()
		
		var perp = dir.orthogonal()
		collision_points.append(center + perp * radius)
	
	# 沿身体线段创建碰撞多边形（下半部分，反向）
	for i in range(grid_positions.size() - 1, -1, -1):
		var grid_pos = grid_positions[i]
		var center = _grid_to_world(grid_pos)
		var radius = lerp(HEAD_SIZE * 0.5, TAIL_SIZE * 0.5, float(i) / max(1, grid_positions.size() - 1))
		
		var dir: Vector2
		if i == 0:
			dir = (_grid_to_world(grid_positions[0]) - _grid_to_world(grid_positions[1])).normalized()
		elif i == grid_positions.size() - 1:
			dir = (_grid_to_world(grid_positions[i]) - _grid_to_world(grid_positions[i - 1])).normalized()
		else:
			dir = (_grid_to_world(grid_positions[i + 1]) - _grid_to_world(grid_positions[i - 1])).normalized()
		
		var perp = dir.orthogonal()
		collision_points.append(center - perp * radius)
	
	collision_shape.polygon = collision_points
	add_child(collision_shape)

## 从网格位置创建
func create_from_grid_positions(positions: Array[Vector2i]) -> void:
	grid_positions = positions.duplicate()
	segment_count = positions.size()
	
	# 计算初始移动方向（从第二段指向第一段）
	if grid_positions.size() >= 2:
		move_direction = grid_positions[0] - grid_positions[1]
	
	_update_visuals()
	_update_bounding_box()

## 生成随机网格形状
func generate_random_grid_shape(start_grid: Vector2i, grid_width: int, grid_height: int, length: int = -1) -> void:
	if length < 0:
		length = randi_range(MIN_SEGMENTS, MAX_SEGMENTS)
	
	length = clamp(length, MIN_SEGMENTS, MAX_SEGMENTS)
	grid_positions.clear()
	
	var current = start_grid
	grid_positions.append(current)
	
	var directions = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
	var current_dir = directions[randi() % directions.size()]
	
	var attempts = 0
	while grid_positions.size() < length and attempts < length * 10:
		attempts += 1
		
		# 70%概率继续当前方向，30%概率转弯
		if randf() < 0.3:
			# 转弯（90度）
			var turn_dirs = _get_perpendicular_directions(current_dir)
			current_dir = turn_dirs[randi() % turn_dirs.size()]
		
		var next = current + current_dir
		
		# 检查边界和自交
		if next.x < 0 or next.x >= grid_width or next.y < 0 or next.y >= grid_height:
			continue
		if next in grid_positions:
			continue
		
		grid_positions.append(next)
		current = next
	
	segment_count = grid_positions.size()
	
	# 计算初始移动方向
	if grid_positions.size() >= 2:
		move_direction = grid_positions[0] - grid_positions[1]
	
	_update_visuals()
	_update_bounding_box()

## 获取垂直方向
func _get_perpendicular_directions(dir: Vector2i) -> Array[Vector2i]:
	if dir.x != 0:  # 水平移动，返回垂直方向
		return [Vector2i.UP, Vector2i.DOWN]
	else:  # 垂直移动，返回水平方向
		return [Vector2i.RIGHT, Vector2i.LEFT]

## 网格坐标转世界坐标
func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * GRID_SIZE_X, grid_pos.y * GRID_SIZE_Y)

## 世界坐标转网格坐标
func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / GRID_SIZE_X), int(world_pos.y / GRID_SIZE_Y))

## 更新包围盒
func _update_bounding_box() -> void:
	if grid_positions.is_empty():
		bounding_box = Rect2()
		return
	
	var min_pos = _grid_to_world(grid_positions[0])
	var max_pos = min_pos
	
	for grid_pos in grid_positions:
		var world_pos = _grid_to_world(grid_pos)
		min_pos = min_pos.min(world_pos)
		max_pos = max_pos.max(world_pos)
	
	var padding = HEAD_SIZE + TOUCH_PADDING
	min_pos -= Vector2(padding, padding)
	max_pos += Vector2(padding, padding)
	
	bounding_box = Rect2(min_pos, max_pos - min_pos)

## 获取头部网格位置
func get_head_grid() -> Vector2i:
	if grid_positions.is_empty():
		return Vector2i.ZERO
	return grid_positions[0]

## 获取尾部网格位置
func get_tail_grid() -> Vector2i:
	if grid_positions.is_empty():
		return Vector2i.ZERO
	return grid_positions[grid_positions.size() - 1]

## 获取头部世界坐标
func get_head_position() -> Vector2:
	return _grid_to_world(get_head_grid())

## 获取尾部世界坐标
func get_tail_position() -> Vector2:
	return _grid_to_world(get_tail_grid())

## 检查点是否在小虫上（用于触摸检测）
func is_point_on_worm(point: Vector2, tolerance: float = TOUCH_PADDING) -> bool:
	# 快速AABB检测
	if not bounding_box.has_point(point):
		return false
	
	# 检查点是否在身体线段上（连续检测）
	for i in range(grid_positions.size() - 1):
		var start_pos = _grid_to_world(grid_positions[i])
		var end_pos = _grid_to_world(grid_positions[i + 1])
		
		# 计算点到线段的距离
		var closest = Geometry2D.get_closest_point_to_segment(point, start_pos, end_pos)
		var dist = closest.distance_to(point)
		
		# 根据线段位置计算合适的检测半径（头部粗，尾部细）
		var t = float(i) / max(1, grid_positions.size() - 2)
		var radius = lerp(HEAD_SIZE, TAIL_SIZE, t) * 0.5 + tolerance
		
		if dist <= radius:
			return true
	
	# 单独检查头部（三角形区域）
	if head_triangle and head_triangle.polygon.size() >= 3:
		var head_pos = _grid_to_world(grid_positions[0])
		if head_pos.distance_to(point) <= (HEAD_SIZE * 0.8 + tolerance):
			return true
	
	return false

## 检查网格位置是否在小虫身体上（不包括头部）
func is_grid_on_body(grid_pos: Vector2i, exclude_head: bool = true) -> bool:
	var start_idx = 1 if exclude_head else 0
	for i in range(start_idx, grid_positions.size()):
		if grid_positions[i] == grid_pos:
			return true
	return false

## 检查小虫是否与其他小虫相交
func intersects_with(other: Worm) -> bool:
	# 快速AABB检测
	if not bounding_box.intersects(other.bounding_box):
		return false
	
	# 检查头部是否与其他小虫身体相交
	var head = get_head_grid()
	if other.is_grid_on_body(head, false):  # 包括其他小虫的头部
		return true
	
	# 检查身体是否与其他小虫相交
	for i in range(1, grid_positions.size()):
		if other.is_grid_on_body(grid_positions[i], false):
			return true
	
	return false

## 检查头部前方是否有碰撞
func check_collision_ahead(all_worms: Array[Worm]) -> bool:
	var next_pos = get_head_grid() + move_direction
	
	for other in all_worms:
		if not is_instance_valid(other):
			continue
		if other == self or other.current_state == State.REMOVED:
			continue
		
		# 检查下一位置是否在其他小虫的身体上
		if other.is_grid_on_body(next_pos, false):
			return true
	
	return false

## 设置高亮状态
func set_highlighted(highlighted: bool) -> void:
	is_highlighted = highlighted
	
	if highlighted:
		modulate = Color(1.4, 1.4, 1.4, 1.0)
	else:
		modulate = Color(1.0, 1.0, 1.0, 1.0)

## 设置自由端状态（视觉反馈）
func set_free_end_state(is_free: bool) -> void:
	is_free_end = is_free
	
	if is_free:
		modulate = Color(1.5, 1.5, 1.5, 1.0)
		if head_triangle:
			head_triangle.color = Color.WHITE
	else:
		modulate = Color(0.8, 0.8, 0.8, 1.0)
		if head_triangle:
			head_triangle.color = worm_color.darkened(0.3)

## 尝试开始移动（沿头部方向前进一格）
func try_move() -> bool:
	if current_state != State.IDLE:
		return false
	
	if not is_free_end:
		return false
	
	# 检查前方是否可以移动
	var next_pos = get_head_grid() + move_direction
	
	# 这里只检查基本有效性，实际碰撞检测在移动时进行
	current_state = State.MOVING
	move_timer = 0.0
	move_started.emit(self)
	
	GameManager.vibrate(10)
	GameManager.play_sound("move")
	
	return true

## 开始反弹（尾巴变头，原路返回）
func start_reverse() -> void:
	if current_state == State.REVERSING:
		return
	
	current_state = State.REVERSING
	
	# 反转身体
	grid_positions.reverse()
	
	# 新的移动方向是从新的头部指向原来的头部（即原来的尾部方向）
	if grid_positions.size() >= 2:
		move_direction = grid_positions[0] - grid_positions[1]
	
	# 清除移动历史
	move_history.clear()
	
	# 更新视觉
	_update_visuals()
	_update_bounding_box()
	
	GameManager.vibrate(50)
	GameManager.play_sound("fail")
	
	move_reversed.emit(self)

## 执行一格移动（贪吃蛇式：头前进，身体跟随）
func move_one_step(all_worms: Array[Worm], grid_width: int, grid_height: int) -> bool:
	var next_pos = get_head_grid() + move_direction
	
	# 检查是否撞墙（头部移出游戏区域边界，包括最外层）
	if next_pos.x < 0 or next_pos.x >= grid_width or next_pos.y < 0 or next_pos.y >= grid_height:
		# 撞墙消失
		current_state = State.REMOVED
		move_completed.emit(self)
		removed.emit(self)
		GameManager.play_sound("death")
		return true
	
	# 检查与其他虫子的碰撞
	for other in all_worms:
		if not is_instance_valid(other):
			continue
		if other == self or other.current_state == State.REMOVED:
			continue
		
		# 如果下一位置在其他小虫的身体上（包括其头部），发生碰撞
		if other.is_grid_on_body(next_pos, false):  # false表示包括其他小虫的头部
			# 发生碰撞，播放碰撞音效并开始反弹
			GameManager.play_sound("collision")
			start_reverse()
			return false
	
	# 记录移动历史（用于反弹时原路返回）
	move_history.append(grid_positions[grid_positions.size() - 1])
	
	# 贪吃蛇移动：从尾部开始，每个段移动到前一个段的位置
	for i in range(grid_positions.size() - 1, 0, -1):
		grid_positions[i] = grid_positions[i - 1]
	
	# 头部移动到下一位置
	grid_positions[0] = next_pos
	
	# 更新视觉
	_update_visuals()
	_update_bounding_box()
	
	return true

## 反弹移动一格（尾巴变头后原路返回）
func reverse_one_step() -> bool:
	if move_history.is_empty():
		# 已经回到原位，停止反弹
		current_state = State.IDLE
		move_failed.emit(self)
		return false
	
	# 获取原位置
	var original_tail = move_history.pop_back()
	
	# 反向移动：头部后退，身体反向跟随
	for i in range(grid_positions.size() - 1, 0, -1):
		grid_positions[i] = grid_positions[i - 1]
	
	grid_positions[0] = original_tail
	
	# 更新移动方向
	if grid_positions.size() >= 2:
		move_direction = grid_positions[0] - grid_positions[1]
	
	# 更新视觉
	_update_visuals()
	_update_bounding_box()
	
	return true

## 更新移动（每帧调用）
func update_move(delta: float, all_worms: Array[Worm], grid_width: int, grid_height: int) -> void:
	if current_state == State.IDLE or current_state == State.REMOVED:
		return
	
	move_timer += delta
	
	if move_timer >= MOVE_INTERVAL:
		move_timer = 0.0
		
		if current_state == State.MOVING:
			move_one_step(all_worms, grid_width, grid_height)
		elif current_state == State.REVERSING:
			reverse_one_step()

## 检查是否移出屏幕
func is_fully_off_screen(screen_grid_width: int, screen_grid_height: int) -> bool:
	# 检查是否所有段都在屏幕外
	for grid_pos in grid_positions:
		if grid_pos.x >= 0 and grid_pos.x < screen_grid_width:
			if grid_pos.y >= 0 and grid_pos.y < screen_grid_height:
				return false
	return true

## 播放移除动画
func play_remove_animation() -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	
	# 淡出
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	
	await tween.finished
	queue_free()

## 停止移动
func stop_move() -> void:
	current_state = State.IDLE
	move_timer = 0.0

## 输入事件处理
func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if current_state == State.IDLE and is_free_end:
				clicked.emit(self)

func _process(delta: float) -> void:
	# 更新移动
	if current_state == State.MOVING or current_state == State.REVERSING:
		var parent = get_parent()
		if parent and parent.has_method("get_all_worms"):
			var g_width = parent.get("grid_width") if parent.has_method("get_all_worms") else 10
			var g_height = parent.get("grid_height") if parent.has_method("get_all_worms") else 10
			update_move(delta, parent.get_all_worms(), g_width, g_height)
