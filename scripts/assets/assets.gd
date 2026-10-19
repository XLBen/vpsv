extends Node
## 素材解析器（自动加载 Assets）。游戏代码只用逻辑 id，这里负责找到文件：
##   1. 替换目录（assets/overrides/、user://overrides/）里以素材 id 命名的文件或帧文件夹优先，
##      规则见 scripts/assets/overrides.gd 与 assets/overrides/说明.md；
##   2. 否则用 assets/generated/ 下工作室导出的文件；
##   3. 找不到时返回醒目的占位图，并只警告一次。
## assets/overrides/manifest.json（可选，旧方式）中的条目会覆盖导出清单里的同 id 条目。

const MANIFEST := "res://assets/manifest.json"
const OVERRIDE_MANIFEST := "res://assets/overrides/manifest.json"
const FONT_PATH := "res://assets/fonts/fusion-pixel-12px.woff2"
const Overrides := preload("res://scripts/assets/overrides.gd")

var manifest := {}
var palette := {}
var font: Font
var _tex := {}
var _frames := {}
var _sounds := {}
var _motions := {}
var _warned := {}
var _missing: Texture2D
var override_dirs: Array = Overrides.DIRS
var overrides := {}               # 素材 id → 替换品位置（见 Overrides.scan）
var override_problems := {}       # 素材 id → 整理替换品时发现的问题（检查工具显示）


class SheetInfo:
	var id: String
	var texture: Texture2D
	var size: Vector2i
	var pivot: Vector2i
	var fps := 8.0
	var clips := {}       # name -> {row, frames, loop, fps}
	var cols := 1
	var rows := 1
	var replaced := false           # 来自替换目录

	func clip(name: String) -> Dictionary:
		if clips.has(name):
			return clips[name]
		return clips.values()[0] if not clips.is_empty() else {"row": 0, "frames": 1, "loop": true, "fps": fps}

	## 按已播放时间算帧号。
	func frame_at(clip_name: String, t: float) -> int:
		var c := clip(clip_name)
		var n: int = c.frames
		var f := int(t * float(c.fps))
		return f % n if c.loop else mini(f, n - 1)

	func clip_length(clip_name: String) -> float:
		var c := clip(clip_name)
		return float(c.frames) / float(c.fps)


func _ready() -> void:
	_load_manifest()
	_scan_overrides()
	_load_font()


func _scan_overrides() -> void:
	overrides = Overrides.scan(manifest, override_dirs)
	override_problems.clear()
	var n := overrides.size() - 1 - (1 if overrides.has("_font") else 0)
	if n > 0:
		print("素材替换：%d 个素材使用替换品" % n)


## 重新扫描替换目录并清空缓存（测试、调试用；已经创建的节点不会自动换图）。
func reload() -> void:
	_tex.clear()
	_frames.clear()
	_sounds.clear()
	_motions.clear()
	_warned.clear()
	_load_manifest()
	_scan_overrides()
	_load_font()


func _load_manifest() -> void:
	var data = _read_json(MANIFEST)
	if data is Dictionary:
		manifest = data.get("assets", {})
		palette = data.get("palette", {})
	else:
		push_error("找不到素材清单 %s，请先在 art-studio 中执行 pnpm export" % MANIFEST)
	var extra = _read_json(OVERRIDE_MANIFEST)
	if extra is Dictionary:
		for id: String in extra.get("assets", {}):
			manifest[id] = extra.assets[id]


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _load_font() -> void:
	if overrides.has("_font"):
		var of := Overrides.load_font(overrides._font)
		if of:
			font = of
			return
	var f := load(FONT_PATH) as FontFile
	if f == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Hiragino Sans GB", "PingFang SC", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
		sf.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		font = sf
		return
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	font = f


func has(id: String) -> bool:
	return manifest.has(id)


func entry(id: String) -> Dictionary:
	return manifest.get(id, {})


## 素材文件路径：覆盖目录优先。
func resolve(file: String) -> String:
	var over := "res://assets/overrides/" + file.trim_prefix("generated/")
	if ResourceLoader.exists(over) or FileAccess.file_exists(over):
		return over
	return "res://assets/" + file


func _warn(id: String, why: String) -> void:
	if not _warned.has(id):
		_warned[id] = true
		push_warning("素材缺失：%s（%s），使用占位图" % [id, why])


func missing_texture() -> Texture2D:
	if _missing == null:
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		for y in 8:
			for x in 8:
				img.set_pixel(x, y, Color(1, 0, 1) if (x / 2 + y / 2) % 2 == 0 else Color(0.1, 0, 0.1))
		_missing = ImageTexture.create_from_image(img)
	return _missing


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	# 未经 Godot 导入的新文件（例如美术刚放进 overrides）直接读图
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img:
			return ImageTexture.create_from_image(img)
	return null


func texture(id: String) -> Texture2D:
	if _tex.has(id):
		return _tex[id]
	var e := entry(id)
	var t: Texture2D = null
	if overrides.has(id) and overrides[id].has("file"):
		var img := Overrides.load_image(overrides[id].file)
		if img:
			t = ImageTexture.create_from_image(img)
	if t == null and not e.is_empty():
		t = _load_texture(resolve(e.file))
	if t == null:
		_warn(id, "无文件")
		t = missing_texture()
	_tex[id] = t
	return t


func sheet(id: String) -> SheetInfo:
	if _frames.has(id):
		return _frames[id]
	var s := SheetInfo.new()
	s.id = id
	var e := entry(id)
	if e.is_empty() or e.get("type") != "sheet":
		_warn(id, "清单中没有序列帧条目")
		s.texture = missing_texture()
		s.size = Vector2i(8, 8)
		s.pivot = Vector2i(4, 7)
		s.clips = {"idle": {"row": 0, "frames": 1, "loop": true, "fps": 1.0}}
	else:
		if overrides.has(id):
			# 替换品：整理成与导出图集相同的结构（帧尺寸、片段、轴心可能变化）
			var built: Array = Overrides.build_sheet(id, e, overrides[id])
			if not built[2].is_empty():
				override_problems[id] = built[2]
				for msg in built[2]:
					push_warning("素材替换 %s：%s" % [id, msg])
			if built[1] != null:
				e = built[0]
				_tex[id] = ImageTexture.create_from_image(built[1])
				s.replaced = true
		s.texture = texture(id)
		s.size = Vector2i(e.size[0], e.size[1])
		s.pivot = Vector2i(e.pivot[0], e.pivot[1])
		s.fps = e.get("fps", 8)
		for name: String in e.clips:
			var c: Dictionary = e.clips[name]
			s.clips[name] = {"row": int(c.row), "frames": int(c.frames), "loop": bool(c.get("loop", false)), "fps": float(c.get("fps", s.fps))}
		s.cols = maxi(1, s.texture.get_width() / s.size.x)
		s.rows = maxi(1, s.texture.get_height() / s.size.y)
	_frames[id] = s
	return s


## 帧在图集中的区域。
func region(id: String, clip: String, frame: int) -> Rect2:
	var s := sheet(id)
	var c := s.clip(clip)
	return Rect2(Vector2(frame * s.size.x, int(c.row) * s.size.y), Vector2(s.size))


## 为 AnimatedSprite2D 生成 SpriteFrames（缓存）。
func sprite_frames(id: String) -> SpriteFrames:
	var key := "sf:" + id
	if _frames.has(key):
		return _frames[key]
	var s := sheet(id)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for name: String in s.clips:
		var c: Dictionary = s.clips[name]
		sf.add_animation(name)
		sf.set_animation_speed(name, c.fps)
		sf.set_animation_loop(name, c.loop)
		for i in int(c.frames):
			var at := AtlasTexture.new()
			at.atlas = s.texture
			at.region = Rect2(Vector2(i * s.size.x, int(c.row) * s.size.y), Vector2(s.size))
			sf.add_frame(name, at)
	_frames[key] = sf
	return sf


## 单帧贴图（图标等）。
func frame_texture(id: String, clip := "idle", frame := 0) -> Texture2D:
	var key := "ft:%s:%s:%d" % [id, clip, frame]
	if _tex.has(key):
		return _tex[key]
	var at := AtlasTexture.new()
	at.atlas = sheet(id).texture
	at.region = region(id, clip, frame) if has(id) else Rect2(0, 0, 8, 8)
	_tex[key] = at
	return at


func sound(id: String) -> AudioStream:
	if _sounds.has(id):
		return _sounds[id]
	var e := entry(id)
	var s: AudioStream = null
	if overrides.has(id) and overrides[id].has("file"):
		s = Overrides.load_audio(overrides[id].file)
	if s == null and not e.is_empty():
		var p := resolve(e.file)
		if ResourceLoader.exists(p):
			s = load(p)
		elif FileAccess.file_exists(p):
			s = AudioStreamWAV.load_from_file(p)
	if s == null:
		_warn(id, "无音频")
	_sounds[id] = s
	return s


## 动效曲线（GSAP / Motion 导出的 JSON）。
func motion(id: String) -> Dictionary:
	if _motions.has(id):
		return _motions[id]
	var e := entry(id)
	var data = null
	if overrides.has(id) and overrides[id].has("file"):
		data = _read_json(overrides[id].file)
	if data == null and not e.is_empty():
		data = _read_json(resolve(e.file))
	if not (data is Dictionary):
		_warn(id, "无动效")
		data = {}
	_motions[id] = data
	return data


func ramp(id: String) -> Texture2D:
	return texture(id)


func color(key: String) -> Color:
	return Color(palette.get(key, "#ff00ff"))
