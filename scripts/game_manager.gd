extends Node

signal score_updated
signal game_over_triggered

var score = 0  # 现在表示金币数量
var game_running = true

func _ready():
	add_to_group("game_manager")

func add_score(coins):
	if not game_running:
		return
		
	score += coins
	emit_signal("score_updated", score)
	
	# 随着金币增加，可以增加游戏难度
	get_node("/root/Main/EnemySpawner").increase_difficulty(score)

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
	
	# 移除所有敌人
	get_tree().call_group("enemies", "queue_free")
	
	# 重置玩家
	var player = get_node("/root/Main/Player")
	player.health = player.max_health
	player.is_alive = true
	
	# 重新开始生成敌人
	get_node("/root/Main/EnemySpawner").start()