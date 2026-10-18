extends "res://scripts/weapons/weapon_base.gd"
## 魔杖 / 圣杖：向最近的敌人发射魔法弹。


func fire_one(_i: int) -> void:
	var from: Vector2 = game.player.position + Vector2(0, -8)
	var rng := float(param("range", 320))
	var target = game.enemies.nearest(from, rng)
	if target == null:
		return
	var spd := float(param("proj_speed", 200)) * speed()
	var p := make_proj(from, (target.center() - from).normalized() * spd)
	p.life = rng / spd
	game.projectiles.add_proj(p)
	play_sfx()
