extends "res://scripts/weapons/weapon_base.gd"
## 时钟长枪：射出冻结光束，每次方向顺时针转 1/12 圈；命中的敌人冻结 duration 秒。

var _step := 0


func fire_one(_i: int) -> void:
	var dir := Vector2.from_angle(-PI * 0.5 + _step * TAU / 12.0)
	_step += 1
	var p := make_proj(game.player.position + Vector2(0, -8), dir * float(param("proj_speed", 260)) * speed(), "beam")
	p.pierce = 9999
	p.life = 0.9
	p.radius = 4.0 * area()
	if p.node:
		# 光束素材只有 16×4：沿飞行方向拉长、加粗，看起来是一道射线
		p.node.scale = Vector2(3.0, 2.0) * maxf(0.5, area())
	p.on_hit = func(_pp, e):
		if not e.def.freeze_immune:
			e.freeze = maxf(e.freeze, duration())
	game.projectiles.add_proj(p)
	play_sfx()
