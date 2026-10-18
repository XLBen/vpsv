extends Control
## 角色选择 / 关卡选择（同一套布局：左侧列表，右侧详情）。

const UiKit := preload("res://scripts/ui/ui_kit.gd")
const MotionPlayer := preload("res://scripts/ui/motion_player.gd")
const Unlocks := preload("res://scripts/core/unlocks.gd")

var app: Node
var kind := "characters"
var on_pick := Callable()
var _detail: VBoxContainer
var _selected: Resource


func setup(a: Node, k: String, pick: Callable) -> void:
	app = a
	kind = k
	on_pick = pick
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)
	root.add_child(UiKit.label("选择角色" if kind == "characters" else "选择关卡", "gold", UiKit.FONT_L))
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	root.add_child(row)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = 200
	list.add_theme_constant_override("separation", 3)
	row.add_child(list)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(panel)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 4)
	panel.add_child(_detail)
	var first: Button = null
	var i := 0
	for def in Registry.all(kind):
		var unlocked := Unlocks.is_unlocked(kind, def)
		var b := UiKit.button(def.name if unlocked else "？？？", _select.bind(def), 200)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_entered.connect(_select.bind(def))
		b.mouse_entered.connect(_select.bind(def))
		list.add_child(b)
		b.modulate.a = 0.0
		MotionPlayer.play(b, "motion.ui.card_in", 0.05 * i)
		if first == null:
			first = b
		i += 1
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 6)
	nav.alignment = BoxContainer.ALIGNMENT_END
	nav.add_child(UiKit.button("返回", func(): app.back(), 80))
	var go := UiKit.button("确定", _confirm, 80)
	nav.add_child(go)
	root.add_child(nav)
	if first:
		first.grab_focus.call_deferred()
		_select(Registry.all(kind)[0])


func _select(def: Resource) -> void:
	_selected = def
	for c in _detail.get_children():
		c.queue_free()
	var unlocked := Unlocks.is_unlocked(kind, def)
	if kind == "characters":
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		var portrait := UiKit.icon(def.sprite, 3)
		if not unlocked:
			portrait.modulate = Color(0, 0, 0, 0.85)
		top.add_child(portrait)
		var info := VBoxContainer.new()
		info.add_child(UiKit.label(def.name if unlocked else "？？？", "white", UiKit.FONT_L))
		var w: Resource = Registry.weapon(def.start_weapon)
		if w and unlocked:
			var wr := HBoxContainer.new()
			wr.add_child(UiKit.icon(w.icon, 1))
			wr.add_child(UiKit.label("初始武器：" + w.name, "ice"))
			info.add_child(wr)
		top.add_child(info)
		_detail.add_child(top)
	else:
		_detail.add_child(UiKit.label(def.name if unlocked else "？？？", "white", UiKit.FONT_L))
		if unlocked:
			_detail.add_child(UiKit.label("时长 %s · %s" % [UiKit.fmt_time(def.duration), "纵向有边界" if def.bounded_height > 0.0 else "无限地图"], "ice"))
	var desc := UiKit.label(def.desc if unlocked else "解锁条件：" + def.unlock_desc, "fog" if unlocked else "coral")
	desc.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	desc.custom_minimum_size.x = 260
	_detail.add_child(desc)


func _confirm() -> void:
	if _selected and Unlocks.is_unlocked(kind, _selected):
		on_pick.call(_selected.id)
	else:
		Audio.play("sfx.ui.deny")
