extends "res://scripts/weapons/weapon_base.gd"
## 飞刀 / 千刃：朝最近一次移动的方向快速掷出，多把时左右错开。


func fire_one(i: int) -> void:
	var dir: Vector2 = game.player.move_dir
	var offset := Vector2(-dir.y, dir.x) * float((i % 3) - 1) * 4.0
	var p := make_proj(game.player.position + Vector2(0, -8) + offset, dir * float(param("proj_speed", 300)) * speed())
	p.life = 1.0
	game.projectiles.add_proj(p)
	play_sfx()
