class_name ModResource extends Resource

enum ModifierType { ADDITIVE, PERCENTAGE }

@export var id: String = ""
@export var mod_name: String = ""
@export var description: String = ""
@export var attribute_id: String = ""
@export var modifier_type: ModifierType = ModifierType.ADDITIVE
@export var value: float = 0.0
@export var rarity: int = 0 # 示例：0 表示普通, 1 表示不常见
@export var level: int = 1 # 示例：Mod 的初始等级
