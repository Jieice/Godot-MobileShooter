extends CanvasLayer

# 升级成本
var damage_upgrade_cost = 100
var crit_chance_upgrade_cost = 150
var multi_shot_upgrade_cost = 200
var attack_speed_upgrade_cost = 180  # 攻速升级成本

func _ready():
	# 连接信号
	var game_manager = get_node("../GameManager")
	game_manager.connect("score_updated", Callable(self, "_on_score_updated"))
	game_manager.connect("game_over_triggered", Callable(self, "_on_game_over"))
	
	# 连接玩家信号
	var player = get_node("../Player")
	player.connect("player_hit", Callable(self, "_on_player_hit"))
	
	# 初始化UI
	$ScoreLabel.text = "金币: 0"
	$ScoreLabel.position = Vector2(130, 30)
	$ScoreLabel.add_theme_font_size_override("font_size", 24)
	if has_node("GameOverPanel"):
		$GameOverPanel.visible = false
	update_health_bar(player.health, player.max_health)
	
	# 创建玩家头像
	var avatar = ColorRect.new()
	avatar.name = "PlayerAvatar"
	avatar.size = Vector2(60, 60)
	avatar.position = Vector2(20, 20)
	avatar.color = Color(0.2, 0.6, 1.0) # 蓝色头像
	add_child(avatar)
	
	# 创建头像边框
	var avatar_border = ColorRect.new()
	avatar_border.name = "AvatarBorder"
	avatar_border.size = Vector2(64, 64)
	avatar_border.position = Vector2(18, 18)
	avatar_border.color = Color(0.9, 0.9, 0.9)
	avatar_border.z_index = -1
	add_child(avatar_border)
	
	# 创建金币图标
	var coin_icon = ColorRect.new()
	coin_icon.name = "CoinIcon"
	coin_icon.size = Vector2(36, 36)
	coin_icon.position = Vector2(avatar.position.x + avatar.size.x + 10, 30)
	coin_icon.color = Color(1, 0.84, 0) # 金色
	coin_icon.set_meta("is_coin", true)
	add_child(coin_icon)
	
	# 创建钻石图标
	var diamond_icon = ColorRect.new()
	diamond_icon.name = "DiamondIcon"
	diamond_icon.size = Vector2(36, 36)
	diamond_icon.position = Vector2(coin_icon.position.x + 150, 30)
	diamond_icon.color = Color(0.3, 0.7, 0.9) # 蓝色钻石
	add_child(diamond_icon)
	
	# 创建钻石数量标签
	var diamond_label = Label.new()
	diamond_label.name = "DiamondLabel"
	diamond_label.text = "钻石: 0"
	diamond_label.position = Vector2(diamond_icon.position.x + 45, 30)
	diamond_label.add_theme_font_size_override("font_size", 24)
	add_child(diamond_label)
	
	# 初始化底部面板
	update_player_stats()
	
	# 连接升级按钮信号
	if has_node("BottomPanel/TabContainer/升级/UpgradeContainer/DamageUpgrade/UpgradeButton"):
		$BottomPanel/TabContainer/升级/UpgradeContainer/DamageUpgrade/UpgradeButton.connect("pressed", Callable(self, "_on_damage_upgrade_pressed"))
		$BottomPanel/TabContainer/升级/UpgradeContainer/CritUpgrade/UpgradeButton.connect("pressed", Callable(self, "_on_crit_upgrade_pressed"))
		$BottomPanel/TabContainer/升级/UpgradeContainer/MultiShotUpgrade/UpgradeButton.connect("pressed", Callable(self, "_on_multi_shot_upgrade_pressed"))
		$BottomPanel/TabContainer/升级/UpgradeContainer/AttackSpeedUpgrade/UpgradeButton.connect("pressed", Callable(self, "_on_attack_speed_upgrade_pressed"))
		
		# 设置升级成本文本
		$BottomPanel/TabContainer/升级/UpgradeContainer/DamageUpgrade/Cost.text = str(damage_upgrade_cost) + " 金币"
		$BottomPanel/TabContainer/升级/UpgradeContainer/CritUpgrade/Cost.text = str(crit_chance_upgrade_cost) + " 金币"
		$BottomPanel/TabContainer/升级/UpgradeContainer/MultiShotUpgrade/Cost.text = str(multi_shot_upgrade_cost) + " 金币"
		$BottomPanel/TabContainer/升级/UpgradeContainer/AttackSpeedUpgrade/Cost.text = str(attack_speed_upgrade_cost) + " 金币"

func _on_score_updated(new_score):
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
	$HealthBar.value = (float(current_health) / max_health) * 100
	$HealthBar/HealthLabel.text = "生命值: " + str(current_health) + "/" + str(max_health)

# 更新玩家属性面板
func update_player_stats():
	var player = get_node("../Player")
	if has_node("BottomPanel/TabContainer/属性/StatsContainer"):
		$BottomPanel/TabContainer/属性/StatsContainer/DamageLabel.text = "伤害: " + str(player.bullet_damage)
		$BottomPanel/TabContainer/属性/StatsContainer/CritChanceLabel.text = "暴击几率: " + str(int(player.crit_chance * 100)) + "%"
		$BottomPanel/TabContainer/属性/StatsContainer/CritMultiplierLabel.text = "暴击倍率: " + str(player.crit_multiplier) + "x"
		$BottomPanel/TabContainer/属性/StatsContainer/DoubleChanceLabel.text = "双连发几率: " + str(int(player.double_shot_chance * 100)) + "%"
		$BottomPanel/TabContainer/属性/StatsContainer/TripleChanceLabel.text = "三连发几率: " + str(int(player.triple_shot_chance * 100)) + "%"
		$BottomPanel/TabContainer/属性/StatsContainer/AttackSpeedLabel.text = "攻击速度: " + str(snapped(1.0 / player.bullet_cooldown, 0.1)) + "/秒"

# 更新升级按钮状态（根据分数启用/禁用）
func update_upgrade_buttons_state():
	var game_manager = get_node("../GameManager")
	var current_score = game_manager.score
	
	if has_node("BottomPanel/TabContainer/升级/UpgradeContainer"):
		$BottomPanel/TabContainer/升级/UpgradeContainer/LeftColumn/DamageUpgrade/UpgradeButton.disabled = current_score < damage_upgrade_cost
		$BottomPanel/TabContainer/升级/UpgradeContainer/LeftColumn/CritUpgrade/UpgradeButton.disabled = current_score < crit_chance_upgrade_cost
		$BottomPanel/TabContainer/升级/UpgradeContainer/RightColumn/MultiShotUpgrade/UpgradeButton.disabled = current_score < multi_shot_upgrade_cost
		$BottomPanel/TabContainer/升级/UpgradeContainer/RightColumn/AttackSpeedUpgrade/UpgradeButton.disabled = current_score < attack_speed_upgrade_cost

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