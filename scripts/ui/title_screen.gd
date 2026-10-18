extends Control
## 标题画面。

const UiKit := preload("res://scripts/ui/ui_kit.gd")
const MotionPlayer := preload("res://scripts/ui/motion_player.gd")

var app: Node


func setup(a: Node) -> void:
	app = a
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	center.add_child(vb)
	var logo_slot := Control.new()
	logo_slot.custom_minimum_size = Vector2(240, 36)
	vb.add_child(logo_slot)
	var logo := UiKit.label("夜幕幸存者", "gold", UiKit.FONT_L, HORIZONTAL_ALIGNMENT_CENTER)
	logo.size = Vector2(240, 30)
	logo.add_theme_constant_override("outline_size", 6)
	logo_slot.add_child(logo)
	vb.add_child(UiKit.label("金币 %d" % int(Save.data.gold), "lemon", UiKit.FONT_S, HORIZONTAL_ALIGNMENT_CENTER))
	var buttons := [
		["开始", func(): app.show_character_select()],
		["强化", func(): app.show_shop()],
		["图鉴", func(): app.show_collection()],
		["设置", func(): app.show_settings()],
		["退出", func(): get_tree().quit()],
	]
	var first: Button = null
	for b in buttons:
		var btn := UiKit.button(b[0], b[1], 120)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(btn)
		if first == null:
			first = btn
	vb.add_child(UiKit.label("WASD / 方向键 / 手柄移动 · Esc 暂停", "dusk", UiKit.FONT_S, HORIZONTAL_ALIGNMENT_CENTER))
	MotionPlayer.play(logo, "motion.ui.banner_drop")
	first.grab_focus.call_deferred()
