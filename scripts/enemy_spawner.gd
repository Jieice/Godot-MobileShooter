extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_interval = 2.0
@export var min_spawn_interval = 0.5
@export var difficulty_increase_rate = 0.05

var spawn_timer = null
var screen_size = Vector2.ZERO
var player = null
var spawn_active = true

func _ready():
	# 获取屏幕尺寸
	screen_size = get_viewport_rect().size
	
	# 创建定时器
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.connect("timeout", Callable(self, "_on_spawn_timer_timeout"))
	add_child(spawn_timer)
	
	# 获取玩家引用
	player = get_node("../Player")
	
	# 开始生成敌人
	start()

func start():
	spawn_active = true
	spawn_timer.start()

func stop():
	spawn_active = false
	spawn_timer.stop()

func _on_spawn_timer_timeout():
	if spawn_active and player != null and player.is_alive:
		spawn_enemy()

func spawn_enemy():
	# 创建敌人实例
	var enemy = enemy_scene.instantiate()
	
	# 将敌人添加到敌人组
	enemy.add_to_group("enemies")
	
	# 设置敌人目标为玩家
	enemy.target = player
	
	# 连接敌人死亡信号
	enemy.connect("enemy_died", Callable(get_node("/root/Main/GameManager"), "add_score"))
	
	# 随机生成敌人位置（屏幕外围）
	var spawn_position = Vector2.ZERO
	var rand_side = randi() % 4  # 0: 上, 1: 右, 2: 下, 3: 左
	
	match rand_side:
		0:  # 上边
			spawn_position.x = randf_range(0, screen_size.x)
			spawn_position.y = -50
		1:  # 右边
			spawn_position.x = screen_size.x + 50
			spawn_position.y = randf_range(0, screen_size.y)
		2:  # 下边
			spawn_position.x = randf_range(0, screen_size.x)
			spawn_position.y = screen_size.y + 50
		3:  # 左边
			spawn_position.x = -50
			spawn_position.y = randf_range(0, screen_size.y)
	
	# 设置敌人位置
	enemy.global_position = spawn_position
	
	# 将敌人添加到场景
	add_child(enemy)

func increase_difficulty(score):
	# 根据分数增加难度（减少生成间隔）
	var new_interval = max(min_spawn_interval, spawn_interval - (score * difficulty_increase_rate / 1000))
	
	if new_interval != spawn_timer.wait_time:
		spawn_timer.wait_time = new_interval