extends Node

signal score_updated
signal game_over_triggered(final_score: int)
signal game_restarted # 游戏重启信号

# 移除 var score = 0
var game_running = true
var current_level_config # 保存当前关卡配置

var level_manager # 类成员变量

# 移除本地 restart_level_number，统一用 Global.restart_level_number

# 静态变量：重启时保留的数据
var restart_persistent_data = {}

var _restart_temp_score = 0
var _restart_temp_diamonds = 0
var _restart_temp_2x = false

func _ready():
	print("GameManager._ready: Global.restart_temp_score=", Global.restart_temp_score, ", Global.restart_temp_diamonds=", Global.restart_temp_diamonds)
	print("GameManager: _ready() called, Global.restart_level_number=", Global.restart_level_number)
	add_to_group("game_manager")
	
	# 确保游戏结束面板在游戏启动时是隐藏的
	var game_over_panel = get_node_or_null("/root/Main/HUD/GameOverPanel")
	if game_over_panel:
		game_over_panel.hide()
	
	# 在_ready中连接Player的死亡信号，确保它在Player实例化后连接
	var player = get_node_or_null("Player")
	if player:
		player.connect("player_died", Callable(self, "game_over"))
	
	print("GameManager: 尝试获取LevelManager...")
	level_manager = get_node_or_null("/root/LevelManager")
	if not level_manager:
		print("GameManager: 警告: 无法找到LevelManager节点, level_manager is Nil!")
		return
	await get_tree().process_frame
	# 关卡初始化判断
	if Global.restart_level_number > 0:
		print("GameManager: 检测到重启关卡号，直接进入关卡:", Global.restart_level_number)
		level_manager.start_level(Global.restart_level_number)
		Global.restart_level_number = -1
	# 移除自动进入第一关的逻辑，关卡启动完全交由 SaveManager 控制
	
	print("GameManager: _ready()结束")
	
	# 连接关卡管理器信号
	level_manager.connect("level_started", Callable(self, "_on_level_started"))
	level_manager.connect("level_completed", Callable(self, "_on_level_completed"))
	level_manager.connect("level_progress_updated", Callable(self, "_on_level_progress_updated"))
	level_manager.connect("player_level_up", Callable(self, "_on_player_level_up"))
	

	# 设置生存时间任务更新定时器
	var survival_timer = Timer.new()
	survival_timer.wait_time = 60.0 # 每分钟更新一次
	survival_timer.autostart = true
	survival_timer.one_shot = false
	add_child(survival_timer)
	survival_timer.connect("timeout", Callable(self, "_on_survival_timer_timeout"))

	# 检查是否有重启保留数据
	if restart_persistent_data.size() > 0:
		print("GameManager: 检测到重启保留数据，恢复...")
		var level_manager = get_node_or_null("/root/LevelManager")
		var talents = get_node_or_null("/root/Talents")
		if level_manager:
			if restart_persistent_data.has("player_level"): level_manager.player_level = restart_persistent_data["player_level"]
			if restart_persistent_data.has("player_exp"): level_manager.player_exp = restart_persistent_data["player_exp"]
			if restart_persistent_data.has("exp_to_next_level"): level_manager.exp_to_next_level = restart_persistent_data["exp_to_next_level"]
			if restart_persistent_data.has("current_level"): level_manager.current_level = restart_persistent_data["current_level"]
			if restart_persistent_data.has("talent_points"): level_manager.talent_points = restart_persistent_data["talent_points"]
			if restart_persistent_data.has("total_talent_points"): level_manager.total_talent_points = restart_persistent_data["total_talent_points"]
			print("GameManager: 已恢复LevelManager数据")
			level_manager.update_player_attributes() # 只调用一次，负责设置 health/max_health
			# 刷新属性栏
			var ui_manager = get_node_or_null("/root/Main/UI")
			if ui_manager and ui_manager.has_node("BottomPanel/属性"):
				var attribute_panel = ui_manager.get_node("BottomPanel/属性")
				if attribute_panel.has_method("update_player_stats"):
					attribute_panel.update_player_stats()
			if ui_manager and ui_manager.has_method("update_player_level"):
				ui_manager.update_player_level()
			if ui_manager and ui_manager.has_method("update_level_display"):
				ui_manager.update_level_display()
		if talents and restart_persistent_data.has("player_talents"):
			talents.player_talents = restart_persistent_data["player_talents"].duplicate(true)
			print("GameManager: 已恢复天赋数据")
		restart_persistent_data.clear()

	# 恢复金币、钻石和2倍速状态（如果是重启）
	if Global.restart_temp_score != 0 or Global.restart_temp_diamonds != 0:
		GameAttributes.score = Global.restart_temp_score
		GameAttributes.diamonds = Global.restart_temp_diamonds
		print("GameManager: 恢复金币=", Global.restart_temp_score, ", 恢复钻石=", Global.restart_temp_diamonds)
		# 主动刷新UI
		var ui_manager = get_node_or_null("/root/Main/UI")
		if ui_manager and ui_manager.has_method("_on_score_updated"):
			ui_manager._on_score_updated(GameAttributes.score)
		if ui_manager and ui_manager.has_method("_on_diamonds_changed"):
			ui_manager._on_diamonds_changed(GameAttributes.diamonds)
		# 清空缓存，避免下次误用
		Global.restart_temp_score = 0
		Global.restart_temp_diamonds = 0

func add_score(coins):
	print("GameManager.add_score called, coins=", coins)
	if not game_running:
		return
	GameAttributes.score += coins
	print("GameManager: 当前金币=", GameAttributes.score)
	emit_signal("score_updated", GameAttributes.score)
	
	# 同时添加经验值（金币的50%转换为经验值）
	var exp_gained = int(coins * 0.5)
	if exp_gained > 0:
		level_manager.add_experience(exp_gained)

func start_level(level_number):
	if not game_running:
		return
	
	# 直接通过关卡管理器开始关卡，GameManager不再维护current_level
	level_manager.start_level(level_number)
	
# 玩家升级处理
func _on_player_level_up(level):
	print("玩家升级到 ", level, " 级")
	
	# 更新UI显示
	var ui_manager = get_node_or_null("/root/Main/HUD")
	if ui_manager and ui_manager.has_method("update_level_display"):
		var level_info = level_manager.get_player_level_info()
		ui_manager.update_level_display(level, level_info)

func _on_level_started(level_number, level_data):
	# 更新UI显示当前关卡
	var ui_manager = get_node_or_null("/root/Main/HUD")
	if ui_manager and ui_manager.has_method("update_level_display"):
		ui_manager.update_level_display(level_number, level_data)

func _on_level_completed(level_number):
	# 短暂延迟后开始下一关
	await get_tree().create_timer(2.0).timeout
	start_level(level_number + 1)

func _on_level_progress_updated(current_progress, target_progress):
	# 更新UI显示关卡进度
	var ui_manager = get_node_or_null("/root/Main/HUD")
	if ui_manager and ui_manager.has_method("update_level_progress"):
		ui_manager.update_level_progress(current_progress, target_progress)

func game_over():
	print("GameManager: game_over() called!")
	game_running = false
	emit_signal("game_over_triggered", GameAttributes.score) # 不带参数地发出信号
	
	# 显示游戏结束面板
	var game_over_panel = get_node_or_null("/root/Main/HUD/GameOverPanel")
	if game_over_panel:
		game_over_panel.show()
	
	# 停止生成敌人
	get_node("/root/Main/EnemySpawner").stop()
	
	# 游戏结束UI由UI管理器处理

func restart_game():
	print("restart_game: 保存金币=", GameAttributes.score, ", 保存钻石=", GameAttributes.diamonds)
	Global.restart_temp_score = GameAttributes.score
	Global.restart_temp_diamonds = GameAttributes.diamonds
	var ui_manager = get_node_or_null("/root/Main/UI")
	_restart_temp_2x = ui_manager._is_2x_speed_active if ui_manager else false
	if level_manager:
		Global.restart_level_number = level_manager.current_level
	print("GameManager: restart_game() called. 保存重启关卡号:", Global.restart_level_number)
	get_tree().reload_current_scene()
	emit_signal("game_restarted")

# 生存时间任务更新
func _on_survival_timer_timeout():
	if game_running and has_node("/root/QuestSystem"):
		var quest_system = get_node("/root/QuestSystem")
		quest_system.update_quest_progress("survive", 1)
