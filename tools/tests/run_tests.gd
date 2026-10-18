extends SceneTree
## 单元测试：godot --headless --path . -s res://tools/tests/run_tests.gd
## 不写盘（存档测试用临时数据），失败时以非零退出码结束。

## 注意：用 -s 运行时脚本先于自动加载编译，所以引用自动加载的游戏脚本要在运行时 load()。
var RunState: GDScript
var Stats: GDScript
var Game: GDScript
var ShopScreen: GDScript
var Runner: GDScript
var Parser: GDScript
var CgRegistry: GDScript

var passed := 0
var failed := 0
var _frame := 0


func check(cond: bool, name: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("  ✗ ", name)


func near(a: float, b: float, eps := 0.0001) -> bool:
	return absf(a - b) <= eps


func _process(_d: float) -> bool:
	_frame += 1
	if _frame < 3:
		return false   # 等自动加载就绪
	RunState = load("res://scripts/core/run_state.gd")
	Stats = load("res://scripts/core/stats.gd")
	Game = load("res://scripts/core/game.gd")
	ShopScreen = load("res://scripts/ui/shop_screen.gd")
	Runner = load("res://scripts/narrative/dialogue_runner.gd")
	Parser = load("res://scripts/narrative/dialogue_parser.gd")
	CgRegistry = load("res://scripts/narrative/cg_registry.gd")
	var save: Node = root.get_node("Save")
	save.persist = false
	save.reset_memory()
	seed(12345)
	for t in ["test_xp", "test_stats", "test_powerup_price", "test_save_roundtrip", "test_parser", "test_runner", "test_cg", "test_game"]:
		print("· ", t)
		call(t)
	print("通过 %d，失败 %d" % [passed, failed])
	quit(1 if failed > 0 else 0)
	return true


func test_xp() -> void:
	check(near(RunState.xp_to_next(1), 5.0), "1→2 需要 5")
	check(near(RunState.xp_to_next(2), 15.0), "2→3 需要 15")
	check(near(RunState.xp_to_next(19), 185.0), "19→20 需要 185")
	check(near(RunState.xp_to_next(20), 798.0), "20→21 额外 +600")
	check(near(RunState.xp_to_next(21), 211.0), "21→22 回落为 +13 递增")
	check(near(RunState.xp_to_next(40), RunState.xp_to_next(39) + 16.0 + 2400.0), "40→41 额外 +2400")
	var r = RunState.new()
	check(r.add_xp(5.0, 1.0) == 1 and r.level == 2, "加 5 经验升到 2 级")
	check(r.add_xp(1000.0, 1.0) > 1, "大量经验连升多级")


func test_stats() -> void:
	var s = Stats.new()
	check(near(s.get_stat("might"), 1.0), "力量默认 1")
	s.set_source("passive:spinach", {"might": 0.3})
	s.set_source("powerup", {"might": 0.1, "cooldown": -0.05})
	check(near(s.get_stat("might"), 1.4), "多来源叠加")
	check(near(s.get_stat("cooldown"), 0.95), "冷却减少")
	s.set_source("character", {"max_hp": 20.0})
	s.set_source("passive:hollow_heart", {"max_hp_mul": 0.4})
	check(near(s.max_hp(), 168.0), "最大生命 = (100+20) × 1.4")
	s.set_source("x", {"cooldown": -5.0})
	check(near(s.get_stat("cooldown"), 0.1), "冷却有下限 0.1")


func test_powerup_price() -> void:
	var save: Node = root.get_node("Save")
	var reg: Node = root.get_node("Registry")
	var might: Resource = reg.get_def("powerups", "might")
	save.data.powerups = {}
	check(ShopScreen.price(might) == 200, "首级价格 = 基础价")
	save.data.powerups = {"might": 1, "armor": 2}
	check(ShopScreen.price(might) == 200 * 2 + 20 * 3, "第 2 级 = 基础价×2 + 公共附加费")


func test_save_roundtrip() -> void:
	var save: Node = root.get_node("Save")
	var d: Dictionary = save.defaults()
	d.gold = 1234
	d.powerups = {"might": 3}
	d.flags = {"met": 2}
	var text := JSON.stringify(d)
	var back = JSON.parse_string(text)
	var into: Dictionary = save.defaults()
	save._merge(into, save.migrate(back))
	check(int(into.gold) == 1234 and int(into.powerups.might) == 3 and int(into.flags.met) == 2, "存档读写往返一致")
	check(into.has("settings") and into.settings.has("sfx"), "旧存档缺少的字段由默认值补全")


func test_parser() -> void:
	var p = Parser.new()
	check(p.parse_file("res://content/dialogue/_dev_test.vsd"), "测试剧本解析无错误：%s" % str(p.errors))
	check(p.labels.has("fight") and p.labels.has("after"), "标签解析")
	var bad = Parser.new()
	check(not bad.parse("@jump nowhere\n@frobnicate"), "未知指令与缺失标签会报错")
	check(bad.errors.size() == 2, "报出两个错误")


func test_runner() -> void:
	var save: Node = root.get_node("Save")
	save.data.flags = {}
	save.data.read_lines = {}
	var r = Runner.new()
	var lines: Array = []
	var choices: Array = []
	var cgs: Array = []
	var done := [false]
	r.said.connect(func(sp, t, _read): lines.append([sp, t]))
	r.choices_shown.connect(func(o): choices.append(o))
	r.cg_changed.connect(func(id, v): cgs.append([id, v]))
	r.wait_requested.connect(func(_t): r.advance())
	r.finished.connect(func(): done[0] = true)
	check(r.load_script("_dev_test"), "加载剧本")
	r.start()
	check(lines.size() == 1 and lines[0][1].contains("第 1 次"), "变量插值：%s" % str(lines))
	r.advance()
	r.advance()
	check(lines.back()[0] == "" and lines.size() == 3, "冒号开头的行是旁白")
	r.advance()
	check(choices.size() == 1 and choices[0].size() == 2, "条件选项被过滤（met=1 时只有 2 项）")
	r.choose(0)
	check(lines.back()[1] == "来吧！", "选择后跳转到对应标签")
	var guard := 0
	while r.running and not done[0] and guard < 50:
		guard += 1
		r.advance()
	check(done[0], "剧本走到结尾")
	check(float(save.flag("courage", 0)) == 1.0, "@set 累加变量")
	check(cgs.size() == 3 and cgs[1] == ["_dev_cg_01", 1], "CG 与差分切换")
	# 第二次进入：met=2，出现第三个选项；行已读
	var r2 = Runner.new()
	var read_flags: Array = []
	var choices2: Array = []
	r2.said.connect(func(_s, _t, read): read_flags.append(read))
	r2.choices_shown.connect(func(o): choices2.append(o))
	r2.load_script("_dev_test")
	r2.start()
	check(read_flags[0] == true, "已读行被记录")
	r2.advance()
	r2.advance()
	r2.advance()
	check(choices2[0].size() == 3, "满足条件后出现额外选项")


func test_cg() -> void:
	var save: Node = root.get_node("Save")
	check(CgRegistry.is_unlocked("_dev_cg_01"), "剧本播放 CG 后自动解锁")
	check(CgRegistry.image("_dev_cg_01", 1) == "cg._dev_01b", "差分素材 id")
	save.data.cg = []
	check(not CgRegistry.is_unlocked("_dev_cg_01"), "清空后未解锁")


func test_game() -> void:
	var save: Node = root.get_node("Save")
	save.data.powerups = {}
	var g = Game.new()
	root.add_child(g)
	g.setup("lorenzo", "forest")
	check(g.weapons.size() == 1 and g.weapons[0].def.id == "whip", "角色初始武器")
	check(near(g.stats.max_hp(), 120.0), "角色生命加成")
	# 升级选项：不重复、数量 3 或 4
	for i in 20:
		var cs: Array = g.make_choices()
		var ids := cs.map(func(c): return c.get("id", c.type))
		var uniq := {}
		for id in ids:
			uniq[id] = true
		check(cs.size() >= 3 and cs.size() <= 4 and uniq.size() == cs.size(), "升级选项不重复")
	# 进化条件：皮鞭满级 + 空心之心
	var whip = g.weapons[0]
	whip.set_level(8)
	check(g.evolutions_available().is_empty(), "缺少被动时不能进化")
	g.add_passive_level("hollow_heart")
	var evo: Array = g.evolutions_available()
	check(evo.size() == 1 and evo[0][1] == "bloody_tear", "满足条件后可进化为血泪")
	# 合体：白鸟 + 黑翼 都满级
	var a = g.add_weapon("peachone")
	var b = g.add_weapon("ebony_wings")
	a.set_level(8)
	check(not g.evolutions_available().any(func(e): return e[1] == "vandalier"), "合体需要两把都满级")
	b.set_level(8)
	check(g.evolutions_available().any(func(e): return e[1] == "vandalier"), "两把满级后可合体")
	# 宝箱：10:00 之后进化优先
	g.run.time = 700.0
	save.data.stats["chests"] = 10
	var res: Dictionary = g.open_chest(null)
	check(res.rewards[0].get("evolved", false), "宝箱优先给进化")
	check(g.get_weapon("bloody_tear") != null or g.get_weapon("vandalier") != null, "进化后武器被替换")
	g.paused = false
	# 宝箱件数概率（固定种子统计）：幸运 1 时约 3% 五件、≈9.7% 三件
	var counts := {1: 0, 3: 0, 5: 0}
	for i in 4000:
		var c := 1
		if randf() < 0.03:
			c = 5
		elif randf() < 0.10:
			c = 3
		counts[c] += 1
	check(absf(counts[5] / 4000.0 - 0.03) < 0.01 and absf(counts[3] / 4000.0 - 0.097) < 0.02, "宝箱件数分布：%s" % str(counts))
	# 前几个宝箱固定 1-1-3-1-1-5
	save.data.stats["chests"] = 2
	g.run.time = 100.0
	check(g.open_chest(null).count == 3, "第 3 个宝箱固定 3 件")
	g.paused = false
	# 光源掉落权重：低等级不会掉高要求的道具
	g.run.level = 1
	var drops := {}
	for i in 2000:
		var before: int = g.pickups.items.size()
		g.pickups.roll_light_drop(Vector2.ZERO)
		var it = g.pickups.items.back()
		if g.pickups.items.size() > before:
			drops[it.kind] = drops.get(it.kind, 0) + 1
	check(not drops.has("vacuum") and not drops.has("rosary") and not drops.has("orologion"), "等级不足的掉落被排除：%s" % str(drops))
	check(drops.get("coin", 0) > drops.get("coin_bag", 0) * 3, "金币权重远高于钱袋")
	g.queue_free()
