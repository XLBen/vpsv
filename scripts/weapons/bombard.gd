extends "res://scripts/weapons/weapon_base.gd"
## 白鸟 / 黑翼 / 双翼骑士：鸟绕玩家盘旋（dir 为方向），沿轨道投下炸弹。
## 双翼骑士（pair = true）同时有两只方向相反的鸟。

var _birds: Array[Node2D] = []
var _angle := 0.0


func setup() -> void:
	var ids := [vfx_id("bird")]
	if param("pair", false):
		ids.append(vfx_id("bird2"))
	for id in ids:
		var s: AnimatedSprite2D = game.vfx.sprite(id)
		s.z_index = 8
		game.projectiles.add_child(s)
		_birds.append(s)


func update(dt: float) -> void:
	_angle += dt * 1.6 * float(param("dir", 1))
	var r := float(param("radius", 70))
	for i in _birds.size():
		var a := _angle * (1.0 if i == 0 else -1.0) + i * PI
		_birds[i].position = (game.player.position + Vector2(cos(a) * r, sin(a) * r * 0.6 - 30.0)).round()
		(_birds[i] as AnimatedSprite2D).flip_h = (cos(a + 0.1) - cos(a)) * (1.0 if i == 0 else -1.0) * float(param("dir", 1)) < 0.0
	super.update(dt)


func fire_one(i: int) -> void:
	var r := float(param("radius", 70))
	var dir := float(param("dir", 1)) * (1.0 if i % 2 == 0 or not param("pair", false) else -1.0)
	var a := _angle * dir + randf_range(-0.6, 0.6)
	var at: Vector2 = game.player.position + Vector2(cos(a), sin(a)) * r * randf_range(0.6, 1.0)
	var br := float(param("blast", 14)) * area()
	hit_circle(at, br)
	var q: Node2D = game.vfx.quad(def.shader, Vector2.ONE * br * 2.0, def.ramp)
	game.vfx.one_shot(q, at, 0.4)
	play_sfx()


func cleanup() -> void:
	for b in _birds:
		game.vfx.release(b)
	_birds.clear()
