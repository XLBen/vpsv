extends Node2D
## 表现层：序列帧精灵、着色器面片、一次性特效、伤害数字、像素粒子。
## 所有素材通过 Assets 的 id 获取，所有特效着色器通过路径加载，便于美术与特效师替换。

const WHITE_SIZE := 4

var game: Node
var _white: Texture2D
var _shaders := {}
var _numbers: Array = []        # [pos, text, life, color]
var _particles: Array = []      # [pos, vel, life, max, color]
var _oneshots: Array = []       # [node, life]
var _layer_top: Node2D


class ShaderQuad:
	extends Node2D
	var size := Vector2(16, 16)
	var tex: Texture2D

	func _draw() -> void:
		draw_texture_rect(tex, Rect2(-size * 0.5, size), false)

	## 供持续区域调用：按半径缩放，并把进度传给着色器。
	func set_radius(r: float, progress := 0.0) -> void:
		var s := Vector2(r, r) * 2.0
		if s != size:
			size = s
			queue_redraw()
		if material is ShaderMaterial:
			(material as ShaderMaterial).set_shader_parameter("progress", progress)
			(material as ShaderMaterial).set_shader_parameter("px_size", size)


func setup(g: Node) -> void:
	game = g
	var img := Image.create(WHITE_SIZE, WHITE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_white = ImageTexture.create_from_image(img)
	_layer_top = Node2D.new()
	_layer_top.z_index = 50
	add_child(_layer_top)
	_layer_top.draw.connect(_draw_top)


func shader(path: String) -> Shader:
	if path == "":
		return null
	if not _shaders.has(path):
		_shaders[path] = load(path) if ResourceLoader.exists(path) else null
		if _shaders[path] == null:
			push_warning("特效着色器缺失：%s" % path)
	return _shaders[path]


## 为武器创建着色器材质：自动带上色带与像素尺寸参数。
func material(shader_path: String, ramp_id := "", params := {}) -> ShaderMaterial:
	var sh := shader(shader_path)
	if sh == null:
		return null
	var m := ShaderMaterial.new()
	m.shader = sh
	if ramp_id != "":
		m.set_shader_parameter("ramp", Assets.ramp(ramp_id))
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	return m


## 序列帧精灵（以帧中心为轴心，适合投射物旋转）。
func sprite(asset_id: String, clip := "idle", centered := true) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = Assets.sprite_frames(asset_id)
	s.centered = centered
	if not centered:
		var info = Assets.sheet(asset_id)
		s.offset = -Vector2(info.pivot) - Vector2(0, 1)
	if s.sprite_frames.has_animation(clip):
		s.play(clip)
	else:
		s.play(s.sprite_frames.get_animation_names()[0])
	return s


## 纯着色器面片（光环、火池、闪电、护盾等程序化特效）。
func quad(shader_path: String, size: Vector2, ramp_id := "", params := {}) -> ShaderQuad:
	var q := ShaderQuad.new()
	q.tex = _white
	q.size = size
	q.material = material(shader_path, ramp_id, params)
	if q.material:
		q.material.set_shader_parameter("px_size", size)
	return q


## 在世界中播放一次性特效，播完自动移除。
func one_shot(node: Node2D, pos: Vector2, life: float, parent: Node = null) -> Node2D:
	node.position = pos.round()
	(parent if parent else self).add_child(node)
	_oneshots.append([node, life, life])
	return node


func release(node: Node2D) -> void:
	if is_instance_valid(node):
		node.queue_free()


func damage_number(pos: Vector2, amount: float) -> void:
	if not Save.settings().get("damage_numbers", true) or _numbers.size() > 80:
		return
	_numbers.append([pos + Vector2(randf_range(-3, 3), 0), str(int(roundf(amount))), 0.55, Color.WHITE])


func float_text(pos: Vector2, text: String, color: Color) -> void:
	_numbers.append([pos, text, 0.9, color])


func burst(pos: Vector2, n: int, palette_key: String) -> void:
	var col := Assets.color(palette_key)
	for i in n:
		if _particles.size() > 400:
			return
		var life := randf_range(0.25, 0.6)
		_particles.append([pos, Vector2.from_angle(randf() * TAU) * randf_range(30.0, 110.0), life, life, col])


func update(dt: float) -> void:
	for n in _numbers:
		n[0].y -= 18.0 * dt
		n[2] -= dt
	_numbers = _numbers.filter(func(n): return n[2] > 0.0)
	for p in _particles:
		p[0] += p[1] * dt
		p[1] *= 0.9
		p[2] -= dt
	_particles = _particles.filter(func(p): return p[2] > 0.0)
	for o in _oneshots:
		o[1] -= dt
		var node: Node2D = o[0]
		if is_instance_valid(node) and node.material is ShaderMaterial:
			(node.material as ShaderMaterial).set_shader_parameter("progress", 1.0 - o[1] / o[2])
		if o[1] <= 0.0 and is_instance_valid(node):
			node.queue_free()
	_oneshots = _oneshots.filter(func(o): return o[1] > 0.0)
	_layer_top.queue_redraw()


func _draw_top() -> void:
	var f: Font = Assets.font
	for p in _particles:
		var c: Color = p[4]
		_layer_top.draw_rect(Rect2(p[0].round(), Vector2(1, 1) * (2.0 if p[2] > p[3] * 0.5 else 1.0)), c)
	for n in _numbers:
		var c: Color = n[3]
		c.a = clampf(n[2] / 0.2, 0.0, 1.0)
		var pos: Vector2 = (n[0] - Vector2(30, 0)).round()
		_layer_top.draw_string_outline(f, pos, n[1], HORIZONTAL_ALIGNMENT_CENTER, 60, 12, 2, Color(0.08, 0.06, 0.11, c.a))
		_layer_top.draw_string(f, pos, n[1], HORIZONTAL_ALIGNMENT_CENTER, 60, 12, c)
