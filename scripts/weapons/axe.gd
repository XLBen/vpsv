extends "res://scripts/weapons/weapon_base.gd"
## 飞斧：向上抛出，受重力落下，旋转并穿透。


func fire_one(i: int) -> void:
	var vx := float(param("vx", 60))
	var face: float = game.player.face
	var vel := Vector2(randf_range(-vx, vx) * 0.5 + face * vx * 0.4 * (1 + i % 2), -float(param("vy", 260))) * speed()
	var p := make_proj(game.player.position + Vector2(0, -10), vel)
	p.gravity = float(param("gravity", 520)) * speed() * speed()
	p.spin = 12.0 * face
	p.face_velocity = false
	p.radius = 7.0 * area()
	p.life = 2.5
	game.projectiles.add_proj(p)
	play_sfx()
