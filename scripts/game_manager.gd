extends Node

signal score_updated
signal game_over_triggered
signal level_changed(level_number)

var score = 0 # 现在表示金币数量
var game_running = true
var level_manager = null
var current_level = 1

func _ready():
	add_to_group("game_manager")
	
	# 创建关卡管理器
	level_manager = preload("res://scripts/level_manager.gd").new()
	add_child(level_manager)
	
	# 天赋系统已移除
	
	# 连接关卡管理器信号
	level_manager.connect("level_started", Callable(self, "_on_level_started"))
	level_manager.connect("level_completed", Callable(self, "_on_level_completed"))
	level_manager.connect("level_progress_updated", Callable(self, "_on_level_progress_updated"))
	level_manager.connect("player_level_up", Callable(self, "_on_player_level_up"))
	
	# 天赋UI已移除
	
	# 开始第一关
	start_level(1)

func add_score(coins):
	if not game_running:
		return
		
	score += coins
	emit_signal("score_updated", score)

func start_level(level_number):
	if not game_running:
		return
	
	current_level = level_number
	emit_signal("level_changed", current_level)
	
	# 通过关卡管理器开始关卡
	level_manager.start_level(level_number)
	
# 玩家升级处理
func _on_player_level_up(level):
	print("玩家升级到 ", level, " 级")

func _on_level_started(level_number, level_data):
	# 更新UI显示当前关卡
	var ui_manager = get_node_or_null("/root/Main/UIManager")
	if ui_manager and ui_manager.has_method("update_level_display"):
		ui_manager.update_level_display(level_number, level_data)

func _on_level_completed(level_number):
	# 短暂延迟后开始下一关
	await get_tree().create_timer(2.0).timeout
	start_level(level_number + 1)

func _on_level_progress_updated(current_progress, target_progress):
	# 更新UI显示关卡进度
	var ui_manager = get_node_or_null("/root/Main/UIManager")
	if ui_manager and ui_manager.has_method("update_level_progress"):
		ui_manager.update_level_progress(current_progress, target_progress)

func game_over():
	game_running = false
	emit_signal("game_over_triggered", score)
	
	# 停止生成敌人
	get_node("/root/Main/EnemySpawner").stop()
	
	# 游戏结束UI由UI管理器处理

func restart_game():
	# 重置游戏状态
	score = 0
	game_running = true
	current_level = 1
	
	# 移除所有敌人
	get_tree().call_group("enemies", "queue_free")
	
	# 重置玩家
	var player = get_node("/root/Main/Player")
	player.health = player.max_health
	player.is_alive = true
	
	# 开始第一关
	start_level(1)
	
	# 发送游戏重启信号
	emit_signal("game_restarted")

# 天赋UI功能已移除
