extends Control
## CG 画廊：缩略图网格（滚动驱动的入场动效）+ 全屏查看器（左右切换差分）。
## 目前没有接入菜单；需要时 add_child(CgGallery.new()) 即可。

const CgRegistry := preload("res://scripts/narrative/cg_registry.gd")
const UiKit := preload("res://scripts/ui/ui_kit.gd")
const MotionPlayer := preload("res://scripts/ui/motion_player.gd")

signal closed

var _scroll: ScrollContainer
var _grid: GridContainer
var _cells: Array[Control] = []
var _viewer: TextureRect
var _view_id := ""
var _view_variant := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	add_child(UiKit.dim(0.85))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var root := VBoxContainer.new()
	margin.add_child(root)
	root.add_child(UiKit.label("回忆", "gold", UiKit.FONT_L))
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	_scroll.add_child(_grid)
	var back := UiKit.button("返回", func():
		closed.emit()
		queue_free(), 80)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	root.add_child(back)
	for def in CgRegistry.all():
		_grid.add_child(_cell(def))
	_viewer = TextureRect.new()
	_viewer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_viewer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_viewer.visible = false
	_viewer.gui_input.connect(_viewer_input)
	add_child(_viewer)


func _cell(def: Resource) -> Control:
	var unlocked := CgRegistry.is_unlocked(def.id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(140, 90)
	var img := TextureRect.new()
	img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if unlocked:
		img.texture = Assets.frame_texture(def.thumbnail if def.thumbnail != "" else CgRegistry.image(def.id), "idle", 0)
	b.add_child(img)
	b.text = "" if unlocked else "？"
	b.tooltip_text = def.title if unlocked else ""
	b.disabled = not unlocked
	b.pressed.connect(func(): _open(def.id))
	_cells.append(b)
	return b


func _open(id: String) -> void:
	_view_id = id
	_view_variant = 0
	_show_variant()
	_viewer.visible = true


func _show_variant() -> void:
	_viewer.texture = Assets.frame_texture(CgRegistry.image(_view_id, _view_variant), "idle", 0)


func _viewer_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		var d: Resource = CgRegistry.get_def(_view_id)
		if ev.button_index == MOUSE_BUTTON_RIGHT or _view_variant >= d.variants.size() - 1:
			_viewer.visible = false
		else:
			_view_variant += 1
			_show_variant()


func _process(_dt: float) -> void:
	var view := _scroll.get_global_rect()
	for c in _cells:
		var r := c.get_global_rect()
		MotionPlayer.apply_progress(c, "motion.ui.scroll_reveal", clampf((view.end.y - r.position.y) / 80.0, 0.0, 1.0) * 0.6)
