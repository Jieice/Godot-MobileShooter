extends CharacterBody2D

signal enemy_died

@export var speed = 100
@export var health = 10
@export var max_health = 10
@export var damage = 5
@export var defense = 0.0 # 防御值，减少受到的伤害百分比（0-1之间）
@export var score_value = 10
@export var attack_cooldown = 1.0 # 攻击冷却时间（秒）

var target = null
var is_alive = true
var can_attack = true # 是否可以攻击

# 流血状态变量
var is_bleeding = false
var bleed_damage = 0
var bleed_time_left = 0.0
var bleed_tick_timer = 0.0
var bleed_tick_interval = 1.0 # 每秒伤害一次

# BOSS特殊效果
var can_speed_burst = false # 是否可以短暂加速
var can_slow_area = false # 是否可以范围减速
var speed_burst_cooldown = 5.0 # 加速冷却时间
var slow_area_cooldown = 8.0 # 减速冷却时间
var speed_burst_duration = 2.0 # 加速持续时间
var slow_area_duration = 3.0 # 减速持续时间
var speed_burst_multiplier = 2.0 # 加速倍率
var slow_area_radius = 200.0 # 减速范围半径
var slow_area_factor = 0.5 # 减速因子

func _ready():
	# 将敌人添加到enemy组，以便玩家可以找到它们
	add_to_group("enemy")
	
	# 随机旋转敌人精灵，增加视觉多样性
	$Sprite2D.rotation = randf_range(0, 2 * PI)
	
	# 初始化血条
	update_health_bar()
	
	# 创建流血效果图标（默认隐藏）
	create_bleed_icon()
	
	# 如果是BOSS，设置特殊效果
	if "is_boss" in self and self.is_boss:
		setup_boss_effects()
		
# 创建流血效果图标
func create_bleed_icon():
	# 检查是否已经存在
	if has_node("BleedIcon"):
		return
		
	var bleed_icon = Sprite2D.new()
	bleed_icon.name = "BleedIcon"
	bleed_icon.texture = load("res://assets/sprites/blood_scratch.svg")
	bleed_icon.position = Vector2(0, 0) # 直接放在敌人身上
	bleed_icon.scale = Vector2(0.7, 0.7) # 适当调整大小
	bleed_icon.visible = false # 默认隐藏
	add_child(bleed_icon)

func _physics_process(delta):
	if not is_alive or target == null:
		return
	
	# 计算朝向玩家的方向
	var direction = (target.global_position - global_position).normalized()
	
	# 设置速度
	velocity = direction * speed
	
	# 处理流血状态
	if is_bleeding:
		bleed_tick_timer -= delta
		bleed_time_left -= delta
		
		# 每秒造成一次伤害
		if bleed_tick_timer <= 0:
			take_damage(bleed_damage, false)
			bleed_tick_timer = bleed_tick_interval
			
			# 显示流血效果，间隔性闪红
			modulate = Color(1.5, 0.3, 0.3) # 红色闪烁
			
			await get_tree().create_timer(0.1).timeout
			if is_alive:
				modulate = Color(1.0, 0.7, 0.7) # 轻微红色
		
		# 流血时间结束
		if bleed_time_left <= 0:
			stop_bleeding()
	
	# 移动敌人
	move_and_slide()
	
	# 检查是否碰到玩家
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider.is_in_group("player"):
			attack_player(collider)
	
	# BOSS特殊能力检查
	if "is_boss" in self and self.is_boss:
		check_boss_abilities()

# 攻击玩家
func attack_player(player):
	if can_attack:
		player.take_damage(damage)
		can_attack = false
		# 创建一个定时器来重置攻击冷却
		get_tree().create_timer(attack_cooldown).timeout.connect(func(): can_attack = true)

# 敌人受到伤害
func take_damage(damage_amount, show_effect = true, penetration = GameAttributes.penetration):
	print("敌人受到伤害调用: ", damage_amount, " 当前生命值: ", health)
	
	if not is_alive:
		print("敌人已死亡，不再受到伤害")
		return
	
	# 应用防御穿透和防御属性减少伤害
	var effective_defense = defense * (1.0 - penetration) # 计算有效防御值
	var actual_damage = damage_amount * (1.0 - effective_defense)
	health -= actual_damage
	print("敌人扣除伤害后生命值: ", health)
	update_health_bar()
	
	if health <= 0:
		print("敌人生命值为0，触发死亡")
		die()
	else:
		# 播放受伤动画或效果
		if show_effect:
			modulate = Color(1, 0.5, 0.5) # 变红表示受伤
			await get_tree().create_timer(0.1).timeout
			if is_alive:
				if is_bleeding:
					modulate = Color(1.0, 0.7, 0.7) # 轻微红色（流血状态）
				else:
					modulate = Color(1, 1, 1) # 恢复正常颜色

func start_bleeding(damage_per_second, duration):
	is_bleeding = true
	bleed_damage = damage_per_second
	bleed_time_left = duration
	bleed_tick_timer = 0.0 # 立即开始计时
	
	# 显示流血图标并持续存在
	if has_node("BleedIcon"):
		$BleedIcon.visible = true
	
	# 视觉效果 - 轻微红色
	$Sprite2D.modulate = Color(1.0, 0.7, 0.7)

# 停止流血效果
func stop_bleeding():
	is_bleeding = false
	bleed_damage = 0
	bleed_time_left = 0
	
	# 恢复正常颜色
	if is_alive:
		$Sprite2D.modulate = Color(1, 1, 1)
		
	# 隐藏流血图标
	if has_node("BleedIcon"):
		$BleedIcon.visible = false
		
# 更新血条显示
func update_health_bar():
	var health_bar = $HealthBar
	# 检查是否为BOSS（通过分组或缩放比例判断）
	var is_boss = is_in_group("boss") or scale.x >= 1.3 or scale.y >= 1.3

	# 获取或创建 ShieldOverlay (ColorRect)
	var shield_overlay = health_bar.get_node_or_null("ShieldOverlay")
	if not shield_overlay:
		shield_overlay = ColorRect.new()
		shield_overlay.name = "ShieldOverlay"
		health_bar.add_child(shield_overlay)
		# 设置为填充父级区域，以便通过 offset_right 控制宽度
		shield_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shield_overlay.color = get_shield_style_box().bg_color # 设置护盾颜色
		shield_overlay.visible = false # 初始隐藏

	# 计算护盾量（超出最大生命值的部分）
	var shield_amount = max(0, health - max_health)

	if is_boss and shield_amount > 0:
		# BOSS 有护盾。显示基础血量为满，护盾作为叠加层
		health_bar.max_value = max_health # 基础血量容量
		health_bar.value = max_health # 基础血条显示为满（绿色）
		health_bar.add_theme_stylebox_override("fill", get_health_style_box()) # 确保基础血条是绿色

		shield_overlay.visible = true
		# 计算护盾宽度，相对于 health_bar 的宽度
		# 护盾的视觉宽度上限也为 health_bar 的宽度 (例如，如果护盾量也达到 max_health，则完全覆盖)
		var shield_fill_ratio = float(min(shield_amount, max_health)) / max_health
		
		# 通过 offset_right 控制 ColorRect 的宽度
		shield_overlay.offset_right = health_bar.get_rect().size.x * shield_fill_ratio
		shield_overlay.offset_left = 0 # 从左侧开始填充

		# 更新血量标签，显示基础血量 + 护盾
		_create_or_update_health_label(health_bar, str(int(max_health)) + " + 护盾: " + str(int(shield_amount)), true)
	else:
		# 无护盾，或不是BOSS，显示正常血量
		health_bar.max_value = max_health
		health_bar.value = health
		health_bar.add_theme_stylebox_override("fill", get_health_style_box()) # 确保是绿色

		shield_overlay.visible = false # 隐藏护盾层

		# 根据是否是BOSS更新标签
		var label_text
		if is_boss: # 对于没有护盾的 BOSS，显示正常血量 (例如 50/100)
			label_text = str(int(health)) + "/" + str(int(max_health))
		else: # 普通敌人
			var health_percent = (float(health) / max_health) * 100
			label_text = str(int(health_percent)) + "%"
		_create_or_update_health_label(health_bar, label_text, is_boss)


# 返回一个 StyleBoxFlat，用于默认血条颜色 (绿色)
func get_health_style_box() -> StyleBoxFlat:
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.8, 0.2, 1) # 绿色
	style_box.border_width_left = 1
	style_box.border_width_top = 1
	style_box.border_width_right = 1
	style_box.border_width_bottom = 1
	style_box.border_color = Color(0.1, 0.4, 0.1, 1)
	style_box.corner_radius_top_left = 2
	style_box.corner_radius_top_right = 2
	style_box.corner_radius_bottom_left = 2
	style_box.corner_radius_bottom_right = 2
	return style_box

# 返回一个 StyleBoxFlat，用于护盾条颜色 (浅蓝色)
func get_shield_style_box() -> StyleBoxFlat:
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.2, 1.0, 1) # 浅蓝色
	style_box.border_width_left = 1
	style_box.border_width_top = 1
	style_box.border_width_right = 1
	style_box.border_width_bottom = 1
	style_box.border_color = Color(0.1, 0.1, 0.5, 1)
	style_box.corner_radius_top_left = 2
	style_box.corner_radius_top_right = 2
	style_box.corner_radius_bottom_left = 2
	style_box.corner_radius_bottom_right = 2
	return style_box

# 辅助函数：创建或更新血量标签
func _create_or_update_health_label(health_bar: ProgressBar, text_content: String, _is_boss_label: bool):
	var label = health_bar.get_node_or_null("HealthLabel")
	if not label:
		label = Label.new()
		label.name = "HealthLabel"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(1, 1, 1)) # 白色文本
		label.add_theme_font_size_override("font_size", 12) # 设置字体大小
		health_bar.add_child(label)
	label.text = text_content

# 敌人死亡
func die():
	print("Enemy: emit_signal('enemy_died'), score_value=", score_value)
	emit_signal("enemy_died")
	
	# 检查击杀回能概率天赋
	if randf() <= GameAttributes.kill_energy_chance:
		# 触发击杀回能效果
		trigger_kill_energy()
	
	
	# 播放死亡动画
	$Sprite2D.modulate.a = 0.7 # 降低透明度
	
	# 禁用碰撞
	$CollisionShape2D.set_deferred("disabled", true)
	
	# 如果是BOSS，移除减速区域
	if "is_boss" in self and self.is_boss and has_node("SlowArea"):
		$SlowArea.queue_free()
	
	# 死亡后消失
	await get_tree().create_timer(0.5).timeout
	queue_free()

# 触发击杀回能效果
func trigger_kill_energy():
	# 恢复玩家生命值（10%最大生命值）
	var player = get_node_or_null("/root/Main/Player")
	if player and player.has_method("restore_health"):
		var heal_amount = int(player.max_health * 0.1)
		player.restore_health(heal_amount)
		print("击杀回能! 恢复生命值: ", heal_amount)
		
		# 显示回能文字效果
		show_kill_energy_text()

# 显示击杀回能文字效果
func show_kill_energy_text():
	var energy_label = Label.new()
	energy_label.text = "击杀回血"
	energy_label.add_theme_font_size_override("font_size", 16)
	energy_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.0)) # 绿色
	energy_label.global_position = global_position + Vector2(0, -30)
	get_tree().get_root().add_child(energy_label)

	var tween = get_tree().create_tween()
	tween.tween_interval(0.5) # 先停留1秒
	tween.tween_property(energy_label, "global_position", energy_label.global_position + Vector2(0, -30), 1.0)
	tween.parallel().tween_property(energy_label, "modulate", Color(0.0, 1.0, 0.0, 0), 1.0)
	tween.tween_callback(energy_label.queue_free)


# BOSS特殊效果设置
func setup_boss_effects():
	# 视觉效果 - 放大
	scale = Vector2(1.5, 1.5)
	
	# 视觉效果 - 如果是20关以上的BOSS，添加红色边框
	if "level" in self and self.level >= 20:
		var outline = Sprite2D.new()
		outline.texture = $Sprite2D.texture
		outline.position = $Sprite2D.position
		outline.scale = Vector2(1.1, 1.1) # 略大于原始精灵
		outline.modulate = Color(1, 0, 0, 0.5) # 红色半透明
		add_child(outline)
		outline.z_index = -1 # 确保在原始精灵后面
	
	# 行为效果 - 短暂加速能力（20关以上）
	if "level" in self and self.level >= 20:
		can_speed_burst = true
		get_tree().create_timer(randf_range(2.0, 5.0)).timeout.connect(activate_speed_burst)
	
	# 行为效果 - 范围减速能力（21关以上）
	if "level" in self and self.level >= 21:
		can_slow_area = true
		get_tree().create_timer(randf_range(3.0, 6.0)).timeout.connect(activate_slow_area)

# 检查BOSS特殊能力
func check_boss_abilities():
	pass # 能力激活由定时器触发

# 激活速度爆发
func activate_speed_burst():
	if not is_alive or not can_speed_burst:
		return
		
	# 保存原始速度
	var original_speed = speed
	
	# 增加速度
	speed *= speed_burst_multiplier
	
	# 视觉效果
	modulate = Color(1, 0.7, 0.2) # 橙黄色表示加速
	
	# 持续一段时间后恢复
	await get_tree().create_timer(speed_burst_duration).timeout
	
	if is_alive:
		speed = original_speed
		modulate = Color(1, 1, 1)
	
	# 冷却后再次激活
	await get_tree().create_timer(speed_burst_cooldown).timeout
	if is_alive and can_speed_burst:
		activate_speed_burst()

# 激活范围减速
func activate_slow_area():
	if not is_alive or not can_slow_area:
		return
	
	# 创建减速区域
	var slow_area = Area2D.new()
	slow_area.name = "SlowArea"
	
	var collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = slow_area_radius
	collision_shape.shape = circle_shape
	slow_area.add_child(collision_shape)
	
	# 视觉效果 - 显示减速区域
	var visual = Sprite2D.new()
	visual.scale = Vector2(slow_area_radius / 32.0, slow_area_radius / 32.0) # 假设基础纹理大小为64x64
	visual.modulate = Color(0.2, 0.2, 1.0, 0.3) # 蓝色半透明
	slow_area.add_child(visual)
	
	add_child(slow_area)
	
	# 连接信号
	slow_area.body_entered.connect(func(body):
		if body.is_in_group("player"):
			body.apply_slow_effect(slow_area_factor, slow_area_duration)
	)
	
	# 持续一段时间后移除
	await get_tree().create_timer(slow_area_duration).timeout
	if is_alive and has_node("SlowArea"):
		$SlowArea.queue_free()
	
	# 冷却后再次激活
	await get_tree().create_timer(slow_area_cooldown).timeout
	if is_alive and can_slow_area:
		activate_slow_area()
