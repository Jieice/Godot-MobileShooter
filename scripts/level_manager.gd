extends Node

signal level_started(level_number, level_data)
signal level_completed(level_number)
signal level_progress_updated(current_progress, target_progress)
signal wave_started(wave_number, total_waves)
signal boss_spawned(level_number)
signal player_level_up(level)
signal talent_points_changed(points)

# 当前关卡
var current_level = 1
var max_level = 100 # 设置一个较大的值以支持循环期

# 玩家等级系统
var player_level = 1
var player_max_level = 30
var player_exp = 0
var exp_to_next_level = 100
var talent_points = 0
var total_talent_points = 0
var player_attack_speed = 0.5 # 初始攻速（每秒0.5次，2秒1次）

# 关卡进度
var current_progress = 0
var target_progress = 0
var current_wave = 0
var total_waves = 0
var enemies_per_wave = 0

# 关卡阶段
enum LevelPhase {
	BEGINNER, # 新手期 (1-5关)
	TRANSITION, # 过渡期 (6-10关)
	GROWTH, # 成长期 (11-15关)
	MATURE, # 成熟期 (16-20关)
	LOOP # 循环期 (21关+)
}

# 获取当前关卡阶段
func get_current_phase():
	if current_level <= 5:
		return LevelPhase.BEGINNER
	elif current_level <= 10:
		return LevelPhase.TRANSITION
	elif current_level <= 15:
		return LevelPhase.GROWTH
	elif current_level <= 20:
		return LevelPhase.MATURE
	else:
		return LevelPhase.LOOP

# 计算循环期的倍率
func get_loop_multiplier():
	if current_level <= 20:
		return 1.0
	
	var loop_count = floor((float(current_level) - 21.0) / 10.0) + 1
	return pow(1.1, loop_count)

# 获取当前关卡配置
func get_level_config():
	var phase = get_current_phase()
	var config = {
		"health_multiplier": 1.0,
		"speed_multiplier": 1.0,
		"damage_multiplier": 1.0,
		"enemies_per_wave": 8, # 默认值从 5 增加到 8
		"wave_interval": 8.0,
		"has_boss": false,
		"boss_scale": 1.0,
		"boss_health_multiplier": 1.0,
		"boss_speed_multiplier": 1.0,
		"boss_effects": [],
		"additional_enemies": 0
	}
	
	match phase:
		LevelPhase.BEGINNER:
			# 新手期（1-5关）血量1倍、移速1倍、每波4只、间隔4秒
			config.health_multiplier = 1.0
			config.speed_multiplier = 1.0
			config.damage_multiplier = 1.0
			config.enemies_per_wave = 4
			config.wave_interval = 4.0
			
		LevelPhase.TRANSITION:
			# 过渡期（6-10关）血量1.2倍、移速1.1倍、每波6只
			config.health_multiplier = 1.2
			config.speed_multiplier = 1.1
			config.damage_multiplier = 1.05
			config.enemies_per_wave = 6
			config.wave_interval = 5.0
			# 10关伪BOSS
			if current_level == 10:
				config.has_boss = true
				config.boss_scale = 1.5
				config.boss_health_multiplier = 3.0
				config.additional_enemies = 3
			
		LevelPhase.GROWTH:
			# 成长期（11-15关）血量1.5倍、移速1.3倍、每波10只
			config.health_multiplier = 1.5
			config.speed_multiplier = 1.3
			config.damage_multiplier = 1.1
			config.enemies_per_wave = 10
			config.wave_interval = 6.0
			# 15关伪BOSS
			if current_level == 15:
				config.has_boss = true
				config.boss_scale = 1.5
				config.boss_health_multiplier = 4.0
				config.additional_enemies = 5
			
		LevelPhase.MATURE:
			# 成熟期（16-20关）血量1.8倍、移速1.5倍、每波12只
			config.health_multiplier = 1.8
			config.speed_multiplier = 1.5
			config.damage_multiplier = 1.15
			config.enemies_per_wave = 12
			config.wave_interval = 5.0
			# 20关伪BOSS
			if current_level == 20:
				config.has_boss = true
				config.boss_scale = 1.5
				config.boss_health_multiplier = 5.0
				config.boss_effects = ["red_border", "speed_burst"]
				config.additional_enemies = 3
			
		LevelPhase.LOOP:
			# 循环期（21关后）每5关数值×1.1倍
			var base_multiplier = get_loop_multiplier()
			config.health_multiplier = 1.8 * base_multiplier
			config.speed_multiplier = 1.5 * base_multiplier
			config.damage_multiplier = 1.15 * pow(1.05, (current_level - 20) / 5)
			config.enemies_per_wave = min(15, int(floor(12.0 * base_multiplier)))
			config.wave_interval = max(2.5, 5.0 - (base_multiplier - 1.0) * 2.0)
			if int(current_level) % 5 == 0:
				config.has_boss = true
				config.boss_scale = 1.5
				config.boss_health_multiplier = 5.0 * base_multiplier
				config.boss_effects = ["red_border", "speed_burst", "area_slow"]
				config.additional_enemies = min(8, int(floor((float(current_level) - 20.0) / 10.0) + 3))
	
	return config

func _ready():
	print("LevelManager: _ready() called")
	add_to_group("level_manager")
	print("LevelManager: 初始玩家等级: ", player_level, ", 初始天赋点: ", talent_points, ", 初始关卡: ", current_level)
	update_player_attributes()
	call_deferred("_deferred_start_level")

func _deferred_start_level():
	print("LevelManager: _deferred_start_level called")
	start_level(current_level)

# 开始指定关卡
func start_level(level_number, wave := 0, progress := 0):
	print("LevelManager: start_level() called with level_number:", level_number)
	var enemy_spawner = get_node_or_null("/root/Main/EnemySpawner")
	print("LevelManager: enemy_spawner =", enemy_spawner)
	if not enemy_spawner:
		print("LevelManager: EnemySpawner 获取失败，无法刷怪！请检查节点名和场景结构。")
		return
	if level_number < 1:
		push_error("无效的关卡编号: " + str(level_number))
		return
	
	current_level = level_number
	print("LevelManager: 设置当前关卡为: ", current_level)
	var level_config = get_level_config()
	
	# 设置关卡进度
	current_progress = progress
	current_wave = wave
	total_waves = 5 # 每关5波怪物
	enemies_per_wave = level_config.enemies_per_wave
	target_progress = total_waves * enemies_per_wave
	print("LevelManager: 关卡进度设置: current_progress=", current_progress, ", target_progress=", target_progress)
	
	if level_config.has_boss:
		target_progress += 1 # BOSS算1个进度
		if level_config.additional_enemies > 0:
			target_progress += level_config.additional_enemies
	
	# 配置敌人生成器
	if enemy_spawner:
		print("LevelManager: 成功获取 EnemySpawner")
		enemy_spawner.health_multiplier = level_config.health_multiplier
		enemy_spawner.speed_multiplier = level_config.speed_multiplier
		enemy_spawner.spawn_interval = level_config.wave_interval
		enemy_spawner.enemies_per_wave = level_config.enemies_per_wave
		enemy_spawner.has_boss = level_config.has_boss
		enemy_spawner.boss_scale = level_config.boss_scale
		enemy_spawner.boss_health_multiplier = level_config.boss_health_multiplier
		enemy_spawner.boss_effects = level_config.boss_effects
		enemy_spawner.additional_enemies = level_config.additional_enemies
		enemy_spawner.current_level = current_level
		enemy_spawner.damage_multiplier = level_config.damage_multiplier
		print("LevelManager: EnemySpawner配置: spawn_interval=", enemy_spawner.spawn_interval, ", enemies_per_wave=", enemy_spawner.enemies_per_wave)
	
	# 发送关卡开始信号
	emit_signal("level_started", current_level, level_config)
	
	# 确保关卡进度在关卡开始时得到更新
	emit_signal("level_progress_updated", current_progress, target_progress)
	
	# 开始生成敌人
	if enemy_spawner:
		print("LevelManager: 调用 EnemySpawner.start_level()")
		enemy_spawner.start_level()

# 更新关卡进度
func update_progress(amount = 1):
	print("LevelManager: update_progress() called with amount: ", amount, ", current_progress: ", current_progress, ", target_progress: ", target_progress)
	current_progress += amount
	emit_signal("level_progress_updated", current_progress, target_progress)
	print("LevelManager: 进度更新: current_progress=", current_progress, ", target_progress=", target_progress)
	
	# 检查关卡是否完成
	if current_progress >= target_progress:
		complete_level()

# 开始新的一波
func start_new_wave():
	current_wave += 1
	emit_signal("wave_started", current_wave, total_waves)
	
	# 如果是最后一波且当前关卡需要BOSS，则生成BOSS
	var level_config = get_level_config()
	if current_wave == total_waves and level_config.has_boss:
		emit_signal("boss_spawned", current_level)

# 完成当前关卡
func complete_level():
	print("LevelManager: complete_level() called")
	var enemy_spawner = get_parent().get_node_or_null("EnemySpawner")
	if enemy_spawner:
		enemy_spawner.stop()
	
	# 给予奖励
	var game_manager = get_parent().get_node_or_null("GameManager")
	if game_manager:
		var reward = 50 + current_level * 10
		game_manager.add_score(reward)
	
	# 发送关卡完成信号
	emit_signal("level_completed", current_level)
	
	# 自动进入下一关
	current_level += 1
	print("LevelManager: 自动进入下一关:", current_level)
	start_level(current_level)
	
	# 刷新存档面板UI（最高关卡等信息）
	var save_panel = get_node_or_null("/root/Main/UI/BottomPanel/设置/SaveManagerSection")
	if save_panel and save_panel.has_method("initialize_save_panel"):
		save_panel.initialize_save_panel()

# 获取当前关卡信息
func get_current_level_info():
	print("LevelManager: get_current_level_info() called")
	var phase_names = {
		LevelPhase.BEGINNER: "新手期",
		LevelPhase.TRANSITION: "过渡期",
		LevelPhase.GROWTH: "成长期",
		LevelPhase.MATURE: "成熟期",
		LevelPhase.LOOP: "循环期"
	}
	
	var phase = get_current_phase()
	var config = get_level_config()
	
	return {
		"level": current_level,
		"phase": phase_names[phase],
		"health_multiplier": config.health_multiplier,
		"speed_multiplier": config.speed_multiplier,
		"enemies_per_wave": config.enemies_per_wave,
		"has_boss": config.has_boss
	}

# 获取关卡进度百分比
func get_progress_percentage():
	if target_progress == 0:
		return 0
	return (float(current_progress) / float(target_progress)) * 100.0

# 玩家等级系统功能
func add_experience(amount):
	print("LevelManager: add_experience(", amount, ") called")
	player_exp += amount
	
	# 显示经验值获取效果
	var ui_manager = get_node_or_null("/root/Main/HUD")
	if ui_manager and ui_manager.has_method("show_exp_gain_effect"):
		ui_manager.show_exp_gain_effect(amount)
	
	# 检查是否升级
	while player_exp >= exp_to_next_level and player_level < player_max_level:
		level_up()
	
	# (这些现在直接由LevelManager管理，无需同步)
	# # GameAttributes.player_experience = current_exp
	# # GameAttributes.experience_required = required_exp

	# 更新UI
	if ui_manager and ui_manager.has_method("update_exp_display"):
		ui_manager.update_exp_display()

func level_up():
	print("LevelManager: level_up() called")
	player_level += 1
	player_exp -= exp_to_next_level
	print("LevelManager: 玩家升级: 新等级=", player_level, ", 剩余经验=", player_exp)
	
	# (这些现在直接由LevelManager管理，无需同步)
	# # GameAttributes.update_attribute("player_level", player_level)
	# # GameAttributes.update_attribute("player_experience", player_exp)
	print("LevelManager: 同步GameAttributes: player_level=", player_level, ", player_experience=", player_exp)

	# 更新任务进度 - 等级提升
	if has_node("/root/QuestSystem"):
		var quest_system = get_node("/root/QuestSystem")
		quest_system.update_quest_progress("level", 1)
	
	# 计算下一级所需经验值 (每级增加20%)
	exp_to_next_level = int(exp_to_next_level * 1.2)
	
	# 每升1级获得1点天赋点（总共30级=30点）
	talent_points += 1
	total_talent_points += 1
	print("LevelManager: 升级后天赋点: ", talent_points, " 总天赋点: ", total_talent_points)
	emit_signal("talent_points_changed", talent_points)
	print("获得天赋点! 当前天赋点: ", talent_points)
	
	# 同步刷新天赋UI（如果存在）
	var ui_manager = get_node_or_null("/root/Main/UI")
	if ui_manager and ui_manager.has_method("initialize_talent_page"):
			ui_manager.initialize_talent_page()
	
	# 显示升级效果
	var ui_mgr = get_node_or_null("/root/Main/UI")
	if ui_mgr and ui_mgr.has_method("show_level_up_effect"):
		ui_mgr.show_level_up_effect(player_level)
	
	# 发送升级信号
	emit_signal("player_level_up", player_level)
	
	# 更新玩家属性
	update_player_attributes()

func update_player_attributes():
	print("LevelManager: update_player_attributes() called")
	# 获取玩家节点
	var player = get_node_or_null("/root/Main/Player")
	if not player:
		return
	
	# 基础属性值
	var base_health = 100
	# var _base_speed = 300 # 移除，速度通过GameAttributes更新
	# var _base_damage = 10 # 移除，伤害通过GameAttributes更新
	
	# 每级增加的属性百分比
	var health_per_level = 0.05 # 5%
	# var _speed_per_level = 0.02 # 移除
	# var _damage_per_level = 0.04 # 移除
	
	# 计算新属性值
	var health_multiplier = 1.0 + (player_level - 1) * health_per_level
	# var _speed_multiplier = 1.0 + (player_level - 1) * _speed_per_level # 移除
	# var _damage_multiplier = 1.0 + (player_level - 1) * _damage_per_level # 移除
	
	# 更新玩家最大生命值和当前生命值通过GameAttributes
	var new_max_health = int(base_health * health_multiplier)
	GameAttributes.update_attribute("max_health", new_max_health)
	GameAttributes.update_attribute("health", new_max_health) # 升级时恢复满血

	# 移除对UIManager的错误调用，UIManager会监听GameAttributes的信号
	# var ui_manager = get_node_or_null("/root/Main/HUD")
	# if ui_manager and ui_manager.has_method("update_player_attributes"):
	#	ui_manager.update_player_attributes(player)

	# 攻速随等级自动成长，每级+0.02，最大1.5
	var attack_speed_per_level = 0.02
	player_attack_speed = 0.5 + (player_level - 1) * attack_speed_per_level
	player_attack_speed = min(player_attack_speed, 1.5)
	GameAttributes.update_attribute("attack_speed", player_attack_speed)

# 新增函数：消耗天赋点数
func spend_talent_points(cost: int):
	if talent_points >= cost:
		talent_points -= cost
		print("LevelManager: 消耗天赋点数: ", cost, ", 剩余: ", talent_points)
		emit_signal("talent_points_changed", talent_points)
		return true
	print("LevelManager: 天赋点不足，无法消耗: ", cost, ", 现有: ", talent_points)
	return false

func get_player_level_info():
	return {
		"level": player_level,
		"max_level": player_max_level,
		"exp": player_exp,
		"exp_to_next": exp_to_next_level,
		"talent_points": talent_points,
		"total_talent_points": total_talent_points
	}
