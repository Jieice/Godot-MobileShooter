extends CanvasLayer

# 升级成本
var damage_upgrade_cost = 100
var crit_chance_upgrade_cost = 150
var multi_shot_upgrade_cost = 200
var attack_speed_upgrade_cost = 180  # 攻速升级成本
var crush_chance_upgrade_cost = 250  # 压碎性打击升级成本

# 关卡UI元素
var level_label = null
var level_progress_bar = null

func _ready():
	# 连接信号
	var game_manager = get_node("../GameManager")
	game_manager.connect("score_updated", Callable(self, "_on_score_updated"))
	game_manager.connect("game_over_triggered", Callable(self, "_on_game_over"))
	game_manager.connect("level_changed", Callable(self, "_on_level_changed"))
	
	# 连接玩家信号
	var player = get_node("../Player")
	player.connect("player_hit", Callable(self, "_on_player_hit"))
	
	# 初始化UI
	$ScoreLabel.text = "金币: 0"
	$ScoreLabel.add_theme_font_size_override("font_size", 24)
	if has_node("GameOverPanel"):
		$GameOverPanel.visible = false
	update_health_bar(player.health, player.max_health)
	
	# 创建关卡UI
	create_level_ui()
	
	# 设置定时器，每秒更新一次属性UI
	var update_timer = Timer.new()
	update_timer.wait_time = 0.5  # 每0.5秒更新一次
	update_timer.autostart = true
	update_timer.one_shot = false
	add_child(update_timer)
	update_timer.connect("timeout", Callable(self, "update_player_stats"))
	
func create_level_ui():
	# 直接使用场景中已有的关卡UI元素
	level_label = $InGameLevelInfo/InGameLevel
	level_progress_bar = $InGameLevelInfo/InGameProgress

# 获取屏幕中心点
func screen_center():
	return get_viewport().get_visible_rect().size / 2

# 更新关卡显示
func update_level_display(level_number, level_data):
	if level_label:
		# 计算大关和小关
		var major_level = ceil(float(level_number) / 5)
		var minor_level = ((level_number - 1) % 5) + 1
		level_label.text = "关卡: " + str(int(major_level)) + "-" + str(minor_level)
	
	# 重置进度条
	if level_progress_bar:
		level_progress_bar.size.x = 0
		
	# 更新场景内关卡信息
	update_in_game_level_info(level_number, level_data)
	

# 更新关卡进度
func update_level_progress(current_progress, _target_progress):
	if level_progress_bar:
		# 使用简单的百分比方式更新进度条
		var progress_percentage = min(float(current_progress) / float(max(_target_progress, 1)), 1.0)
		level_progress_bar.size.x = 300 * progress_percentage
		
		# 尝试获取level_manager并使用波次信息（如果可用）
		var level_manager = get_tree().get_nodes_in_group("level_manager")
		if level_manager.size() > 0:
			level_manager = level_manager[0]
			if level_manager and level_manager.has_method("get_current_phase"):
				var total_segments = 5  # 总共5个波次
				var segment_width = 300.0 / total_segments  # 每个波次占进度条的宽度
				
				# 安全地获取波次信息
				var current_wave = level_manager.current_wave
				var enemies_per_wave = level_manager.enemies_per_wave
				
				if enemies_per_wave > 0:  # 防止除以零
					# 计算当前波次内的进度
					var enemies_in_current_wave = current_progress - (current_wave * enemies_per_wave)
					var wave_progress = min(float(enemies_in_current_wave) / float(enemies_per_wave), 1.0)
					
					# 计算总进度条宽度：已完成的波次 + 当前波次的进度
					var progress_width = (current_wave * segment_width) + (segment_width * wave_progress)
					level_progress_bar.size.x = min(progress_width, 300.0)  # 确保不超过总宽度
					
					# 更新场景内进度条
					update_in_game_progress_bar(progress_width)

# 更新波次显示
func update_wave_display(current_wave, total_waves):
	# 小关进度显示已移除
	pass
		
# 更新场景内关卡信息
func update_in_game_level_info(level_number, level_data):
	if level_label:
		# 计算大关和小关
		var major_level = ceil(float(level_number) / 5)
		var minor_level = ((level_number - 1) % 5) + 1
		level_label.text = "关卡: " + str(int(major_level)) + "-" + str(minor_level)
		
	# 重置场景内进度条
	if level_progress_bar:
		level_progress_bar.size.x = 0
		
# 更新场景内进度条
func update_in_game_progress_bar(progress_width):
	if level_progress_bar:
		level_progress_bar.size.x = min(progress_width, 300.0)  # 确保不超过总宽度

# 当关卡变化时
func _on_level_changed(level_number):
	if level_label:
		# 计算大关和小关
		var major_level = ceil(float(level_number) / 5)
		var minor_level = ((level_number - 1) % 5) + 1
		level_label.text = "关卡: " + str(int(major_level)) + "-" + str(minor_level)
	
	# 初始化底部面板
	update_player_stats()
	
	# 连接升级按钮信号
	if has_node("BottomPanel/TabContainer/升级/UpgradeContainer/DamageUpgrade/UpgradeButton"):
		$BottomPanel/TabContainer/升级/UpgradeContainer/DamageUpgrade/UpgradeButton.connect("pressed", Callable(self, "_on_damage_upgrade_pressed"))
		$BottomPanel/TabContainer/升级/UpgradeContainer/CritUpgrade/UpgradeButton.connect("pressed", Callable(self, "_on_crit_upgrade_pressed"))
		$BottomPanel/TabContainer/升级/UpgradeContainer/MultiShotUpgrade/UpgradeButton.connect("pressed", Callable(self, "_on_multi_shot_upgrade_pressed"))
		$BottomPanel/TabContainer/升级/UpgradeContainer/AttackSpeedUpgrade/UpgradeButton.connect("pressed", Callable(self, "_on_attack_speed_upgrade_pressed"))
		
		# 添加流血和裂变按钮信号连接
		if has_node("BottomPanel/TabContainer/升级/UpgradeContainer/BleedUpgrade/UpgradeButton"):
			$BottomPanel/TabContainer/升级/UpgradeContainer/BleedUpgrade/UpgradeButton.connect("pressed", Callable(self, "_on_bleed_chance_upgrade_pressed"))
		else:
			# 创建流血升级按钮
			create_upgrade_button("BleedUpgrade", "流血几率", "200 金币", "_on_bleed_chance_upgrade_pressed")
			
		if has_node("BottomPanel/TabContainer/升级/UpgradeContainer/FissionUpgrade/UpgradeButton"):
			$BottomPanel/TabContainer/升级/UpgradeContainer/FissionUpgrade/UpgradeButton.connect("pressed", Callable(self, "_on_fission_chance_upgrade_pressed"))
		else:
			# 创建裂变升级按钮
			create_upgrade_button("FissionUpgrade", "裂变几率", "250 金币", "_on_fission_chance_upgrade_pressed")
		
		# 设置升级成本文本
		$BottomPanel/TabContainer/升级/UpgradeContainer/DamageUpgrade/Cost.text = str(damage_upgrade_cost) + " 金币"
		$BottomPanel/TabContainer/升级/UpgradeContainer/CritUpgrade/Cost.text = str(crit_chance_upgrade_cost) + " 金币"
		$BottomPanel/TabContainer/升级/UpgradeContainer/MultiShotUpgrade/Cost.text = str(multi_shot_upgrade_cost) + " 金币"
		$BottomPanel/TabContainer/升级/UpgradeContainer/AttackSpeedUpgrade/Cost.text = str(attack_speed_upgrade_cost) + " 金币"

func _on_score_updated(new_score):
	if has_node("ScoreLabel"):
		$ScoreLabel.text = "金币: " + str(new_score)
	update_upgrade_buttons_state()

func _on_game_over(final_score):
	if has_node("GameOverPanel"):
		$GameOverPanel.visible = true
		$GameOverPanel/FinalScoreLabel.text = "最终金币: " + str(final_score)

func _on_restart_button_pressed():
	var game_manager = get_node("../GameManager")
	game_manager.restart_game()
	if has_node("GameOverPanel"):
		$GameOverPanel.visible = false
	
	# 重置血条
	var player = get_node("../Player")
	update_health_bar(player.health, player.max_health)
	update_player_stats()

func _on_player_hit():
	var player = get_node("../Player")
	update_health_bar(player.health, player.max_health)

func update_health_bar(current_health, max_health):
	var health_percent = (float(current_health) / max_health) * 100
	$HealthBar.value = health_percent
	$HealthBar/HealthLabel.text = str(int(health_percent)) + "% (" + str(current_health) + "/" + str(max_health) + ")"

# 更新玩家属性面板
func update_player_stats():
	if has_node("BottomPanel/TabContainer/属性/StatsContainer"):
		# 确保StatsContainer是GridContainer
		var stats_container = $BottomPanel/TabContainer/属性/StatsContainer
		var parent = stats_container.get_parent()
		
		if not (stats_container is GridContainer):
			# 创建一个新的GridContainer
			var grid = GridContainer.new()
			grid.name = "StatsContainer"
			grid.columns = 2  # 设置为两列
			
			# 从父节点移除原容器
			parent.remove_child(stats_container)
			
			# 将原容器的所有子节点移到新的GridContainer
			for child in stats_container.get_children():
				stats_container.remove_child(child)
				grid.add_child(child)
			
			# 将新的GridContainer添加到原容器的位置
			var pos_in_parent = stats_container.get_index()
			parent.add_child(grid)
			parent.move_child(grid, pos_in_parent)
			
			# 更新引用
			stats_container = grid
		
		# 更新防御穿透属性显示
		if stats_container.has_node("PenetrationLabel"):
			stats_container.get_node("PenetrationLabel").text = "防御穿透: " + str(int(GameAttributes.penetration * 100)) + "%"
		else:
			# 如果标签不存在，创建一个新的
			var penetration_label = Label.new()
			penetration_label.name = "PenetrationLabel"
			penetration_label.text = "防御穿透: " + str(int(GameAttributes.penetration * 100)) + "%"
			stats_container.add_child(penetration_label)
		
		# 确保列数为2
		stats_container.columns = 2
		
		# 添加生命值显示
		if has_node("BottomPanel/TabContainer/属性/StatsContainer/HealthLabel"):
			var player = get_node_or_null("/root/Main/Player")
			if player:
				$BottomPanel/TabContainer/属性/StatsContainer/HealthLabel.text = "生命值: " + str(player.health) + "/" + str(player.max_health)
		else:
			# 创建生命值标签
			var health_label = Label.new()
			health_label.name = "HealthLabel"
			var player = get_node_or_null("/root/Main/Player")
			if player:
				health_label.text = "生命值: " + str(player.health) + "/" + str(player.max_health)
			else:
				health_label.text = "生命值: 0/0"
			$BottomPanel/TabContainer/属性/StatsContainer.add_child(health_label)
		
		# 只更新已存在的标签
		if has_node("BottomPanel/TabContainer/属性/StatsContainer/DamageLabel"):
			$BottomPanel/TabContainer/属性/StatsContainer/DamageLabel.text = "伤害: " + str(GameAttributes.bullet_damage)
		if has_node("BottomPanel/TabContainer/属性/StatsContainer/CritChanceLabel"):
			$BottomPanel/TabContainer/属性/StatsContainer/CritChanceLabel.text = "暴击几率: " + str(int(GameAttributes.crit_chance * 100)) + "%"
		
		if has_node("BottomPanel/TabContainer/属性/StatsContainer/DoubleChanceLabel"):
			$BottomPanel/TabContainer/属性/StatsContainer/DoubleChanceLabel.text = "双连发几率: " + str(int(GameAttributes.double_shot_chance * 100)) + "%"
		
		if has_node("BottomPanel/TabContainer/属性/StatsContainer/TripleChanceLabel"):
			$BottomPanel/TabContainer/属性/StatsContainer/TripleChanceLabel.text = "三连发几率: " + str(int(GameAttributes.triple_shot_chance * 100)) + "%"
		
		# 更新攻击速度显示
		if has_node("BottomPanel/TabContainer/属性/StatsContainer/AttackSpeedLabel"):
			$BottomPanel/TabContainer/属性/StatsContainer/AttackSpeedLabel.text = "攻击速度: " + str(snapped(GameAttributes.attack_speed, 0.1)) + "x"
		else:
			# 创建攻击速度标签
			var attack_speed_label = Label.new()
			attack_speed_label.name = "AttackSpeedLabel"
			attack_speed_label.text = "攻击速度: " + str(snapped(GameAttributes.attack_speed, 0.1)) + "x"
			$BottomPanel/TabContainer/属性/StatsContainer.add_child(attack_speed_label)
		
		# 更新压碎几率显示（如果标签存在）
		if has_node("BottomPanel/TabContainer/属性/StatsContainer/CrushChanceLabel"):
			$BottomPanel/TabContainer/属性/StatsContainer/CrushChanceLabel.text = "压碎几率: " + str(snappedf(GameAttributes.crush_chance * 100, 0.1)) + "%"
			
		# 更新撕裂伤口属性显示（如果标签存在）
		if has_node("BottomPanel/TabContainer/属性/StatsContainer/BleedChanceLabel"):
			$BottomPanel/TabContainer/属性/StatsContainer/BleedChanceLabel.text = "撕裂几率: " + str(snappedf(GameAttributes.bleed_chance * 100, 0.1)) + "%"
			
		if has_node("BottomPanel/TabContainer/属性/StatsContainer/BleedDamageLabel"):
			$BottomPanel/TabContainer/属性/StatsContainer/BleedDamageLabel.text = "流血伤害: " + str(GameAttributes.bleed_damage_per_second) + "/秒"
			
		if has_node("BottomPanel/TabContainer/属性/StatsContainer/BleedDurationLabel"):
			$BottomPanel/TabContainer/属性/StatsContainer/BleedDurationLabel.text = "流血持续: " + str(snappedf(GameAttributes.bleed_duration, 0.1)) + "秒"
			
		# 更新裂变几率显示
		if has_node("BottomPanel/TabContainer/属性/StatsContainer/FissionChanceLabel"):
			$BottomPanel/TabContainer/属性/StatsContainer/FissionChanceLabel.text = "裂变几率: " + str(snappedf(GameAttributes.fission_chance * 100, 0.1)) + "%"
			
		# 更新防御属性显示
		if has_node("BottomPanel/TabContainer/属性/StatsContainer/DefenseLabel"):
			$BottomPanel/TabContainer/属性/StatsContainer/DefenseLabel.text = "防御: " + str(snappedf(GameAttributes.defense * 100, 0.1)) + "%"
		else:
			# 创建防御标签
			var defense_label = Label.new()
			defense_label.name = "DefenseLabel"
			defense_label.text = "防御: " + str(snappedf(GameAttributes.defense * 100, 0.1)) + "%"
			$BottomPanel/TabContainer/属性/StatsContainer.add_child(defense_label)
		
		# 更新闪避率显示
		if has_node("BottomPanel/TabContainer/属性/StatsContainer/DodgeChanceLabel"):
			$BottomPanel/TabContainer/属性/StatsContainer/DodgeChanceLabel.text = "闪避率: " + str(snappedf(GameAttributes.dodge_chance * 100, 0.1)) + "%"
		else:
			# 创建闪避率标签
			var dodge_label = Label.new()
			dodge_label.name = "DodgeChanceLabel"
			dodge_label.text = "闪避率: " + str(snappedf(GameAttributes.dodge_chance * 100, 0.1)) + "%"
			$BottomPanel/TabContainer/属性/StatsContainer.add_child(dodge_label)
		
		# 更新BOSS压碎加成显示（如果标签存在）
		if has_node("BottomPanel/TabContainer/属性/StatsContainer/CrushBonusLabel"):
			$BottomPanel/TabContainer/属性/StatsContainer/CrushBonusLabel.text = "BOSS压碎加成: " + str(snappedf(GameAttributes.crush_boss_bonus * 100, 0.1)) + "%"
		
		# 添加定时更新功能
		if not has_node("UpdateTimer"):
			var update_timer = Timer.new()
			update_timer.name = "UpdateTimer"
			update_timer.wait_time = 0.5
			update_timer.autostart = true
			update_timer.one_shot = false
			add_child(update_timer)
			update_timer.timeout.connect(update_player_stats)

# 创建升级按钮
func create_upgrade_button(name, label_text, cost_text, callback_function):
	# 检查升级容器是否存在
	if not has_node("BottomPanel/TabContainer/升级/UpgradeContainer"):
		return
		
	# 创建升级按钮容器
	var upgrade_container = VBoxContainer.new()
	upgrade_container.name = name
	
	# 创建标签
	var label = Label.new()
	label.text = label_text
	upgrade_container.add_child(label)
	
	# 创建按钮
	var button = Button.new()
	button.name = "UpgradeButton"
	button.text = "升级"
	button.connect("pressed", Callable(self, callback_function))
	upgrade_container.add_child(button)
	
	# 创建成本标签
	var cost_label = Label.new()
	cost_label.name = "Cost"
	cost_label.text = cost_text
	upgrade_container.add_child(cost_label)
	
	# 添加到升级容器
	$BottomPanel/TabContainer/升级/UpgradeContainer.add_child(upgrade_container)

# 更新升级按钮状态（根据分数启用/禁用）
func update_upgrade_buttons_state():
	var game_manager = get_node("../GameManager")
	var current_score = game_manager.score
	
	if has_node("BottomPanel/TabContainer/升级/UpgradeContainer"):
		$BottomPanel/TabContainer/升级/UpgradeContainer/LeftColumn/DamageUpgrade/UpgradeButton.disabled = current_score < damage_upgrade_cost
		$BottomPanel/TabContainer/升级/UpgradeContainer/LeftColumn/CritUpgrade/UpgradeButton.disabled = current_score < crit_chance_upgrade_cost
		$BottomPanel/TabContainer/升级/UpgradeContainer/RightColumn/MultiShotUpgrade/UpgradeButton.disabled = current_score < multi_shot_upgrade_cost
		$BottomPanel/TabContainer/升级/UpgradeContainer/RightColumn/AttackSpeedUpgrade/UpgradeButton.disabled = current_score < attack_speed_upgrade_cost
		
		# 更新流血和裂变按钮状态
		if has_node("BottomPanel/TabContainer/升级/UpgradeContainer/BleedUpgrade/UpgradeButton"):
			$BottomPanel/TabContainer/升级/UpgradeContainer/BleedUpgrade/UpgradeButton.disabled = current_score < 200
		
		if has_node("BottomPanel/TabContainer/升级/UpgradeContainer/FissionUpgrade/UpgradeButton"):
			$BottomPanel/TabContainer/升级/UpgradeContainer/FissionUpgrade/UpgradeButton.disabled = current_score < 250

# 升级按钮处理函数
func _on_damage_upgrade_pressed():
	var game_manager = get_node("../GameManager")
	var player = get_node("../Player")
	
	if game_manager.score >= damage_upgrade_cost:
		game_manager.score -= damage_upgrade_cost
		player.bullet_damage += 1
		damage_upgrade_cost = int(damage_upgrade_cost * 1.5)  # 增加下一级升级成本
		
		# 更新UI
		$BottomPanel/TabContainer/升级/UpgradeContainer/LeftColumn/DamageUpgrade/Cost.text = str(damage_upgrade_cost) + " 金币"
		update_player_stats()
		_on_score_updated(game_manager.score)
		
# 流血概率升级
func _on_bleed_chance_upgrade_pressed():
	var game_manager = get_node("../GameManager")
	var player = get_node("../Player")
	var cost = 200
	
	if game_manager.score >= cost:
		game_manager.score -= cost
		player.bleed_chance += 0.05  # 增加5%流血几率
		
		# 更新UI
		update_player_stats()
		_on_score_updated(game_manager.score)
		
# 裂变概率升级
func _on_fission_chance_upgrade_pressed():
	var game_manager = get_node("../GameManager")
	var player = get_node("../Player")
	var cost = 250
	
	if game_manager.score >= cost:
		game_manager.score -= cost
		player.fission_chance += 0.05  # 增加5%裂变几率
		
		# 更新UI
		update_player_stats()
		_on_score_updated(game_manager.score)

func _on_crit_upgrade_pressed():
	var game_manager = get_node("../GameManager")
	var player = get_node("../Player")
	
	if game_manager.score >= crit_chance_upgrade_cost:
		game_manager.score -= crit_chance_upgrade_cost
		player.crit_chance += 0.05  # 增加5%暴击几率
		crit_chance_upgrade_cost = int(crit_chance_upgrade_cost * 1.5)  # 增加下一级升级成本
		
		# 更新UI
		$BottomPanel/TabContainer/升级/UpgradeContainer/LeftColumn/CritUpgrade/Cost.text = str(crit_chance_upgrade_cost) + " 金币"
		update_player_stats()
		_on_score_updated(game_manager.score)

func _on_multi_shot_upgrade_pressed():
	var game_manager = get_node("../GameManager")
	var player = get_node("../Player")
	
	if game_manager.score >= multi_shot_upgrade_cost:
		game_manager.score -= multi_shot_upgrade_cost
		player.double_shot_chance += 0.05  # 增加5%双连发几率
		player.triple_shot_chance += 0.05  # 增加5%三连发几率
		multi_shot_upgrade_cost = int(multi_shot_upgrade_cost * 1.5)  # 增加下一级升级成本
		
		# 更新UI
		$BottomPanel/TabContainer/升级/UpgradeContainer/RightColumn/MultiShotUpgrade/Cost.text = str(multi_shot_upgrade_cost) + " 金币"
		update_player_stats()
		_on_score_updated(game_manager.score)

func _on_attack_speed_upgrade_pressed():
	var game_manager = get_node("../GameManager")
	var player = get_node("../Player")
	
	if game_manager.score >= attack_speed_upgrade_cost:
		game_manager.score -= attack_speed_upgrade_cost
		# 减少冷却时间（提高攻击速度）
		player.bullet_cooldown = max(0.1, player.bullet_cooldown - 0.1)  # 最小冷却时间为0.1秒
		attack_speed_upgrade_cost = int(attack_speed_upgrade_cost * 1.5)  # 增加下一级升级成本
		
		# 更新UI
		$BottomPanel/TabContainer/升级/UpgradeContainer/RightColumn/AttackSpeedUpgrade/Cost.text = str(attack_speed_upgrade_cost) + " 金币"
		update_player_stats()
		_on_score_updated(game_manager.score)
