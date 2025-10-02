extends VBoxContainer

# 引用Player节点，避免重复获取
var player_node = null

func _ready():
	player_node = get_node("/root/Main/Player")
	# 连接GameAttributes的信号
	if GameAttributes.has_signal("attributes_changed") and not GameAttributes.is_connected("attributes_changed", Callable(self, "_on_game_attributes_changed")):
		GameAttributes.connect("attributes_changed", Callable(self, "_on_game_attributes_changed"))
	
	# 初始化所有属性标签
	_initialize_attribute_labels()
	
	# 首次更新显示
	update_player_stats()

# 初始化属性标签
func _initialize_attribute_labels():
	var stats_to_create = [
		{"name": "HealthLabel", "label": "生命值: "},
		{"name": "AttackSpeedLabel", "label": "攻击速度: "},
		{"name": "DefenseLabel", "label": "防御: "},
		{"name": "DodgeChanceLabel", "label": "闪避率: "},
		{"name": "PenetrationCountLabel", "label": "穿透数量: "},
		{"name": "CritChanceLabel", "label": "暴击率: "},
		{"name": "PlayerSpeedLabel", "label": "移动速度: "},
		{"name": "BulletDamageLabel", "label": "子弹伤害: "},
		{"name": "BulletCooldownLabel", "label": "子弹冷却: "},
		{"name": "PenetrationLabel", "label": "防御穿透: "},
		{"name": "AttackRangeLabel", "label": "攻击范围: "},
		{"name": "CritMultiplierLabel", "label": "暴击倍率: "},
		{"name": "DoubleShotChanceLabel", "label": "双连发几率: "},
		{"name": "TripleShotChanceLabel", "label": "三连发几率: "},
		{"name": "FissionChanceLabel", "label": "裂变几率: "}
	]
	
	for stat_info in stats_to_create:
		var existing_label = get_node_or_null(stat_info.name)
		if not existing_label:
			var new_label = Label.new()
			new_label.name = stat_info.name
			add_child(new_label)

# 当GameAttributes属性变化时更新
func _on_game_attributes_changed(attribute_name, value):
	print("AttributePanel: Game attribute changed: ", attribute_name, " to ", value)
	# 检查当前面板是否可见，如果不可见则无需立即更新，等待下次打开时刷新
	if visible:
		update_player_stats()

func update_player_stats(): # 移除player参数，直接使用player_node
	if not player_node:
		player_node = get_node("/root/Main/Player") # 尝试再次获取
		if not player_node:
			print("AttributePanel: 警告: 无法找到Player节点")
			return

	var stats = [
		{"name": "HealthLabel", "label": "生命值: ", "value": str(GameAttributes.health) + "/" + str(GameAttributes.max_health)}, # 直接从GameAttributes获取生命值
		{"name": "AttackSpeedLabel", "label": "攻击速度: ", "value": str(snapped(GameAttributes.attack_speed, 0.1)) + "x"},
		{"name": "DefenseLabel", "label": "防御: ", "value": str(snappedf(GameAttributes.defense * 100, 0.1)) + "%"},
		{"name": "DodgeChanceLabel", "label": "闪避率: ", "value": str(snappedf(GameAttributes.dodge_chance * 100, 0.1)) + "%"},
		{"name": "PenetrationCountLabel", "label": "穿透数量: ", "value": str(GameAttributes.penetration_count)},
		{"name": "CritChanceLabel", "label": "暴击率: ", "value": str(snappedf(GameAttributes.crit_chance * 100, 0.1)) + "%"},
		{"name": "PlayerSpeedLabel", "label": "移动速度: ", "value": str(snapped(GameAttributes.player_speed, 0.1))},
		{"name": "BulletDamageLabel", "label": "子弹伤害: ", "value": str(GameAttributes.bullet_damage)},
		{"name": "BulletCooldownLabel", "label": "子弹冷却: ", "value": str(snapped(GameAttributes.bullet_cooldown, 0.01)) + "s"},
		{"name": "PenetrationLabel", "label": "防御穿透: ", "value": str(snappedf(GameAttributes.penetration * 100, 0.1)) + "%"},
		{"name": "AttackRangeLabel", "label": "攻击范围: ", "value": str(snapped(GameAttributes.attack_range, 0.1)) + "x"},
		{"name": "CritMultiplierLabel", "label": "暴击倍率: ", "value": str(snapped(GameAttributes.crit_multiplier, 0.1)) + "x"},
		{"name": "DoubleShotChanceLabel", "label": "双连发几率: ", "value": str(snappedf(GameAttributes.double_shot_chance * 100, 0.1)) + "%"},
		{"name": "TripleShotChanceLabel", "label": "三连发几率: ", "value": str(snappedf(GameAttributes.triple_shot_chance * 100, 0.1)) + "%"},
		{"name": "FissionChanceLabel", "label": "裂变几率: ", "value": str(snappedf(GameAttributes.fission_chance * 100, 0.1)) + "%"}
	]
	for stat in stats:
		var label = get_node_or_null(stat.name)
		if label:
			label.text = stat["label"] + stat["value"]
		# else: # 移除动态创建标签的逻辑，因为_initialize_attribute_labels已经创建了
		#	var new_label = Label.new()
		#	new_label.name = stat.name
		#	new_label.text = stat["label"] + stat["value"]
		#	add_child(new_label)
