extends Control
## 结算：通关 / 失败、时间、等级、击杀、金币，以及每把武器的伤害、持有时间、DPS。

const UiKit := preload("res://scripts/ui/ui_kit.gd")
const MotionPlayer := preload("res://scripts/ui/motion_player.gd")

var on_done := Callable()
var _panel: PanelContainer


func show_result(r: Dictionary) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.dim(0.75))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	center.add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_panel.add_child(vb)
	var title := UiKit.label("通关！" if r.cleared else "游戏结束", "gold" if r.cleared else "coral", UiKit.FONT_L, HORIZONTAL_ALIGNMENT_CENTER)
	vb.add_child(title)
	var stage: Resource = Registry.stage(r.stage)
	var ch: Resource = Registry.character(r.character)
	vb.add_child(UiKit.label("%s · %s" % [ch.name, stage.name], "mist", UiKit.FONT_S, HORIZONTAL_ALIGNMENT_CENTER))
	vb.add_child(UiKit.label("存活 %s　等级 %d　击杀 %s　金币 +%d" % [UiKit.fmt_time(r.time), r.level, UiKit.fmt_num(r.kills), r.gold], "paper", UiKit.FONT_S, HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	for h in ["武器", "等级", "伤害", "时长", "DPS"]:
		grid.add_child(UiKit.label(h, "dusk"))
	var ws: Array = r.weapons.duplicate()
	ws.sort_custom(func(a, b): return a.damage > b.damage)
	for w: Dictionary in ws:
		var name_row := HBoxContainer.new()
		name_row.add_child(UiKit.icon(w.icon, 1))
		name_row.add_child(UiKit.label(w.name))
		grid.add_child(name_row)
		grid.add_child(UiKit.label(str(w.level), "paper", UiKit.FONT_S, HORIZONTAL_ALIGNMENT_RIGHT))
		grid.add_child(UiKit.label(UiKit.fmt_num(w.damage), "lemon", UiKit.FONT_S, HORIZONTAL_ALIGNMENT_RIGHT))
		grid.add_child(UiKit.label(UiKit.fmt_time(w.time), "paper", UiKit.FONT_S, HORIZONTAL_ALIGNMENT_RIGHT))
		grid.add_child(UiKit.label(UiKit.fmt_num(w.dps), "ice", UiKit.FONT_S, HORIZONTAL_ALIGNMENT_RIGHT))
	vb.add_child(grid)
	var ok := UiKit.button("完成", func(): on_done.call(), 100)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(ok)
	MotionPlayer.play(_panel, "motion.ui.panel_in")
	MotionPlayer.play(title, "motion.ui.banner_drop")
	ok.grab_focus.call_deferred()
