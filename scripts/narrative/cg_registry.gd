extends RefCounted
## CG 登记：读取 content/cg/*.tres（经由 Registry），解锁状态存于 Save.data.cg。


static func all() -> Array:
	var list: Array = Registry.all("cg")
	list.sort_custom(func(a, b): return a.order < b.order)
	return list


static func get_def(id: String) -> Resource:
	return Registry.get_def("cg", id)


static func is_unlocked(id: String) -> bool:
	return id in Save.data.cg


static func unlock(id: String) -> void:
	if not is_unlocked(id):
		Save.data.cg.append(id)
		Save.write()


## 某个 CG 第 variant 张差分的素材 id。
static func image(id: String, variant := 0) -> String:
	var d := get_def(id)
	if d == null or d.variants.is_empty():
		return id
	return d.variants[clampi(variant, 0, d.variants.size() - 1)]
