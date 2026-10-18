extends RefCounted
## 武器基类。子类只实现 fire()（以及需要时的 update()）描述“怎么攻击”；
## 数值查询、冷却、按数量连发、伤害统计都在这里统一处理。

const PS := preload("res://scripts/combat/projectile_system.gd")
const GLOW := "res://shaders/weapons/projectile_glow.gdshader"

var game: Node
var def: Resource
var level := 1
var timer := 0.3
var acquired_at := 0.0
var damage_done := 0.0
var kills := 0
var _lv := {}           # 当前等级累计增量
var _burst := 0
var _burst_t := 0.0


func _init(g: Node, d: Resource) -> void:
	game = g
	def = d
	acquired_at = g.run.time
	_recalc_levels()
	setup()


## 子类初始化钩子。
func setup() -> void:
	pass


func set_level(l: int) -> void:
	level = clampi(l, 1, def.max_level)
	_recalc_levels()
	on_level_changed()


func on_level_changed() -> void:
	pass


func _recalc_levels() -> void:
	_lv = {}
	for i in mini(level - 1, def.levels.size()):
		var lvl: Resource = def.levels[i]
		for f: String in ["damage", "area", "speed", "amount", "duration", "pierce", "cooldown", "knockback"]:
			_lv[f] = _lv.get(f, 0.0) + float(lvl.get(f))


# ------------------------------------------------------------ 最终数值（已叠加玩家属性）

func damage() -> float:
	return (def.damage + _lv.get("damage", 0.0)) * game.stats.get_stat("might")


func area() -> float:
	return (def.area + _lv.get("area", 0.0)) * game.stats.get_stat("area")


func speed() -> float:
	return (def.speed + _lv.get("speed", 0.0)) * game.stats.get_stat("speed")


func amount() -> int:
	return int(def.amount + _lv.get("amount", 0.0) + game.stats.get_stat("amount"))


func duration() -> float:
	return (def.duration + _lv.get("duration", 0.0)) * game.stats.get_stat("duration")


func pierce() -> int:
	return int(def.pierce + _lv.get("pierce", 0.0))


func cooldown() -> float:
	return maxf(0.05, (def.cooldown - _lv.get("cooldown", 0.0)) * game.stats.get_stat("cooldown"))


func knockback() -> float:
	return def.knockback + _lv.get("knockback", 0.0)


func param(key: String, default: Variant = null) -> Variant:
	return def.params.get(key, default)


# ------------------------------------------------------------ 主循环

## 默认行为：冷却到了就开火；amount > 1 时按 interval 依次发射（fire_one）。
func update(dt: float) -> void:
	timer -= dt
	if timer <= 0.0:
		timer += cooldown()
		fire()
	if _burst > 0:
		_burst_t -= dt
		while _burst > 0 and _burst_t <= 0.0:
			_burst -= 1
			_burst_t += def.interval
			fire_one(amount() - _burst - 1)


## 一轮攻击。默认按数量连发 fire_one(i)。
func fire() -> void:
	if def.interval <= 0.0:
		for i in amount():
			fire_one(i)
	else:
		_burst = amount()
		_burst_t = 0.0


func fire_one(_index: int) -> void:
	pass


# ------------------------------------------------------------ 工具

func hit(e: Object, dmg := -1.0, kdir := Vector2.ZERO, crit := false) -> float:
	return game.enemies.damage(e, damage() if dmg < 0.0 else dmg, kdir, knockback(), self, crit)


func record_damage(v: float) -> void:
	damage_done += v


func record_kill() -> void:
	kills += 1


func vfx_id(role: String) -> String:
	return def.vfx.get(role, "")


## 创建投射物：表现节点为武器的序列帧素材 + 武器着色器。
func make_proj(pos: Vector2, vel: Vector2, role := "projectile") -> PS.Proj:
	var p := PS.Proj.new()
	p.weapon = self
	p.pos = pos
	p.vel = vel
	p.damage = damage()
	p.pierce = pierce()
	p.knockback = knockback()
	p.radius = 4.0 * area()
	p.life = 2.0
	p.fade = def.fade_out
	var id := vfx_id(role)
	if id != "":
		var s: AnimatedSprite2D = game.vfx.sprite(id)
		# 光束类投射物用武器自己的着色器，其余用通用的投射物发光着色器
		var sh: String = def.shader if role == "beam" and def.shader != "" else GLOW
		s.material = game.vfx.material(sh, def.ramp)
		# 外观缩放与判定半径同步连续变化（不再按 0.5 取整跳档）；visual_scale 参数放大偏小的素材
		s.scale = Vector2.ONE * maxf(0.5, area()) * float(param("visual_scale", 1.0))
		p.node = s
	return p


func play_sfx() -> void:
	if def.sfx != "":
		Audio.play(def.sfx)


## 在矩形内立即命中一次，同时打碎光源（判定对怪物身体中心）。
## 需要跟随角色、有生效窗口的近战攻击用 make_strike()。
func hit_rect(r: Rect2, kdir: Vector2) -> void:
	game.debug.rect(r)
	var c := r.get_center()
	for e in game.enemies.query(c, maxf(r.size.x, r.size.y) * 0.5 + 16.0):
		if e.alive() and r.grow(e.radius).has_point(e.center()):
			hit(e, -1.0, kdir)
	game.pickups.hit_props(c, maxf(r.size.x, r.size.y) * 0.5)


## 在圆内命中（雷击、爆炸等）。
func hit_circle(c: Vector2, r: float, dmg := -1.0, kb := true) -> void:
	game.debug.circle(c, r)
	for e in game.enemies.query(c, r + 16.0):
		if e.alive() and e.center().distance_to(c) < r + e.radius:
			hit(e, dmg, (e.center() - c).normalized() if kb else Vector2.ZERO)
	game.pickups.hit_props(c, r)


## 近战判定：跟随玩家的矩形（中心相对玩家脚底 offset），在 start 秒后生效 window 秒。
func make_strike(offset: Vector2, size: Vector2, kdir: Vector2, start := 0.0, window := 0.1) -> PS.Strike:
	var s := PS.Strike.new()
	s.weapon = self
	s.follow = game.player
	s.offset = offset
	s.size = size
	s.kdir = kdir
	s.start = start
	s.window = window
	return game.projectiles.add_strike(s)


## 本武器在结算面板中显示的数据。
func summary() -> Dictionary:
	var held := maxf(1.0, game.run.time - acquired_at)
	return {"id": def.id, "name": def.name, "icon": def.icon, "level": level, "damage": damage_done, "time": held, "dps": damage_done / held, "kills": kills}


func cleanup() -> void:
	pass
