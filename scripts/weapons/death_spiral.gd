extends "res://scripts/weapons/weapon_base.gd"
## 死亡螺旋：一次向四周均匀射出多把斧头，沿螺线向外扩散。


func fire() -> void:
	var n := amount()
	var base := randf() * TAU
	for i in n:
		var dir := Vector2.from_angle(base + i * TAU / n)
		var p := make_proj(game.player.position + Vector2(0, -8), dir * float(param("proj_speed", 120)) * speed())
		p.mode = "spiral"
		p.data = {"turn": float(param("turn", 1.6))}
		p.spin = 14.0
		p.face_velocity = false
		p.radius = 7.0 * area()
		p.life = 2.2 * game.stats.get_stat("duration")
		game.projectiles.add_proj(p)
	play_sfx()
