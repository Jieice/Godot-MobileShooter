extends CanvasLayer

# HUD管理器 - 负责游戏内UI显示
signal hud_ready

var _player: CharacterBody2D
var _game_manager: Node

func _ready():
	print("HUD: _ready() called")
	add_to_group("hud")
	
	# 获取玩家引用
	_player = get_node("/root/Main/Player")
	if not _player:
		print("警告: 无法找到Player节点")
		return
	
	# 获取游戏管理器引用
	_game_manager = get_node("/root/Main/GameManager")
	if not _game_manager:
		print("警告: 无法找到GameManager节点")
		return
	
	# 连接信号
	_connect_signals()
	
	# 初始化显示
	_initialize_display()
	
	emit_signal("hud_ready")

func _connect_signals():
	# 连接玩家信号
	if _player.has_signal("player_damaged"):
		_player.connect("player_damaged", Callable(self, "_on_player_damaged"))
	
	# 连接游戏管理器信号
	if _game_manager.has_signal("score_updated"):
		_game_manager.connect("score_updated", Callable(self, "_on_score_updated"))
	
	# 连接游戏属性信号
	if GameAttributes.has_signal("diamonds_changed"):
		GameAttributes.connect("diamonds_changed", Callable(self, "_on_diamonds_changed"))
	
	# 连接游戏属性信号
	if GameAttributes.has_signal("attributes_changed"):
		GameAttributes.connect("attributes_changed", Callable(self, "_on_game_attributes_changed"))
	
	# 连接LevelManager信号
	var level_manager = get_node("/root/LevelManager")
	if level_manager:
		if level_manager.has_signal("player_level_up"):
			level_manager.connect("player_level_up", Callable(self, "_on_player_level_up"))
		# 连接天赋点数变化信号
		level_manager.connect("talent_points_changed", Callable(self, "_on_talent_points_changed"))

func _initialize_display():
	print("HUD: _initialize_display() called")
	# 初始化分数显示
	_on_score_updated(_game_manager.score)
	
	# 初始化钻石显示
	_on_diamonds_changed(GameAttributes.diamonds)
	
	# 初始化血条
	update_health_bar(_player.health, _player.max_health)
	
	# 初始化等级显示
	update_player_level()
	
	# 初始化经验条
	var level_manager = get_node("/root/LevelManager")
	if level_manager:
		update_exp_bar(level_manager.player_exp, level_manager.exp_to_next_level)
	else:
		print("HUD: 警告: 无法找到LevelManager节点，经验条初始化失败")
	
	# 初始化关卡显示
	update_level_display() # 确保这里被调用

# 更新血条
func update_health_bar(current_health: float, max_health: float):
	if has_node("HealthBar"):
		var health_bar = $HealthBar
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.get_node("HealthLabel").text = str(int(current_health)) + "/" + str(int(max_health))

# 更新玩家等级显示
func update_player_level():
	print("HUD: update_player_level() called")
	var level_manager = get_node("/root/LevelManager")
	if has_node("PlayerLevel") and level_manager:
		var level_text = "等级: " + str(level_manager.player_level) + "/" + str(level_manager.player_max_level)
		$PlayerLevel.text = level_text
		print("HUD: 更新玩家等级到: ", level_text, " (从LevelManager获取: ", level_manager.player_level, "/", level_manager.player_max_level, ")")
		
		# 同步到GameAttributes
		GameAttributes.player_level = level_manager.player_level
	else:
		print("HUD: 警告: 无法更新PlayerLevel，节点或LevelManager缺失")

# 更新经验条
func update_exp_bar(current_exp: int, required_exp: int):
	print("HUD: update_exp_bar() called with exp:", current_exp, ", required:", required_exp)
	if has_node("LevelUI/LevelPanel/ExpBar"):
		var exp_bar = $LevelUI/LevelPanel/ExpBar
		exp_bar.max_value = required_exp
		exp_bar.value = current_exp
		
		# 更新经验标签
		if has_node("LevelUI/LevelPanel/ExpLabel"):
			$LevelUI/LevelPanel/ExpLabel.text = "经验: " + str(current_exp) + "/" + str(required_exp)
			print("HUD: 更新经验标签到: ", $LevelUI/LevelPanel/ExpLabel.text)
		
		# 根据经验百分比改变颜色
		var exp_percent = float(current_exp) / float(required_exp) if required_exp > 0 else 0.0
		if exp_percent >= 0.7:
			exp_bar.modulate = Color(0.0, 1.0, 0.0, 1) # 70%以上变绿色
		else:
			exp_bar.modulate = Color(0.2, 0.6, 1.0, 1) # 默认蓝色

# 更新关卡显示
func update_level_display(level_number: int = null, level_data: Dictionary = {}):
	print("HUD: update_level_display() called")
	if has_node("LevelUI/LevelPanel/InGameLevel"):
		if level_number != null:
			$LevelUI/LevelPanel/InGameLevel.text = "关卡: " + str(level_number)
			print("HUD: 更新关卡显示到: ", level_number)
		else:
			var level_manager = get_node("/root/LevelManager")
			if level_manager:
				$LevelUI/LevelPanel/InGameLevel.text = "关卡: " + str(level_manager.current_level)
				print("HUD: 更新关卡显示到: ", level_manager.current_level, " (从LevelManager获取)")
			else:
				print("HUD: 警告: 无法找到LevelManager节点，关卡显示更新失败")
	else:
		print("HUD: 警告: 无法找到LevelUI/LevelPanel/InGameLevel节点")

# 信号处理函数
func _on_player_damaged(_damage: float):
	update_health_bar(_player.health, _player.max_health)

func _on_score_updated(new_score: int):
	if has_node("ScoreLabel"):
		$ScoreLabel.text = "金币: " + str(new_score)

func _on_diamonds_changed(new_diamonds: int):
	if has_node("DiamondLabel"):
		$DiamondLabel.text = "钻石: " + str(new_diamonds)

func _on_player_level_up(level):
	print("HUD: _on_player_level_up() called with level: ", level)
	update_player_level()
	var level_manager = get_node("/root/LevelManager")
	if level_manager:
		update_exp_bar(level_manager.player_exp, level_manager.exp_to_next_level)
	else:
		print("HUD: 警告: 无法找到LevelManager节点，经验条更新失败")
	# 刷新天赋面板UI
	var talent_panel = get_node_or_null("BottomPanel/天赋") # 假设天赋面板在BottomPanel下，且节点名为"天赋"
	if talent_panel and talent_panel.has_method("_refresh"):
		talent_panel._refresh()

func _on_talent_points_changed(talent_points):
	# 刷新天赋面板UI
	var talent_panel = get_node_or_null("BottomPanel/天赋") # 假设天赋面板在BottomPanel下，且节点名为"天赋"
	if talent_panel and talent_panel.has_method("_refresh"):
		talent_panel._refresh()

func _on_game_attributes_changed(attribute_name: String, value):
	print("HUD: _on_game_attributes_changed called: ", attribute_name, ": ", value)
	match attribute_name:
		"max_health":
			# 玩家的最大生命值改变，更新血条
			# 需要获取当前的玩家生命值
			update_health_bar(_player.health, value)
		"health":
			# 玩家当前生命值改变，更新血条
			update_health_bar(value, _player.max_health)
		"player_level":
			update_player_level()
		"talent_points":
			# 如果天赋点数直接在GameAttributes中更新，则也在此处处理
			# 目前天赋点数由LevelManager管理并通过其信号处理
			pass
		_:
			# 对于其他属性，如果HUD有显示，可以在这里添加更新逻辑
			pass
