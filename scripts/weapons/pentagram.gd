extends "res://scripts/weapons/weapon_base.gd"
## 五芒星 / 华美之月：消灭视野内所有非首领敌人。
## 五芒星同时抹掉视野内的宝石（与原版一致）；华美之月改为吸取全部宝石并按 xp_bonus 额外加经验。

const Layers := preload("res://scripts/render/layers.gd")


func fire() -> void:
	var view: Rect2 = game.view_rect()
	var bonus := float(param("xp_bonus", 0.0))
	game.enemies.clear_view(false)
	if bonus > 0.0:
		game.pickups.vacuum()
		game.run.xp_bonus_until = game.run.time + 3.0
		game.run.xp_bonus = bonus
	else:
		for it in game.pickups.items:
			if it.kind == "gem" and view.has_point(it.pos):
				it.dead = true
				game.pickups._gem_count -= 1
	var q: Node2D = game.vfx.quad(def.shader, view.size, def.ramp)
	Layers.put(q, Layers.SCREEN_FX)
	game.vfx.one_shot(q, view.get_center(), 0.8)
	game.flash_screen(0.4)
	play_sfx()
