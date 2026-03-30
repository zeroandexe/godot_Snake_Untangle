## GameScene - 游戏主场景
## 管理网格游戏流程、虫子实例化、输入处理等

extends Node2D

# 节点引用
@onready var worms_container: Node2D = $WormsContainer
@onready var particles: GPUParticles2D = $Particles
@onready var camera: Camera2D = $Camera2D

# 游戏状态
var worms: Array[Worm] = []
var selected_worm: Worm = null
var is_input_enabled: bool = true

# 关卡数据
var level_generator: LevelGenerator
var grid_width: int = 10
var grid_height: int = 10

# 箭头指示器（显示可移动方向）
var direction_arrows: Dictionary = {}  # worm_id -> arrow_node

# 调试选项
var show_grid_lines: bool = false  # 设为true可显示网格线（调试用）

func _ready() -> void:
	# 初始化关卡生成器
	level_generator = LevelGenerator.new(GameManager.current_level)
	var grid_size = level_generator.get_grid_size()
	grid_width = grid_size.width
	grid_height = grid_size.height
	
	# 根据屏幕尺寸和网格数量动态计算框格尺寸，确保覆盖整个游戏画面
	_calculate_grid_size()
	
	# 延迟调整相机和绘制（确保视口尺寸已准备好）
	call_deferred("_adjust_camera")
	call_deferred("_draw_grid_lines")
	
	# 生成关卡
	_generate_level()
	
	# 延迟更新UI
	call_deferred("_update_ui")
	
	# 连接信号
	GameManager.level_started.emit(GameManager.current_level)
	
	# 绘制游戏区域边界（可视化调试）
	_draw_game_area_border()
	
	# 设置随机背景
	_update_background()

## 计算网格单元大小，确保覆盖整个游戏画面
func _calculate_grid_size() -> void:
	var viewport_size = get_viewport_rect().size
	
	# 计算每个网格单元的大小，使游戏区域覆盖整个屏幕
	# X和Y方向分别计算，支持非正方形网格
	Worm.GRID_SIZE_X = viewport_size.x / grid_width
	Worm.GRID_SIZE_Y = viewport_size.y / grid_height
	
	print("屏幕尺寸: ", viewport_size)
	print("网格数量: ", grid_width, "x", grid_height)
	print("计算出的 GRID_SIZE_X: ", Worm.GRID_SIZE_X)
	print("计算出的 GRID_SIZE_Y: ", Worm.GRID_SIZE_Y)
	
	# 更新所有小虫的身体段大小
	_update_all_worms_body_sizes()

## 调整相机以居中显示游戏区域
## 游戏区域覆盖整个屏幕
func _adjust_camera() -> void:
	if not camera:
		return
	
	# 计算网格中心
	var grid_center = Vector2(grid_width * Worm.GRID_SIZE_X, grid_height * Worm.GRID_SIZE_Y) / 2
	camera.position = grid_center
	
	# 游戏区域已覆盖整个屏幕，使用1.0缩放
	camera.zoom = Vector2(1.0, 1.0)

func _generate_level() -> void:
	# 清除现有虫子和箭头
	_clear_worms()
	_clear_direction_arrows()
	
	# 生成关卡数据
	var viewport_size = get_viewport_rect().size
	var worms_data = level_generator.generate_level(viewport_size)
	
	# 实例化虫子
	for i in range(worms_data.size()):
		var data = worms_data[i]
		_create_worm(data, i)
	
	# 创建方向箭头
	_create_direction_arrows()
	
	# 更新自由端状态
	_update_free_end_status()
	
	# 更新游戏管理器
	GameManager.remaining_worms = worms.size()
	
	# 更新UI
	_update_ui()
	
	# 更新所有小虫的身体段大小
	_update_all_worms_body_sizes()

func _create_worm(data: Dictionary, z_idx: int) -> void:
	var worm = Worm.new()
	worm.worm_id = data["id"]
	worm.worm_color = Worm.NEON_COLORS[data["color_index"]]
	worm.z_index = z_idx
	worm.create_from_grid_positions(data["grid_positions"])
	
	# 连接信号
	worm.clicked.connect(_on_worm_clicked)
	worm.move_started.connect(_on_worm_move_started)
	worm.move_failed.connect(_on_worm_move_failed)
	worm.move_reversed.connect(_on_worm_move_reversed)
	worm.move_completed.connect(_on_worm_move_completed)
	worm.removed.connect(_on_worm_removed)
	
	worms_container.add_child(worm)
	worms.append(worm)

## 创建方向箭头（显示在可移动虫子的头部）
func _create_direction_arrows() -> void:
	# 小虫自身头部已作为方向指示，无需额外创建箭头
	pass

## 更新方向箭头位置（小虫自身头部已作为指示，无需额外处理）
func _update_direction_arrows() -> void:
	pass

## 清除方向箭头
func _clear_direction_arrows() -> void:
	direction_arrows.clear()

## 清理所有虫子
func _clear_worms() -> void:
	for child in worms_container.get_children():
		if child is Worm and is_instance_valid(child):
			_safe_disconnect(child.clicked, _on_worm_clicked)
			_safe_disconnect(child.move_started, _on_worm_move_started)
			_safe_disconnect(child.move_failed, _on_worm_move_failed)
			_safe_disconnect(child.move_reversed, _on_worm_move_reversed)
			_safe_disconnect(child.move_completed, _on_worm_move_completed)
			_safe_disconnect(child.removed, _on_worm_removed)
			
			child.current_state = Worm.State.REMOVED
			child.queue_free()
	
	worms.clear()

## 安全断开信号辅助函数
func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)

## 更新自由端状态
func _update_free_end_status() -> void:
	for worm in worms:
		if not is_instance_valid(worm):
			continue
		if worm.current_state != Worm.State.IDLE:
			continue
		
		var is_free = _check_worm_is_free(worm)
		worm.set_free_end_state(is_free)
	
	# 更新方向箭头显示
	_update_direction_arrows()

## 检查虫子是否是自由端
func _check_worm_is_free(worm: Worm) -> bool:
	var head = worm.get_head_grid()
	var tail = worm.get_tail_grid()
	
	for other in worms:
		if not is_instance_valid(other):
			continue
		if other == worm or other.current_state == Worm.State.REMOVED:
			continue
		
		# 检查头部是否被其他虫子的身体覆盖（不包括头部）
		if other.is_grid_on_body(head, true):
			return false
		
		# 检查尾部是否被其他虫子的身体覆盖
		if other.is_grid_on_body(tail, true):
			return false
	
	return true

## 获取所有虫子（供Worm类调用）
func get_all_worms() -> Array[Worm]:
	return worms

## 更新所有小虫的身体段大小
func _update_all_worms_body_sizes() -> void:
	for worm in worms:
		if is_instance_valid(worm):
			worm.update_body_sizes()

# 输入处理
func _input(event: InputEvent) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	if not is_input_enabled:
		return
	
	# 触摸/鼠标处理
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			var touch_pos = get_global_mouse_position()
			_handle_touch(touch_pos)

## 处理触摸/点击
func _handle_touch(pos: Vector2) -> void:
	# 检测点击的虫子
	var clicked_worm = _get_worm_at_position(pos)
	
	if clicked_worm and clicked_worm.is_free_end:
		# 点击小虫身体任意位置都可以触发移动
		if clicked_worm.try_move():
			GameManager.worm_moved.emit(clicked_worm, true)
	elif clicked_worm and not clicked_worm.is_free_end:
		# 点击了不可移动的虫子
		GameManager.vibrate(20)
		_show_blocked_hint(clicked_worm)

## 检查点击是否在移动方向上
func _is_click_in_direction(worm: Worm, click_pos: Vector2) -> bool:
	var head_pos = worm.get_head_position()
	var dir = Vector2(worm.move_direction.x, worm.move_direction.y)
	
	# 计算点击位置相对于头部的方向
	var click_dir = (click_pos - head_pos).normalized()
	
	# 计算点积（判断方向是否一致）
	var dot = click_dir.dot(dir)
	
	# 如果点击方向与移动方向大致相同（允许45度偏差）
	return dot > 0.7

## 显示方向提示
func _show_direction_hint(worm: Worm) -> void:
	# 创建闪烁效果提示玩家点击箭头方向
	var tween = create_tween()
	tween.set_loops(3)
	tween.tween_property(worm, "modulate", Color(1.5, 1.5, 0.5, 1.0), 0.1)
	tween.tween_property(worm, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)

## 显示被阻挡提示
func _show_blocked_hint(worm: Worm) -> void:
	# 创建闪烁效果提示玩家这条虫子被阻挡
	var tween = create_tween()
	tween.set_loops(2)
	tween.tween_property(worm, "modulate", Color(1.5, 0.3, 0.3, 0.8), 0.15)
	tween.tween_property(worm, "modulate", Color(0.6, 0.6, 0.6, 0.5), 0.15)

## 获取位置处的虫子
func _get_worm_at_position(pos: Vector2) -> Worm:
	# 从上到下检测（按z_index倒序）
	var sorted_worms = worms.duplicate()
	sorted_worms.sort_custom(func(a, b): return a.z_index > b.z_index)
	
	for worm in sorted_worms:
		if worm.current_state == Worm.State.IDLE and worm.is_point_on_worm(pos):
			return worm
	
	return null

## 虫子点击回调
func _on_worm_clicked(worm: Worm) -> void:
	# 选中小虫时的处理
	selected_worm = worm
	GameManager.worm_selected.emit(worm)
	GameManager.play_sound("select")

## 虫子开始移动回调
func _on_worm_move_started(_worm: Worm) -> void:
	is_input_enabled = false
	_update_direction_arrows()

## 虫子移动失败回调（反弹完成后）
func _on_worm_move_failed(_worm: Worm) -> void:
	is_input_enabled = true
	_update_free_end_status()

## 虫子反弹回调
func _on_worm_move_reversed(_worm: Worm) -> void:
	# 反弹时更新方向箭头
	_update_direction_arrows()

## 虫子移出屏幕完成回调
func _on_worm_move_completed(worm: Worm) -> void:
	_play_success_effect(worm)

## 虫子被移除回调
func _on_worm_removed(worm: Worm) -> void:
	if not is_instance_valid(worm):
		return
	if not worms.has(worm):
		return
	
	# 移除对应的箭头
	var arrow = direction_arrows.get(worm.worm_id)
	if arrow and is_instance_valid(arrow):
		arrow.queue_free()
	direction_arrows.erase(worm.worm_id)
	
	# 立即从数组中移除
	worms.erase(worm)
	
	# 减少计数
	GameManager.remaining_worms = max(0, GameManager.remaining_worms - 1)
	
	_update_ui()
	
	# 播放移除动画
	worm.play_remove_animation()
	
	# 检查胜利条件
	if GameManager.remaining_worms <= 0:
		_level_completed()
	else:
		# 重新启用输入并更新状态
		is_input_enabled = true
		_update_free_end_status()

## 播放成功效果
func _play_success_effect(worm: Worm) -> void:
	# 粒子效果
	particles.position = worm.get_head_position()
	particles.emitting = true
	
	GameManager.vibrate(30)
	await get_tree().create_timer(0.1).timeout
	GameManager.vibrate(30)

## 关卡完成
func _level_completed() -> void:
	GameManager.complete_level()
	
	# 显示胜利UI
	_show_victory_ui()
	
	# 延迟进入下一关
	await get_tree().create_timer(2.0).timeout
	
	GameManager.current_level += 1
	
	# 重新创建关卡生成器以获取新的网格大小
	level_generator = LevelGenerator.new(GameManager.current_level)
	var grid_size = level_generator.get_grid_size()
	grid_width = grid_size.width
	grid_height = grid_size.height
	
	# 重新计算框格尺寸（网格数量改变，框格大小会自动调整以覆盖屏幕）
	_calculate_grid_size()
	
	# 调整相机并生成新关卡
	_adjust_camera()
	_draw_grid_lines()  # 重新绘制网格线
	_generate_level()
	
	# 更新所有小虫的身体段大小（已在 _generate_level 中调用，这里确保）
	_update_all_worms_body_sizes()
	
	# 切换到下一关随机背景
	_update_background()
	
	# 恢复游戏状态
	is_input_enabled = true
	GameManager.current_state = GameManager.GameState.PLAYING

## 获取UI层
func _get_ui_layer() -> CanvasLayer:
	return get_node_or_null("../UILayer") as CanvasLayer

## 更新背景图片
func _update_background() -> void:
	var bg_texture = GameManager.get_random_background()
	if bg_texture == null:
		return
	var bg_node = get_node_or_null("../GameBackground") as TextureRect
	if bg_node:
		bg_node.texture = bg_texture
		bg_node.visible = true

## 更新UI
func _update_ui() -> void:
	var ui_data = {
		"level": GameManager.current_level,
		"remaining": GameManager.remaining_worms,
	}
	
	var ui = _get_ui_layer()
	if ui and ui.has_method("update_game_ui"):
		ui.update_game_ui(ui_data)

## 显示胜利UI
func _show_victory_ui() -> void:
	var ui = _get_ui_layer()
	if ui and ui.has_method("show_victory"):
		ui.show_victory()

func _process(delta: float) -> void:
	# 更新虫子的移动
	var all_moving_done = true
	
	for worm in worms:
		if not is_instance_valid(worm):
			continue
		
		if worm.current_state == Worm.State.MOVING:
			all_moving_done = false
			worm.update_move(delta, worms, grid_width, grid_height)
		elif worm.current_state == Worm.State.REVERSING:
			all_moving_done = false
			worm.update_move(delta, worms, grid_width, grid_height)
	
	# 如果所有移动都完成了，重新启用输入
	if is_input_enabled == false and all_moving_done:
		var any_reversing = false
		for worm in worms:
			if worm.current_state == Worm.State.REVERSING:
				any_reversing = true
				break
		
		if not any_reversing:
			is_input_enabled = true
			_update_free_end_status()
	
	# 更新方向箭头位置
	_update_direction_arrows()

## 绘制网格线（调试用，默认不显示）
func _draw_grid_lines() -> void:
	var grid_lines = get_node_or_null("../GridLines")
	if not grid_lines:
		return
	
	# 清除旧的网格线
	for child in grid_lines.get_children():
		child.queue_free()
	
	if not show_grid_lines:
		return
	
	# 绘制垂直线
	for x in range(grid_width + 1):
		var line = Line2D.new()
		line.width = 1.0
		line.default_color = Color(0.2, 0.2, 0.2, 0.3)  # 很淡的灰色
		
		var points: PackedVector2Array = []
		points.append(Vector2(x * Worm.GRID_SIZE_X, 0))
		points.append(Vector2(x * Worm.GRID_SIZE_X, grid_height * Worm.GRID_SIZE_Y))
		line.points = points
		
		grid_lines.add_child(line)
	
	# 绘制水平线
	for y in range(grid_height + 1):
		var line = Line2D.new()
		line.width = 1.0
		line.default_color = Color(0.2, 0.2, 0.2, 0.3)
		
		var points: PackedVector2Array = []
		points.append(Vector2(0, y * Worm.GRID_SIZE_Y))
		points.append(Vector2(grid_width * Worm.GRID_SIZE_X, y * Worm.GRID_SIZE_Y))
		line.points = points
		
		grid_lines.add_child(line)


## 绘制游戏区域边界（可视化调试）
func _draw_game_area_border() -> void:
	var border = Line2D.new()
	border.name = "GameAreaBorder"
	border.width = 3.0
	border.default_color = Color(0.5, 0.5, 0.5, 0.5)  # 半透明灰色
	
	# 计算游戏区域的四个角
	var top_left = Vector2(0, 0)
	var top_right = Vector2(grid_width * Worm.GRID_SIZE_X, 0)
	var bottom_right = Vector2(grid_width * Worm.GRID_SIZE_X, grid_height * Worm.GRID_SIZE_Y)
	var bottom_left = Vector2(0, grid_height * Worm.GRID_SIZE_Y)
	
	# 绘制矩形边界
	var points: PackedVector2Array = [
		top_left,
		top_right,
		bottom_right,
		bottom_left,
		top_left  # 闭合
	]
	border.points = points
	
	add_child(border)
