extends RefCounted
## 玩家属性：按来源叠加修正值。最终值 = 基础值 + 各来源之和。
## 来源例如 "character"、"powerup"、"passive:spinach"、"growth"、"pickup"。

const BASE := {
	"might": 1.0,          # 伤害倍率
	"armor": 0.0,          # 每次受伤减免
	"max_hp": 100.0,       # 基础最大生命（角色加成加在这里）
	"max_hp_mul": 1.0,     # 最大生命倍率（空心之心、局外强化）
	"recovery": 0.0,       # 每秒回复
	"cooldown": 1.0,       # 冷却倍率，越小越快
	"area": 1.0,
	"speed": 1.0,          # 投射物速度倍率
	"duration": 1.0,
	"amount": 0.0,         # 额外投射物数量
	"move_speed": 1.0,
	"magnet": 1.0,         # 拾取半径倍率
	"luck": 1.0,
	"growth": 1.0,         # 经验倍率
	"greed": 1.0,          # 金币倍率
	"curse": 1.0,          # 敌人速度/生命/数量/频率倍率
	"revival": 0.0,
	"rerolls": 0.0,
	"skips": 0.0,
	"banishes": 0.0,
}

## 下限，避免叠加出不合理的数值。
const MIN := {"cooldown": 0.1, "might": 0.1, "area": 0.1, "speed": 0.1, "duration": 0.1, "move_speed": 0.1}

var _mods := {}      # source -> {stat: value}
var _cache := {}
var _dirty := true

signal changed


func set_source(source: String, values: Dictionary) -> void:
	if values.is_empty():
		_mods.erase(source)
	else:
		_mods[source] = values.duplicate()
	_dirty = true
	changed.emit()


func add_to_source(source: String, stat: String, value: float) -> void:
	var m: Dictionary = _mods.get(source, {})
	m[stat] = m.get(stat, 0.0) + value
	_mods[source] = m
	_dirty = true
	changed.emit()


func get_stat(stat: String) -> float:
	if _dirty:
		_rebuild()
	return _cache.get(stat, 0.0)


func max_hp() -> float:
	return get_stat("max_hp") * get_stat("max_hp_mul")


func _rebuild() -> void:
	_cache = BASE.duplicate()
	for source: String in _mods:
		var m: Dictionary = _mods[source]
		for stat: String in m:
			_cache[stat] = _cache.get(stat, 0.0) + float(m[stat])
	for stat: String in MIN:
		_cache[stat] = maxf(_cache[stat], MIN[stat])
	_dirty = false


## 调试 / 面板显示用：所有属性的最终值。
func snapshot() -> Dictionary:
	if _dirty:
		_rebuild()
	return _cache.duplicate()
