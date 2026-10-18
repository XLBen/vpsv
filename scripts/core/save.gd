extends Node
## 存档（自动加载 Save）：user://save.json，带版本号。
## 局外金币、强化等级、解锁、设置、图鉴、成就、CG 解锁、剧情变量都在这里。

const PATH := "user://save.json"
const VERSION := 1

var data := {}
var persist := true            ## 测试时设为 false，不写盘

signal changed


func _ready() -> void:
	load_save()


func defaults() -> Dictionary:
	return {
		"version": VERSION,
		"gold": 0,
		"powerups": {},          # id -> 等级
		"powerup_spent": 0,
		"unlocked": {"characters": [], "stages": [], "weapons": []},
		"seen": {"weapons": [], "passives": [], "enemies": [], "pickups": []},
		"achievements": [],
		"stats": {"kills": 0, "runs": 0, "best_time": {}, "best_level": {}, "gold_earned": 0},
		"settings": {"sfx": 1.0, "music": 0.7, "damage_numbers": true, "screen_shake": true, "reduce_flashing": false, "fullscreen": false},
		"cg": [],                # 已解锁的 CG id
		"read_lines": {},        # 剧本 id -> 已读行号列表（只跳过已读用）
		"flags": {},             # 剧情变量
	}


func load_save() -> void:
	data = defaults()
	if not FileAccess.file_exists(PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		_merge(data, migrate(parsed))


## 版本迁移：以后改存档结构时在这里升级旧数据。
func migrate(d: Dictionary) -> Dictionary:
	d["version"] = VERSION
	return d


func _merge(into: Dictionary, src: Dictionary) -> void:
	for k: String in src:
		if into.has(k) and into[k] is Dictionary and src[k] is Dictionary:
			_merge(into[k], src[k])
		else:
			into[k] = src[k]


func write() -> void:
	if not persist:
		changed.emit()
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
	changed.emit()


func settings() -> Dictionary:
	return data.settings


func powerup_rank(id: String) -> int:
	return int(data.powerups.get(id, 0))


func is_unlocked(kind: String, id: String) -> bool:
	return id in data.unlocked.get(kind, [])


func unlock(kind: String, id: String) -> bool:
	var list: Array = data.unlocked.get(kind, [])
	if id in list:
		return false
	list.append(id)
	data.unlocked[kind] = list
	return true


func mark_seen(kind: String, id: String) -> void:
	var list: Array = data.seen.get(kind, [])
	if not (id in list):
		list.append(id)
		data.seen[kind] = list


func flag(name: String, default: Variant = null) -> Variant:
	return data.flags.get(name, default)


func set_flag(name: String, value: Variant) -> void:
	data.flags[name] = value


## 测试用：清空到默认值（不写盘）。
func reset_memory() -> void:
	data = defaults()
