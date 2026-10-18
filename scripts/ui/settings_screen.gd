extends Control
## 设置：音量、伤害数字、屏幕震动、减少闪烁、全屏。改动即时生效并写入存档。

const UiKit := preload("res://scripts/ui/ui_kit.gd")

var app: Node


func setup(a: Node) -> void:
	app = a
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	vb.add_child(UiKit.label("设置", "gold", UiKit.FONT_L, HORIZONTAL_ALIGNMENT_CENTER))
	var s: Dictionary = Save.settings()
	vb.add_child(_slider("音效", "sfx", s))
	vb.add_child(_slider("音乐", "music", s))
	for row in [["damage_numbers", "伤害数字"], ["screen_shake", "屏幕震动"], ["reduce_flashing", "减少闪烁"], ["fullscreen", "全屏"]]:
		var cb := CheckButton.new()
		cb.text = row[1]
		cb.button_pressed = bool(s.get(row[0], false))
		cb.toggled.connect(func(on: bool):
			s[row[0]] = on
			apply(s)
			Save.write())
		vb.add_child(cb)
	var back := UiKit.button("返回", func(): app.back(), 100)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(back)
	back.grab_focus.call_deferred()


func _slider(text: String, key: String, s: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_child(UiKit.label(text))
	var sl := HSlider.new()
	sl.custom_minimum_size.x = 140
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = float(s.get(key, 1.0))
	sl.value_changed.connect(func(v: float):
		s[key] = v
		apply(s)
		Audio.play("sfx.ui.hover"))
	sl.drag_ended.connect(func(_c): Save.write())
	row.add_child(sl)
	return row


## 把设置应用到引擎（启动时也会调用）。
static func apply(s: Dictionary) -> void:
	Audio.sfx_volume = float(s.get("sfx", 1.0))
	Audio.music_volume = float(s.get("music", 0.7))
	var full := bool(s.get("fullscreen", false))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED)
