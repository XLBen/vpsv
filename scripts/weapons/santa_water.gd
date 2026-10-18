extends "res://scripts/weapons/weapon_base.gd"
## 圣水 / 圣泉：投出瓶子，落地形成持续伤害的圣火区域。
## 圣泉参数：grow（区域每秒扩大比例）、follow（区域向玩家移动的速度）。
## 火池贴地（ground_fx 层，在怪物之下）；落地时有一圈溅射。

const EXPLOSION := "res://shaders/weapons/explosion.gdshader"


func fire_one(_i: int) -> void:
	var from: Vector2 = game.player.position + Vector2(0, -8)
	var targets: Array = game.enemies.in_view(-40.0)
	var throw := float(param("throw_range", 90))
	var to: Vector2 = targets.pick_random().pos if not targets.is_empty() and randf() < 0.7 else from + Vector2.from_angle(randf() * TAU) * randf_range(20.0, throw)
	var flight := 0.35
	var p := make_proj(from, (to - from) / flight, "bottle")
	p.life = flight
	p.pierce = 9999
	p.damage = 0.0
	p.face_velocity = false
	p.spin = 10.0
	p.on_hit = func(_pp, _e): pass
	p.on_expire = func(pp): _splash(pp.pos)
	game.projectiles.add_proj(p)
	play_sfx()


func _splash(at: Vector2) -> void:
	var z := PS.Zone.new()
	z.weapon = self
	z.pos = at
	z.radius = float(param("radius", 18)) * area()
	z.life = duration()
	z.damage = damage()
	z.knockback = knockback()
	z.hit_delay = def.hit_delay
	z.grow = float(param("grow", 0.0))
	z.follow = float(param("follow", 0.0))
	z.node = game.vfx.quad(def.shader, Vector2.ONE * z.radius * 2.0, def.ramp)
	game.projectiles.add_zone(z, game.ground_fx)
	var ring: Node2D = game.vfx.quad(EXPLOSION, Vector2.ONE * z.radius * 2.4, def.ramp)
	game.vfx.one_shot(ring, at, 0.3, game.ground_fx)
	Audio.play("sfx.weapon.water_splash")
