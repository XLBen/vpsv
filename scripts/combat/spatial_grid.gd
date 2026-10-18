extends RefCounted
## 均匀网格空间索引，用于范围查询（碰撞、分离、索敌）。

var cell := 32.0
var cells := {}


func _init(cell_size := 32.0) -> void:
	cell = cell_size


func clear() -> void:
	cells.clear()


func insert(o: Object, p: Vector2) -> void:
	var k := Vector2i(floori(p.x / cell), floori(p.y / cell))
	var a = cells.get(k)
	if a == null:
		cells[k] = [o]
	else:
		a.append(o)


## 返回中心落在以 p 为中心、边长 2r 的正方形覆盖到的格子里的对象（调用方再做精确判定）。
func query(p: Vector2, r: float) -> Array:
	var out := []
	for cx in range(floori((p.x - r) / cell), floori((p.x + r) / cell) + 1):
		for cy in range(floori((p.y - r) / cell), floori((p.y + r) / cell) + 1):
			var a = cells.get(Vector2i(cx, cy))
			if a != null:
				out.append_array(a)
	return out
