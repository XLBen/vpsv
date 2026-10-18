extends Control
## 暂停：属性面板 + 背包 + 继续 / 放弃本局。

const UiKit := preload("res://scripts/ui/ui_kit.gd")
const MotionPlayer := preload("res://scripts/ui/motion_player.gd")

const STAT_ROWS := [
	["max_hp", "最大生命", "hp"], ["recovery", "回复", "num"], ["armor", "护甲", "num"], ["move_speed", "移速", "pct"],
	["might", "力量", "pct"], ["area", "范围", "pct"], ["speed", "弹速", "pct"], ["duration", "持续", "pct"],
	["amount", "数量", "num"], ["cooldown", "冷却", "pct"], ["luck", "幸运", "pct"], ["growth", "成长", "pct"],
	["greed", "贪婪", "pct"], ["curse", "诅咒", "pct"], ["magnet", "磁力", "pct"], ["revival", "复活", "num"],
]

var game: Node
var on_quit := Callable()
var _panel: PanelContainer
var _body: VBoxContainer


func setup(g: Node) -> void:
	game = g
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	add_child(UiKit.dim(0.6))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	center.add_child(_panel)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 4)
	_panel.add_child(_body)


func open() -> void:
	if game.paused or game.finished:
		return
	game.paused = true
	visible = true
	for c in _body.get_children():
		c.queue_free()
	_body.add_child(UiKit.label("暂停", "gold", UiKit.FONT_L, HORIZONTAL_ALIGNMENT_CENTER))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	_body.add_child(cols)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	var snap: Dictionary = game.stats.snapshot()
	for row in STAT_ROWS:
		grid.add_child(UiKit.label(row[1], "mist"))
		grid.add_child(UiKit.label(_fmt(row[0], row[2], snap), "paper", UiKit.FONT_S, HORIZONTAL_ALIGNMENT_RIGHT))
	cols.add_child(grid)
	var inv := VBoxContainer.new()
	inv.add_child(UiKit.label("武器", "mist"))
	var wrow := HBoxContainer.new()
	for w in game.weapons:
		wrow.add_child(UiKit.slot(w.def.icon, w.level, w.def.max_level))
	inv.add_child(wrow)
	inv.add_child(UiKit.label("被动", "mist"))
	var prow := HBoxContainer.new()
	for id: String in game.passive_order:
		var d: Resource = Registry.passive(id)
		prow.add_child(UiKit.slot(d.icon, game.passives[id], d.max_level))
	inv.add_child(prow)
	inv.add_child(UiKit.label("%s · %s" % [game.character.name, game.stage.name], "dusk"))
	cols.add_child(inv)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	var resume := UiKit.button("继续", close, 80)
	row.add_child(resume)
	row.add_child(UiKit.button("放弃本局", func():
		close()
		game.finish(), 80))
	_body.add_child(row)
	MotionPlayer.reset_rest(_panel)
	MotionPlayer.play(_panel, "motion.ui.panel_in")
	resume.grab_focus.call_deferred()


func close() -> void:
	visible = false
	game.paused = false


func _fmt(stat: String, kind: String, snap: Dictionary) -> String:
	match kind:
		"hp":
			return str(int(game.stats.max_hp()))
		"pct":
			var v: float = snap[stat] - 1.0
			return ("+" if v >= 0.0 else "") + "%d%%" % roundi(v * 100.0)
	return str(snappedf(snap[stat], 0.1))


func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("pause"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
