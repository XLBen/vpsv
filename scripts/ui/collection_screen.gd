extends Control
## 图鉴：武器 / 被动 / 敌人 / 拾取物。未见过的显示为剪影问号。
## 列表项用“滚动驱动”的动效：随项目进入可视区域的程度取样 motion.ui.scroll_reveal。

const UiKit := preload("res://scripts/ui/ui_kit.gd")
const MotionPlayer := preload("res://scripts/ui/motion_player.gd")

const Unlocks := preload("res://scripts/core/unlocks.gd")
const TABS := [["weapons", "武器"], ["passives", "被动"], ["enemies", "敌人"], ["pickups", "道具"], ["achievements", "成就"]]

var app: Node
var _scroll: ScrollContainer
var _grid: GridContainer
var _info: Label
var _items: Array[Control] = []


func setup(a: Node) -> void:
	app = a
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)
	root.add_child(UiKit.label("图鉴", "gold", UiKit.FONT_L))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	root.add_child(tabs)
	var first: Button = null
	for t in TABS:
		var b := UiKit.button(t[1], _show.bind(t[0]), 70)
		tabs.add_child(b)
		if first == null:
			first = b
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = 10
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	_scroll.add_child(_grid)
	_info = UiKit.label("", "fog")
	root.add_child(_info)
	var back := UiKit.button("返回", func(): app.back(), 80)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	root.add_child(back)
	_show("weapons")
	first.grab_focus.call_deferred()


func _show(kind: String) -> void:
	for c in _grid.get_children():
		c.queue_free()
	_items.clear()
	if kind == "achievements":
		_show_achievements()
		return
	_grid.columns = 10
	var seen: Array = Save.data.seen.get(kind, [])
	for def in Registry.all(kind):
		var known: bool = def.id in seen
		var icon_id: String = def.get("icon") if def.get("icon") else def.get("sprite")
		var cell := PanelContainer.new()
		cell.add_theme_stylebox_override("panel", UiKit.frame("ui.frame.slot", "normal", 2))
		cell.custom_minimum_size = Vector2(44, 44)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		var ic := UiKit.icon(icon_id, 2 if Assets.sheet(icon_id).size.x <= 16 else 1)
		if not known:
			ic.modulate = Color(0, 0, 0, 0.8)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(ic)
		var text: String = ("%s：%s" % [def.name, def.get("desc") if def.get("desc") else ""]) if known else "？？？（尚未遇见）"
		cell.mouse_entered.connect(func(): _info.text = text)
		_grid.add_child(cell)
		_items.append(ic)


func _process(_dt: float) -> void:
	# 滚动驱动：图标按进入可视区域的比例逐步显现
	var view := _scroll.get_global_rect()
	for ic in _items:
		if not is_instance_valid(ic):
			continue
		var r := ic.get_global_rect()
		var p := clampf((view.end.y - r.position.y) / 60.0, 0.0, 1.0)
		MotionPlayer.apply_progress(ic, "motion.ui.scroll_reveal", p * 0.6)


func _show_achievements() -> void:
	_grid.columns = 2
	for id: String in Unlocks.ACHIEVEMENTS:
		var got: bool = id in Save.data.achievements
		var row := HBoxContainer.new()
		row.custom_minimum_size.x = 280
		var mark := UiKit.label("★" if got else "☆", "gold" if got else "dusk", UiKit.FONT_L)
		row.add_child(mark)
		var vb := VBoxContainer.new()
		vb.add_child(UiKit.label(Unlocks.ACHIEVEMENTS[id][0], "white" if got else "mist"))
		vb.add_child(UiKit.label(Unlocks.CONDITION_TEXT.get(Unlocks.ACHIEVEMENTS[id][1], ""), "fog" if got else "dusk"))
		row.add_child(vb)
		_grid.add_child(row)
		_items.append(row)
