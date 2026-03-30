## UILayer - 游戏UI层
## 管理所有游戏界面元素

extends CanvasLayer

# 游戏HUD
@onready var hud: Control = $HUD
@onready var level_label: Label = $HUD/TopBar/LevelLabel
@onready var remaining_label: Label = $HUD/TopBar/RemainingLabel

# 菜单
@onready var victory_menu: Control = $Menus/VictoryMenu
@onready var main_menu: Control = $Menus/MainMenu

# 特效
@onready var flash_effect: ColorRect = $Effects/FlashEffect

var game_scene: Node2D = null

func _ready() -> void:
	# 连接游戏管理器信号
	GameManager.level_started.connect(_on_level_started)
	GameManager.level_completed.connect(_on_level_completed)
	
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
		level_label.text = "Level %d" % data.level
	
	if data.has("remaining") and remaining_label:
		remaining_label.text = "🐍 × %d" % data.remaining

## 显示胜利界面
func show_victory() -> void:
	victory_menu.visible = true
	
	# 播放闪光效果
	var tween = create_tween()
	flash_effect.visible = true
	flash_effect.modulate = Color(1, 1, 1, 1)
	tween.tween_property(flash_effect, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(func(): flash_effect.visible = false)

# 按钮回调
func _on_settings_pressed() -> void:
	# TODO: 显示设置菜单
	GameManager.play_sound("select")

func _on_next_level_pressed() -> void:
	if victory_menu:
		victory_menu.visible = false
	GameManager.play_sound("select")

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

## 开始新游戏（清除存档）
func _on_new_game_pressed() -> void:
	GameManager.play_sound("select")
	
	# 清除存档数据
	SaveManager.reset_save()
	
	# 重置游戏管理器状态
	GameManager.current_level = 1
	
	# 隐藏菜单，显示游戏
	if main_menu:
		main_menu.visible = false
	if hud:
		hud.visible = true
	
	# 获取游戏场景并开始
	game_scene = get_node_or_null("../GameScene")
	if game_scene:
		GameManager.start_level(1)

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
	
	GameManager.play_sound("select")

func _on_level_started(_level: int) -> void:
	if hud:
		hud.visible = true
	if victory_menu:
		victory_menu.visible = false
	if main_menu:
		main_menu.visible = false
