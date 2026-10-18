extends "res://scripts/weapons/weapon_base.gd"
## 皮鞭 / 血泪：向面朝方向水平抽打，第二鞭打向身后，之后每鞭上移一行。
## 血泪额外参数：heal（回复量）、heal_chance（每次命中回复的几率）。


func fire_one(i: int) -> void:
	var p: Vector2 = game.player.position
	var side: float = game.player.face * (1.0 if i % 2 == 0 else -1.0)
	var ln: float = float(param("length", 70)) * area()
	var h: float = float(param("height", 18)) * area()
	var y := -8.0 - float(i / 2) * 10.0
	var c := p + Vector2(side * (ln * 0.5 + 4.0), y)
	hit_rect(Rect2(c - Vector2(ln, h) * 0.5, Vector2(ln, h)), Vector2(side, 0))
	var id := vfx_id("slash")
	if id != "":
		var s: AnimatedSprite2D = game.vfx.sprite(id, "idle")
		s.sprite_frames.set_animation_loop("idle", false)
		var info = Assets.sheet(id)
		s.scale = Vector2(side * ln / info.size.x, h / info.size.y * 1.6)
		s.material = game.vfx.material("res://shaders/weapons/whip.gdshader", def.ramp)
		game.vfx.one_shot(s, c, info.clip_length("idle"))
	play_sfx()


func hit(e: Object, dmg := -1.0, kdir := Vector2.ZERO) -> float:
	var dealt := super.hit(e, dmg, kdir)
	if param("heal", 0) and randf() < float(param("heal_chance", 0.1)):
		game.player.heal(float(param("heal")))
	return dealt
