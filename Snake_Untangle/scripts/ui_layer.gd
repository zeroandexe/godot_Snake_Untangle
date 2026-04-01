## UILayer - 游戏UI层
## 管理所有游戏界面元素

extends CanvasLayer

# 游戏HUD
@onready var hud: Control = $HUD
@onready var level_label: Label = $HUD/TopBar/LevelLabel
@onready var remaining_label: Label = $HUD/TopBar/RemainingLabel
@onready var score_label: Label = $HUD/BottomBar/ScoreLabel

# 菜单
@onready var victory_menu: Control = $Menus/VictoryMenu
@onready var main_menu: Control = $Menus/MainMenu

# 设置菜单节点（运行时创建）
var settings_menu: Control = null
var temp_start_level: int = 1

# 特效
@onready var flash_effect: ColorRect = $Effects/FlashEffect

var game_scene: Node2D = null
var game_background: TextureRect = null

func _ready() -> void:
	# 连接游戏管理器信号
	GameManager.level_started.connect(_on_level_started)
	GameManager.level_completed.connect(_on_level_completed)
	
	# 获取游戏背景节点
	game_background = get_node_or_null("../GameBackground")
	
	# 初始显示主菜单
	_show_main_menu()
	
	# 连接主菜单按钮
	var new_game_btn = main_menu.get_node_or_null("Panel/NewGameButton")
	var continue_btn = main_menu.get_node_or_null("Panel/ContinueButton")
	var settings_btn = main_menu.get_node_or_null("Panel/SettingsButton")
	
	if new_game_btn:
		new_game_btn.pressed.connect(_on_new_game_pressed)
	if continue_btn:
		continue_btn.pressed.connect(_on_continue_pressed)
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)
	
	# 根据是否有存档更新按钮状态
	_update_menu_buttons()
	
	# 胜利菜单按钮
	var next_btn = victory_menu.get_node_or_null("Panel/NextButton")
	if next_btn:
		next_btn.pressed.connect(_on_next_level_pressed)

## 更新游戏UI
func update_game_ui(data: Dictionary) -> void:
	if data.has("level") and level_label:
		level_label.text = GameConfig.UI.hud.level_label_format % data.level
	
	if data.has("remaining") and remaining_label:
		remaining_label.text = GameConfig.UI.hud.remaining_label_format % data.remaining
	
	if data.has("score") and score_label:
		var multiplier = data.get("multiplier", 1)
		if multiplier > 1:
			score_label.text = GameConfig.UI.hud.score_label_with_multiplier_format % [data.score, multiplier]
		else:
			score_label.text = GameConfig.UI.hud.score_label_format % data.score

## 显示胜利界面
func show_victory() -> void:
	# 直接显示胜利菜单，无动画效果，让玩家可以快速点击进入下一关
	victory_menu.visible = true

# 按钮回调
func _set_game_background_visible(show_bg: bool) -> void:
	if not game_background:
		return
	
	# 如果禁用了背景图片，始终隐藏
	if DebugConfig.DISABLE_BACKGROUND_IMAGES:
		game_background.visible = false
		return
	
	game_background.visible = show_bg

func _on_settings_pressed() -> void:
	GameManager.play_sound("select")
	_show_settings_menu()

func _on_next_level_pressed() -> void:
	if victory_menu:
		victory_menu.visible = false
	GameManager.play_sound("select")
	
	# 立即生成下一关，无延迟
	if game_scene:
		game_scene.generate_next_level()

func _on_level_completed(_level: int) -> void:
	# 胜利界面由game_scene调用show_victory显示
	pass

## 显示主菜单
func _show_main_menu() -> void:
	if main_menu:
		main_menu.visible = true
	if hud:
		hud.visible = false
	if victory_menu:
		victory_menu.visible = false
	_set_game_background_visible(false)
	GameManager.current_state = GameManager.GameState.MENU
	
	# 更新按钮状态
	_update_menu_buttons()

## 更新主菜单按钮状态（根据是否有存档）
func _update_menu_buttons() -> void:
	var continue_btn = main_menu.get_node_or_null("Panel/ContinueButton")
	var data = SaveManager.load_game()
	
	# 检查是否有存档进度
	var current_level = data.get("current_level", 1)
	var level_stats = data.get("level_stats", {})
	var has_save = current_level > 1 or not level_stats.is_empty()
	
	if continue_btn:
		continue_btn.disabled = not has_save
		continue_btn.modulate = Color(1, 1, 1, 1.0 if has_save else 0.3)

## 开始新游戏（使用设置的起始关卡）
func _on_new_game_pressed() -> void:
	GameManager.play_sound("select")
	
	# 获取设置的起始关卡
	var start_level = GameManager.get_start_level()
	
	# 清除存档数据，但保留设置
	var current_settings = GameManager.settings.duplicate()
	SaveManager.reset_save()
	GameManager.settings = current_settings
	
	# 清空积分
	GameManager.score = 0
	
	# 重新保存设置，确保 start_level 被正确保存
	SaveManager.save_game({
		"current_level": start_level,  # 使用起始关卡作为当前关卡
		"score": 0,  # 新游戏积分清零
		"settings": GameManager.settings,
	})
	
	# 设置当前关卡为起始关卡
	GameManager.current_level = start_level
	
	# 隐藏菜单，显示游戏
	if main_menu:
		main_menu.visible = false
	if hud:
		hud.visible = true
	_set_game_background_visible(true)
	
	# 获取游戏场景并开始
	game_scene = get_node_or_null("../GameScene")
	if game_scene:
		GameManager.start_level(start_level)

## 继续游戏
func _on_continue_pressed() -> void:
	if main_menu:
		main_menu.visible = false
	if hud:
		hud.visible = true
	
	# 获取游戏场景并开始
	game_scene = get_node_or_null("../GameScene")
	if game_scene:
		GameManager.start_level(GameManager.current_level)
	
	_set_game_background_visible(true)
	GameManager.play_sound("select")

func _on_level_started(_level: int) -> void:
	if hud:
		hud.visible = true
	if victory_menu:
		victory_menu.visible = false
	if main_menu:
		main_menu.visible = false
	_set_game_background_visible(true)

## ==================== 设置菜单 ====================

## 显示设置菜单
func _show_settings_menu() -> void:
	if settings_menu:
		settings_menu.visible = true
		return
	
	# 创建设置菜单
	_create_settings_menu()

## 创建设置菜单UI
func _create_settings_menu() -> void:
	settings_menu = Control.new()
	settings_menu.name = "SettingsMenu"
	settings_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# 半透明背景
	var overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.8)
	settings_menu.add_child(overlay)
	
	# 面板 - 使用居中锚点实现响应式布局
	var panel = Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	# 使用配置中的尺寸
	panel.custom_minimum_size = GameConfig.UI.settings_menu.min_size
	settings_menu.add_child(panel)
	
	# 创建垂直容器来管理所有元素
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)
	
	# 标题
	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "游戏设置"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", GameConfig.UI.settings_menu.title_font_size)
	vbox.add_child(title_label)
	
	# 起始关卡标签
	var level_title = Label.new()
	level_title.name = "LevelTitle"
	level_title.text = "起始关卡"
	level_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_title.add_theme_font_size_override("font_size", GameConfig.UI.settings_menu.subtitle_font_size)
	vbox.add_child(level_title)
	
	# 当前关卡显示
	var level_value = Label.new()
	level_value.name = "LevelValue"
	level_value.text = str(GameManager.get_start_level())
	level_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_value.add_theme_font_size_override("font_size", GameConfig.UI.settings_menu.value_font_size)
	vbox.add_child(level_value)
	
	# 按钮容器（水平布局）
	var button_container = HBoxContainer.new()
	button_container.name = "ButtonContainer"
	button_container.add_theme_constant_override("separation", GameConfig.UI.settings_menu.button_separation)
	vbox.add_child(button_container)
	
	# 左侧占位
	var left_spacer = Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_container.add_child(left_spacer)
	
	# 减号按钮 - 使用容器布局
	var minus_btn = Button.new()
	minus_btn.name = "MinusButton"
	minus_btn.text = "-"
	minus_btn.custom_minimum_size = GameConfig.UI.settings_menu.button_min_size
	minus_btn.add_theme_font_size_override("font_size", GameConfig.UI.settings_menu.button_font_size)
	minus_btn.pressed.connect(_on_level_minus)
	button_container.add_child(minus_btn)
	
	# 加号按钮 - 使用容器布局
	var plus_btn = Button.new()
	plus_btn.name = "PlusButton"
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = GameConfig.UI.settings_menu.button_min_size
	plus_btn.add_theme_font_size_override("font_size", GameConfig.UI.settings_menu.button_font_size)
	plus_btn.pressed.connect(_on_level_plus)
	button_container.add_child(plus_btn)
	
	# 右侧占位
	var right_spacer = Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_container.add_child(right_spacer)
	
	# 说明文字
	var desc_label = Label.new()
	desc_label.name = "DescLabel"
	desc_label.text = "设置后点击'开始新游戏'\n将从该关卡开始"
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", GameConfig.UI.settings_menu.desc_font_size)
	vbox.add_child(desc_label)
	
	# 底部占位
	var bottom_spacer = Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(bottom_spacer)
	
	# 返回按钮 - 使用容器布局
	var back_btn = Button.new()
	back_btn.name = "BackButton"
	back_btn.text = "返回主菜单"
	back_btn.custom_minimum_size = GameConfig.UI.settings_menu.back_button_min_size
	back_btn.add_theme_font_size_override("font_size", GameConfig.UI.settings_menu.subtitle_font_size)
	back_btn.pressed.connect(_on_settings_back)
	vbox.add_child(back_btn)
	
	# 添加到场景
	$Menus.add_child(settings_menu)

## 关卡减
func _on_level_minus() -> void:
	GameManager.play_sound("select")
	var current = GameManager.get_start_level()
	if current > 1:
		GameManager.set_start_level(current - 1)
		_update_settings_level_display()

## 关卡加
func _on_level_plus() -> void:
	GameManager.play_sound("select")
	var current = GameManager.get_start_level()
	if current < GameConfig.UI.max_start_level:
		GameManager.set_start_level(current + 1)
		_update_settings_level_display()

## 更新设置菜单中的关卡显示
func _update_settings_level_display() -> void:
	if not settings_menu:
		return
	var level_value = settings_menu.get_node_or_null("Panel/VBoxContainer/LevelValue")
	if level_value:
		level_value.text = str(GameManager.get_start_level())

## 返回主菜单
func _on_settings_back() -> void:
	GameManager.play_sound("select")
	if settings_menu:
		settings_menu.visible = false
