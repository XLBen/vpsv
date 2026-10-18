extends "res://scripts/weapons/weapon_base.gd"
## 火焰杖 / 地狱火：朝随机敌人的方向扇形发射火球。


func fire() -> void:
	var from: Vector2 = game.player.position + Vector2(0, -8)
	var targets: Array = game.enemies.in_view()
	var dir: Vector2 = (targets.pick_random().center() - from).normalized() if not targets.is_empty() else Vector2.from_angle(randf() * TAU)
	var n := amount()
	var spread := float(param("spread", 0.35))
	for i in n:
		var a := (i - (n - 1) * 0.5) * spread / maxf(1.0, n - 1) * 2.0 if n > 1 else 0.0
		var p := make_proj(from, dir.rotated(a) * float(param("proj_speed", 110)) * speed())
		p.radius = 5.0 * area() * float(param("visual_scale", 1.0))   # 与放大后的火球外观一致
		p.life = 3.0
		game.projectiles.add_proj(p)
	play_sfx()
