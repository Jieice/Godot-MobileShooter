extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_interval = 2.0
@export var min_spawn_interval = 0.5
@export var difficulty_increase_rate = 0.05

# 关卡系统相关变量
var health_multiplier = 1.0
var speed_multiplier = 1.0
var enemies_per_wave = 5
var has_boss = false
var boss_scale = 1.5
var boss_health_multiplier = 3.0
var boss_effects = []
var additional_enemies = 0
var current_level = 1
var current_wave_enemies = 0
var wave_count = 0
var max_waves = 5

var spawn_timer = null
var wave_timer = null
var screen_size = Vector2.ZERO
var player = null
var spawn_active = true
var level_manager = null

# 敌人类型配置
var enemy_types = {
	"normal": {
		"color": Color(1, 1, 1),
		"scale": 1.0,
		"health_mod": 1.0,
		"speed_mod": 1.0,
		"damage_mod": 1.0,
		"score": 10
	},
	"fast": {
		"color": Color(0.2, 0.8, 0.2),
		"scale": 0.8,
		"health_mod": 0.8,
		"speed_mod": 1.5,
		"damage_mod": 0.8,
		"score": 15
	},
	"tank": {
		"color": Color(0.2, 0.2, 0.8),
		"scale": 1.2,
		"health_mod": 2.0,
		"speed_mod": 0.7,
		"damage_mod": 1.2,
		"score": 20
	},
	"boss": {
		"color": Color(0.8, 0.2, 0.2),
		"scale": 1.5,
		"health_mod": 3.0,
		"speed_mod": 0.9,
		"damage_mod": 2.0,
		"score": 50
	}
}

func _ready():
	# 将自己添加到enemy_spawner组
	add_to_group("enemy_spawner")
	
	# 获取屏幕尺寸
	screen_size = get_viewport_rect().size
	
	# 创建定时器
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.connect("timeout", Callable(self, "_on_spawn_timer_timeout"))
	add_child(spawn_timer)
	
	# 创建波次定时器
	wave_timer = Timer.new()
	wave_timer.one_shot = true
	wave_timer.connect("timeout", Callable(self, "_on_wave_timer_timeout"))
	add_child(wave_timer)
	
	# 获取玩家引用
	player = get_node("../Player")
	
	# 尝试获取关卡管理器引用
	level_manager = get_tree().get_nodes_in_group("level_manager")
	if level_manager.size() > 0:
		level_manager = level_manager[0]
	else:
		level_manager = null
		
	# 默认启动敌人生成
	start()

func start():
	spawn_active = true
	spawn_timer.start()

func stop():
	spawn_active = false
	spawn_timer.stop()
	wave_timer.stop()

# 开始关卡
func start_level():
	wave_count = 0
	current_wave_enemies = 0
	spawn_active = true
	print("敌人生成器：开始关卡 " + str(current_level))
	
	# 确保定时器启动
	if spawn_timer:
		spawn_timer.start()
		
	start_wave()

# 开始新的一波敌人
func start_wave():
	wave_count += 1
	current_wave_enemies = 0
	
	# 通知关卡管理器开始新的一波
	if level_manager:
		level_manager.start_new_wave()
	
	# 检查是否需要生成BOSS
	var current_level = self.current_level
	
	# 设置BOSS效果
	boss_effects = []
	boss_health_multiplier = 3.0
	boss_scale = 1.5
	
	# 根据关卡设置BOSS特性
	if current_level == 10 and wave_count == max_waves:
		# 10关BOSS：放大1.5倍，血量3倍
		has_boss = true
		boss_health_multiplier = 3.0
	elif current_level == 15 and wave_count == max_waves:
		# 15关BOSS：放大1.5倍，血量3倍，带2只小怪
		has_boss = true
		boss_health_multiplier = 3.0
		additional_enemies = 2
	elif current_level == 20 and wave_count == max_waves:
		# 20关BOSS：红色边框，血量5倍，短暂加速
		has_boss = true
		boss_health_multiplier = 5.0
		boss_effects.append("red_border")
		boss_effects.append("speed_burst")
	elif current_level > 20 and current_level % 5 == 0 and wave_count == max_waves:
		# 循环期BOSS：每5关数值×1.1倍、伪BOSS加"范围减速"
		has_boss = true
		boss_health_multiplier = 5.0 * pow(1.1, floor((current_level - 20) / 5))
		boss_effects.append("red_border")
		boss_effects.append("speed_burst")
		boss_effects.append("area_slow")
	
	# 如果是最后一波且有BOSS，则生成BOSS
	if wave_count == max_waves and has_boss:
		spawn_boss()
		
		# 如果有额外的小怪，也一起生成
		for i in range(additional_enemies):
			spawn_enemy()
	
	# 开始生成这一波的敌人
	if spawn_timer:
		spawn_timer.start()

# 生成BOSS
func spawn_boss():
	var enemy = enemy_scene.instantiate()
	enemy.add_to_group("enemies")
	enemy.add_to_group("boss")
	
	# 设置BOSS属性
	enemy.target = player
	enemy.health *= boss_health_multiplier * health_multiplier
	enemy.speed *= speed_multiplier
	enemy.scale = Vector2(boss_scale, boss_scale)
	
	# 应用BOSS特殊效果
	if "red_border" in boss_effects:
		var outline = enemy.get_node_or_null("Outline")
		if not outline:
			outline = Sprite2D.new()
			outline.texture = enemy.get_node("Sprite2D").texture
			outline.scale = Vector2(1.1, 1.1)
			outline.modulate = Color(1, 0, 0, 0.5)
			outline.z_index = -1
			enemy.add_child(outline)
			outline.name = "Outline"
	
	if "speed_burst" in boss_effects:
		enemy.can_speed_burst = true
	
	if "area_slow" in boss_effects:
		enemy.can_slow_area = true
	
	# 随机生成BOSS位置（屏幕外围）
	var spawn_position = Vector2.ZERO
	var rand_side = randi() % 4
	
	match rand_side:
		0:  # 上边
			spawn_position.x = screen_size.x / 2
			spawn_position.y = -100
		1:  # 右边
			spawn_position.x = screen_size.x + 100
			spawn_position.y = screen_size.y / 2
		2:  # 下边
			spawn_position.x = screen_size.x / 2
			spawn_position.y = screen_size.y + 100
		3:  # 左边
			spawn_position.x = -100
			spawn_position.y = screen_size.y / 2
	
	# 设置BOSS位置
	enemy.global_position = spawn_position
	
	# 连接BOSS死亡信号
	enemy.connect("enemy_died", Callable(get_node("/root/Main/GameManager"), "add_score"))
	if level_manager:
		enemy.connect("enemy_died", Callable(level_manager, "update_progress"))
	
	# 将BOSS添加到场景
	add_child(enemy)

func _on_spawn_timer_timeout():
	if not spawn_active:
		return
	
	print("尝试生成敌人: 当前波次 " + str(wave_count) + ", 已生成 " + str(current_wave_enemies) + "/" + str(enemies_per_wave))
	
	# 检查是否达到当前波次的敌人数量
	if current_wave_enemies >= enemies_per_wave:
		spawn_timer.stop()
		
		# 如果不是最后一波，则开始下一波
		if wave_count < max_waves:
			wave_timer.wait_time = 3.0  # 波次间隔
			wave_timer.start()
		return
	
	spawn_enemy()
	current_wave_enemies += 1

func _on_wave_timer_timeout():
	# 开始下一波敌人
	start_wave()

func spawn_enemy(is_boss = false):
	if not enemy_scene:
		print("错误：敌人场景未设置")
		return
		
	if not player:
		player = get_node_or_null("../Player")
		if not player:
			print("错误：找不到玩家节点")
			return
	
	if not player.is_alive:
		return
	
	print("生成敌人：" + ("BOSS" if is_boss else "普通"))
	
	# 创建敌人实例
	var enemy = enemy_scene.instantiate()
	
	# 将敌人添加到敌人组
	enemy.add_to_group("enemies")
	if is_boss:
		enemy.add_to_group("boss")
	
	# 设置敌人目标为玩家
	enemy.target = player
	
	# 选择敌人类型
	var type_config
	if is_boss:
		type_config = enemy_types["boss"]
		# 应用BOSS特殊效果
		enemy.health *= boss_health_multiplier * health_multiplier
		enemy.speed *= speed_multiplier
		enemy.scale = Vector2(boss_scale, boss_scale)
		
		# 应用BOSS特殊效果
		if "red_border" in boss_effects:
			var outline = enemy.get_node_or_null("Outline")
			if not outline:
				outline = Sprite2D.new()
				outline.texture = enemy.get_node("Sprite2D").texture
				outline.scale = Vector2(1.1, 1.1)
				outline.modulate = Color(1, 0, 0, 0.5)
				outline.z_index = -1
				enemy.add_child(outline)
				outline.name = "Outline"
		
		if "speed_burst" in boss_effects:
			enemy.can_speed_burst = true
		
		if "area_slow" in boss_effects:
			enemy.can_slow_area = true
	else:
		# 随机选择敌人类型
		var enemy_type_keys = enemy_types.keys()
		enemy_type_keys.erase("boss")  # 移除BOSS类型，BOSS单独生成
		var selected_type = enemy_type_keys[randi() % enemy_type_keys.size()]
		type_config = enemy_types[selected_type]
		
		# 应用敌人类型属性
		enemy.get_node("Sprite2D").modulate = type_config.color
		enemy.scale = Vector2(type_config.scale, type_config.scale)
		enemy.health = enemy.health * type_config.health_mod * health_multiplier
		enemy.speed = enemy.speed * type_config.speed_mod * speed_multiplier
		enemy.damage = enemy.damage * type_config.damage_mod
	
	enemy.score_value = type_config.score
	
	# 连接敌人死亡信号
	enemy.connect("enemy_died", Callable(get_node("/root/Main/GameManager"), "add_score"))
	if level_manager:
		enemy.connect("enemy_died", Callable(level_manager, "update_progress"))
	
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
	
	return enemy

func increase_difficulty(score):
	# 根据分数增加难度（减少生成间隔）
	var new_interval = max(min_spawn_interval, spawn_interval - (score * difficulty_increase_rate / 1000))
	
	if new_interval != spawn_timer.wait_time:
		spawn_timer.wait_time = new_interval
