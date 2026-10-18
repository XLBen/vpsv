extends "res://scripts/weapons/weapon_base.gd"
## 国王圣经 / 不洁晚祷：书本环绕角色旋转 duration 秒，再冷却 cooldown 秒。
## 持续时间极长（≥ 999）时永不停歇。

var _active := false
var _t := 0.0
var _angle := 0.0
var _books: Array[Node2D] = []


func update(dt: float) -> void:
	_t -= dt
	if _active:
		if _t <= 0.0 and duration() < 900.0:
			_set_active(false)
			_t = cooldown()
	elif _t <= 0.0:
		_set_active(true)
		_t = duration()
	if not _active:
		return
	var n := amount()
	if n != _books.size():
		_set_active(true)
	_angle += float(param("spin", 3.2)) * speed() * dt
	var r := float(param("radius", 40)) * area()
	var center: Vector2 = game.player.position + Vector2(0, -8)
	var hit_r := 6.0 * area()
	for i in n:
		var a := _angle + i * TAU / n
		var bp := center + Vector2.from_angle(a) * r
		_books[i].position = bp.round()
		for e in game.enemies.query(bp, hit_r + 16.0):
			if e.alive() and e.pos.distance_to(bp) < hit_r + e.radius and game.enemies.can_hit(e, self, def.hit_delay):
				hit(e, -1.0, (e.pos - center).normalized())
		game.pickups.hit_props(bp, hit_r)


func _set_active(on: bool) -> void:
	for b in _books:
		game.vfx.release(b)
	_books.clear()
	_active = on
	if not on:
		return
	var id := vfx_id("orbit")
	for i in amount():
		var s: AnimatedSprite2D = game.vfx.sprite(id)
		s.material = game.vfx.material("res://shaders/weapons/projectile_glow.gdshader", def.ramp)
		s.scale = Vector2.ONE * snappedf(maxf(1.0, area()), 0.5)
		game.projectiles.add_child(s)
		_books.append(s)
	play_sfx()


func cleanup() -> void:
	_set_active(false)
