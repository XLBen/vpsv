extends Node2D
## 一局游戏的总控：创建各系统、推进主循环、管理背包（武器 / 被动）、
## 升级选项、进化、宝箱、拾取效果与胜负。界面通过信号和公开方法与它交互。

const Stats := preload("res://scripts/core/stats.gd")
const RunState := preload("res://scripts/core/run_state.gd")
const Player := preload("res://scripts/core/player.gd")
const EnemySystem := preload("res://scripts/combat/enemy_system.gd")
const ProjectileSystem := preload("res://scripts/combat/projectile_system.gd")
const PickupSystem := preload("res://scripts/combat/pickup_system.gd")
const Vfx := preload("res://scripts/render/vfx.gd")
const Ground := preload("res://scripts/render/ground.gd")
const Spawner := preload("res://scripts/stage/spawner.gd")
const Layers := preload("res://scripts/render/layers.gd")
const DebugOverlay := preload("res://scripts/render/debug_overlay.gd")

const MAX_WEAPONS := 6
const MAX_PASSIVES := 6
const EVOLVE_AFTER := 600.0          # 10:00 之后的首领宝箱才能进化
const FIRST_CHESTS := [1, 1, 3, 1, 1, 5]

signal level_up(choices: Array)
signal chest_opened(result: Dictionary)
signal run_finished(result: Dictionary)
signal toast_requested(text: String)
signal inventory_changed

var stats := Stats.new()
var run := RunState.new()
var stage: Resource
var character: Resource
var player: Node2D
var enemies: Node2D
var projectiles: Node2D
var pickups: Node2D
var vfx: Node2D
var ground: Node2D
var ground_fx: Node2D          # 贴地特效层（圣水、大蒜）：在怪物之下
var debug: Node2D              # 判定框调试层（F3）
var spawner: RefCounted
var spawning := true           # 关掉后不再刷怪（武器实验室用）
var cam: Camera2D
var weapons: Array = []
var passives := {}
var passive_order: Array = []
var paused := false
var finished := false
var cleared := false
var choices: Array = []
var _shake := 0.0
## 开发用：设为 true 后按系统统计每帧耗时（微秒），自动试玩 --profile 会打开。
var profiling := false
var profile := {}           # 系统 → [总耗时, 最大耗时]
var _t0 := 0
var flash := 0.0
var _hitstop := 0.0


func setup(character_id: String, stage_id: String) -> void:
	character = Registry.character(character_id)
	stage = Registry.stage(stage_id)
	run.stage_id = stage_id
	run.character_id = character_id
	_apply_meta_stats()

	ground = Ground.new()
	add_child(ground)
	ground.setup(self, stage.tileset, stage.bounded_height)
	ground_fx = Node2D.new()
	Layers.put(ground_fx, Layers.GROUND_FX)
	add_child(ground_fx)
	pickups = PickupSystem.new()
	Layers.put(pickups, Layers.PICKUPS)
	add_child(pickups)
	pickups.setup(self)
	enemies = EnemySystem.new()
	Layers.put(enemies, Layers.ENEMIES)
	add_child(enemies)
	enemies.setup(self)
	player = Player.new()
	add_child(player)
	player.setup(self, character.sprite)
	player.died.connect(_on_player_died)
	projectiles = ProjectileSystem.new()
	Layers.put(projectiles, Layers.PROJECTILES)
	add_child(projectiles)
	projectiles.setup(self)
	vfx = Vfx.new()
	Layers.put(vfx, Layers.VFX)
	add_child(vfx)
	vfx.setup(self)
	debug = DebugOverlay.new()
	add_child(debug)
	debug.setup(self)
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	spawner = Spawner.new(self, stage)

	run.rerolls = int(stats.get_stat("rerolls"))
	run.skips = int(stats.get_stat("skips"))
	run.banishes = int(stats.get_stat("banishes"))
	add_weapon(character.start_weapon)
	Audio.play_music(stage.bgm)


## 角色加成 + 局外强化。
func _apply_meta_stats() -> void:
	stats.set_source("character", character.stats)
	var pu := {}
	for def in Registry.all("powerups"):
		var r := Save.powerup_rank(def.id)
		if r > 0:
			pu[def.stat] = pu.get(def.stat, 0.0) + def.per_rank * r
	stats.set_source("powerup", pu)
	_update_growth()


func _update_growth() -> void:
	if character.growth_stat == "":
		return
	var v := minf(character.growth_cap, character.growth_amount * float(run.level / maxi(1, character.growth_every)))
	stats.set_source("growth", {character.growth_stat: v})


# ------------------------------------------------------------ 主循环

func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	_shake = maxf(0.0, _shake - 30.0 * dt)
	flash = maxf(0.0, flash - dt)
	var shake_on: bool = Save.settings().get("screen_shake", true)
	cam.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)).round() if shake_on else Vector2.ZERO
	if paused or finished:
		return
	if _hitstop > 0.0:
		_hitstop -= delta
		return
	run.time += dt
	_t0 = Time.get_ticks_usec()
	player.update(dt)
	cam.position = player.position.round()
	if spawning:
		spawner.update(dt)
	_mark("spawner")
	enemies.update(dt)
	_mark("enemies")
	for w in weapons:
		w.update(dt)
	_mark("weapons")
	projectiles.update(dt)
	_mark("projectiles")
	pickups.update(dt)
	_mark("pickups")
	vfx.update(dt)
	debug.update(dt)
	ground.refresh(view_rect())
	_mark("vfx")
	if not cleared and run.time >= stage.duration:
		cleared = true
	if run.pending_levels > 0 and not paused and not finished:
		_open_level_up()


func _mark(name: String) -> void:
	if not profiling:
		return
	var now := Time.get_ticks_usec()
	var d := now - _t0
	var p: Array = profile.get(name, [0, 0])
	p[0] += d
	p[1] = maxi(p[1], d)
	profile[name] = p
	_t0 = now


func view_rect() -> Rect2:
	var vs := get_viewport_rect().size
	var c := cam.get_screen_center_position() if cam else player.position
	return Rect2(c - vs * 0.5, vs)


func spawn_ring_pos(bias := Vector2.ZERO) -> Vector2:
	var vs := get_viewport_rect().size
	var a := randf() * TAU
	if bias != Vector2.ZERO:
		a = bias.angle() + randf_range(-0.9, 0.9)
	var p: Vector2 = player.position + Vector2.from_angle(a) * (vs.length() * 0.5 + 16.0)
	if stage.bounded_height > 0.0:
		var h: float = stage.bounded_height * 0.5 - 12.0
		if absf(p.y) > h:
			p.y = clampf(p.y, -h, h)
			p.x = player.position.x + signf(p.x - player.position.x + 0.01) * (vs.x * 0.5 + 16.0)
	return p


func in_bounds(p: Vector2) -> bool:
	return stage.bounded_height <= 0.0 or absf(p.y) < stage.bounded_height * 0.5 - 8.0


func clamp_to_bounds(p: Vector2) -> Vector2:
	if stage.bounded_height > 0.0:
		var h: float = stage.bounded_height * 0.5 - 8.0
		p.y = clampf(p.y, -h, h)
	return p


## 顿帧：整个战斗暂停 t 秒（content/feel.json 的 hitstop，默认关闭，原版没有顿帧）。
func hitstop(t: float) -> void:
	if t > 0.0:
		_hitstop = maxf(_hitstop, t)


func camera_shake(v: float) -> void:
	_shake = maxf(_shake, v)


func flash_screen(v: float) -> void:
	if not Save.settings().get("reduce_flashing", false):
		flash = maxf(flash, v)


func toast(text: String) -> void:
	toast_requested.emit(text)


# ------------------------------------------------------------ 背包

func get_weapon(id: String) -> Object:
	for w in weapons:
		if w.def.id == id:
			return w
	return null


func add_weapon(id: String) -> Object:
	var def: Resource = Registry.weapon(id)
	if def == null or def.behavior == null:
		push_warning("武器缺少数据或行为脚本：%s" % id)
		return null
	var w = def.behavior.new(self, def)
	weapons.append(w)
	Save.mark_seen("weapons", id)
	inventory_changed.emit()
	return w


func passive_level(id: String) -> int:
	return passives.get(id, 0)


func add_passive_level(id: String) -> void:
	var def: Resource = Registry.passive(id)
	if def == null:
		return
	if not passives.has(id):
		passive_order.append(id)
	passives[id] = mini(def.max_level, passive_level(id) + 1)
	var old_max := stats.max_hp()
	stats.set_source("passive:" + id, {def.stat: def.per_level * passives[id]})
	if stats.max_hp() > old_max:
		player.hp += stats.max_hp() - old_max
	if def.stat == "revival" or def.stat in ["rerolls", "skips", "banishes"]:
		pass
	Save.mark_seen("passives", id)
	inventory_changed.emit()


## 一个可升级项的显示信息（升级卡片、宝箱、背包共用）。
func choice_info(c: Dictionary) -> Dictionary:
	match c.type:
		"weapon":
			var d: Resource = Registry.weapon(c.id)
			var desc: String = d.desc if c.get("new", false) or c.level <= 1 else d.levels[c.level - 2].desc
			if c.get("evolved", false):
				desc = d.desc
			return {"name": d.name, "icon": d.icon, "tag": "进化！" if c.get("evolved", false) else ("新！" if c.get("new", false) else "Lv %d" % c.level), "desc": desc}
		"passive":
			var d: Resource = Registry.passive(c.id)
			return {"name": d.name, "icon": d.icon, "tag": "新！" if c.get("new", false) else "Lv %d" % c.level, "desc": d.desc}
		"gold":
			return {"name": "金币", "icon": "pickup.coin_bag", "tag": "", "desc": "获得 %d 金币" % int(c.get("value", 25))}
	return {"name": "烤鸡", "icon": "pickup.floor_chicken", "tag": "", "desc": "回复 30 点生命"}


func _upgradable() -> Array:
	var pool := []
	for def in Registry.all("weapons"):
		if def.hidden or def.behavior == null or run.banished.has(def.id):
			continue
		var w = get_weapon(def.id)
		if w != null:
			if w.level < def.max_level:
				pool.append({"type": "weapon", "id": def.id, "level": w.level + 1, "new": false, "w": def.rarity})
		elif weapons.size() < MAX_WEAPONS:
			pool.append({"type": "weapon", "id": def.id, "level": 1, "new": true, "w": def.rarity})
	for def in Registry.all("passives"):
		if def.hidden or run.banished.has(def.id):
			continue
		var l := passive_level(def.id)
		if l > 0:
			if l < def.max_level:
				pool.append({"type": "passive", "id": def.id, "level": l + 1, "new": false, "w": def.rarity})
		elif passive_order.size() < MAX_PASSIVES:
			pool.append({"type": "passive", "id": def.id, "level": 1, "new": true, "w": def.rarity})
	return pool


static func _weighted_pick(pool: Array) -> Dictionary:
	var total := 0.0
	for c in pool:
		total += float(c.w)
	var r := randf() * total
	for c in pool:
		r -= float(c.w)
		if r <= 0.0:
			return c
	return pool.back()


## 生成升级选项：按稀有度加权、不重复；幸运可能多出第 4 个选项。
func make_choices() -> Array:
	var pool := _upgradable()
	if pool.is_empty():
		return [{"type": "gold", "value": 25}, {"type": "chicken"}]
	var n := 3
	if randf() < 1.0 - 1.0 / maxf(1.0, stats.get_stat("luck")):
		n = 4
	var out := []
	while out.size() < n and not pool.is_empty():
		var c := _weighted_pick(pool)
		pool.erase(c)
		out.append(c)
	return out


func _open_level_up() -> void:
	paused = true
	choices = make_choices()
	Audio.play("sfx.ui.level_up")
	level_up.emit(choices)


func apply_choice(c: Dictionary) -> void:
	match c.type:
		"weapon":
			var w = get_weapon(c.id)
			if w:
				w.set_level(w.level + 1)
			else:
				add_weapon(c.id)
		"passive":
			add_passive_level(c.id)
		"gold":
			run.gold += float(c.get("value", 25)) * stats.get_stat("greed")
		_:
			player.heal(30.0)
	inventory_changed.emit()


## 界面调用：选择第 i 个选项。
func choose(i: int) -> void:
	if i < 0 or i >= choices.size():
		return
	apply_choice(choices[i])
	_finish_level()


func reroll() -> bool:
	if run.rerolls <= 0:
		return false
	run.rerolls -= 1
	choices = make_choices()
	level_up.emit(choices)
	return true


func skip_level() -> bool:
	if run.skips <= 0:
		return false
	run.skips -= 1
	_finish_level()
	return true


## 封禁某个选项：本局不再出现，并刷新这一格。
func banish(i: int) -> bool:
	if run.banishes <= 0 or i < 0 or i >= choices.size() or not choices[i].has("id"):
		return false
	run.banishes -= 1
	run.banished[choices[i].id] = true
	var pool := _upgradable().filter(func(c): return not choices.any(func(x): return x.get("id") == c.id))
	if pool.is_empty():
		choices.remove_at(i)
	else:
		choices[i] = _weighted_pick(pool)
	level_up.emit(choices)
	return true


func _finish_level() -> void:
	run.pending_levels -= 1
	_update_growth()
	if run.pending_levels > 0:
		_open_level_up()
	else:
		paused = false


func add_xp(v: float) -> void:
	if run.add_xp(v, stats.get_stat("growth")) > 0:
		_update_growth()


# ------------------------------------------------------------ 进化与宝箱

## 当前可以进化的武器：[[武器实例, 进化后的 id], ...]
func evolutions_available() -> Array:
	var out := []
	for w in weapons:
		var d: Resource = w.def
		if d.evolve_into == "" or w.level < d.max_level or Registry.weapon(d.evolve_into) == null:
			continue
		if run.banished.has(d.evolve_into):
			continue
		if d.evolve_passive != "":
			var pd: Resource = Registry.passive(d.evolve_passive)
			var need: int = pd.max_level if d.evolve_passive_max else 1
			if passive_level(d.evolve_passive) < need:
				continue
		if d.evolve_weapon != "":
			var other = get_weapon(d.evolve_weapon)
			if other == null or other.level < other.def.max_level:
				continue
		out.append([w, d.evolve_into])
	return out


func evolve(w: Object, into: String) -> void:
	var def: Resource = Registry.weapon(into)
	var idx := weapons.find(w)
	w.cleanup()
	if w.def.evolve_weapon != "":
		var other = get_weapon(w.def.evolve_weapon)
		if other:
			other.cleanup()
			weapons.erase(other)
			idx = weapons.find(w)
	var nw = def.behavior.new(self, def)
	nw.damage_done = w.damage_done
	nw.acquired_at = w.acquired_at
	weapons[idx] = nw
	Save.mark_seen("weapons", into)
	inventory_changed.emit()


## 宝箱：决定件数（前几个固定，之后看幸运）、优先进化、其余升级已有道具，并给金币。
func open_chest(it: Object) -> Dictionary:
	var total_chests: int = Save.data.stats.get("chests", 0)
	var count := 1
	if total_chests < FIRST_CHESTS.size():
		count = FIRST_CHESTS[total_chests]
	else:
		var luck := stats.get_stat("luck")
		if randf() < 0.03 * luck:
			count = 5
		elif randf() < 0.10 * luck:
			count = 3
	Save.data.stats["chests"] = total_chests + 1
	run.chests += 1
	var can_evolve: bool = run.time >= EVOLVE_AFTER or (stage.id == "forest" and run.chests == 1)
	var rewards := []
	for i in count:
		var evo := evolutions_available() if can_evolve else []
		if not evo.is_empty() and rewards.filter(func(r): return r.get("evolved", false)).is_empty():
			var e: Array = evo[0]
			rewards.append({"type": "weapon", "id": e[1], "from": e[0].def.id, "level": 1, "evolved": true})
			evolve(e[0], e[1])
			continue
		var owned := _upgradable().filter(func(c): return not c.new)
		if owned.is_empty():
			rewards.append({"type": "gold", "value": 50})
			run.gold += 50.0 * stats.get_stat("greed")
			continue
		var c := _weighted_pick(owned)
		rewards.append(c)
		apply_choice(c)
	var lo: float = [100.0, 300.0, 500.0][[1, 3, 5].find(count)]
	var gold := randf_range(lo, lo * 2.0) * stats.get_stat("greed")
	run.gold += gold
	var result := {"count": count, "rewards": rewards, "gold": int(gold)}
	paused = true
	chest_opened.emit(result)
	return result


func close_chest() -> void:
	paused = run.pending_levels > 0
	if paused:
		_open_level_up()


# ------------------------------------------------------------ 拾取

func collect(it: Object) -> void:
	var def: Resource = it.def
	var effect: String = def.effect if def else "xp"
	match effect:
		"xp":
			add_xp(it.value)
			Audio.play("sfx.pickup.gem")
			return
		"gold":
			run.gold += it.value * stats.get_stat("greed")
		"heal":
			player.heal(it.value)
		"freeze":
			enemies.freeze_all = it.value
			flash_screen(0.2)
		"clear":
			enemies.clear_view(false)
			flash_screen(0.5)
			camera_shake(5.0)
		"vacuum":
			pickups.vacuum()
		"luck":
			stats.add_to_source("pickup", "luck", it.value)
		"chest":
			Audio.play(def.sfx)
			open_chest(it)
			return
	Save.mark_seen("pickups", def.id if def else "gem")
	if def and def.sfx != "":
		Audio.play(def.sfx)


# ------------------------------------------------------------ 胜负

func _on_player_died() -> void:
	if run.revivals_used < int(stats.get_stat("revival")):
		run.revivals_used += 1
		player.revive()
		enemies.clear_view(false)
		flash_screen(0.6)
		toast("复活！")
		Audio.play("sfx.player.revive")
		return
	finish()


func finish() -> void:
	if finished:
		return
	finished = true
	paused = true
	var result := {
		"cleared": cleared,
		"stage": stage.id,
		"character": character.id,
		"time": run.time,
		"level": run.level,
		"kills": run.kills,
		"gold": int(run.gold),
		"weapons": weapons.map(func(w): return w.summary()),
		"passives": passive_order.map(func(id): return {"id": id, "level": passives[id]}),
	}
	Audio.play("sfx.ui.game_over" if not cleared else "sfx.ui.victory")
	run_finished.emit(result)
