extends Node2D
## 敌人系统：生成、移动（追击 / 直线群 / 包围墙 / 首领冲锋 / 死神）、
## 分离、接触伤害、受伤与死亡，并按素材分批渲染。

const SheetBatch := preload("res://scripts/render/sheet_batch.gd")
const SpatialGrid := preload("res://scripts/combat/spatial_grid.gd")
const Feel := preload("res://scripts/core/feel.gd")

const DEATH_TIME := 0.75
const HURT_TIME := 0.15
# 行为编号（spawn 时由 behavior 字符串换算，主循环里比较整数而不是字符串）
const B_CHASE := 0
const B_SWARM := 1
const B_WALL := 2
const B_BOSS_CHARGE := 3
const B_REAPER := 4
const BEHAVIORS := {"swarm": B_SWARM, "wall": B_WALL, "boss_charge": B_BOSS_CHARGE, "reaper": B_REAPER}


class Enemy:
	var def: Resource
	var id := ""
	var uid := 0
	var sprite := ""
	var pos := Vector2.ZERO          # 脚底（排序、分离、接触伤害、贴地区域用）
	var hy := -8.0                   # 身体中心相对脚底的偏移（武器判定、火花、数字用）
	var dir := Vector2.ZERO          # 直线群 / 冲锋方向
	var hp := 1.0
	var max_hp := 1.0
	var speed := 30.0
	var damage := 5.0
	var radius := 6.0
	var xp := 1
	var kb := Vector2.ZERO
	var kb_resist := 0.0
	var flash := 0.0
	var hurt_t := 0.0
	var freeze := 0.0
	var anim_t := 0.0
	var face := 1.0
	var dying := -1.0                # >= 0：死亡动画已播放的秒数
	var dying_for := 0.75            # 死亡 / 消散动画总时长
	var dead := false                # 可以移除
	var boss := false
	var behavior := "chase"
	var bcode := 0                   # behavior 对应的 B_* 编号
	var batch: Node = null           # 渲染批次（首次渲染时缓存）
	var state := 0
	var timer := 0.0
	var life := -1.0                 # >0 时到期自动消失（直线群、花墙）
	var anchor := Vector2.ZERO       # 花墙收缩中心
	var hit_until := {}              # 伤害来源 → 可再次受击的时刻（持续型武器）

	func alive() -> bool:
		return dying < 0.0 and not dead

	## 身体中心：武器判定、瞄准、命中火花都以这里为准（画面上看到的身体在脚底上方）。
	func center() -> Vector2:
		return pos + Vector2(0.0, hy)


var game: Node
var grid := SpatialGrid.new(32.0)
var list: Array = []
var batches := {}
var freeze_all := 0.0
var _sort_t := 0.0
var _frame := 0
var _uid := 0
var _hy := {}            # 素材 id → 身体中心偏移
var _colors := {}        # 素材 id → 碎屑颜色
var reach := 0.0         # 已生成的怪里，脚底到身体中心的距离 + 半径的最大值（贴地区域查询的余量用）
var _sort_keys := PackedInt64Array()
var _sort_tmp: Array = []
# 手感参数：每局开始时读一次（feel.json 改完重开一局生效）
var _flash := 0.11
var _kb_impulse := 120.0
var _kb_max := 260.0
var _kb_decay := 14.0
var _hitstop := 0.0
var _tint_t := 0.05

signal killed(enemy: Enemy)


func setup(g: Node) -> void:
	game = g
	_flash = Feel.f("flash_white", 0.06) + Feel.f("flash_tint", 0.05)
	_tint_t = Feel.f("flash_tint", 0.05)
	_kb_impulse = Feel.f("knockback_impulse", 120.0)
	_kb_max = Feel.f("knockback_max", 260.0)
	_kb_decay = Feel.f("knockback_decay", 14.0)
	_hitstop = Feel.f("hitstop", 0.0)


func alive_count() -> int:
	var n := 0
	for e: Enemy in list:
		if e.alive():
			n += 1
	return n


func spawn(def: Resource, pos: Vector2, opts := {}) -> Enemy:
	var e := Enemy.new()
	var curse: float = game.stats.get_stat("curse")
	e.def = def
	e.id = def.id
	e.sprite = def.sprite
	e.pos = pos
	e.max_hp = (def.hp + def.hp_per_level * game.run.level) * curse
	e.hp = e.max_hp
	e.speed = def.speed * randf_range(0.92, 1.08) * (curse if not def.boss else 1.0)
	e.damage = def.damage
	e.radius = def.radius
	e.xp = def.xp
	e.kb_resist = def.knockback_resist
	e.boss = def.boss
	e.behavior = def.behavior
	e.anim_t = randf() * 2.0
	if not _hy.has(e.sprite):
		_hy[e.sprite] = -float(Assets.sheet(e.sprite).size.y) * 0.5
	e.hy = _hy[e.sprite]
	_uid += 1
	e.uid = _uid
	e.timer = randf_range(3.0, 5.0)
	for k: String in opts:
		e.set(k, opts[k])
	e.bcode = BEHAVIORS.get(e.behavior, B_CHASE)
	reach = maxf(reach, absf(e.hy) + e.radius)
	list.append(e)
	Save.mark_seen("enemies", e.id)
	return e


func update(dt: float) -> void:
	_frame += 1
	freeze_all = maxf(0.0, freeze_all - dt)
	# 按身体中心建网格（与 grid.insert(e, e.center()) 相同，内联以省去每只怪的函数调用）
	grid.clear()
	var cells: Dictionary = grid.cells
	var inv: float = grid.inv
	var pool: Array = grid.pool
	for e: Enemy in list:
		if e.dying < 0.0 and not e.dead:
			var c := e.pos + Vector2(0.0, e.hy)
			var k := (floori(c.x * inv) << 32) + floori(c.y * inv)
			var a = cells.get(k)
			if a == null:
				a = pool.pop_back() if not pool.is_empty() else []
				cells[k] = a
			a.append(e)

	var ppos: Vector2 = game.player.position
	var pr: float = game.player.radius
	var view: Rect2 = game.view_rect()
	var far := view.size.length() * 0.5 + 120.0
	var kdecay := exp(-_kb_decay * dt)
	var all_frozen := freeze_all > 0.0

	for e: Enemy in list:
		e.anim_t += dt
		if e.dying >= 0.0:
			e.dying += dt
			if e.dying >= e.dying_for:
				e.dead = true
			continue
		e.flash = maxf(0.0, e.flash - dt)
		e.hurt_t = maxf(0.0, e.hurt_t - dt)
		if e.life > 0.0:
			e.life -= dt
			if e.life <= 0.0:
				despawn(e)
				continue
		var bc := e.bcode
		var frozen: bool = (all_frozen or e.freeze > 0.0) and not e.def.freeze_immune
		e.freeze = maxf(0.0, e.freeze - dt)

		var to := ppos - e.pos
		var d := to.length()
		var dir := to / d if d > 0.001 else Vector2.ZERO
		var v := Vector2.ZERO
		if bc == B_CHASE:
			v = dir * e.speed
			# 跑太远的普通敌人重新放到玩家前方屏幕外
			if d > far and not e.boss:
				e.pos = game.spawn_ring_pos(game.player.move_dir if game.player.moving else Vector2.ZERO)
				continue
		elif bc == B_SWARM:
			v = e.dir * e.speed
			if d > far * 1.6:
				e.dead = true
				continue
		elif bc == B_WALL:
			var to_anchor := e.anchor - e.pos
			if to_anchor.length() > 48.0:
				v = to_anchor.normalized() * e.speed
		elif bc == B_BOSS_CHARGE:
			v = _boss_charge(e, dir, dt)
		else:
			v = dir * e.speed
		if frozen:
			v = Vector2.ZERO
		if absf(v.x) > 1.0:
			e.face = signf(v.x)
		e.pos += (v + e.kb) * dt
		e.kb *= kdecay

		# 分离隔帧轮流做（一半敌人一帧），推力加倍补偿，视觉上无差别
		if bc != B_WALL and bc != B_REAPER and (e.uid + _frame) % 2 == 0:
			_separate(e, 2.0, cells, inv)
		if d < e.radius + pr - 1.0 and not frozen:
			game.player.hurt(e.damage, e)

	_compact()
	_sort_t -= dt
	if _sort_t <= 0.0:
		_sort_t = 0.1
		_sort_by_y()
	_render(view.grow(48.0))


## 直接遍历身体中心所在格子周围 3×3 个格子，推开重叠的同伴（推力计算内联，省去每对怪的函数调用）。
func _separate(e: Enemy, strength: float, cells: Dictionary, inv: float) -> void:
	var c := e.pos + Vector2(0.0, e.hy)
	var cx := floori(c.x * inv)
	var cy := floori(c.y * inv)
	var er := e.radius
	var boss := e.boss
	var ep := e.pos
	for gx in range(cx - 1, cx + 2):
		var kx := gx << 32
		for gy in range(cy - 1, cy + 2):
			var bucket = cells.get(kx + gy)
			if bucket == null:
				continue
			for o: Enemy in bucket:
				if o == e:
					continue
				var diff := ep - o.pos
				var dd := diff.length_squared()
				var rr := er + o.radius
				if dd >= rr * rr:
					continue
				if dd < 0.0001:
					ep += Vector2(randf() - 0.5, randf() - 0.5)
					continue
				var dist := sqrt(dd)
				var w := minf(1.0, o.radius / rr * 0.5 * strength)
				if o.bcode == B_WALL:
					w = 1.0
				elif boss:
					w *= 0.1
				ep += diff / dist * (rr - dist) * w
	e.pos = ep


## 按脚底 y 排序（远处的先画）。键 = 量化到 1/1024 像素的 y 与当前下标拼成的整数，交给原生排序，
## 比 sort_custom + lambda 快一个数量级。y 相同时保持上一次的先后（稳定排序），重叠的同 y 怪不会来回换层。
func _sort_by_y() -> void:
	var n := list.size()
	if n < 2:
		return
	_sort_keys.resize(n)
	for i in n:
		_sort_keys[i] = (int(floorf(list[i].pos.y * 1024.0)) << 20) | i
	_sort_keys.sort()
	_sort_tmp.assign(list)
	for i in n:
		list[i] = _sort_tmp[_sort_keys[i] & 0xFFFFF]
	_sort_tmp.clear()


func _boss_charge(e: Enemy, dir: Vector2, dt: float) -> Vector2:
	e.timer -= dt
	match e.state:
		0:
			if e.timer <= 0.0:
				e.state = 1
				e.timer = 0.8
				e.dir = dir
			return dir * e.speed
		1:
			if e.timer <= 0.0:
				e.state = 2
				e.timer = 0.55
				Audio.play("sfx.enemy.dash")
			return Vector2.ZERO
		_:
			if e.timer <= 0.0:
				e.state = 0
				e.timer = randf_range(3.0, 5.0)
			return e.dir * e.speed * 4.0


## 对敌人造成伤害；source 为造成伤害的武器（统计、命中火花与音效用，可为 null）。返回实际伤害。
func damage(e: Enemy, amount: float, kdir := Vector2.ZERO, kb := 0.0, source: Object = null, crit := false) -> float:
	if not e.alive() or (e.behavior == "reaper" and amount < 1e6):
		return 0.0
	var dealt := minf(amount, e.hp)
	e.hp -= amount
	e.flash = _flash
	e.hurt_t = HURT_TIME
	if kb > 0.0 and not e.boss:
		e.kb = (e.kb + kdir * kb * _kb_impulse * (1.0 - e.kb_resist)).limit_length(_kb_max)
	game.vfx.damage_number(e.uid, e.pos + Vector2(0, e.hy * 2.0 - 2.0), amount, crit)
	var wdef: Resource = source.def if source != null and source.get("def") is Resource else null
	if wdef != null:
		game.vfx.hit_spark(e.center() - kdir * e.radius * 0.5, kdir, wdef.hit_fx, wdef.ramp)
		if wdef.hit_shake > 0.0:
			game.camera_shake(wdef.hit_shake)
			game.hitstop(_hitstop)
	Audio.play(wdef.hit_sfx if wdef != null and wdef.hit_sfx != "" else "sfx.enemy.hit")
	# 统计按命中伤害计（与伤害数字一致，原版结算也如此）
	if source != null and source.has_method("record_damage"):
		source.record_damage(amount)
	if e.hp <= 0.0:
		kill(e, source)
	return dealt


## 持续型伤害的受击间隔：同一来源在 delay 秒内只能命中一次。
func can_hit(e: Enemy, key: Object, delay: float) -> bool:
	var t: float = game.run.time
	if t < float(e.hit_until.get(key, -1.0)):
		return false
	e.hit_until[key] = t + delay
	return true


func kill(e: Enemy, source: Object = null) -> void:
	if not e.alive():
		return
	e.dying = 0.0
	e.hp = 0.0
	game.run.kills += 1
	if source != null and source.has_method("record_kill"):
		source.record_kill()
	if e.xp > 0:
		game.pickups.drop_xp(e.pos, e.xp)
	if e.def.chest:
		game.pickups.drop_chest(e.pos, e.def)
	if e.boss:
		game.vfx.burst(e.center(), 24, "red")
		game.camera_shake(6.0)
		Audio.play("sfx.enemy.boss_down")
	else:
		game.vfx.debris(e.center(), _debris_color(e.sprite), int(Feel.f("debris", 5)))
		Audio.play("sfx.enemy.die")
	killed.emit(e)


## 到期消失（蝙蝠群、花墙）：播放消散动画，不掉经验、不计击杀。
func despawn(e: Enemy) -> void:
	if not e.alive():
		return
	e.dying = 0.0
	e.dying_for = Feel.f("despawn_time", 0.3)


## 死亡碎屑的颜色：取素材第一帧里最常见的不透明颜色（每种素材只算一次）。
func _debris_color(sprite: String) -> Color:
	if _colors.has(sprite):
		return _colors[sprite]
	var info = Assets.sheet(sprite)
	var col := Color(0.9, 0.85, 0.8)
	var img: Image = info.texture.get_image() if info.texture else null
	if img != null:
		if img.is_compressed():
			img.decompress()
		var counts := {}
		for y in info.size.y:
			for x in info.size.x:
				var c := img.get_pixel(x, y)
				if c.a > 0.5 and c.get_luminance() > 0.12:
					counts[c] = counts.get(c, 0) + 1
		var best := 0
		for c in counts:
			if counts[c] > best:
				best = counts[c]
				col = c
	_colors[sprite] = col
	return col


## 清屏（念珠 / 五芒星）。返回清掉的数量。
func clear_view(include_boss := false) -> int:
	var view: Rect2 = game.view_rect()
	var n := 0
	for e: Enemy in list:
		if e.alive() and view.has_point(e.center()) and (include_boss or not e.boss) and e.behavior != "reaper":
			kill(e)
			n += 1
	return n


func query(p: Vector2, r: float) -> Array:
	return grid.query(p, r)


func nearest(p: Vector2, max_d: float, exclude: Array = []) -> Enemy:
	var best: Enemy = null
	var bd := max_d * max_d
	var ex := not exclude.is_empty()
	# alive() / center() 内联；排除表只在距离够近时才查（大多数调用没有排除表）
	for e: Enemy in list:
		if e.dying >= 0.0 or e.dead:
			continue
		var d := p.distance_squared_to(e.pos + Vector2(0.0, e.hy))
		if d < bd and not (ex and e in exclude):
			bd = d
			best = e
	return best


func in_view(margin := 0.0) -> Array:
	var view: Rect2 = game.view_rect().grow(margin)
	var out := []
	for e: Enemy in list:
		if e.dying < 0.0 and not e.dead and view.has_point(e.pos + Vector2(0.0, e.hy)):
			out.append(e)
	return out


func _compact() -> void:
	var j := 0
	for i in list.size():
		var e: Enemy = list[i]
		if not e.dead:
			list[j] = e
			j += 1
	list.resize(j)


func _batch(sprite: String) -> Node:
	if not batches.has(sprite):
		var b := SheetBatch.new()
		b.setup(sprite, "ramp.fire", bool(Feel.v("enemy_outline", true)))
		add_child(b)
		batches[sprite] = b
	return batches[sprite]


func _render(view: Rect2) -> void:
	for b in batches.values():
		b.begin()
	var global_freeze := freeze_all > 0.0
	var tint_t := _tint_t
	for e: Enemy in list:
		if not view.has_point(e.pos):
			continue
		if e.batch == null:
			e.batch = _batch(e.sprite)
		var b = e.batch
		var info = b.info
		var clip := "walk"
		var t := e.anim_t
		if e.dying >= 0.0:
			clip = "death"
			t = e.dying
		elif e.hurt_t > 0.0:
			clip = "hurt"
			t = HURT_TIME - e.hurt_t
		elif e.boss and e.state > 0 and info.clips.has("attack"):
			clip = "attack"
		var frozen: bool = (global_freeze or e.freeze > 0.0) and not e.def.freeze_immune and e.dying < 0.0
		if frozen:
			clip = "idle"
			t = 0.0
		var c: Dictionary = info.clip(clip)
		# 同 info.frame_at(clip, t)，内联省去一次查表
		var fi := int(t * float(c.fps))
		var nf: int = c.frames
		var frame: int = fi % nf if c.loop else mini(fi, nf - 1)
		# z：闪白（1 纯白 / 0.5 色调）+ 冻结 ×2 + 溶解种子 ×4（每只怪固定，溶解图案不闪）
		var fl := 0.0
		if e.flash > tint_t:
			fl = 1.0
		elif e.flash > 0.0:
			fl = 0.5
		var z := fl + (2.0 if frozen else 0.0) + float(e.uid % 64) * 4.0
		var w := (2.0 if e.boss else 0.0)
		if e.dying >= 0.0:
			# 死亡：前 1/3 播放倒下动画，之后溶解；消散（despawn）直接溶解
			var lead := e.dying_for * 0.33 if e.dying_for >= DEATH_TIME else 0.0
			w += clampf((e.dying - lead) / (e.dying_for - lead), 0.0, 1.0)
		b.add(e.pos, e.face < 0.0, frame, int(c.row), z, w)
	for b in batches.values():
		b.commit()
