extends CharacterBody2D

signal player_hit

@export var health = 80
@export var max_health = 80
@export var speed = 250
@export var bullet_cooldown = 1.0  # 子弹冷却时间（秒）
@export var auto_fire = true  # 自动发射子弹
@export var double_shot_chance = 0.3  # 双连发几率
@export var triple_shot_chance = 0.1  # 三连发几率
@export var bullet_damage = 5  # 子弹基础伤害
@export var crit_chance = 0.1  # 暴击几率 (10%)
@export var crit_multiplier = 1.5  # 暴击伤害倍数

# 预加载子弹场景
var bullet_scene = preload("res://scenes/bullet.tscn")

# 玩家状态
var is_alive = true
var can_shoot = true

func _ready():
	# 初始化玩家
	health = max_health
	
	# 启动自动发射子弹的计时器
	if auto_fire:
		start_auto_fire()

# 玩家受到伤害
func take_damage(damage_amount):
	if not is_alive:
		return
		
	health -= damage_amount
	
	if health <= 0:
		health = 0
		die()
	
	# 播放受伤视觉效果
	$AnimatedSprite2D.modulate = Color(1, 0.5, 0.5)  # 变红表示受伤
	await get_tree().create_timer(0.1).timeout
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
		
# 发射子弹
func shoot():
	if not can_shoot or not is_alive:
		return
	
	# 决定发射多少发子弹
	var shot_count = 1
	var random_value = randf()
	
	if random_value < triple_shot_chance:
		shot_count = 3
		show_multi_shot_text("三连发!")
	elif random_value < triple_shot_chance + double_shot_chance:
		shot_count = 2
		show_multi_shot_text("双连发!")
	
	# 获取最近的敌人作为目标
	var target_direction = find_nearest_enemy_direction()
	
	# 发射子弹
	for i in range(shot_count):
		# 创建子弹实例
		var bullet = bullet_scene.instantiate()
		bullet.position = position
		
		# 设置子弹属性（使用玩家的属性设置）
		bullet.damage = bullet_damage
		bullet.crit_chance = crit_chance
		bullet.crit_multiplier = crit_multiplier
		
		# 如果是多连发，稍微调整方向使子弹散开
		var bullet_direction = target_direction
		if shot_count > 1:
			# 为每个子弹添加一点随机偏移
			var spread = 0.1 * (i - (shot_count - 1) / 2.0)
			bullet_direction = target_direction.rotated(spread)
		
		bullet.direction = bullet_direction
		
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
	await get_tree().create_timer(bullet_cooldown).timeout
	can_shoot = true
	
# 启动自动发射子弹
func start_auto_fire():
	while is_alive:
		shoot()
		await get_tree().create_timer(bullet_cooldown).timeout
		
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
	shot_label.add_theme_color_override("font_color", Color(1, 0.8, 0))  # 金色
	shot_label.add_theme_font_size_override("font_size", 20)  # 字体大小
	
	# 设置位置
	shot_label.global_position = global_position + Vector2(0, -40)  # 在玩家头上方显示
	
	# 添加到场景（使用延迟调用避免在场景设置过程中添加节点）
	get_tree().get_root().call_deferred("add_child", shot_label)
	
	# 创建动画效果（延迟到下一帧执行）
	await get_tree().process_frame
	var tween = get_tree().create_tween()
	tween.tween_property(shot_label, "global_position", global_position + Vector2(0, -70), 0.5)  # 向上移动
	tween.parallel().tween_property(shot_label, "modulate", Color(1, 0.8, 0, 0), 0.5)  # 淡出
	
	# 动画完成后删除
	await tween.finished
	shot_label.queue_free()