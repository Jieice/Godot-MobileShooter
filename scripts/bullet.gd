extends Area2D

# 使用GameAttributes单例管理属性
@export var speed = 400
var damage = 5 # 默认值，将由GameAttributes设置
@export var lifetime = 2.0

# 子弹特有属性
var is_secondary_bullet = false # 是否为次级子弹
var fission_level = 0 # 当前分裂等级，0为原始子弹
var penetration_count = 0 # 当前穿透次数
var max_penetration = 0 # 最大穿透次数

# 在_ready中从GameAttributes获取属性
func _init():
	# 这些属性将在_ready中从GameAttributes获取
	pass

var direction = Vector2.RIGHT
var is_critical = false # 是否为暴击
var is_crush = false # 是否为压碎性打击

func _ready():
	# 从GameAttributes获取属性
	damage = GameAttributes.bullet_damage
	max_penetration = GameAttributes.penetration_count
	
	# 设置子弹的生命周期
	var timer = get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)
	
	# 设置子弹的旋转，使其朝向移动方向
	rotation = direction.angle()
	
	# 计算是否触发暴击
	if randf() <= GameAttributes.crit_chance:
		is_critical = true
		# 暴击时子弹变大并变色
		scale = Vector2(1.5, 1.5)
		modulate = Color(1.0, 0.5, 0.0) # 橙色
		damage *= GameAttributes.crit_multiplier
	
	# 压碎性打击和暴击互斥，优先判断压碎性打击
	# 注意：压碎性打击的判定会在击中敌人时进行，这里只是预设样式
	if !is_critical && randf() <= GameAttributes.crush_chance:
		is_crush = true
		# 压碎性打击时子弹变为紫色并有特殊效果
		scale = Vector2(1.3, 1.3)
		modulate = Color(0.5, 0.0, 0.8) # 紫色
		
	# 如果是次级子弹，应用特殊视觉效果
	if is_secondary_bullet:
		# 次级子弹为蓝色调
		if !is_critical && !is_crush:
			modulate = Color(0.4, 0.7, 1.0)
		
		# 如果是链式反应的子弹，添加特殊效果
		if fission_level >= 2:
			# 链式反应子弹为青色调
			if !is_critical && !is_crush:
				modulate = Color(0.0, 0.9, 0.9)

func _process(_delta):
	# 移动子弹
	position += direction * speed * _delta

func _on_body_entered(body):
	# 添加调试输出
	print("子弹碰撞到: ", body.name, " 是否为敌人: ", body.is_in_group("enemy"))
	
	# 检查碰撞的是否为敌人
	if body.is_in_group("enemy"):
		var final_damage = damage
		var is_boss = body.is_in_group("boss") or (body.scale.x >= 1.3 or body.scale.y >= 1.3)
		var _is_elite = is_boss or (body.scale.x >= 1.3 or body.scale.y >= 1.3)
		
		# 应用精英伤害MOD效果
		
		# 更新任务进度 - 击杀敌人
		if has_node("/root/QuestSystem"):
			var quest_system = get_node("/root/QuestSystem")
			quest_system.update_quest_progress("kill", 1)
		
		# 检查是否触发流血效果
		var bleed_roll = randf()
		var should_bleed = bleed_roll <= GameAttributes.bleed_chance
		
		# 如果触发流血效果，调用敌人的start_bleeding函数
		if should_bleed and body.has_method("start_bleeding"):
			body.start_bleeding(GameAttributes.bleed_damage_per_second, GameAttributes.bleed_duration)
			print("触发流血效果! 每秒伤害: ", GameAttributes.bleed_damage_per_second, " 持续时间: ", GameAttributes.bleed_duration)
		
		# 压碎性打击判定（对BOSS有额外几率）
		var boss_bonus = GameAttributes.crush_boss_bonus if is_boss else 0.0
		if is_crush or (!is_critical and randf() <= (GameAttributes.crush_chance + boss_bonus)):
			# 压碎性打击按目标当前生命值百分比造成伤害
			var percent_damage = 0.05 # 基础5%当前生命值
			if is_boss:
				percent_damage = 0.03 # BOSS降低到3%防止过强
			
			# 计算百分比伤害，最小为基础伤害值
			var crush_damage = max(damage, body.health * percent_damage)
			final_damage = crush_damage
			
			# 显示压碎性打击文本
			show_crush_text(body.global_position, body, int(crush_damage))
			is_crush = true
		# 如果是暴击，增加伤害
		elif is_critical:
			final_damage = damage * GameAttributes.crit_multiplier
			# 显示暴击文本，传递敌人对象
			show_crit_text(body.global_position, body)
			# 更新任务进度 - 暴击
			if has_node("/root/QuestSystem"):
				var quest_system = get_node("/root/QuestSystem")
				quest_system.update_quest_progress("crit", 1)
		
		print("对敌人造成伤害: ", final_damage)
		body.take_damage(final_damage)
		
		# 处理裂变效果
		if GameAttributes.is_fission_enabled and (fission_level < GameAttributes.max_fission_level):
			# 所有子弹分裂都用概率判定
			var should_fission = randf() <= GameAttributes.fission_chance
			if should_fission:
				# 使用call_deferred延迟调用create_fission_bullets，避免在物理查询刷新过程中修改物理状态
				call_deferred("create_fission_bullets", body.global_position)
				print("子弹分裂! 等级: ", fission_level, " 分裂数量: ", GameAttributes.fission_count)
		
		# 检查穿透效果
		penetration_count += 1
		
		
		if penetration_count > max_penetration:
			# 子弹击中敌人后销毁
			queue_free()
		else:
			# 穿透效果：子弹继续飞行，但伤害略微降低
			damage *= 0.9 # 每次穿透后伤害降低10%
			print("子弹穿透! 剩余穿透次数: ", max_penetration - penetration_count)
		
		# 连锁闪电效果
		if GameAttributes.chain_lightning_chance > 0 and body.is_in_group("enemy"):
			if randf() <= GameAttributes.chain_lightning_chance:
				var nearest_enemy = null
				var min_dist = INF
				for enemy in get_tree().get_nodes_in_group("enemy"):
					if enemy != body and enemy.is_alive:
						var dist = body.global_position.distance_to(enemy.global_position)
						if dist < min_dist:
							min_dist = dist
							nearest_enemy = enemy
				if nearest_enemy:
					# 用Line2D锯齿线代替SVG，准确连接两敌人
					var lightning = Line2D.new()
					lightning.width = 10
					lightning.default_color = Color(1.0, 0.95, 0.4) # 亮黄
					var start = body.global_position
					var end = nearest_enemy.global_position
					var points = []
					var segs = 8
					var phase = randf() * PI * 2 # 每次生成随机相位，模拟动画
					for i in range(segs + 1):
						var t = float(i) / segs
						var pos = start.lerp(end, t)
						var normal = (end - start).normalized().orthogonal()
						var amp = 12.0 * (1.0 - abs(t - 0.5) * 2)
						var offset = normal * sin(t * PI * segs + phase) * amp
						points.append(pos + offset)
					lightning.points = points
					lightning.z_index = 100
					# 颜色渐变
					var grad = Gradient.new()
					grad.colors = [Color(1, 1, 0.4, 0.8), Color(1, 1, 1, 0.8), Color(0.5, 0.8, 1, 0.8)]
					lightning.gradient = grad
					# 宽度曲线：两头极细，中间细
					var curve = Curve.new()
					curve.add_point(Vector2(0, 0.05))
					curve.add_point(Vector2(0.5, 0.4))
					curve.add_point(Vector2(1, 0.05))
					lightning.width_curve = curve
					# 动画：0.2秒后淡出
					var tween = get_tree().create_tween()
					tween.tween_property(lightning, "modulate:a", 0.0, 0.2)
					tween.tween_callback(lightning.queue_free)
					# 0.2秒后移除特效（保险）
					get_tree().get_root().add_child(lightning)
					# 直接同步添加Timer并autostart，去除call_deferred
					var timer = Timer.new()
					timer.wait_time = 0.2
					timer.one_shot = true
					timer.autostart = true
					timer.connect("timeout", Callable(lightning, "queue_free"))
					lightning.add_child(timer)
					# 造成弹射伤害（50%）
					if nearest_enemy.has_method("take_damage"):
						nearest_enemy.take_damage(damage * 0.5)
					# 颜色渐变
					grad = Gradient.new()
					grad.colors = [Color(1, 1, 0.4), Color(1, 1, 1), Color(0.5, 0.8, 1)]
					lightning.gradient = grad
					# 宽度曲线
					curve = Curve.new()
					curve.add_point(Vector2(0, 0.2))
					curve.add_point(Vector2(0.5, 1.0))
					curve.add_point(Vector2(1, 0.2))
					lightning.width_curve = curve

# 显示暴击文本
func show_crit_text(pos, _enemy = null):
	# 创建一个Label节点
	var crit_label = Label.new()
	crit_label.text = "暴击!"
	
	# 设置文本样式
	# 直接设置字体大小和颜色
	crit_label.add_theme_font_size_override("font_size", 16)
	crit_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0)) # 橙色
	crit_label.add_theme_constant_override("outline_size", 1)
	crit_label.add_theme_color_override("font_outline_color", Color(1, 1, 1)) # 白色描边
	
	# 设置位置
	crit_label.global_position = pos + Vector2(0, -20)
	
	# 添加到场景中
	get_tree().get_root().add_child(crit_label)
	
	# 创建动画效果
	var tween = get_tree().create_tween()
	tween.tween_property(crit_label, "global_position", crit_label.global_position + Vector2(0, -30), 1.0)
	tween.parallel().tween_property(crit_label, "modulate", Color(1.0, 0.5, 0.0, 0), 1.0)
	tween.tween_callback(crit_label.queue_free)

# 显示压碎性打击文本
func show_crush_text(pos, _enemy = null, _crush_damage = 0):
	# 创建一个RichTextLabel节点，以支持更丰富的文本效果
	var rich_text = RichTextLabel.new()
	
	# 计算百分比并格式化文本
	var percent_text = ""
	if damage > 0:
		# 计算百分比，保留1位小数
		var percent = snappedf(damage / 100.0, 0.1) if damage >= 100 else snappedf(damage, 0.1)
		percent_text = str(percent) + "%!"
	else:
		percent_text = "压碎!"
	
	# 设置文本样式
	rich_text.bbcode_enabled = true
	rich_text.fit_content = true
	rich_text.scroll_active = false
	rich_text.add_theme_font_size_override("normal_font_size", 20)
	rich_text.add_theme_color_override("default_color", Color(0.7, 0.0, 1.0)) # 鲜艳的紫色
	rich_text.add_theme_constant_override("outline_size", 2)
	rich_text.add_theme_color_override("font_outline_color", Color(1, 1, 1)) # 白色描边
	
	# 设置弯曲文本
	rich_text.text = "[center][wave amp=20 freq=5]" + percent_text + "[/wave][/center]"
	
	# 检查是否已经有暴击文本显示
	var offset_y = -40
	var crit_texts = []
	
	# 查找场景中所有可能的暴击文本
	for node in get_tree().get_root().get_children():
		if node is RichTextLabel and "暴击" in node.text and node.global_position.distance_to(pos) < 100:
			crit_texts.append(node)
			
	# 如果找到暴击文本，将压碎性打击文本显示在其上方
	if crit_texts.size() > 0:
		offset_y = -70 # 显示在暴击文本上方
	
	# 设置位置和大小
	rich_text.global_position = pos + Vector2(-50, offset_y)
	rich_text.custom_minimum_size = Vector2(100, 40)
	
	# 添加到场景中
	get_tree().get_root().add_child(rich_text)
	
	# 创建动画效果
	var crush_tween = get_tree().create_tween()
	crush_tween.tween_property(rich_text, "global_position", rich_text.global_position + Vector2(0, -30), 1.0)
	crush_tween.parallel().tween_property(rich_text, "modulate", Color(0.7, 0.0, 1.0, 0), 1.0)
	crush_tween.tween_callback(rich_text.queue_free)

# 创建分裂子弹
func create_fission_bullets(pos):
	# 计算实际分裂数量（如果范围>=2.5，则分裂数量+1）
	var actual_fission_count = GameAttributes.fission_count
	if GameAttributes.fission_range >= 2.5 and fission_level == 0:
		actual_fission_count += 1
	
	# 创建分裂子弹
	for i in range(actual_fission_count):
		# 创建子弹实例
		var bullet_scene = load("res://scenes/bullet.tscn")
		var new_bullet = bullet_scene.instantiate()
		
		# 设置子弹属性
		new_bullet.global_position = pos
		new_bullet.is_secondary_bullet = true
		new_bullet.fission_level = fission_level + 1
		new_bullet.damage = damage * GameAttributes.fission_damage_ratio
		new_bullet.scale = scale * 0.8 # 固定缩放比例
		
		# 设置随机方向（在一个圆形范围内）
		var random_angle = randf_range(0, 2 * PI)
		new_bullet.direction = Vector2(cos(random_angle), sin(random_angle))
		
		# 如果是链式反应（分裂次数>=2），则使用GameAttributes中的分裂概率
		# 不需要单独设置fission_chance，因为会使用GameAttributes.fission_chance
		
		# 添加到场景中
		get_tree().get_root().add_child(new_bullet)
		
	# 显示分裂效果文本
	show_fission_text(pos)

# 显示分裂效果文本
func show_fission_text(pos):
	# 创建一个Label节点
	var fission_label = Label.new()
	fission_label.text = "分裂!"
	
	# 设置文本样式
	fission_label.add_theme_font_size_override("font_size", 16)
	fission_label.add_theme_color_override("font_color", Color(0.0, 0.7, 1.0)) # 蓝色
	fission_label.add_theme_constant_override("outline_size", 1)
	fission_label.add_theme_color_override("font_outline_color", Color(1, 1, 1)) # 白色描边
	
	# 设置位置
	fission_label.global_position = pos + Vector2(0, -50)
	
	# 添加到场景中
	get_tree().get_root().add_child(fission_label)
	
	# 创建动画效果
	var tween = get_tree().create_tween()
	tween.tween_property(fission_label, "global_position", fission_label.global_position + Vector2(0, -20), 0.8)
	tween.parallel().tween_property(fission_label, "modulate", Color(0.0, 0.7, 1.0, 0), 0.8)
	tween.tween_callback(fission_label.queue_free)
