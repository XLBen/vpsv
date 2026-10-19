extends Node2D
## 表现层：序列帧精灵、着色器面片、一次性特效、命中火花、伤害数字、像素粒子与碎屑。
## 所有素材通过 Assets 的 id 获取，所有特效着色器通过路径加载，便于美术与特效师替换。
## 手感数值（数字寿命、火花上限、碎屑数量……）在 content/feel.json。

const Layers := preload("res://scripts/render/layers.gd")
const Feel := preload("res://scripts/core/feel.gd")
const MotionPlayer := preload("res://scripts/ui/motion_player.gd")
const GLOW := "res://shaders/weapons/projectile_glow.gdshader"
const NUMBER_MOTION := "motion.fx.damage_number"
const WHITE_SIZE := 4

var game: Node
var _white: Texture2D
var _shaders := {}
var _numbers: Array = []        # [pos, text, life, max, color, key, value, crit]
var _number_of := {}            # key → 该怪最新的伤害数字（合并时直接取，不必扫描全部数字）
var _particles: Array = []      # [pos, vel, life, max, color, gravity]
var _oneshots: Array = []       # [node, life, max, follow, offset, 是否逐帧传 progress]
var _sparks := 0
var _spark_mats := {}           # 色带 id → 命中火花共用的材质（火花着色器没有逐个实例的参数）
var _gold := Color.WHITE
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
	Layers.put(_layer_top, Layers.NUMBERS)
	add_child(_layer_top)
	_layer_top.draw.connect(_draw_top)
	_gold = Assets.color("gold")


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
## follow 不为空时特效跟随该节点移动（保持出生时的相对位置），例如贴着角色的刀光。
func one_shot(node: Node2D, pos: Vector2, life: float, parent: Node = null, follow: Node2D = null) -> Node2D:
	node.position = pos.round()
	(parent if parent else self).add_child(node)
	_oneshots.append([node, life, life, follow, pos - follow.position if follow else Vector2.ZERO, true])
	return node


## 命中火花：素材 id 为空或超出同屏上限时跳过。灰阶造型按武器色带上色，朝击退方向。
func hit_spark(pos: Vector2, dir: Vector2, sprite_id: String, ramp_id: String) -> void:
	if sprite_id == "" or not Feel.v("hit_spark", true) or _sparks >= int(Feel.f("spark_cap", 48)) or not Assets.has(sprite_id):
		return
	var s := sprite(sprite_id)
	var ramp := ramp_id if ramp_id != "" else "ramp.steel"
	var m = _spark_mats.get(ramp)
	if m == null:
		m = material(GLOW, ramp, {"glow": 0.0})
		_spark_mats[ramp] = m
	s.material = m
	s.rotation = dir.angle() if dir != Vector2.ZERO else randf() * TAU
	s.flip_v = randf() < 0.5
	_sparks += 1
	one_shot(s, pos, Assets.sheet(sprite_id).clip_length("idle"))
	_oneshots.back()[5] = false      # 共用材质，且火花着色器不用 progress
	s.tree_exiting.connect(_on_spark_exit)


func _on_spark_exit() -> void:
	_sparks -= 1


func release(node: Node2D) -> void:
	if is_instance_valid(node):
		node.queue_free()


## 伤害数字。key 相同（同一只怪）且在 number_merge 秒内的多次伤害合并成一个数字。
func damage_number(key: int, pos: Vector2, amount: float, crit := false) -> void:
	if not Save.settings().get("damage_numbers", true):
		return
	var life := Feel.f("number_life", 0.6)
	var merge := Feel.f("number_merge", 0.1)
	# 同一只怪在合并窗口内至多一个数字（寿命大于窗口），所以只需看它最新的那个
	var n = _number_of.get(key)
	if n != null and n[2] > 0.0 and n[3] - n[2] < merge:
		n[6] += amount
		n[1] = str(int(roundf(n[6])))
		n[7] = n[7] or crit
		n[4] = _gold if n[7] else Color.WHITE
		return
	if _numbers.size() >= int(Feel.f("number_cap", 80)):
		return
	n = [pos + Vector2(randf_range(-3, 3), 0), str(int(roundf(amount))), life, life, _gold if crit else Color.WHITE, key, amount, crit]
	_numbers.append(n)
	_number_of[key] = n


func float_text(pos: Vector2, text: String, color: Color) -> void:
	_numbers.append([pos, text, 0.9, 0.9, color, -1, 0.0, false])


func burst(pos: Vector2, n: int, palette_key: String) -> void:
	var col := Assets.color(palette_key)
	for i in n:
		if _particles.size() > 400:
			return
		var life := randf_range(0.25, 0.6)
		_particles.append([pos, Vector2.from_angle(randf() * TAU) * randf_range(30.0, 110.0), life, life, col, 0.0])


## 死亡碎屑：向上溅起、受重力落下的本体颜色像素块。
func debris(pos: Vector2, col: Color, n: int) -> void:
	for i in n:
		if _particles.size() >= int(Feel.f("debris_cap", 300)):
			return
		var life := randf_range(0.3, 0.5)
		var v := Vector2(randf_range(-55.0, 55.0), randf_range(-90.0, -35.0))
		_particles.append([pos + Vector2(randf_range(-3, 3), randf_range(-3, 3)), v, life, life, col if i % 3 != 2 else col.darkened(0.35), 260.0])


func update(dt: float) -> void:
	# 原地压缩（不用 filter + lambda，免得每帧分配新数组、逐个调用闭包）
	var j := 0
	for n in _numbers:
		n[2] -= dt
		if n[2] > 0.0:
			_numbers[j] = n
			j += 1
		elif is_same(_number_of.get(n[5]), n):
			_number_of.erase(n[5])
	_numbers.resize(j)
	var drag := exp(-6.0 * dt)       # 与帧率无关的阻尼
	j = 0
	for p in _particles:
		p[0] += p[1] * dt
		p[1] = Vector2(p[1].x * drag, p[1].y * drag + p[5] * dt) if p[5] > 0.0 else p[1] * drag
		p[2] -= dt
		if p[2] > 0.0:
			_particles[j] = p
			j += 1
	_particles.resize(j)
	j = 0
	for o in _oneshots:
		o[1] -= dt
		var node: Node2D = o[0]
		if is_instance_valid(node) and o[3] != null and is_instance_valid(o[3]):
			node.position = ((o[3] as Node2D).position + o[4]).round()
		if o[5] and is_instance_valid(node) and node.material is ShaderMaterial:
			(node.material as ShaderMaterial).set_shader_parameter("progress", 1.0 - o[1] / o[2])
		if o[1] <= 0.0:
			if is_instance_valid(node):
				node.queue_free()
		else:
			_oneshots[j] = o
			j += 1
	_oneshots.resize(j)
	_layer_top.queue_redraw()


func _draw_top() -> void:
	var f: Font = Assets.font
	for p in _particles:
		var c: Color = p[4]
		_layer_top.draw_rect(Rect2(p[0].round(), Vector2(1, 1) * (2.0 if p[2] > p[3] * 0.5 else 1.0)), c)
	for n in _numbers:
		# 弹跳与淡出来自工作室导出的曲线 motion.fx.damage_number；刚出现的一小段时间为纯白
		var age: float = n[3] - n[2]
		var m := MotionPlayer.sample(NUMBER_MOTION, age)
		var c: Color = n[4] if age > 0.06 else Color.WHITE
		c.a = float(m.get("alpha", clampf(n[2] / 0.2, 0.0, 1.0)))
		var size := 24 if n[7] else 12
		var pos: Vector2 = (n[0] + Vector2(-30, float(m.get("y", -18.0 * age)))).round()
		_layer_top.draw_string_outline(f, pos, n[1], HORIZONTAL_ALIGNMENT_CENTER, 60, size, 2, Color(0.08, 0.06, 0.11, c.a))
		_layer_top.draw_string(f, pos, n[1], HORIZONTAL_ALIGNMENT_CENTER, 60, size, c)
