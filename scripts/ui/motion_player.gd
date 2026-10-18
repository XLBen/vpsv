extends Node
## 把美术工作室导出的动效曲线（GSAP / Motion / CSS / WAAPI 采样结果）应用到界面节点上。
## 曲线记录的是相对静止位置的平移、缩放、旋转（度）、不透明度；文字、数值仍由界面实时更新。
##
##   MotionPlayer.play(node, "motion.ui.card_in", 0.07 * i)   # 带交错延迟
##   MotionPlayer.apply_progress(node, "motion.ui.scroll_reveal", 0.4)   # 按进度驱动

const META_REST := "motion_rest"
const META_PLAYER := "motion_player"

var target: CanvasItem
var data := {}
var track := {}
var delay := 0.0
var t := 0.0
var loop := false
var on_done := Callable()


static func play(node: CanvasItem, motion_id: String, start_delay := 0.0, done := Callable(), looping := false) -> Node:
	stop(node)
	var data: Dictionary = Assets.motion(motion_id)
	if data.is_empty() or not data.has("tracks"):
		if done.is_valid():
			done.call()
		return null
	var mp := new()
	mp.target = node
	mp.data = data
	mp.track = data.tracks.values()[0]
	mp.delay = start_delay
	mp.loop = looping
	mp.on_done = done
	_remember_rest(node)
	_set_pivot(node, data)
	node.set_meta(META_PLAYER, mp)
	node.add_child(mp, false, Node.INTERNAL_MODE_BACK)
	mp._apply_frame(0)
	return mp


static func stop(node: CanvasItem, reset := false) -> void:
	if node.has_meta(META_PLAYER):
		var old = node.get_meta(META_PLAYER)
		if is_instance_valid(old):
			old.queue_free()
		node.remove_meta(META_PLAYER)
	if reset and node.has_meta(META_REST):
		_apply(node, node.get_meta(META_REST), 0.0, 0.0, 1.0, 1.0, 0.0, 1.0)


## 按 0..1 的进度直接取样（滚动驱动等）。
static func apply_progress(node: CanvasItem, motion_id: String, progress: float) -> void:
	var data: Dictionary = Assets.motion(motion_id)
	if data.is_empty():
		return
	_remember_rest(node)
	_set_pivot(node, data)
	var tr: Dictionary = data.tracks.values()[0]
	var n: int = tr.x.size()
	var f := clampi(roundi(clampf(progress, 0.0, 1.0) * (n - 1)), 0, n - 1)
	_apply(node, node.get_meta(META_REST), tr.x[f], tr.y[f], tr.sx[f], tr.sy[f], tr.rot[f], tr.alpha[f])


## 只取样不应用：返回第 t 秒的 {x, y, sx, sy, rot, alpha}（超出时长取最后一帧）。
## 给每帧位置由代码决定的世界内节点用（环绕的书本、伤害数字等）。曲线缺失时返回空字典。
static func sample(motion_id: String, t: float) -> Dictionary:
	var data: Dictionary = Assets.motion(motion_id)
	if data.is_empty() or not data.has("tracks"):
		return {}
	var tr: Dictionary = data.tracks.values()[0]
	var n: int = tr.x.size()
	var f := clampi(int(t * float(data.get("fps", 60))), 0, n - 1)
	return {"x": tr.x[f], "y": tr.y[f], "sx": tr.sx[f], "sy": tr.sy[f], "rot": tr.rot[f], "alpha": tr.alpha[f]}


## 曲线时长（秒）。
static func length_of(motion_id: String) -> float:
	return float(Assets.motion(motion_id).get("duration", 0)) / 1000.0


## 重新记录静止位置（布局变化后调用）。
static func reset_rest(node: CanvasItem) -> void:
	node.set_meta(META_REST, node.position)


static func _remember_rest(node: CanvasItem) -> void:
	if not node.has_meta(META_REST):
		node.set_meta(META_REST, node.position)


static func _set_pivot(node: CanvasItem, data: Dictionary) -> void:
	if node is Control:
		var pv: Array = data.targets.values()[0]
		(node as Control).pivot_offset = ((node as Control).size * Vector2(pv[0], pv[1])).round()


## 容器内的控件位置由容器管理：只应用缩放、旋转、透明度，不动位置。
static func _apply(node: CanvasItem, rest: Vector2, x: float, y: float, sx: float, sy: float, rot: float, alpha: float) -> void:
	if not (node is Control and node.get_parent() is Container):
		node.position = (rest + Vector2(x, y)).round()
	node.scale = Vector2(sx, sy)
	node.rotation = deg_to_rad(rot)
	node.modulate.a = alpha


func _apply_frame(f: int) -> void:
	var n: int = track.x.size()
	f = clampi(f, 0, n - 1)
	_apply(target, target.get_meta(META_REST), track.x[f], track.y[f], track.sx[f], track.sy[f], track.rot[f], track.alpha[f])


func _process(dt: float) -> void:
	t += dt
	var local := t - delay
	if local < 0.0:
		return
	var fps := float(data.get("fps", 60))
	var n: int = track.x.size()
	var f := int(local * fps)
	if f >= n:
		if loop:
			t = delay
			f = 0
		else:
			_apply_frame(n - 1)
			if target.get_meta(META_PLAYER, null) == self:
				target.remove_meta(META_PLAYER)
			if on_done.is_valid():
				on_done.call()
			queue_free()
			return
	_apply_frame(f)
