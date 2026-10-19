extends "res://scripts/weapons/weapon_base.gd"
## 国王圣经 / 不洁晚祷：书本环绕角色旋转 duration 秒，再冷却 cooldown 秒。
## 持续时间极长（≥ 999）时永不停歇。书本出现 / 收起时播放工作室导出的 pop 曲线。

const MotionPlayer := preload("res://scripts/ui/motion_player.gd")
const POP_IN := "motion.fx.pop_in"
const POP_OUT := "motion.fx.pop_out"

var _active := false
var _t := 0.0
var _angle := 0.0
var _books: Array[Node2D] = []
var _leaving: Array[Node2D] = []    # 正在收起的书（继续环绕，不再造成伤害）
var _pop := 0.0                     # 出现 / 收起动画已播放的秒数
var _base_scale := 1.0


func update(dt: float) -> void:
	_t -= dt
	_pop += dt
	if _active:
		if _t <= 0.0 and duration() < 900.0:
			_set_active(false)
			_t = cooldown()
	elif _t <= 0.0:
		_set_active(true)
		_t = duration()
	_angle += float(param("spin", 3.2)) * speed() * dt
	var r := float(param("radius", 40)) * area()
	var center: Vector2 = game.player.position + Vector2(0, -8)
	if not _leaving.is_empty():
		var m := MotionPlayer.sample(POP_OUT, _pop)
		_orbit(_leaving, center, r, m)
		if _pop >= MotionPlayer.length_of(POP_OUT):
			for b in _leaving:
				game.vfx.release(b)
			_leaving.clear()
	if not _active:
		return
	var n := amount()
	if n != _books.size():
		_set_active(true, false)
	_orbit(_books, center, r, MotionPlayer.sample(POP_IN, _pop))
	var hit_r := 6.0 * area()
	for i in n:
		var bp: Vector2 = _books[i].position
		game.debug.circle(bp, hit_r, 0.02)
		for e in game.enemies.query(bp, hit_r + 16.0):
			var ec: Vector2 = e.pos + Vector2(0.0, e.hy)    # = e.center()
			if ec.distance_to(bp) < hit_r + e.radius and e.alive() and game.enemies.can_hit(e, self, def.hit_delay):
				hit(e, -1.0, (ec - center).normalized())
		game.pickups.hit_props(bp, hit_r)


func _orbit(books: Array[Node2D], center: Vector2, r: float, m: Dictionary) -> void:
	var n := books.size()
	for i in n:
		var a := _angle + i * TAU / n
		books[i].position = (center + Vector2.from_angle(a) * r).round()
		books[i].scale = Vector2.ONE * _base_scale * float(m.get("sx", 1.0))
		books[i].modulate.a = float(m.get("alpha", 1.0))


func _set_active(on: bool, animate := true) -> void:
	if animate:
		for b in _leaving:
			game.vfx.release(b)
		_leaving.clear()
		if on:
			for b in _books:
				game.vfx.release(b)
		else:
			_leaving.assign(_books)
		_pop = 0.0
	else:
		for b in _books:
			game.vfx.release(b)
	_books.clear()
	_active = on
	if not on:
		return
	var id := vfx_id("orbit")
	_base_scale = maxf(0.5, area())
	for i in amount():
		var s: AnimatedSprite2D = game.vfx.sprite(id)
		s.material = game.vfx.material(GLOW, def.ramp)
		s.scale = Vector2.ZERO
		game.projectiles.add_child(s)
		_books.append(s)
	play_sfx()


func cleanup() -> void:
	for b in _books + _leaving:
		game.vfx.release(b)
	_books.clear()
	_leaving.clear()
