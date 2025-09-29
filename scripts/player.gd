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
func _on_attributes_changed():
	# 这里可以处理属性变化后的逻辑
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
	if GameAttributes.last_stand_shield_enabled and health <= max_health * GameAttributes.last_stand_shield_threshold:
		print("触发濒死护盾，无敌", GameAttributes.last_stand_shield_duration, "秒")
		$InvincibilityTimer.wait_time = GameAttributes.last_stand_shield_duration
		$InvincibilityTimer.start()
		$AnimatedSprite2D.modulate = Color(0.5, 0.8, 1.0)  # 蓝色护盾效果
		return
		
	# 应用防御属性减少伤害
	var actual_damage = damage_amount * (1.0 - GameAttributes.defense)
	health -= actual_damage
	emit_signal("player_damaged", actual_damage)
	
	if health <= 0:
		health = 0
		die()
	
	# 播放受伤视觉效果
	$AnimatedSprite2D.modulate = Color(1, 0.5, 0.5)  # 变红表示受伤
	await get_tree().create_timer(0.1).timeout
	$AnimatedSprite2D.modulate = Color(1, 1, 1)  # 恢复正常颜色
	
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
	$AnimatedSprite2D.modulate = Color(1, 1, 1)  # 恢复正常颜色
	
	# 发出受伤信号
	emit_signal("player_hit")

# 玩家死亡
func die():
	is_alive = false
	# 死亡视觉效果
	$AnimatedSprite2D.modulate = Color(0.5, 0.5, 0.5)  # 变灰表示死亡
	
	# 游戏结束逻辑
	await get_tree().create_timer(2.0).timeout
	get_tree().call_group("game_manager", "game_over")

# 恢复生命值
func heal(amount):
	health = min(health + amount, max_health)
	
# 处理输入和移动
func _process(delta):
	if not is_alive:
		return
	
	# 手动射击功能保留，但不再需要按键触发
	# 自动发射由start_auto_fire()函数处理
	
# 应用减速效果
func apply_slow_effect(slow_factor, duration):
	is_slowed = true
	current_speed_multiplier = slow_factor
	
	# 视觉效果
	$AnimatedSprite2D.modulate = Color(0.5, 0.5, 1.0)  # 蓝色表示减速
	
	# 持续一段时间后恢复
	await get_tree().create_timer(duration).timeout
	
	if is_alive:
		is_slowed = false
		current_speed_multiplier = 1.0
		$AnimatedSprite2D.modulate = Color(1, 1, 1)  # 恢复正常颜色
		
# 发射子弹
func shoot():
	if not can_shoot or not is_alive:
		return
	
	# 决定发射多少发子弹
	var shot_count = 1
	var random_value = randf()
	
	if random_value < GameAttributes.triple_shot_chance:
		shot_count = 3
		show_multi_shot_text("三连发!")
	elif random_value < GameAttributes.triple_shot_chance + GameAttributes.double_shot_chance:
		shot_count = 2
		show_multi_shot_text("双连发!")
	
	# 获取最近的敌人作为目标
	var target_direction = find_nearest_enemy_direction()
	
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
		
		# 根据连击数设置子弹颜色和位置
		if shot_count == 2:  # 双发子弹
			# 禁用暴击颜色变化，使用固定的浅蓝色
			# 设置一个标志来禁用暴击，而不是直接修改crit_chance
			bullet.is_critical = false  # 禁用暴击
			
			# 浅蓝色子弹
			var style = bullet.get_node("Panel").get_theme_stylebox("panel").duplicate()
			style.bg_color = Color("#87CEEB")
			bullet.get_node("Panel").add_theme_stylebox_override("panel", style)
			
			# 平行排列，间距5px
			var offset = Vector2(-5, 0) if i == 0 else Vector2(5, 0)
			# 旋转偏移向量，使其与射击方向垂直
			offset = offset.rotated(target_direction.angle() + PI/2)
			bullet.position += offset
			
			# 设置方向（平行）
			bullet.direction = target_direction
			
		elif shot_count == 3:  # 三发子弹
			# 禁用暴击颜色变化，使用固定的深蓝色
			bullet.is_critical = false  # 禁用暴击
			
			# 深蓝色子弹
			var style = bullet.get_node("Panel").get_theme_stylebox("panel").duplicate()
			style.bg_color = Color("#0000CD")
			bullet.get_node("Panel").add_theme_stylebox_override("panel", style)
			
			# 扇形排列，角度各偏10°
			var angle_offset = 0
			if i == 0:
				angle_offset = -10 * (PI/180)  # 左偏10度
			elif i == 2:
				angle_offset = 10 * (PI/180)   # 右偏10度
			
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
		modulate = Color(1.0, 1.0, 0.5, 1.0)  # 黄色发光
		await get_tree().create_timer(0.1).timeout
		modulate = Color(1.0, 1.0, 1.0, 1.0)  # 恢复正常
	
	# 设置冷却
	can_shoot = false
	await get_tree().create_timer(GameAttributes.bullet_cooldown).timeout
	can_shoot = true
	
# 启动自动发射子弹
func start_auto_fire():
	while is_alive:
		shoot()
		# 应用攻速属性影响子弹冷却时间
		var adjusted_cooldown = GameAttributes.bullet_cooldown / GameAttributes.attack_speed
		await get_tree().create_timer(adjusted_cooldown).timeout
		
# 寻找最近的敌人并返回朝向该敌人的方向
func find_nearest_enemy_direction():
	var enemies = get_tree().get_nodes_in_group("enemy")
	var nearest_enemy = null
	var min_distance = INF
	
	# 如果没有敌人，随机方向
	if enemies.size() == 0:
		return Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	
	# 寻找最近的敌人
	for enemy in enemies:
		var distance = global_position.distance_to(enemy.global_position)
		if distance < min_distance:
			min_distance = distance
			nearest_enemy = enemy
	
	# 返回朝向最近敌人的方向
	if nearest_enemy:
		return (nearest_enemy.global_position - global_position).normalized()
	else:
		return Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

# 显示多连发文字
func show_multi_shot_text(text):
	# 创建一个Label节点
	var shot_label = Label.new()
	shot_label.text = text
	shot_label.add_theme_color_override("font_color", Color("#87CEEB"))  # 浅蓝色
	shot_label.add_theme_font_size_override("font_size", 20)  # 字体大小
	shot_label.add_theme_constant_override("outline_size", 1)  # 1px描边
	shot_label.add_theme_color_override("font_outline_color", Color(1, 1, 1))  # 白色描边
	
	# 设置位置
	shot_label.global_position = global_position + Vector2(0, -40)  # 在玩家头上方显示
	
	# 添加到场景（使用延迟调用避免在场景设置过程中添加节点）
	get_tree().get_root().call_deferred("add_child", shot_label)
	
	# 创建动画效果（延迟到下一帧执行）
	await get_tree().process_frame
	var tween = get_tree().create_tween()
	tween.tween_property(shot_label, "global_position", global_position + Vector2(0, -70), 0.5)  # 向上移动
	tween.parallel().tween_property(shot_label, "modulate", Color("#87CEEB", 0), 0.5)  # 淡出
	
	# 动画完成后删除
	await tween.finished
	shot_label.queue_free()
