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

# === 性能优化：空间哈希网格缓存 ===
# grid_cache[Vector2i] = worm，用于 O(1) 碰撞检测
var _grid_cache: Dictionary = {}
var _free_end_dirty: bool = true  # 自由端状态脏标记
var _cached_free_worms: Array[Worm] = []  # 缓存的自由端虫子

# 调试配置已移至 debug_config.gd，通过 DebugConfig.SHOW_GRID_LINES 访问

func _ready() -> void:
	# 连接信号
	GameManager.level_started.connect(_on_level_started)
	
	# 初始化关卡生成器
	level_generator = LevelGenerator.new(GameManager.current_level)
	var grid_size = level_generator.get_grid_size()
	grid_width = grid_size.width
	# 注意：grid_height 由 _calculate_grid_size 根据屏幕尺寸动态计算
	
	# 根据屏幕尺寸和网格数量动态计算框格尺寸，确保覆盖整个游戏画面
	_calculate_grid_size()
	
	# 延迟调整相机和绘制（确保视口尺寸已准备好）
	call_deferred("_adjust_camera")
	call_deferred("_draw_grid_lines")
	
	# 生成关卡
	_generate_level()
	
	# 延迟更新UI
	call_deferred("_update_ui")
	
	# 绘制游戏区域边界（可视化调试）
	call_deferred("_draw_game_area_border")
	
	# 设置随机背景
	_update_background()


## 关卡开始信号回调 - 重新生成关卡
func _on_level_started(level: int) -> void:
	# 清除现有关卡
	_clear_worms()
	_clear_direction_arrows()
	
	# 重新初始化关卡生成器
	level_generator = LevelGenerator.new(level)
	var grid_size = level_generator.get_grid_size()
	grid_width = grid_size.width
	
	# 重新计算网格大小
	_calculate_grid_size()
	
	# 调整相机
	_adjust_camera()
	_draw_grid_lines()
	
	# 生成新关卡
	_generate_level()
	
	# 更新UI
	_update_ui()
	
	# 更新背景
	_update_background()

## 计算网格单元大小
## 每个网格是正方形，宽度填满屏幕，高度方向第一行和最后一行分配余数
func _calculate_grid_size() -> void:
	var viewport_size = get_viewport_rect().size
	
	# 根据宽度计算基准网格尺寸（正方形）
	var base_grid_size: float = viewport_size.x / grid_width
	
	# 计算高度方向能容纳多少完整网格
	var full_rows: int = int(viewport_size.y / base_grid_size)
	
	# 计算余数（多出来的高度）
	var remainder: float = viewport_size.y - full_rows * base_grid_size
	
	# 设置网格参数
	Worm.GRID_SIZE_X = base_grid_size
	Worm.GRID_SIZE_Y = base_grid_size
	Worm.GRID_SIZE = base_grid_size
	Worm.GRID_HEIGHT = full_rows
	Worm.FIRST_ROW_EXTRA = remainder / 2
	Worm.LAST_ROW_EXTRA = remainder / 2
	
	# 更新本地网格高度变量（用于其他计算）
	grid_height = full_rows
	
	# 更新 level_generator 的高度（用于蛇的生成和移动边界）
	if level_generator:
		level_generator.set_grid_height(full_rows)
	
	print("屏幕尺寸: ", viewport_size)
	print("网格宽度: ", grid_width, " 网格高度: ", grid_height)
	print("基准网格尺寸: ", base_grid_size)
	print("第一行额外高度: ", Worm.FIRST_ROW_EXTRA)
	print("最后一行额外高度: ", Worm.LAST_ROW_EXTRA)
	
	# 更新所有小虫的身体段大小
	_update_all_worms_body_sizes()

## 调整相机以居中显示游戏区域
## 游戏区域覆盖整个屏幕
func _adjust_camera() -> void:
	if not camera:
		return
	
	var viewport_size = get_viewport_rect().size
	
	# 相机位于屏幕中心
	camera.position = viewport_size / 2
	
	# 游戏区域已覆盖整个屏幕，使用1.0缩放
	camera.zoom = Vector2(1.0, 1.0)

func _generate_level() -> void:
	# 清除现有虫子和箭头
	_clear_worms()
	_clear_direction_arrows()
	
	# 清空网格缓存
	_grid_cache.clear()
	_cached_free_worms.clear()
	_free_end_dirty = true
	
	# 生成关卡数据
	var viewport_size = get_viewport_rect().size
	var worms_data = level_generator.generate_level(viewport_size)
	
	# 实例化虫子
	for i in range(worms_data.size()):
		var data = worms_data[i]
		_create_worm(data, i)
	
	# 创建方向箭头
	_create_direction_arrows()
	
	# 立即更新自由端状态（确保虫子可以被点击）
	_free_end_dirty = true
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
## 优化：减少不必要的 is_instance_valid 检查
func _clear_worms() -> void:
	for child in worms_container.get_children():
		if child is Worm:
			_safe_disconnect(child.clicked, _on_worm_clicked)
			_safe_disconnect(child.move_started, _on_worm_move_started)
			_safe_disconnect(child.move_failed, _on_worm_move_failed)
			_safe_disconnect(child.move_reversed, _on_worm_move_reversed)
			_safe_disconnect(child.move_completed, _on_worm_move_completed)
			_safe_disconnect(child.removed, _on_worm_removed)
			
			child.current_state = Worm.State.REMOVED
			child.queue_free()
	
	worms.clear()
	_cached_free_worms.clear()
	_grid_cache.clear()

## 安全断开信号辅助函数
func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)

## 重建网格空间哈希缓存
func _rebuild_grid_cache() -> void:
	_grid_cache.clear()
	for worm in worms:
		if worm.current_state == Worm.State.REMOVED:
			continue
		# 只缓存身体部分（不包括头部），用于碰撞检测
		for i in range(1, worm.grid_positions.size()):
			_grid_cache[worm.grid_positions[i]] = worm

## 检查网格位置是否被占用（使用空间哈希，O(1)）
func _is_grid_occupied(grid_pos: Vector2i, exclude_worm: Worm = null) -> bool:
	var worm = _grid_cache.get(grid_pos)
	if worm == null:
		return false
	if exclude_worm != null and worm == exclude_worm:
		return false
	return true

## 更新自由端状态（脏标记版本）
func _update_free_end_status() -> void:
	if not _free_end_dirty:
		return
	
	# 重建网格缓存
	_rebuild_grid_cache()
	
	_cached_free_worms.clear()
	
	for worm in worms:
		if worm.current_state != Worm.State.IDLE:
			continue
		
		var is_free = _check_worm_is_free_fast(worm)
		worm.set_free_end_state(is_free)
		
		if is_free:
			_cached_free_worms.append(worm)
	
	_free_end_dirty = false
	
	# 更新方向箭头显示
	_update_direction_arrows()

## 检查虫子是否是自由端（快速版本，使用空间哈希）
func _check_worm_is_free_fast(worm: Worm) -> bool:
	var head = worm.get_head_grid()
	var tail = worm.get_tail_grid()
	
	# 使用网格缓存进行 O(1) 查询
	if _is_grid_occupied(head, worm):
		return false
	if _is_grid_occupied(tail, worm):
		return false
	
	return true

## 检查虫子是否是自由端（兼容旧版本，用于外部调用）
func _check_worm_is_free(worm: Worm) -> bool:
	return _check_worm_is_free_fast(worm)

## 获取所有虫子（供Worm类调用）
func get_all_worms() -> Array[Worm]:
	return worms

## 更新所有小虫的身体段大小
## 优化：移除不必要的 is_instance_valid 检查
func _update_all_worms_body_sizes() -> void:
	for worm in worms:
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
## 优化：使用预排序的数组，避免每次点击都复制和排序
func _get_worm_at_position(pos: Vector2) -> Worm:
	# 直接遍历（通常虫子数量不多，无需复杂优化）
	# 优先检查 IDLE 状态和自由端，快速跳过不可交互的虫子
	for worm in worms:
		if worm.current_state != Worm.State.IDLE:
			continue
		if not worm.is_free_end:
			continue
		if worm.is_point_on_worm(pos):
			return worm
	
	# 如果没有找到可移动的，再检查所有 IDLE 状态的虫子（用于显示被阻挡提示）
	for worm in worms:
		if worm.current_state != Worm.State.IDLE:
			continue
		if worm.is_point_on_worm(pos):
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
	_free_end_dirty = true
	_update_free_end_status()

## 虫子反弹回调
func _on_worm_move_reversed(_worm: Worm) -> void:
	# 反弹时更新方向箭头
	_update_direction_arrows()

## 虫子移出屏幕完成回调
func _on_worm_move_completed(worm: Worm) -> void:
	_play_success_effect(worm)

## 虫子被移除回调
## 优化：简化有效性检查，依赖正常生命周期管理
func _on_worm_removed(worm: Worm) -> void:
	if not worms.has(worm):
		return
	
	# 移除对应的箭头
	var arrow = direction_arrows.get(worm.worm_id)
	if arrow:
		arrow.queue_free()
	direction_arrows.erase(worm.worm_id)
	
	# 立即从数组中移除
	worms.erase(worm)
	
	# 减少计数
	GameManager.remaining_worms = max(0, GameManager.remaining_worms - 1)
	
	# 标记脏标记
	_free_end_dirty = true
	
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
	
	# 重新创建关卡生成器以获取新的网格宽度
	level_generator = LevelGenerator.new(GameManager.current_level)
	var grid_size = level_generator.get_grid_size()
	grid_width = grid_size.width
	# 注意：高度由 _calculate_grid_size 根据屏幕尺寸动态计算
	
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
	var bg_node = get_node_or_null("../GameBackground") as TextureRect
	if not bg_node:
		return
	
	# 如果禁用了背景图片，显示黑色背景（便于查看网格线）
	if DebugConfig.DISABLE_BACKGROUND_IMAGES:
		bg_node.visible = false
		return
	
	var bg_texture = GameManager.get_random_background()
	if bg_texture == null:
		return
	
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
	var any_state_changed = false
	
	for worm in worms:
		if not is_instance_valid(worm):
			continue
		
		var prev_state = worm.current_state
		
		if worm.current_state == Worm.State.MOVING:
			all_moving_done = false
			worm.update_move(delta, worms, grid_width, grid_height)
		elif worm.current_state == Worm.State.REVERSING:
			all_moving_done = false
			worm.update_move(delta, worms, grid_width, grid_height)
		
		# 检测状态变化，标记脏标记
		if worm.current_state != prev_state and prev_state != Worm.State.IDLE:
			any_state_changed = true
	
	# 如果有状态变化，标记自由端需要重新计算
	if any_state_changed:
		_free_end_dirty = true
	
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
## 支持第一行和最后一行的额外高度
func _draw_grid_lines() -> void:
	var grid_lines = get_node_or_null("../GridLines")
	if not grid_lines:
		return
	
	# 清除旧的网格线
	for child in grid_lines.get_children():
		child.queue_free()
	
	if not DebugConfig.SHOW_GRID_LINES:
		return
	
	var viewport_size = get_viewport_rect().size
	
	# 绘制垂直线（垂直线不受高度调整影响）
	for x in range(grid_width + 1):
		var line = Line2D.new()
		line.width = 1.0
		line.default_color = Color(0.2, 0.2, 0.2, 0.3)  # 很淡的灰色
		
		var points: PackedVector2Array = []
		points.append(Vector2(x * Worm.GRID_SIZE_X, 0))
		points.append(Vector2(x * Worm.GRID_SIZE_X, viewport_size.y))
		line.points = points
		
		grid_lines.add_child(line)
	
	# 绘制水平线（需要考虑第一行和最后一行的额外高度）
	var current_y: float = 0
	
	for y in range(grid_height + 1):
		var line = Line2D.new()
		line.width = 1.0
		line.default_color = Color(0.2, 0.2, 0.2, 0.3)
		
		var points: PackedVector2Array = []
		points.append(Vector2(0, current_y))
		points.append(Vector2(viewport_size.x, current_y))
		line.points = points
		
		grid_lines.add_child(line)
		
		# 计算下一行的 Y 坐标
		if y == 0:
			# 第一行底部 = 第一行额外高度 + 基准高度
			current_y += Worm.FIRST_ROW_EXTRA + Worm.GRID_SIZE
		elif y == grid_height - 1:
			# 最后一行底部 = 最后一行额外高度 + 基准高度
			current_y += Worm.LAST_ROW_EXTRA + Worm.GRID_SIZE
		else:
			# 中间行 = 基准高度
			current_y += Worm.GRID_SIZE
	
	
	## 绘制游戏区域边界（可视化调试）
func _draw_game_area_border() -> void:
	if not DebugConfig.SHOW_GAME_AREA_BORDER:
		return
	
	var viewport_size = get_viewport_rect().size
	
	var border = Line2D.new()
	border.name = "GameAreaBorder"
	border.width = 3.0
	border.default_color = Color(0.5, 0.5, 0.5, 0.5)  # 半透明灰色
	
	# 游戏区域就是整个屏幕
	var top_left = Vector2(0, 0)
	var top_right = Vector2(viewport_size.x, 0)
	var bottom_right = Vector2(viewport_size.x, viewport_size.y)
	var bottom_left = Vector2(0, viewport_size.y)
	
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
