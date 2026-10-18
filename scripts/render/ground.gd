extends Node2D
## 地面：用关卡图块素材的变体，按固定种子拼出一张可无缝平铺的大贴图，跟随镜头重复绘制。
## 图块素材约定：第一个 clip 是底图变体，名为 deco 的 clip 是装饰变体。

const TILES := 32          # 平铺贴图边长（图块数）
const DECO_CHANCE := 0.09

var game: Node
var _sprite: Sprite2D
var _band := 0.0


func setup(g: Node, tileset_id: String, bounded_height: float) -> void:
	game = g
	_band = bounded_height
	z_index = -100
	_sprite = Sprite2D.new()
	_sprite.texture = _build(tileset_id)
	_sprite.centered = false
	_sprite.region_enabled = true
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_sprite.show_behind_parent = true   # 让本节点 _draw 的边界墙画在地面之上
	add_child(_sprite)


func _build(tileset_id: String) -> Texture2D:
	var info = Assets.sheet(tileset_id)
	var src: Image = info.texture.get_image()
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var ts: Vector2i = info.size
	var out := Image.create(TILES * ts.x, TILES * ts.y, false, Image.FORMAT_RGBA8)
	var names: Array = info.clips.keys()
	var base: Dictionary = info.clips[names[0]]
	var deco: Dictionary = info.clips.get("deco", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(tileset_id)
	for ty in TILES:
		for tx in TILES:
			var c := base
			if not deco.is_empty() and rng.randf() < DECO_CHANCE:
				c = deco
			var f := rng.randi_range(0, int(c.frames) - 1)
			out.blit_rect(src, Rect2i(f * ts.x, int(c.row) * ts.y, ts.x, ts.y), Vector2i(tx * ts.x, ty * ts.y))
	return ImageTexture.create_from_image(out)


func refresh(view: Rect2) -> void:
	var r := view.grow(32.0)
	_sprite.position = r.position.floor()
	_sprite.region_rect = Rect2(_sprite.position, r.size.ceil())
	queue_redraw()


func _draw() -> void:
	if _band <= 0.0:
		return
	# 纵向有边界的关卡：边界外画成书架墙
	var view: Rect2 = game.view_rect().grow(64.0)
	var wall := Assets.color("bark")
	var trim := Assets.color("wood")
	var top := -_band * 0.5
	var bottom := _band * 0.5
	draw_rect(Rect2(view.position.x, view.position.y, view.size.x, top - view.position.y), wall)
	draw_rect(Rect2(view.position.x, bottom, view.size.x, view.end.y - bottom), wall)
	draw_rect(Rect2(view.position.x, top - 3, view.size.x, 3), trim)
	draw_rect(Rect2(view.position.x, bottom, view.size.x, 3), trim)
	# 书脊
	var x0 := floorf(view.position.x / 6.0) * 6.0
	var keys := ["blood", "navy", "moss", "plum", "amber"]
	var x := x0
	while x < view.end.x:
		var k: String = keys[int(absf(x / 6.0)) % keys.size()]
		draw_rect(Rect2(x, top - 14, 4, 10), Assets.color(k))
		draw_rect(Rect2(x, bottom + 5, 4, 10), Assets.color(k))
		x += 6.0
