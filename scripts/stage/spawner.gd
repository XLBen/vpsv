extends RefCounted
## 刷怪：按关卡的分钟波次维持“最少同屏数”，并按间隔持续补充；
## 每分钟开始时刷出该分钟的首领；处理关卡事件；到时限刷出死神。

var game: Node
var stage: Resource
var _minute := -1
var _interval_t := 0.0
var _event_i := 0
var _reaper_t := -1.0
var _reapers := 0


func _init(g: Node, s: Resource) -> void:
	game = g
	stage = s
	var evs: Array = stage.events.duplicate()
	evs.sort_custom(func(a, b): return a.at < b.at)
	stage.events = evs


func wave() -> Dictionary:
	if stage.waves.is_empty():
		return {}
	return stage.waves[clampi(_minute, 0, stage.waves.size() - 1)]


func update(dt: float) -> void:
	var t: float = game.run.time
	var m := int(t / 60.0)
	if m != _minute:
		_minute = m
		_on_minute()
	var w := wave()
	if w.is_empty() or t >= stage.duration:
		_reaper(dt)
		return
	var curse: float = game.stats.get_stat("curse")
	var min_count := int(float(w.min) * curse)
	var cap: int = stage.max_enemies
	var alive: int = game.enemies.alive_count()
	# 少于最少数量时立即补足（每帧最多 20 个，避免卡顿）
	if alive < min_count:
		for i in mini(20, min_count - alive):
			_spawn_one(w)
		alive = game.enemies.alive_count()
	_interval_t -= dt * curse
	if _interval_t <= 0.0:
		_interval_t = maxf(0.05, float(w.interval))
		if alive < cap:
			_spawn_one(w)
	while _event_i < stage.events.size() and t >= float(stage.events[_event_i].at):
		_run_event(stage.events[_event_i])
		_event_i += 1


func _spawn_one(w: Dictionary) -> void:
	var id: String = w.enemies.pick_random()
	var def: Resource = Registry.enemy(id)
	if def:
		game.enemies.spawn(def, game.spawn_ring_pos())


func _on_minute() -> void:
	var w := wave()
	if _minute * 60.0 >= stage.duration:
		_reaper_t = 0.0
		return
	var boss: String = w.get("boss", "")
	if boss != "" and _minute > 0:
		var def: Resource = Registry.enemy(boss)
		if def:
			game.enemies.spawn(def, game.spawn_ring_pos())
			game.toast("%s 出现了！" % def.name)
			Audio.play("sfx.enemy.boss_appear")


func _run_event(ev: Dictionary) -> void:
	match ev.type:
		"bat_swarm", "ghost_swarm":
			if randf() > float(ev.get("chance", 1.0)):
				return
			var id: String = ev.get("enemy", "bat" if ev.type == "bat_swarm" else "ghost")
			_swarm(Registry.enemy(id), int(ev.get("count", 20)))
			game.toast("蝙蝠群来袭！" if id == "bat" else ("幽灵群来袭！" if id == "ghost" else "敌群来袭！"))
		"flower_wall":
			_flower_wall(int(ev.get("count", 48)), float(ev.get("radius", 200.0)))
			game.toast("花墙包围了你！")


## 直线横扫的敌群：从屏幕一侧排成一列冲向另一侧。
func _swarm(def: Resource, n: int) -> void:
	if def == null:
		return
	var view: Rect2 = game.view_rect()
	var dir := Vector2.from_angle(randf() * TAU)
	var start: Vector2 = game.player.position - dir * (view.size.length() * 0.5 + 20.0)
	var perp := Vector2(-dir.y, dir.x)
	for i in n:
		var off := perp * (float(i) - n * 0.5) * 9.0 + dir * randf_range(-10.0, 10.0)
		var e = game.enemies.spawn(def, start + off, {"behavior": "swarm", "dir": dir, "life": 20.0})
		e.speed = def.speed * 1.8


## 花墙：一圈不可推动的墙缓慢向中心收缩，存在 40 秒。
func _flower_wall(n: int, radius: float) -> void:
	var def: Resource = Registry.enemy("flower_wall")
	if def == null:
		return
	var c: Vector2 = game.player.position
	for i in n:
		var p := c + Vector2.from_angle(i * TAU / n) * radius
		game.enemies.spawn(def, p, {"anchor": c, "life": 40.0})


func _reaper(dt: float) -> void:
	if _reaper_t < 0.0:
		return
	_reaper_t -= dt
	if _reaper_t > 0.0:
		return
	# 时限到：清屏并刷出死神，之后每分钟再加一个
	if _reapers == 0:
		game.enemies.clear_view(true)
		game.toast("死神降临……")
		Audio.play("sfx.enemy.reaper")
	var def: Resource = Registry.enemy("reaper")
	if def:
		game.enemies.spawn(def, game.spawn_ring_pos())
	_reapers += 1
	_reaper_t = 60.0
