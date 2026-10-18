extends SceneTree
## 开发用自动试玩：随机走位、自动选升级卡与开宝箱，结束时打印统计。
##   godot --path . --fixed-fps 20 -s res://tools/autoplay.gd -- [参数]
## 参数：
##   --seconds=120          跑到第几秒
##   --god                  无敌（不会死）
##   --character=lorenzo    --stage=forest    --seed=1
##   --shot=/abs/a.png      结束时截图（需要带窗口运行）
##   --shots=60,600         在这些秒数各截一张图（文件名追加 _秒数）
##   --shot-levelup=/abs/b.png   第一次升级界面出现时截图并退出
##   --shot-title=/abs/c.png     截标题画面并退出
##   --shot-chest=/abs/d.png     第一次宝箱演出结束时截图
##   --narrative-test       运行对话系统测试剧本后退出
##   --give=whip:8,garlic:8 开局直接给武器（可超过 6 把，用于检查特效）
##   --profile              打印各系统每帧平均 / 最大耗时
##   --open-chest=5        第 3 秒直接打开一个宝箱（配合 --shot-chest 截演出）
##   --screen=shop          配合 --shot-title：先打开某个菜单（character_select / stage_select / shop / collection / settings / dialogue）

var app: Node
var secs := 120.0
var god := false
var character := "lorenzo"
var stage := "forest"
var shot := ""
var shots: Array[float] = []
var shot_levelup := ""
var shot_title := ""
var shot_chest := ""
var narrative_test := false
var frames := 0
var dir_t := 0.0
var levelups := 0
var chests := 0
var last_us := 0
var samples := PackedFloat32Array()
var max_enemies := 0
var _wait := 0
var _started := false
var give := []
var screen := ""
var open_chest := 0
var profile := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var v := a.get_slice("=", 1)
		if a == "--god":
			god = true
		elif a == "--narrative-test":
			narrative_test = true
		elif a.begins_with("--seconds="):
			secs = float(v)
		elif a.begins_with("--character="):
			character = v
		elif a.begins_with("--stage="):
			stage = v
		elif a.begins_with("--seed="):
			seed(int(v))
		elif a.begins_with("--shot="):
			shot = v
		elif a.begins_with("--shots="):
			for s in v.split(","):
				shots.append(float(s))
		elif a.begins_with("--shot-levelup="):
			shot_levelup = v
		elif a.begins_with("--shot-title="):
			shot_title = v
		elif a == "--profile":
			profile = true
		elif a.begins_with("--open-chest="):
			open_chest = int(v)
		elif a.begins_with("--screen="):
			screen = v
		elif a.begins_with("--give="):
			give = Array(v.split(","))
		elif a.begins_with("--shot-chest="):
			shot_chest = v
	app = load("res://main.tscn").instantiate()
	root.add_child(app)


func _save(path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("saved ", path)


func _process(delta: float) -> bool:
	frames += 1
	if frames == 1:
		root.get_node("Save").persist = false   # 自动试玩不改动真实存档
	if frames > 200000:
		print("frame limit hit")
		return true
	if shot_title != "":
		if frames == 40 and screen != "":
			if screen == "dialogue":
				var v = load("res://scripts/narrative/dialogue_view.gd").new()
				app.ui_root.add_child(v)
				v.play("_dev_test")
				v.runner.advance()
			else:
				app.call("show_" + screen)
		if frames == 40 + 60 and screen == "dialogue":
			pass
		if frames == 150:
			_save(shot_title)
			return true
		return false
	if narrative_test:
		if frames == 5:
			var NarrativeTest := load("res://tools/narrative_test.gd")
			var ok: bool = NarrativeTest.run(app)
			print("narrative_test=", "PASS" if ok else "FAIL")
			return true
		return false
	if not _started:
		if frames == 40:
			app.start_run(character, stage, true)
			app.game.profiling = profile
			_started = true
			for g in give:
				var id: String = g.get_slice(":", 0)
				var w = app.game.get_weapon(id)
				if w == null:
					w = app.game.add_weapon(id)
				if w and g.contains(":"):
					w.set_level(int(g.get_slice(":", 1)))
		return false
	var game = app.game
	if game == null:
		return true

	if open_chest > 0 and game.run.time > 3.0 and not game.paused:
		# 前 6 个宝箱的件数固定为 1-1-3-1-1-5，借此指定件数
		root.get_node("Save").data.stats["chests"] = {1: 0, 3: 2, 5: 5}.get(open_chest, 0)
		game.open_chest(null)
		open_chest = 0

	# 随机走位
	dir_t -= delta
	if dir_t <= 0.0:
		dir_t = randf_range(0.8, 2.0)
		for a in ["move_left", "move_right", "move_up", "move_down"]:
			Input.action_release(a)
		Input.action_press(["move_left", "move_right"].pick_random())
		if randf() < 0.6:
			Input.action_press(["move_up", "move_down"].pick_random())

	# 界面自动操作
	for c in app.run_ui:
		if not is_instance_valid(c) or not c.visible:
			continue
		var n: String = c.get_script().resource_path.get_file()
		if n == "level_up_panel.gd":
			if shot_levelup != "" and game.run.time > 5.0:
				_wait += 1
				if _wait > 30:
					_save(shot_levelup)
					return true
				return false
			if Time.get_ticks_msec() - c._opened_at > 210:
				levelups += 1
				c._pick(0)
		elif n == "chest_panel.gd":
			if c._phase < 3:
				if shot_chest == "":
					c._skip()
			else:
				chests += 1
				if shot_chest != "":
					_wait += 1
					if _wait > 20:
						_save(shot_chest)
						return true
					return false
				c._close()
		elif n == "pause_panel.gd":
			c.close()

	if god and game.player:
		game.player.hp = game.stats.max_hp()
	max_enemies = maxi(max_enemies, game.enemies.alive_count())
	var now := Time.get_ticks_usec()
	if last_us > 0 and game.run.time > 5.0:
		samples.append((now - last_us) / 1000.0)
	last_us = now
	if not shots.is_empty() and game.run.time >= shots[0]:
		_save(shot.get_basename() + "_%d.png" % int(shots[0]))
		shots.remove_at(0)
	if game.run.time >= secs or game.finished:
		print("time=%.1f lvl=%d kills=%d hp=%.0f finished=%s enemies_now=%d max_enemies=%d items=%d levelups=%d chests=%d gold=%d" % [
			game.run.time, game.run.level, game.run.kills, game.player.hp, game.finished, game.enemies.alive_count(), max_enemies,
			game.pickups.items.size(), levelups, chests, int(game.run.gold)])
		print("weapons=", game.weapons.map(func(w): return "%s:%d dmg=%d" % [w.def.id, w.level, int(w.damage_done)]))
		print("passives=", game.passives)
		for k in game.profile:
			print("  %-12s avg %.2f ms  max %.2f ms" % [k, game.profile[k][0] / 1000.0 / maxf(1.0, frames), game.profile[k][1] / 1000.0])
		samples.sort()
		if samples.size() > 0:
			print("frame ms p50=%.2f p95=%.2f p99=%.2f" % [samples[samples.size() / 2], samples[int(samples.size() * 0.95)], samples[int(samples.size() * 0.99)]])
		if shot != "" and shots.is_empty():
			_save(shot)
		return true
	return false
