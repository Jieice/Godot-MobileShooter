extends CharacterBody2D

# 玩家控制脚本
# 处理玩家的移动、射击和状态

# 信号
signal player_hit
signal player_damaged(amount)

# 玩家特有属性，其他属性从GameAttributes获取
@export var health = 80
@export var max_health = 80

# 预加载子弹场景
var bullet_scene = preload("res://scenes/bullet.tscn")

# 减速效果
var is_slowed = false
var current_speed_multiplier = 1.0

# 玩家状态
var is_alive = true
var can_shoot = true

func _ready():
	# 初始化玩家属性
	health = GameAttributes.health
	max_health = GameAttributes.max_health
	
	# 监听属性变化
	GameAttributes.attributes_changed.connect(_on_attributes_changed)
	
	# 启动自动发射子弹的计时器
	if GameAttributes.auto_fire:
		start_auto_fire()

# 当GameAttributes属性变化时更新
func _on_attributes_changed(attribute_name, value):
	print("Player: _on_attributes_changed called for ", attribute_name, ": ", value)
	match attribute_name:
		"player_speed":
			# TODO: 更新玩家移动速度
			pass
		"max_health":
			max_health = value
			# 同时更新当前生命值，避免升级生命上限后当前生命值不变
			# health = min(health, max_health) # 这行由GameAttributes统一管理
			GameAttributes.update_attribute("health", min(GameAttributes.health, value))
			# if has_node("/root/Main/HUD"):
			#	get_node("/root/Main/HUD").update_health_bar(health, max_health)
		"health": # 如果直接修改了health属性（例如被治疗）
			health = value
			# if has_node("/root/Main/HUD"):
			#	get_node("/root/Main/HUD").update_health_bar(health, max_health)
		"bullet_damage":
			# 子弹伤害会在bullet.gd中直接从GameAttributes读取
			pass
		"bullet_cooldown":
			# 射击冷却会在start_auto_fire中重新计算
			pass
		"attack_range":
			# 攻击范围会在find_nearest_enemy_direction中直接从GameAttributes读取
			pass
		"defense":
			# 防御会在take_damage中直接从GameAttributes读取
			pass
		"dodge_chance":
			# 闪避几率会在take_damage中直接从GameAttributes读取
			pass
		"last_stand_shield_enabled", "last_stand_shield_duration", "last_stand_shield_threshold":
			# 濒死护盾相关属性会在take_damage中直接从GameAttributes读取
			pass
		"elite_priority_chance":
			# 精英优先率会在find_nearest_enemy_direction中直接从GameAttributes读取
			pass
		"dual_target_enabled":
			# 双目标锁定会在shoot中直接从GameAttributes读取
			pass
		"attack_speed":
			# 攻击速度会在start_auto_fire中重新计算射击间隔
			pass
		"player_level":
			# 玩家等级变化可能需要额外处理，例如解锁新功能或更新UI
			pass
		_:
			# 对于其他直接从GameAttributes读取的属性，无需在Player中特别处理
			pass

# 玩家受到伤害
func take_damage(damage_amount):
	if not is_alive:
		return
	
	# 检查是否闪避
	if randf() <= GameAttributes.dodge_chance:
		# 显示闪避效果
		show_dodge_effect()
		return
		
	# 检查是否触发濒死护盾
	if GameAttributes.last_stand_shield_enabled and GameAttributes.health <= GameAttributes.max_health * GameAttributes.last_stand_shield_threshold:
		print("触发濒死护盾，无敌", GameAttributes.last_stand_shield_duration, "秒")
		var inv_timer = get_node_or_null("InvincibilityTimer")
		if inv_timer:
			inv_timer.wait_time = GameAttributes.last_stand_shield_duration
			inv_timer.start()
		$AnimatedSprite2D.modulate = Color(0.5, 0.8, 1.0) # 蓝色护盾效果
		return
		
	# 应用防御属性减少伤害
	var actual_damage = damage_amount * (1.0 - GameAttributes.defense)
	# health -= actual_damage # 直接修改health，不再通过GameAttributes
	var new_health = max(0, GameAttributes.health - actual_damage)
	GameAttributes.update_attribute("health", new_health) # 通过GameAttributes更新生命值
	emit_signal("player_damaged", actual_damage)
	
	if GameAttributes.health <= 0:
		GameAttributes.update_attribute("health", 0)
		die()
	
	# 播放受伤视觉效果
	$AnimatedSprite2D.modulate = Color(1, 0.5, 0.5) # 变红表示受伤
	await get_tree().create_timer(0.1).timeout
	$AnimatedSprite2D.modulate = Color(1, 1, 1) # 恢复正常颜色
	
# 显示闪避效果
func show_dodge_effect():
	# 创建一个Label节点
	var dodge_label = Label.new()
	dodge_label.text = "闪避!"
	
	# 设置文本样式
	dodge_label.add_theme_font_size_override("font_size", 16)
	dodge_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.5)) # 绿色
	dodge_label.add_theme_constant_override("outline_size", 1)
	dodge_label.add_theme_color_override("font_outline_color", Color(1, 1, 1)) # 白色描边
	
	# 设置位置
	dodge_label.global_position = global_position + Vector2(0, -50)
	
	# 添加到场景中
	get_tree().get_root().add_child(dodge_label)
	
	# 创建动画效果
	var tween = get_tree().create_tween()
	tween.tween_property(dodge_label, "global_position", dodge_label.global_position + Vector2(0, -20), 0.8)
	tween.parallel().tween_property(dodge_label, "modulate", Color(0.0, 1.0, 0.5, 0), 0.8)
	tween.tween_callback(dodge_label.queue_free)
	$AnimatedSprite2D.modulate = Color(1, 1, 1) # 恢复正常颜色
	
	# 发出受伤信号
	emit_signal("player_hit")

# 玩家死亡
func die():
	print("Player: die() called - Player has died!")
	is_alive = false
	# 死亡视觉效果
	$AnimatedSprite2D.modulate = Color(0.5, 0.5, 0.5) # 变灰表示死亡
	
	# 游戏结束逻辑
	await get_tree().create_timer(2.0).timeout
	get_tree().call_group("game_manager", "game_over")

# 恢复生命值
func heal(amount):
	if not is_alive:
		return
	
	var new_health = min(GameAttributes.health + amount, GameAttributes.max_health)
	GameAttributes.update_attribute("health", new_health) # 通过GameAttributes更新生命值
	print("恢复生命值: ", amount, " 当前生命值: ", new_health)
	
	# UIManager会监听GameAttributes的信号进行更新，这里不再需要直接调用
	# var ui_manager = get_node_or_null("/root/Main/HUD")
	# if ui_manager and ui_manager.has_method("update_health_bar"):
	#	ui_manager.update_health_bar(health, max_health)
	
# 处理输入和移动
func _process(_delta):
	if not is_alive:
		return
	
	# 手动射击功能保留，但不再需要按键触发
	# 自动发射由start_auto_fire()函数处理
	
# 应用减速效果
func apply_slow_effect(slow_factor, duration):
	is_slowed = true
	current_speed_multiplier = slow_factor
	
	# 视觉效果
	$AnimatedSprite2D.modulate = Color(0.5, 0.5, 1.0) # 蓝色表示减速
	
	# 持续一段时间后恢复
	await get_tree().create_timer(duration).timeout
	
	if is_alive:
		is_slowed = false
		current_speed_multiplier = 1.0
		$AnimatedSprite2D.modulate = Color(1, 1, 1) # 恢复正常颜色
		
# 发射子弹
func shoot():
	if not can_shoot or not is_alive:
		return
	
	# 获取目标方向
	var target_directions = []
	if GameAttributes.dual_target_enabled:
		target_directions = find_dual_target_directions()
	else:
		var single_direction = find_nearest_enemy_direction()
		if single_direction != null:
			target_directions.append(single_direction)
	
	# 如果没有找到目标方向，则不射击
	if target_directions.is_empty(): # 修正：使用 is_empty() 方法
		return

	# 决定发射多少发子弹
	var shot_count = 1
	var random_value = randf()
	
	if random_value < GameAttributes.triple_shot_chance:
		shot_count = 3
		show_multi_shot_text("三连发!")
		# 更新任务进度 - 连击
		if has_node("/root/QuestSystem"):
			var quest_system = get_node("/root/QuestSystem")
			quest_system.update_quest_progress("combo", 1)
	elif random_value < GameAttributes.triple_shot_chance + GameAttributes.double_shot_chance:
		shot_count = 2
		show_multi_shot_text("双连发!")
		# 更新任务进度 - 连击
		if has_node("/root/QuestSystem"):
			var quest_system = get_node("/root/QuestSystem")
			quest_system.update_quest_progress("combo", 1)
	
	# 发射子弹
	for i in range(shot_count):
		# 创建子弹实例
		var bullet = bullet_scene.instantiate()
		bullet.position = position
		
		# 子弹会在_ready中自动从GameAttributes获取属性
		# 只需设置特殊情况下需要覆盖的属性
		
		# 记录裂变流模式状态
		if GameAttributes.is_fission_enabled:
			print("裂变流模式激活!")
		
		# 选择目标方向
		var target_direction = target_directions[i % target_directions.size()]
		
		# 根据连击数设置子弹颜色和位置
		if shot_count == 2: # 双发子弹
			# 禁用暴击颜色变化，使用固定的浅蓝色
			# 设置一个标志来禁用暴击，而不是直接修改crit_chance
			bullet.is_critical = false # 禁用暴击
			
			# 浅蓝色子弹
			var style = bullet.get_node("Panel").get_theme_stylebox("panel").duplicate()
			style.bg_color = Color("#87CEEB")
			bullet.get_node("Panel").add_theme_stylebox_override("panel", style)
			
			# 平行排列，间距5px
			var offset = Vector2(-5, 0) if i == 0 else Vector2(5, 0)
			# 旋转偏移向量，使其与射击方向垂直
			offset = offset.rotated(target_direction.angle() + PI / 2)
			bullet.position += offset
			
			# 设置方向（平行）
			bullet.direction = target_direction
			
		elif shot_count == 3: # 三发子弹
			# 禁用暴击颜色变化，使用固定的深蓝色
			bullet.is_critical = false # 禁用暴击
			
			# 深蓝色子弹
			var style = bullet.get_node("Panel").get_theme_stylebox("panel").duplicate()
			style.bg_color = Color("#0000CD")
			bullet.get_node("Panel").add_theme_stylebox_override("panel", style)
			
			# 扇形排列，角度各偏10°
			var angle_offset = 0
			if i == 0:
				angle_offset = -10 * (PI / 180) # 左偏10度
			elif i == 2:
				angle_offset = 10 * (PI / 180) # 右偏10度
			
			bullet.direction = target_direction.rotated(angle_offset)
		else:
			# 默认单发 - 保持原始颜色
			bullet.direction = target_direction
		
		# 将子弹添加到场景中（使用延迟调用避免在场景设置过程中添加节点）
		get_parent().call_deferred("add_child", bullet)
		
		# 如果是多连发，在子弹之间添加小延迟
		if i < shot_count - 1:
			await get_tree().create_timer(0.05).timeout
	
	# 视觉反馈 - 玩家短暂发光
	if shot_count > 1:
		modulate = Color(1.0, 1.0, 0.5, 1.0) # 黄色发光
		await get_tree().create_timer(0.1).timeout
		modulate = Color(1.0, 1.0, 1.0, 1.0) # 恢复正常
	
	# 设置冷却
	can_shoot = false
	await get_tree().create_timer(GameAttributes.bullet_cooldown).timeout
	can_shoot = true
	
# 启动自动发射子弹
func start_auto_fire():
	while is_alive:
		shoot()
		# 应用攻速属性影响子弹冷却时间
		# attack_speed是倍率，1.0为基础速度，>1.0为加速
		var adjusted_cooldown = GameAttributes.bullet_cooldown / GameAttributes.attack_speed
		await get_tree().create_timer(adjusted_cooldown).timeout
		
# 寻找最近的敌人并返回朝向该敌人的方向
func find_nearest_enemy_direction():
	var enemies = get_tree().get_nodes_in_group("enemy")
	var nearest_enemy = null
	var min_distance = INF
	
	# 如果没有敌人，随机方向
	if enemies.size() == 0:
		return null # 如果没有敌人，返回null，表示不射击
	
	# 应用攻击范围天赋 - 只考虑范围内的敌人
	var max_attack_range = 300.0 * GameAttributes.attack_range # 基础范围300像素
	
	# 寻找最近的敌人（在攻击范围内且在屏幕内）
	# 优先考虑精英敌人（如果有精英优先率天赋）
	var elite_enemies = []
	var normal_enemies = []
	
	# 获取屏幕尺寸
	var screen_size = get_viewport_rect().size
	
	for enemy in enemies:
		var distance = global_position.distance_to(enemy.global_position)
		# 检查敌人是否在屏幕内
		var enemy_pos = enemy.global_position
		var is_on_screen = (enemy_pos.x >= 0 and enemy_pos.x <= screen_size.x and
							enemy_pos.y >= 0 and enemy_pos.y <= screen_size.y)
		
		# 只考虑在攻击范围内且在屏幕内的敌人
		if distance <= max_attack_range and is_on_screen:
			if enemy.is_in_group("boss") or enemy.scale.x >= 1.3 or enemy.scale.y >= 1.3:
				elite_enemies.append({"enemy": enemy, "distance": distance})
			else:
				normal_enemies.append({"enemy": enemy, "distance": distance})
	
	# 应用精英优先率天赋
	var use_elite_priority = randf() <= GameAttributes.elite_priority_chance
	var target_list = elite_enemies if use_elite_priority and elite_enemies.size() > 0 else normal_enemies
	
	# 如果精英优先失败或没有精英，使用普通敌人列表
	if target_list.size() == 0:
		target_list = normal_enemies
	
	# 从目标列表中找到最近的敌人
	for enemy_data in target_list:
		if enemy_data.distance < min_distance:
			min_distance = enemy_data.distance
			nearest_enemy = enemy_data.enemy
	
	# 返回朝向最近敌人的方向
	if nearest_enemy:
		return (nearest_enemy.global_position - global_position).normalized()
	else:
		return null # 如果没有在攻击范围内且在屏幕内的敌人，返回null，表示不射击

# 寻找双目标方向
func find_dual_target_directions():
	var enemies = get_tree().get_nodes_in_group("enemy")
	var directions = []
	
	# 如果没有敌人，返回两个随机方向
	if enemies.size() == 0:
		return []
	
	# 应用攻击范围天赋
	var max_attack_range = 300.0 * GameAttributes.attack_range
	
	# 获取屏幕尺寸
	var screen_size = get_viewport_rect().size
	
	# 分类敌人
	var elite_enemies = []
	var normal_enemies = []
	
	for enemy in enemies:
		var distance = global_position.distance_to(enemy.global_position)
		# 检查敌人是否在屏幕内
		var enemy_pos = enemy.global_position
		var is_on_screen = (enemy_pos.x >= 0 and enemy_pos.x <= screen_size.x and
							enemy_pos.y >= 0 and enemy_pos.y <= screen_size.y)
		
		# 只考虑在攻击范围内且在屏幕内的敌人
		if distance <= max_attack_range and is_on_screen:
			if enemy.is_in_group("boss") or enemy.scale.x >= 1.3 or enemy.scale.y >= 1.3:
				elite_enemies.append({"enemy": enemy, "distance": distance})
			else:
				normal_enemies.append({"enemy": enemy, "distance": distance})
	
	# 优先选择精英敌人
	var target_list = elite_enemies if elite_enemies.size() > 0 else normal_enemies
	
	# 按距离排序
	target_list.sort_custom(func(a, b): return a.distance < b.distance)
	
	# 选择前两个最近的敌人
	for i in range(min(2, target_list.size())):
		var enemy = target_list[i].enemy
		directions.append((enemy.global_position - global_position).normalized())
	
	# 如果只有一个目标，添加一个随机方向
	if directions.size() == 1:
		directions.append(Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized())
	
	# 如果没有目标，返回两个随机方向
	if directions.size() == 0:
		directions = [Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized(),
					  Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()]
	
	return directions

# 显示多连发文字
func show_multi_shot_text(text):
	# 创建一个Label节点
	var shot_label = Label.new()
	shot_label.text = text
	shot_label.add_theme_color_override("font_color", Color("#87CEEB")) # 浅蓝色
	shot_label.add_theme_font_size_override("font_size", 20) # 字体大小
	shot_label.add_theme_constant_override("outline_size", 1) # 1px描边
	shot_label.add_theme_color_override("font_outline_color", Color(1, 1, 1)) # 白色描边
	
	# 设置位置
	shot_label.global_position = global_position + Vector2(0, -40) # 在玩家头上方显示
	
	# 添加到场景（使用延迟调用避免在场景设置过程中添加节点）
	get_tree().get_root().call_deferred("add_child", shot_label)
	
	# 创建动画效果（延迟到下一帧执行）
	await get_tree().process_frame
	var tween = get_tree().create_tween()
	tween.tween_property(shot_label, "global_position", global_position + Vector2(0, -70), 0.5) # 向上移动
	tween.parallel().tween_property(shot_label, "modulate", Color("#87CEEB", 0), 0.5) # 淡出
	
	# 动画完成后删除
	await tween.finished
	shot_label.queue_free()

# 恢复生命值
func restore_health(amount):
	if not is_alive:
		return
	
	var new_health = min(GameAttributes.health + amount, GameAttributes.max_health)
	GameAttributes.update_attribute("health", new_health) # 通过GameAttributes更新生命值
	print("恢复生命值: ", amount, " 当前生命值: ", new_health)
	
	# UIManager会监听GameAttributes的信号进行更新，这里不再需要直接调用
	# var ui_manager = get_node_or_null("/root/Main/HUD")
	# if ui_manager and ui_manager.has_method("update_health_bar"):
	#	ui_manager.update_health_bar(health, max_health)
