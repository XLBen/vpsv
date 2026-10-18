extends Control
## 升级选择：3～4 张卡片交错入场；支持重抽、跳过、封禁（封禁模式下点卡片即封禁）。
## 键盘 1–4 选择，手柄用方向键 + 确认。

const UiKit := preload("res://scripts/ui/ui_kit.gd")
const MotionPlayer := preload("res://scripts/ui/motion_player.gd")

const CARD_W := 296
const CARD_H := 40

var game: Node
var _panel: PanelContainer
var _cards: VBoxContainer
var _title: Label
var _reroll: Button
var _skip: Button
var _banish: Button
var _banish_mode := false
var _opened_at := 0
var _rain: ColorRect
var _rain_t := 99.0

const GEM_RAIN := preload("res://shaders/fx/gem_rain.gdshader")


func setup(g: Node) -> void:
	game = g
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	add_child(UiKit.dim(0.55))
	_rain = ColorRect.new()
	_rain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rm := ShaderMaterial.new()
	rm.shader = GEM_RAIN
	rm.set_shader_parameter("c1", UiKit.color("sky"))
	rm.set_shader_parameter("c2", UiKit.color("lime"))
	rm.set_shader_parameter("c3", UiKit.color("red"))
	_rain.material = rm
	add_child(_rain)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(CARD_W + 24, 260)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(holder)
	_panel = PanelContainer.new()
	holder.add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_panel.add_child(vb)
	_title = UiKit.label("升级！", "gold", UiKit.FONT_L, HORIZONTAL_ALIGNMENT_CENTER)
	vb.add_child(_title)
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 3)
	vb.add_child(_cards)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	_reroll = UiKit.button("重抽", func(): game.reroll(), 70)
	_skip = UiKit.button("跳过", func(): game.skip_level(), 70)
	_banish = UiKit.button("封禁", _toggle_banish, 70)
	for b in [_reroll, _skip, _banish]:
		row.add_child(b)
	vb.add_child(row)
	vb.add_child(UiKit.label("按 1–4 选择", "dusk", UiKit.FONT_S, HORIZONTAL_ALIGNMENT_CENTER))
	game.level_up.connect(show_choices)


func show_choices(choices: Array) -> void:
	var first_open := not visible
	visible = true
	_opened_at = Time.get_ticks_msec()
	_banish_mode = false
	for c in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	for i in choices.size():
		_cards.add_child(_card(choices[i], i))
	_update_buttons()
	await get_tree().process_frame
	_panel.size = _panel.get_combined_minimum_size()
	_panel.position = ((_panel.get_parent().size - _panel.size) * 0.5).round()
	if first_open:
		_rain_t = 0.0
		MotionPlayer.stop(_panel)
		MotionPlayer.reset_rest(_panel)
		MotionPlayer.play(_panel, "motion.ui.panel_in")
		MotionPlayer.play(_title, "motion.ui.banner_drop")
	for i in _cards.get_child_count():
		var slot: Control = _cards.get_child(i)
		var card: Control = slot.get_child(0)
		MotionPlayer.play(card, "motion.ui.card_in", 0.07 * i)
	if _cards.get_child_count() > 0:
		_cards.get_child(0).get_child(0).grab_focus()


func _process(dt: float) -> void:
	if visible and _rain_t < 2.0:
		_rain_t += dt
		_rain.material.set_shader_parameter("elapsed", _rain_t)


func _update_buttons() -> void:
	_reroll.text = "重抽 %d" % game.run.rerolls
	_skip.text = "跳过 %d" % game.run.skips
	_banish.text = ("取消" if _banish_mode else "封禁 %d" % game.run.banishes)
	_reroll.disabled = game.run.rerolls <= 0
	_skip.disabled = game.run.skips <= 0
	_banish.disabled = game.run.banishes <= 0 and not _banish_mode
	_reroll.visible = game.run.rerolls > 0 or Save.powerup_rank("reroll") > 0
	_skip.visible = game.run.skips > 0 or Save.powerup_rank("skip") > 0
	_banish.visible = game.run.banishes > 0 or Save.powerup_rank("banish") > 0


func _toggle_banish() -> void:
	_banish_mode = not _banish_mode
	_update_buttons()
	_title.text = "选择要封禁的项目" if _banish_mode else "升级！"
	_title.add_theme_color_override("font_color", UiKit.color("red" if _banish_mode else "gold"))


func _card(c: Dictionary, i: int) -> Control:
	var info: Dictionary = game.choice_info(c)
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(CARD_W, CARD_H)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b := Button.new()
	b.size = Vector2(CARD_W, CARD_H)
	b.focus_mode = Control.FOCUS_ALL
	for s: String in ["normal", "disabled"]:
		b.add_theme_stylebox_override(s, UiKit.frame("ui.frame.card", "normal", 4))
	for s: String in ["hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(s, UiKit.frame("ui.frame.card", "hover", 4))
	b.pressed.connect(_pick.bind(i))
	b.mouse_entered.connect(func(): Audio.play("sfx.ui.hover"))
	slot.add_child(b)
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 6)
	b.add_child(hb)
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	var icon := UiKit.icon(info.icon, 2)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(icon)
	var tv := VBoxContainer.new()
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(UiKit.label(info.name, "white"))
	if info.tag != "":
		name_row.add_child(UiKit.label(info.tag, "gold" if info.tag in ["新！", "进化！"] else "ice"))
	tv.add_child(name_row)
	tv.add_child(UiKit.label(info.desc, "fog"))
	hb.add_child(tv)
	var key := UiKit.label(str(i + 1), "dusk")
	key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(key)
	return slot


func _pick(i: int) -> void:
	if Time.get_ticks_msec() - _opened_at < 200:
		return
	if _banish_mode:
		if game.banish(i):
			Audio.play("sfx.ui.banish")
		return
	visible = false
	Audio.play("sfx.ui.pick")
	game.choose(i)


func _unhandled_input(ev: InputEvent) -> void:
	if not visible:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var k: int = ev.physical_keycode - KEY_1
		if k >= 0 and k < _cards.get_child_count():
			_pick(k)
			get_viewport().set_input_as_handled()
