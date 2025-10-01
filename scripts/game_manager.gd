extends Node

signal score_updated
signal game_over_triggered(final_score: int)
signal game_restarted # 游戏重启信号

var score = 0 # 现在表示金币数量
var game_running = true
var current_level_config # 保存当前关卡配置

var level_manager # 类成员变量

func _ready():
	print("GameManager: _ready() called")
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
	# 获取关卡管理器引用并启动第一关
	level_manager = get_node_or_null("/root/LevelManager") # 直接赋值给类成员变量
	if level_manager:
		print("GameManager: 成功获取LevelManager: ", level_manager)
		level_manager.start_level(1)
	else:
		print("GameManager: 警告: 无法找到LevelManager节点, level_manager is Nil!")
	
	print("GameManager: _ready()结束")
	
	# 连接关卡管理器信号
	level_manager.connect("level_started", Callable(self, "_on_level_started"))
	level_manager.connect("level_completed", Callable(self, "_on_level_completed"))
	level_manager.connect("level_progress_updated", Callable(self, "_on_level_progress_updated"))
	level_manager.connect("player_level_up", Callable(self, "_on_player_level_up"))
	
	# 天赋UI已移除
	
	# 开始第一关
	start_level(1)
	
	# 设置生存时间任务更新定时器
	var survival_timer = Timer.new()
	survival_timer.wait_time = 60.0 # 每分钟更新一次
	survival_timer.autostart = true
	survival_timer.one_shot = false
	add_child(survival_timer)
	survival_timer.connect("timeout", Callable(self, "_on_survival_timer_timeout"))

func add_score(coins):
	if not game_running:
		return
		
	score += coins
	emit_signal("score_updated", score)
	
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
	emit_signal("game_over_triggered", score) # 不带参数地发出信号
	
	# 显示游戏结束面板
	var game_over_panel = get_node_or_null("/root/Main/HUD/GameOverPanel")
	if game_over_panel:
		game_over_panel.show()
	
	# 停止生成敌人
	get_node("/root/Main/EnemySpawner").stop()
	
	# 游戏结束UI由UI管理器处理

func restart_game():
	print("GameManager: restart_game() called. Reloading current scene.")
	get_tree().reload_current_scene()
	emit_signal("game_restarted")

# 生存时间任务更新
func _on_survival_timer_timeout():
	if game_running and has_node("/root/QuestSystem"):
		var quest_system = get_node("/root/QuestSystem")
		quest_system.update_quest_progress("survive", 1)

# 天赋UI功能已移除
