extends "res://scripts/weapons/weapon_base.gd"
## 十字镖 / 天堂之剑：飞向最近的敌人，减速后折返。天堂之剑可暴击（crit 参数为几率，伤害 ×2）。


func fire_one(_i: int) -> void:
	var from: Vector2 = game.player.position + Vector2(0, -8)
	var target = game.enemies.nearest(from, 260.0)
	var dir: Vector2 = (target.pos - from).normalized() if target else Vector2.from_angle(randf() * TAU)
	var p := make_proj(from, dir * float(param("proj_speed", 180)) * speed())
	p.mode = "boomerang"
	p.data = {"accel": float(param("return_accel", 380)) * speed()}
	p.spin = 16.0
	p.face_velocity = false
	p.radius = 6.0 * area()
	p.life = 3.0
	p.hit_delay = 0.25
	if param("crit", 0.0) > 0.0:
		p.on_hit = func(pp, e):
			var crit := randf() < float(param("crit"))
			game.enemies.damage(e, pp.damage * (2.0 if crit else 1.0), pp.vel.normalized(), pp.knockback, self)
	game.projectiles.add_proj(p)
	play_sfx()
