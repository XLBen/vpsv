extends "res://scripts/weapons/weapon_base.gd"
## 大蒜 / 噬魂者：角色周围的光环按冷却周期伤害范围内敌人。噬魂者每次命中回复 heal 生命。
## 光环贴地（在怪物之下）；每次造成伤害时光环闪一下（着色器 pulse）。

const Layers := preload("res://scripts/render/layers.gd")

var _aura: Node2D
var _pulse := 0.0


func setup() -> void:
	_aura = game.vfx.quad("res://shaders/weapons/garlic.gdshader", Vector2(48, 48), def.ramp)
	game.ground_fx.add_child(_aura)


func update(dt: float) -> void:
	var r := float(param("radius", 22)) * area()
	var c: Vector2 = game.player.position + Vector2(0, -6)
	_aura.position = c.round()
	_aura.set_radius(r, fmod(game.run.time, 1.0))
	_pulse = maxf(0.0, _pulse - dt * 5.0)
	if _aura.material:
		_aura.material.set_shader_parameter("pulse", _pulse)
	timer -= dt
	if timer > 0.0:
		return
	timer += cooldown()
	var heal := float(param("heal", 0.0))
	var any := false
	for e in game.enemies.query(c, r + 16.0):
		if e.alive() and e.center().distance_to(c) < r + e.radius:
			hit(e, -1.0, (e.center() - c).normalized())
			any = true
			if heal > 0.0:
				game.player.hp = minf(game.stats.max_hp(), game.player.hp + heal)
	if any:
		_pulse = 1.0
	game.debug.circle(c, r)
	game.pickups.hit_props(c, r)


func cleanup() -> void:
	game.vfx.release(_aura)
