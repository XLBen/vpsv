extends RefCounted
## 均匀网格空间索引，用于范围查询（碰撞、分离、索敌）。
## 格子键为整数 (cx << 32) + cy（比 Vector2i 键构造与哈希都便宜）；
## 清空时格子数组回收到池里复用，每帧重建不再分配新数组。

var cell := 32.0
var inv := 1.0 / 32.0
var cells := {}
var pool: Array = []


func _init(cell_size := 32.0) -> void:
	cell = cell_size
	inv = 1.0 / cell_size


static func key(cx: int, cy: int) -> int:
	return (cx << 32) + cy


func clear() -> void:
	for a: Array in cells.values():
		a.clear()
		pool.append(a)
	cells.clear()


func insert(o: Object, p: Vector2) -> void:
	var k := (floori(p.x * inv) << 32) + floori(p.y * inv)
	var a = cells.get(k)
	if a == null:
		a = pool.pop_back() if not pool.is_empty() else []
		cells[k] = a
	a.append(o)


## 返回中心落在以 p 为中心、边长 2r 的正方形覆盖到的格子里的对象（调用方再做精确判定）。
func query(p: Vector2, r: float) -> Array:
	var out := []
	var y0 := floori((p.y - r) * inv)
	var y1 := floori((p.y + r) * inv)
	for cx in range(floori((p.x - r) * inv), floori((p.x + r) * inv) + 1):
		var kx := cx << 32
		for cy in range(y0, y1 + 1):
			var a = cells.get(kx + cy)
			if a != null:
				out.append_array(a)
	return out
