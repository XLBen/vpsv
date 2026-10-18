extends "res://scripts/weapons/weapon_base.gd"
## 符文追踪 / 无未来：穿透敌人，碰到屏幕边缘反弹。无未来每次反弹引发爆炸（explode 为半径）。


func fire_one(_i: int) -> void:
	var dir := Vector2.from_angle(randf() * TAU)
	var p := make_proj(game.player.position + Vector2(0, -8), dir * float(param("proj_speed", 160)) * speed())
	p.mode = "bounce"
	p.life = duration()
	p.hit_delay = def.hit_delay
	p.radius = 5.0 * area()
	var boom := float(param("explode", 0.0))
	if boom > 0.0:
		p.on_bounce = func(pp):
			hit_circle(pp.pos, boom * area())
			var q: Node2D = game.vfx.quad("res://shaders/weapons/explosion.gdshader", Vector2.ONE * boom * area() * 2.0, def.ramp)
			game.vfx.one_shot(q, pp.pos, 0.35)
	game.projectiles.add_proj(p)
	play_sfx()
