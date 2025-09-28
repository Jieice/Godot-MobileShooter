extends CharacterBody2D

signal enemy_died

@export var speed = 100
@export var health = 10
@export var max_health = 10
@export var damage = 5
@export var score_value = 10
@export var attack_cooldown = 1.0  # 攻击冷却时间（秒）

var target = null
var is_alive = true
var can_attack = true  # 是否可以攻击

func _ready():
	# 将敌人添加到enemy组，以便玩家可以找到它们
	add_to_group("enemy")
	
	# 随机旋转敌人精灵，增加视觉多样性
	$Sprite2D.rotation = randf_range(0, 2 * PI)
	
	# 初始化血条
	update_health_bar()

func _physics_process(delta):
	if not is_alive or target == null:
		return
	
	# 计算朝向玩家的方向
	var direction = (target.global_position - global_position).normalized()
	
	# 设置速度
	velocity = direction * speed
	
	# 移动敌人
	move_and_slide()
	
	# 检查是否碰到玩家
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider.is_in_group("player"):
			attack_player(collider)

# 攻击玩家
func attack_player(player):
	if can_attack:
		player.take_damage(damage)
		can_attack = false
		# 创建一个定时器来重置攻击冷却
		get_tree().create_timer(attack_cooldown).timeout.connect(func(): can_attack = true)

# 敌人受到伤害
func take_damage(damage_amount):
	if not is_alive:
		return
		
	health -= damage_amount
	update_health_bar()
	
	if health <= 0:
		die()
	else:
		# 播放受伤动画或效果
		modulate = Color(1, 0.5, 0.5)  # 变红表示受伤
		await get_tree().create_timer(0.1).timeout
		modulate = Color(1, 1, 1)  # 恢复正常颜色
		
# 更新血条显示
func update_health_bar():
	$HealthBar.value = (float(health) / max_health) * 100

# 敌人死亡
func die():
	is_alive = false
	emit_signal("enemy_died", score_value)
	
	# 播放死亡动画
	$Sprite2D.modulate.a = 0.7  # 降低透明度
	
	# 禁用碰撞
	$CollisionShape2D.set_deferred("disabled", true)
	
	# 死亡后消失
	await get_tree().create_timer(0.5).timeout
	queue_free()