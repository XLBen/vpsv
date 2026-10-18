extends Node2D
## 敌人系统：生成、移动（追击 / 直线群 / 包围墙 / 首领冲锋 / 死神）、
## 分离、接触伤害、受伤与死亡，并按素材分批渲染。

const SheetBatch := preload("res://scripts/render/sheet_batch.gd")
const SpatialGrid := preload("res://scripts/combat/spatial_grid.gd")

const DEATH_TIME := 0.75
const HURT_TIME := 0.15


class Enemy:
	var def: Resource
	var id := ""
	var uid := 0
	var sprite := ""
	var pos := Vector2.ZERO
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
	var dead := false                # 可以移除
	var boss := false
	var behavior := "chase"
	var state := 0
	var timer := 0.0
	var life := -1.0                 # >0 时到期自动消失（直线群、花墙）
	var anchor := Vector2.ZERO       # 花墙收缩中心
	var hit_until := {}              # 伤害来源 → 可再次受击的时刻（持续型武器）

	func alive() -> bool:
		return dying < 0.0 and not dead


var game: Node
var grid := SpatialGrid.new(32.0)
var list: Array = []
var batches := {}
var freeze_all := 0.0
var _sort_t := 0.0
var _frame := 0
var _uid := 0

signal killed(enemy: Enemy)


func setup(g: Node) -> void:
	game = g


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
	_uid += 1
	e.uid = _uid
	e.timer = randf_range(3.0, 5.0)
	for k: String in opts:
		e.set(k, opts[k])
	list.append(e)
	Save.mark_seen("enemies", e.id)
	return e


func update(dt: float) -> void:
	_frame += 1
	freeze_all = maxf(0.0, freeze_all - dt)
	grid.clear()
	for e: Enemy in list:
		if e.alive():
			grid.insert(e, e.pos)

	var ppos: Vector2 = game.player.position
	var pr: float = game.player.radius
	var view: Rect2 = game.view_rect()
	var far := view.size.length() * 0.5 + 120.0
	var kdecay := exp(-10.0 * dt)

	for e: Enemy in list:
		e.anim_t += dt
		if e.dying >= 0.0:
			e.dying += dt
			if e.dying >= DEATH_TIME:
				e.dead = true
			continue
		e.flash = maxf(0.0, e.flash - dt)
		e.hurt_t = maxf(0.0, e.hurt_t - dt)
		if e.life > 0.0:
			e.life -= dt
			if e.life <= 0.0:
				e.dead = true
				continue
		var frozen: bool = (freeze_all > 0.0 or e.freeze > 0.0) and not e.def.freeze_immune
		e.freeze = maxf(0.0, e.freeze - dt)

		var to := ppos - e.pos
		var d := to.length()
		var dir := to / d if d > 0.001 else Vector2.ZERO
		var v := Vector2.ZERO
		match e.behavior:
			"swarm":
				v = e.dir * e.speed
				if d > far * 1.6:
					e.dead = true
					continue
			"wall":
				var to_anchor := e.anchor - e.pos
				if to_anchor.length() > 48.0:
					v = to_anchor.normalized() * e.speed
			"boss_charge":
				v = _boss_charge(e, dir, dt)
			"reaper":
				v = dir * e.speed
			_:
				v = dir * e.speed
				# 跑太远的普通敌人重新放到玩家前方屏幕外
				if d > far and not e.boss:
					e.pos = game.spawn_ring_pos(game.player.move_dir if game.player.moving else Vector2.ZERO)
					continue
		if frozen:
			v = Vector2.ZERO
		if absf(v.x) > 1.0:
			e.face = signf(v.x)
		e.pos += (v + e.kb) * dt
		e.kb *= kdecay

		# 分离隔帧轮流做（一半敌人一帧），推力加倍补偿，视觉上无差别
		if e.behavior != "wall" and e.behavior != "reaper" and (e.uid + _frame) % 2 == 0:
			_separate(e, 2.0)
		if d < e.radius + pr - 1.0 and not frozen:
			game.player.hurt(e.damage, e)

	_compact()
	_sort_t -= dt
	if _sort_t <= 0.0:
		_sort_t = 0.1
		list.sort_custom(func(a: Enemy, b: Enemy) -> bool: return a.pos.y < b.pos.y)
	_render(view.grow(48.0))


func _separate(e: Enemy, strength := 1.0) -> void:
	# 直接遍历 3×3 个格子，避免每个敌人分配查询数组
	var cell: float = grid.cell
	var cx := floori(e.pos.x / cell)
	var cy := floori(e.pos.y / cell)
	var cells: Dictionary = grid.cells
	for gx in range(cx - 1, cx + 2):
		for gy in range(cy - 1, cy + 2):
			var bucket = cells.get(Vector2i(gx, gy))
			if bucket == null:
				continue
			for o: Enemy in bucket:
				if o != e:
					_push(e, o, strength)


func _push(e: Enemy, o: Enemy, strength: float) -> void:
	var diff := e.pos - o.pos
	var dd := diff.length_squared()
	var rr := e.radius + o.radius
	if dd >= rr * rr:
		return
	if dd < 0.0001:
		e.pos += Vector2(randf() - 0.5, randf() - 0.5)
		return
	var dist := sqrt(dd)
	var w := minf(1.0, o.radius / rr * 0.5 * strength)
	if o.behavior == "wall":
		w = 1.0
	elif e.boss:
		w *= 0.1
	e.pos += diff / dist * (rr - dist) * w


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


## 对敌人造成伤害；source 为造成伤害的武器（统计用，可为 null）。返回实际伤害。
func damage(e: Enemy, amount: float, kdir := Vector2.ZERO, kb := 0.0, source: Object = null) -> float:
	if not e.alive() or (e.behavior == "reaper" and amount < 1e6):
		return 0.0
	var dealt := minf(amount, e.hp)
	e.hp -= amount
	e.flash = 0.1
	e.hurt_t = HURT_TIME
	if kb > 0.0 and not e.boss:
		e.kb = (e.kb + kdir * kb * 90.0 * (1.0 - e.kb_resist)).limit_length(240.0)
	game.vfx.damage_number(e.pos + Vector2(0, -e.radius * 2.0), amount)
	Audio.play("sfx.enemy.hit")
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
		game.vfx.burst(e.pos, 24, "red")
		game.camera_shake(6.0)
		Audio.play("sfx.enemy.boss_down")
	else:
		Audio.play("sfx.enemy.die")
	killed.emit(e)


## 清屏（念珠 / 五芒星）。返回清掉的数量。
func clear_view(include_boss := false) -> int:
	var view: Rect2 = game.view_rect()
	var n := 0
	for e: Enemy in list:
		if e.alive() and view.has_point(e.pos) and (include_boss or not e.boss) and e.behavior != "reaper":
			kill(e)
			n += 1
	return n


func query(p: Vector2, r: float) -> Array:
	return grid.query(p, r)


func nearest(p: Vector2, max_d: float, exclude: Array = []) -> Enemy:
	var best: Enemy = null
	var bd := max_d * max_d
	for e: Enemy in list:
		if not e.alive() or e in exclude:
			continue
		var d := p.distance_squared_to(e.pos)
		if d < bd:
			bd = d
			best = e
	return best


func in_view(margin := 0.0) -> Array:
	var view: Rect2 = game.view_rect().grow(margin)
	var out := []
	for e: Enemy in list:
		if e.alive() and view.has_point(e.pos):
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
		b.setup(sprite)
		add_child(b)
		batches[sprite] = b
	return batches[sprite]


func _render(view: Rect2) -> void:
	for b in batches.values():
		b.begin()
	var global_freeze := freeze_all > 0.0
	for e: Enemy in list:
		if not view.has_point(e.pos):
			continue
		var b = _batch(e.sprite)
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
		var frame: int = info.frame_at(clip, t)
		var z := (1.0 if e.flash > 0.0 else 0.0) + (2.0 if frozen else 0.0)
		var w := (clampf((e.dying - 0.25) / (DEATH_TIME - 0.25), 0.0, 1.0) if e.dying >= 0.0 else 0.0) + (2.0 if e.boss else 0.0)
		b.add(e.pos, e.face < 0.0, frame, int(c.row), z, w)
	for b in batches.values():
		b.commit()
