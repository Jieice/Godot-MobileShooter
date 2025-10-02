extends Node2D

@export var enemy_scene: PackedScene # 敌人场景，用于实例化新的敌人
@export var spawn_interval = 1.0 # 初始敌人生成间隔时间（秒），该值会随难度增加而减少
@export var min_spawn_interval = 0.5 # 最小敌人生成间隔时间，生成间隔不会低于此值
@export var difficulty_increase_rate = 0.05 # 难度增加率，分数越高，生成间隔减少越快

# 关卡系统相关变量，由 LevelManager 配置
var health_multiplier = 1.0 # 敌人生命值乘数，由 LevelManager 根据关卡难度设置
var speed_multiplier = 1.0 # 敌人速度乘数，由 LevelManager 根据关卡难度设置
var enemies_per_wave = 10 # 每波普通敌人生成的数量，由 LevelManager 根据关卡配置设置
var has_boss = false # 当前关卡波次是否会生成 BOSS，由 LevelManager 设置
var boss_scale = 1.5 # BOSS 的缩放比例，由 LevelManager 设置
var boss_health_multiplier = 3.0 # BOSS 生命值额外的乘数，由 LevelManager 设置
var boss_effects = [] # 存储 BOSS 的特殊效果，如 "red_border", "speed_burst", "area_slow"
var additional_enemies = 0 # BOSS 战时额外生成的小怪数量
var current_level = 1 # 当前关卡，从 LevelManager 获取
var max_concurrent_enemies = 5 # 屏幕上允许同时存在的最大敌人数量
var current_wave_enemies = 0 # 当前波次已生成的敌人数量
var wave_count = 0 # 已进行的波次计数
var max_waves = 7 # 每关最大波次

var spawn_timer = null # 控制敌人生成间隔的定时器
var wave_timer = null # 控制波次间隔的定时器
var screen_size = Vector2.ZERO
var player = null
var spawn_active = true # 控制敌人生成是否激活
var level_manager = null # LevelManager 节点的引用

# 敌人类型配置，定义了不同类型敌人的基础属性修正
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
	},
	"elite": {
		"color": Color(1, 0.5, 0),
		"scale": 1.1,
		"health_mod": 2.5,
		"speed_mod": 1.2,
		"damage_mod": 1.5,
		"score": 40
	}
}

func _ready():
	# 将当前节点添加到 "enemy_spawner" 组，以便 LevelManager 可以获取其引用
	add_to_group("enemy_spawner")
	
	# 获取视口（屏幕）尺寸，用于计算敌人生成位置
	screen_size = get_viewport_rect().size
	print("敌人生成器屏幕尺寸: ", screen_size)
	
	# 初始化敌人生成定时器，控制敌人生成频率
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval # 默认生成间隔
	spawn_timer.connect("timeout", Callable(self, "_on_spawn_timer_timeout")) # 连接超时信号
	add_child(spawn_timer)
	
	# 初始化波次计时器，控制波次之间的间隔
	wave_timer = Timer.new()
	wave_timer.one_shot = true # 只计时一次
	wave_timer.connect("timeout", Callable(self, "_on_wave_timer_timeout")) # 连接超时信号
	add_child(wave_timer)
	
	# 获取玩家节点的引用，敌人需要追逐玩家
	player = get_node("../Player")
	
	# 尝试获取 LevelManager 节点的引用（单例），用于关卡进度和经验管理
	level_manager = get_tree().get_nodes_in_group("level_manager")
	if level_manager.size() > 0:
		level_manager = level_manager[0]
	else:
		level_manager = null # 如果找不到 LevelManager，则设置为 null
		
	# 敌人生成器默认不主动启动，由 LevelManager 在关卡开始时调用 start_level() 启动
	# start()

func start():
	# 激活敌人生成
	spawn_active = true
	spawn_timer.start() # 启动敌人生成定时器

func stop():
	# 停止敌人生成和波次计时
	spawn_active = false
	spawn_timer.stop() # 停止敌人生成定时器
	wave_timer.stop() # 停止波次计时器

# 开始关卡，由 LevelManager 调用
func start_level():
	# 重置波次和敌人计数
	wave_count = 0
	current_wave_enemies = 0
	spawn_active = true # 确保生成激活
	print("敌人生成器：开始关卡 " + str(current_level))
	
	# 确保定时器存在并启动（如果不存在则创建，通常在 _ready() 中已创建）
	if not spawn_timer:
		spawn_timer = Timer.new()
		spawn_timer.wait_time = spawn_interval
		spawn_timer.connect("timeout", Callable(self, "_on_spawn_timer_timeout"))
		add_child(spawn_timer)
	
	# 强制重启生成定时器，并应用当前关卡的生成间隔
	spawn_timer.stop()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.start()
	print("✅ 定时器已启动，间隔: ", spawn_interval)
	
	# 启动第一波敌人
	start_wave()

# 开始新的一波敌人生成
func start_wave():
	wave_count += 1 # 增加波次计数
	current_wave_enemies = 0 # 重置当前波次敌人计数
	
	# 通知 LevelManager 新波次开始，用于 UI 更新和关卡进度管理
	if level_manager:
		level_manager.start_new_wave()
	
	# 根据当前关卡配置 BOSS 特性（这些属性应由 LevelManager 统一配置，这里只是确保兼容性）
	var level_num = self.current_level
	
	# 初始化 BOSS 效果和属性乘数
	boss_effects = []
	boss_health_multiplier = 3.0
	boss_scale = 1.5
	
	# 根据关卡编号和波次设置 BOSS 具体特性
	# BOSS 只有在每关的第5关（例如5，10，15等）的最后一波才出现
	if level_num % 5 == 0 and wave_count == max_waves:
		has_boss = true
		# 可以根据 level_num 动态调整 BOSS 属性，例如：
		var difficulty_factor = pow(1.1, floor((float(level_num) - 5.0) / 5.0))
		boss_health_multiplier = 3.0 * difficulty_factor
		boss_scale = 1.5 + (difficulty_factor - 1.0) * 0.2 # 随难度略微增大体型
		
		# 示例：根据关卡增加 BOSS 特殊效果
		if level_num >= 10:
			boss_effects.append("red_border")
		if level_num >= 15:
			boss_effects.append("speed_burst")
		if level_num >= 20:
			boss_effects.append("area_slow")
		
		# 可以在这里设置 additional_enemies, 比如每隔几关增加小怪
		if level_num >= 10 and level_num % 10 == 0:
			additional_enemies = 2
	
	# 如果是最后一波且有 BOSS，则生成 BOSS
	if wave_count == max_waves and has_boss:
		spawn_boss()
		
		# 如果有额外的小怪，也一起生成
		for i in range(additional_enemies):
			spawn_enemy()
	
	# 启动敌人生成定时器，开始生成这一波的普通敌人
	if spawn_timer:
		spawn_timer.start()

# 生成 BOSS 敌人
func spawn_boss():
	var enemy = enemy_scene.instantiate() # 实例化敌人场景
	enemy.add_to_group("enemies") # 将敌人添加到 "enemies" 组
	enemy.add_to_group("boss") # 将 BOSS 添加到 "boss" 组
	
	# 设置 BOSS 属性
	enemy.target = player # 设置 BOSS 的目标为玩家
	enemy.health *= boss_health_multiplier * health_multiplier # 应用 BOSS 生命值乘数和关卡难度乘数
	enemy.speed *= speed_multiplier # 应用关卡难度速度乘数
	enemy.scale = Vector2(boss_scale, boss_scale) # 应用 BOSS 缩放比例
	
	# 应用 BOSS 特殊效果（如红色边框、加速、范围减速）
	if "red_border" in boss_effects:
		var outline = enemy.get_node_or_null("Outline")
		if not outline:
			outline = Sprite2D.new()
			outline.texture = enemy.get_node("Sprite2D").texture
			outline.scale = Vector2(1.1, 1.1) # 略大于原始精灵，形成边框效果
			outline.modulate = Color(1, 0, 0, 0.5) # 红色半透明
			outline.z_index = -1 # 确保在原始精灵后面
			enemy.add_child(outline)
			outline.name = "Outline"
	
	if "speed_burst" in boss_effects:
		enemy.can_speed_burst = true # 激活 BOSS 的短暂加速能力
	
	if "area_slow" in boss_effects:
		enemy.can_slow_area = true # 激活 BOSS 的范围减速能力
	
	# 随机生成 BOSS 位置（屏幕外围）
	var spawn_position = Vector2.ZERO
	var rand_side = randi() % 4 # 随机选择屏幕的四条边之一
	
	match rand_side:
		0: # 上边
			spawn_position.x = screen_size.x / 2
			spawn_position.y = -100 # 在屏幕上方外 100 像素处生成
		1: # 右边
			spawn_position.x = screen_size.x + 100 # 在屏幕右方外 100 像素处生成
			spawn_position.y = screen_size.y / 2
		2: # 下边
			spawn_position.x = screen_size.x / 2
			spawn_position.y = screen_size.y + 100 # 在屏幕下方外 100 像素处生成
		3: # 左边
			spawn_position.x = -100 # 在屏幕左方外 100 像素处生成
			spawn_position.y = screen_size.y / 2
	
	# 设置 BOSS 敌人的全局位置
	enemy.global_position = spawn_position
	
	# 连接 BOSS 死亡信号到 GameManager (增加分数) 和 LevelManager (更新进度和经验)
	enemy.connect("enemy_died", Callable(get_node("/root/Main/GameManager"), "add_score").bind(enemy.score_value))
	if level_manager:
		enemy.connect("enemy_died", Callable(level_manager, "update_progress")) # 更新关卡进度
		# 新增：敌人死亡时，玩家获得经验。使用 .bind() 确保只传递 score_value 作为 add_experience 的参数
		enemy.connect("enemy_died", Callable(level_manager, "add_experience").bind(enemy.score_value))
	
	# 将 BOSS 敌人添加到场景中
	add_child(enemy)

# 敌人生成定时器超时时调用
func _on_spawn_timer_timeout():
	if not spawn_active:
		return # 如果生成不活跃，则不执行任何操作

	# 获取当前场景中的敌人数量
	var current_enemies_on_screen = get_tree().get_nodes_in_group("enemies").size()

	# 如果屏幕上的敌人数量已达到上限，则不生成新敌人，并重新启动定时器，等待下一次检查
	if current_enemies_on_screen >= max_concurrent_enemies:
		spawn_timer.start() # 重新启动定时器，等待下一次生成尝试
		return

	# 如果当前波次生成的敌人数量达到上限，则停止生成，并根据情况启动波次计时器
	if current_wave_enemies >= enemies_per_wave:
		spawn_timer.stop() # 停止敌人生成定时器
		
		# 如果不是最后一波，则启动波次间隔计时器，等待下一波开始
		if wave_count < max_waves:
			wave_timer.wait_time = 3.0 # 波次间隔时间 (3 秒)
			wave_timer.start() # 启动波次计时器
		else:
			return # 如果是最后一波，则返回，等待关卡结束
	
	spawn_enemy() # 生成一个普通敌人
	current_wave_enemies += 1 # 增加当前波次敌人计数

# 波次计时器超时时调用，表示可以开始新的一波敌人了
func _on_wave_timer_timeout():
	# 重启敌人生成定时器
	if spawn_timer:
		spawn_timer.start() # 启动敌人生成定时器
	
	start_wave() # 开始新的一波敌人

# 生成普通敌人（is_boss 参数用于区分普通敌人和 BOSS，但 BOSS 通常通过 spawn_boss() 单独生成）
func spawn_enemy(is_boss = false):
	if not enemy_scene:
		print("错误：敌人场景未设置，请在编辑器中设置 'enemy_scene' 属性")
		return
		
	if not player:
		player = get_node_or_null("../Player") # 尝试再次获取玩家引用
		if not player:
			print("错误：找不到玩家节点，无法生成敌人")
			return
	
	if not player.is_alive:
		return # 如果玩家已死亡，则不生成敌人

	var is_elite = false
	if randf() < 0.05: # 5% 的几率生成精英敌人
		is_elite = true

	# 实例化敌人场景
	var enemy = enemy_scene.instantiate()
	
	# 将敌人添加到 "enemies" 组
	enemy.add_to_group("enemies")
	if is_boss:
		enemy.add_to_group("boss") # 如果是 BOSS，也添加到 "boss" 组
	
	# 设置敌人目标为玩家
	enemy.target = player
	
	# 根据是否是 BOSS 或精英，或者随机选择普通敌人类型来配置敌人属性
	var type_config
	if is_boss:
		type_config = enemy_types["boss"]
		# 应用 BOSS 特殊效果和属性（这些值应该由 LevelManager 在 start_level() 中设置）
		enemy.health *= boss_health_multiplier * health_multiplier
		enemy.speed *= speed_multiplier
		enemy.scale = Vector2(boss_scale, boss_scale)
		
		# 应用 BOSS 特殊视觉和行为效果
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
		
	if is_elite:
		type_config = enemy_types["elite"]
		enemy.get_node("Sprite2D").modulate = type_config.color
		enemy.scale = Vector2(type_config.scale, type_config.scale)
		enemy.health = enemy.health * type_config.health_mod * health_multiplier
		enemy.speed = enemy.speed * type_config.speed_mod * speed_multiplier
		enemy.damage = enemy.damage * type_config.damage_mod
	else:
		# 随机选择普通敌人类型（排除 BOSS 类型）
		var enemy_type_keys = enemy_types.keys()
		enemy_type_keys.erase("boss") # 移除 BOSS 类型，BOSS 单独生成
		enemy_type_keys.erase("elite") # 移除 elite 类型，精英敌人单独生成
		var selected_type = enemy_type_keys[randi() % enemy_type_keys.size()] # 随机选择一个类型
		type_config = enemy_types[selected_type]
		
		# 应用敌人类型属性和关卡难度乘数
		enemy.get_node("Sprite2D").modulate = type_config.color
		enemy.scale = Vector2(type_config.scale, type_config.scale)
		enemy.health = enemy.health * type_config.health_mod * health_multiplier
		enemy.speed = enemy.speed * type_config.speed_mod * speed_multiplier
		enemy.damage = enemy.damage * type_config.damage_mod
	
	enemy.score_value = type_config.score # 设置敌人死亡时提供的分数和经验值
	
	# 连接敌人死亡信号到 GameManager (增加分数) 和 LevelManager (更新进度和经验)
	enemy.connect("enemy_died", Callable(get_node("/root/Main/GameManager"), "add_score").bind(enemy.score_value))
	if level_manager:
		enemy.connect("enemy_died", Callable(level_manager, "update_progress")) # 更新关卡进度
		# 敌人死亡时，玩家获得经验。使用 .bind() 确保只传递 score_value 作为 add_experience 的参数
		enemy.connect("enemy_died", Callable(level_manager, "add_experience").bind(enemy.score_value))
	
	# 随机生成敌人位置（屏幕外围）
	var spawn_position = Vector2.ZERO
	var rand_side = randi() % 4 # 0: 上, 1: 右, 2: 下, 3: 左
	
	match rand_side:
		0: # 上边
			spawn_position.x = randf_range(0, screen_size.x) # 随机 X 坐标
			spawn_position.y = -50 # 在屏幕上方外 50 像素处生成
		1: # 右边
			spawn_position.x = screen_size.x + 50 # 在屏幕右方外 50 像素处生成
			spawn_position.y = randf_range(0, screen_size.y) # 随机 Y 坐标
		2: # 下边
			spawn_position.x = randf_range(0, screen_size.x) # 随机 X 坐标
			spawn_position.y = screen_size.y + 50 # 在屏幕下方外 50 像素处生成
		3: # 左边
			spawn_position.x = -50 # 在屏幕左方外 50 像素处生成
			spawn_position.y = randf_range(0, screen_size.y) # 随机 Y 坐标
	
	# 设置敌人位置，并将其添加到场景中 (作为 Main 节点的子节点)
	enemy.position = spawn_position # 先设置本地位置
	get_parent().add_child(enemy) # 添加到 Main 节点 (假设 EnemySpawner 是 Main 的子节点)
	enemy.global_position = spawn_position # 确保全局位置正确
	
	return enemy

func increase_difficulty(score):
	# 根据分数增加难度（减少敌人生成间隔），使游戏更具挑战性
	var new_interval = max(min_spawn_interval, spawn_interval - (score * difficulty_increase_rate / 1000))
	
	# 如果新的生成间隔与当前定时器设置不同，则更新定时器
	if new_interval != spawn_timer.wait_time:
		spawn_timer.wait_time = new_interval
