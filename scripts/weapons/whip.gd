extends "res://scripts/weapons/weapon_base.gd"
## 皮鞭 / 血泪：向面朝方向水平抽打，第二鞭打向身后，之后每鞭上移一行。
## 刀光和判定都跟随角色：判定只在刀光抽出的那几帧生效（strike_start / strike_window 参数）。
## 血泪额外参数：heal（回复量）、heal_chance（每次命中回复的几率）。


func fire_one(i: int) -> void:
	var side: float = game.player.face * (1.0 if i % 2 == 0 else -1.0)
	var ln: float = float(param("length", 70)) * area()
	var h: float = float(param("height", 18)) * area()
	var off := Vector2(side * (ln * 0.5 + 4.0), -8.0 - float(i / 2) * 10.0)
	make_strike(off, Vector2(ln, h), Vector2(side, 0), float(param("strike_start", 0.0)), float(param("strike_window", 0.12)))
	var id := vfx_id("slash")
	if id != "":
		var s: AnimatedSprite2D = game.vfx.sprite(id, "idle")
		var info = Assets.sheet(id)
		# 刀光素材按判定矩形缩放：横向铺满长度，纵向铺满高度（左右朝向靠负缩放翻转）
		s.scale = Vector2(side * ln / info.size.x, h / info.size.y)
		s.material = game.vfx.material("res://shaders/weapons/whip.gdshader", def.ramp)
		game.vfx.one_shot(s, game.player.position + off, info.clip_length("idle"), null, game.player)
	play_sfx()


func hit(e: Object, dmg := -1.0, kdir := Vector2.ZERO, crit := false) -> float:
	var dealt := super.hit(e, dmg, kdir, crit)
	if param("heal", 0) and randf() < float(param("heal_chance", 0.1)):
		game.player.heal(float(param("heal")))
	return dealt
