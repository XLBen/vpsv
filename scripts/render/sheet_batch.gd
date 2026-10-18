extends MultiMeshInstance2D
## 一个序列帧素材的批量渲染器：每帧 begin() → add() × N → commit()。
## 敌人、宝石、金币、光源等大量同类对象都用它画，一次绘制调用。

const SHADER := preload("res://shaders/sprite_batch.gdshader")
const STRIDE := 12  # 2D 变换 8 个 float + 自定义数据 4 个 float

var info  # Assets.SheetInfo
var _buf := PackedFloat32Array()
var _n := 0
var _cap := 0


func setup(sheet_id: String, ramp_id := "ramp.fire") -> void:
	info = Assets.sheet(sheet_id)
	texture = info.texture
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_custom_data = true
	multimesh.mesh = _quad(info.size, info.pivot)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("grid", Vector2(info.cols, info.rows))
	mat.set_shader_parameter("dissolve_ramp", Assets.ramp(ramp_id))
	material = mat


static func _quad(size: Vector2i, pivot: Vector2i) -> ArrayMesh:
	var x0 := -float(pivot.x)
	var y0 := -float(pivot.y) - 1.0
	var x1 := x0 + size.x
	var y1 := y0 + size.y
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
	a[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	a[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m


func begin() -> void:
	_n = 0


## flags_z：闪白 0..1，冻结时 +2；flags_w：溶解 0..1，首领描边 +2。
func add(pos: Vector2, flip: bool, col: int, row: int, flags_z := 0.0, flags_w := 0.0, scale := 1.0) -> void:
	if _n >= _cap:
		_cap = maxi(32, _cap * 2)
		_buf.resize(_cap * STRIDE)
	var i := _n * STRIDE
	var p := pos.round()
	_buf[i] = -scale if flip else scale
	_buf[i + 1] = 0.0
	_buf[i + 2] = 0.0
	_buf[i + 3] = p.x
	_buf[i + 4] = 0.0
	_buf[i + 5] = scale
	_buf[i + 6] = 0.0
	_buf[i + 7] = p.y
	_buf[i + 8] = col
	_buf[i + 9] = row
	_buf[i + 10] = flags_z
	_buf[i + 11] = flags_w
	_n += 1


func commit() -> void:
	if multimesh.instance_count != _cap:
		multimesh.instance_count = _cap
	if _cap > 0:
		multimesh.buffer = _buf
	multimesh.visible_instance_count = _n


func count() -> int:
	return _n
