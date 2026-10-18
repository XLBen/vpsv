extends Control
## 局外强化商店。价格：第 n 级 = 基础价 × n + 公共附加费（每已购 1 级 +20）。可全部退款。

const UiKit := preload("res://scripts/ui/ui_kit.gd")
const MotionPlayer := preload("res://scripts/ui/motion_player.gd")

const FEE_PER_RANK := 20

var app: Node
var _gold: Label
var _grid: GridContainer
var _info: Label


static func total_ranks() -> int:
	var n := 0
	for id: String in Save.data.powerups:
		n += int(Save.data.powerups[id])
	return n


static func price(def: Resource) -> int:
	var next := Save.powerup_rank(def.id) + 1
	return def.base_cost * next + FEE_PER_RANK * total_ranks()


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
	var head := HBoxContainer.new()
	head.add_child(UiKit.label("强化", "gold", UiKit.FONT_L))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UiKit.icon("pickup.coin", 2))
	_gold = UiKit.label("", "lemon", UiKit.FONT_L)
	head.add_child(_gold)
	root.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(_grid)
	_info = UiKit.label("", "fog")
	root.add_child(_info)
	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_END
	nav.add_theme_constant_override("separation", 6)
	nav.add_child(UiKit.button("全部退款", _refund, 90))
	var back := UiKit.button("返回", func(): app.back(), 80)
	nav.add_child(back)
	root.add_child(nav)
	_rebuild()
	back.grab_focus.call_deferred()


func _rebuild() -> void:
	_gold.text = str(int(Save.data.gold))
	for c in _grid.get_children():
		c.queue_free()
	var i := 0
	for def in Registry.all("powerups"):
		var rank := Save.powerup_rank(def.id)
		var maxed: bool = rank >= def.max_rank
		var b := Button.new()
		b.custom_minimum_size = Vector2(112, 56)
		for s in ["normal", "disabled"]:
			b.add_theme_stylebox_override(s, UiKit.frame("ui.frame.card", "normal", 3))
		for s in ["hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(s, UiKit.frame("ui.frame.card", "hover", 3))
		var vb := VBoxContainer.new()
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_theme_constant_override("separation", 0)
		b.add_child(vb)
		vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(UiKit.icon(def.icon, 1))
		top.add_child(UiKit.label(def.name, "white"))
		vb.add_child(top)
		vb.add_child(UiKit.label("■".repeat(rank) + "□".repeat(def.max_rank - rank), "gold"))
		vb.add_child(UiKit.label("已满" if maxed else str(price(def)), "dusk" if maxed else "lemon"))
		b.pressed.connect(_buy.bind(def))
		b.focus_entered.connect(func(): _info.text = "%s：%s" % [def.name, def.desc])
		b.mouse_entered.connect(func(): _info.text = "%s：%s" % [def.name, def.desc])
		_grid.add_child(b)
		MotionPlayer.play(b, "motion.ui.card_in", 0.03 * i)
		i += 1


func _buy(def: Resource) -> void:
	var rank := Save.powerup_rank(def.id)
	var cost := price(def)
	if rank >= def.max_rank or int(Save.data.gold) < cost:
		Audio.play("sfx.ui.deny")
		return
	Save.data.gold = int(Save.data.gold) - cost
	Save.data.powerup_spent = int(Save.data.get("powerup_spent", 0)) + cost
	Save.data.powerups[def.id] = rank + 1
	Save.write()
	Audio.play("sfx.ui.buy")
	_rebuild()


func _refund() -> void:
	Save.data.gold = int(Save.data.gold) + int(Save.data.get("powerup_spent", 0))
	Save.data.powerup_spent = 0
	Save.data.powerups = {}
	Save.write()
	Audio.play("sfx.ui.coin_tick")
	_rebuild()
