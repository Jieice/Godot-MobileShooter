extends Area2D

@export var speed = 400
@export var damage = 5  # 将由玩家属性设置
@export var lifetime = 2.0
var crit_chance = 0.1  # 将由玩家属性设置
var crit_multiplier = 1.5  # 将由玩家属性设置

var direction = Vector2.RIGHT
var is_critical = false  # 是否为暴击

func _ready():
	# 设置子弹的生命周期
	var timer = get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)
	
	# 设置子弹的旋转，使其朝向移动方向
	rotation = direction.angle()
	
	# 计算是否触发暴击
	if randf() <= crit_chance:
		is_critical = true
		# 暴击时子弹变大并变色
		scale = Vector2(1.5, 1.5)
		modulate = Color(1.0, 0.5, 0.0)  # 橙色

func _process(delta):
	# 移动子弹
	position += direction * speed * delta

func _on_body_entered(body):
	# 检查碰撞的是否为敌人
	if body.is_in_group("enemy"):
		var final_damage = damage
		
		# 如果是暴击，增加伤害
		if is_critical:
			final_damage = damage * crit_multiplier
			# 显示暴击文本
			show_crit_text(body.global_position)
		
		body.take_damage(final_damage)
		queue_free()
		
# 显示暴击文本
func show_crit_text(pos):
	# 创建一个Label节点
	var crit_label = Label.new()
	crit_label.text = "暴击!"
	crit_label.add_theme_color_override("font_color", Color(1, 0, 0))  # 红色
	crit_label.add_theme_font_size_override("font_size", 24)  # 字体大小
	
	# 设置位置
	crit_label.global_position = pos + Vector2(0, -30)  # 在敌人头上方显示
	
	# 添加到场景
	get_tree().get_root().add_child(crit_label)
	
	# 创建动画效果
	var tween = get_tree().create_tween()
	tween.tween_property(crit_label, "global_position", pos + Vector2(0, -60), 0.5)  # 向上移动
	tween.parallel().tween_property(crit_label, "modulate", Color(1, 0, 0, 0), 0.5)  # 淡出
	
	# 动画完成后删除
	await tween.finished
	crit_label.queue_free()