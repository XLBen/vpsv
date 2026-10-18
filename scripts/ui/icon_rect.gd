extends Control
## 序列帧图标（带 idle 光泽动画）。按整数倍放大，保持像素清晰。

var asset_id := ""
var clip := "idle"
var pixel_scale := 2
var animate := true
var _t := 0.0
var _info


func set_icon(id: String, scale := 2) -> void:
	asset_id = id
	pixel_scale = scale
	_info = Assets.sheet(id) if id != "" else null
	if _info:
		custom_minimum_size = Vector2(_info.size) * pixel_scale
		size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _process(dt: float) -> void:
	if animate and _info and _info.clip(clip).frames > 1:
		_t += dt
		queue_redraw()


func _draw() -> void:
	if _info == null:
		return
	var c: Dictionary = _info.clip(clip)
	var f: int = _info.frame_at(clip, _t) if animate else 0
	var src := Rect2(Vector2(f * _info.size.x, int(c.row) * _info.size.y), Vector2(_info.size))
	var dst_size := Vector2(_info.size) * pixel_scale
	draw_texture_rect_region(_info.texture, Rect2(((size - dst_size) * 0.5).round(), dst_size), src)
