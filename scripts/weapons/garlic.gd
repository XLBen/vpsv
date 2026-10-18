extends "res://scripts/weapons/weapon_base.gd"
## 大蒜 / 噬魂者：角色周围的光环按冷却周期伤害范围内敌人。噬魂者每次命中回复 heal 生命。

var _aura: Node2D


func setup() -> void:
	_aura = game.vfx.quad("res://shaders/weapons/garlic.gdshader", Vector2(48, 48), def.ramp)
	_aura.z_index = -5
	game.projectiles.add_child(_aura)


func update(dt: float) -> void:
	var r := float(param("radius", 22)) * area()
	_aura.position = (game.player.position + Vector2(0, -6)).round()
	_aura.set_radius(r, fmod(game.run.time, 1.0))
	timer -= dt
	if timer > 0.0:
		return
	timer += cooldown()
	var c: Vector2 = game.player.position + Vector2(0, -6)
	var heal := float(param("heal", 0.0))
	for e in game.enemies.query(c, r + 16.0):
		if e.alive() and e.pos.distance_to(c) < r + e.radius:
			hit(e, -1.0, (e.pos - c).normalized())
			if heal > 0.0:
				game.player.hp = minf(game.stats.max_hp(), game.player.hp + heal)
	game.pickups.hit_props(c, r)


func cleanup() -> void:
	game.vfx.release(_aura)
