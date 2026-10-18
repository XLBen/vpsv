extends Node
## 内容注册表（自动加载 Registry）：启动时扫描 res://content/<类别>/ 下的 .tres。
## 新增武器、敌人、关卡……只要放进对应目录即可，无需改代码。

const KINDS := ["weapons", "passives", "characters", "enemies", "stages", "pickups", "powerups", "cg"]

var tables := {}


func _ready() -> void:
	for kind: String in KINDS:
		tables[kind] = _scan("res://content/%s/" % kind)


func _scan(dir_path: String) -> Dictionary:
	var out := {}
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	var files := Array(dir.get_files())
	files.sort()
	for f: String in files:
		# 导出后的资源可能带 .remap 后缀
		f = f.trim_suffix(".remap")
		if not f.ends_with(".tres") and not f.ends_with(".res"):
			continue
		var r := load(dir_path + f)
		if r == null or not ("id" in r):
			push_warning("跳过无法识别的内容：%s" % (dir_path + f))
			continue
		out[r.id] = r
	return out


## 按 order 字段（若有）排序，其次按 id。
func all(kind: String) -> Array:
	var list: Array = tables.get(kind, {}).values()
	list.sort_custom(func(a, b):
		var oa: int = a.get("order") if a.get("order") != null else 0
		var ob: int = b.get("order") if b.get("order") != null else 0
		return oa < ob if oa != ob else a.id < b.id)
	return list


func get_def(kind: String, id: String) -> Resource:
	return tables.get(kind, {}).get(id)


func weapon(id: String) -> Resource:
	return get_def("weapons", id)


func passive(id: String) -> Resource:
	return get_def("passives", id)


func enemy(id: String) -> Resource:
	return get_def("enemies", id)


func stage(id: String) -> Resource:
	return get_def("stages", id)


func character(id: String) -> Resource:
	return get_def("characters", id)


func pickup(id: String) -> Resource:
	return get_def("pickups", id)
