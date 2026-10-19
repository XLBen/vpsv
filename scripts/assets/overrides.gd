extends RefCounted
## 素材替换：在替换目录里按“文件名 / 文件夹名 = 素材 id”找到替换品，并把它整理成游戏能直接用的样子。
##
## 替换目录（后面的优先）：
##   res://assets/overrides/   项目内，随游戏一起导出
##   user://overrides/         用户数据目录，导出后的游戏也能直接放文件替换（无需重新导出）
## 目录内可以随意建子文件夹整理；以 . 或 _ 开头的文件和文件夹会被忽略。
##
## 序列帧素材（角色、怪物、图标、特效造型、界面边框……）三种放法：
##   1. 帧文件夹  actor.enemy.bat/walk_0.png walk_1.png idle_0.png …（片段名也可用中文：待机 / 行走 / 受伤 / 死亡 / 攻击；
##      也可以每个片段一个子文件夹 walk/0.png …）。缺少的片段自动借用其它片段（受伤 → 待机 …）。
##   2. 整张图集  actor.enemy.bat.png，布局与原图相同（一行一个片段），帧可以整体放大缩小。
##   3. 单张图    actor.enemy.bat.png，尺寸对不上图集时视为一张静态图，所有片段都用它。
## 可选的设置文件（与素材同名的 .json，或帧文件夹里的 meta.json）：
##   {"fps": 10, "pivot": [8, 15], "scale": 0.5, "fit": true, "align": "bottom",
##    "size": [32, 32], "clips": {"walk": {"fps": 12, "loop": true}}}
## 音效 / 音乐：同名 .wav / .ogg / .mp3。动效曲线：同名 .json。色带：同名 .png。字体：font.ttf / .otf / .woff2。

const DIRS := ["res://assets/overrides", "user://overrides"]
const IMAGE_EXT := ["png", "webp", "jpg", "jpeg"]
const AUDIO_EXT := ["wav", "ogg", "mp3"]
const FONT_EXT := ["ttf", "otf", "woff", "woff2"]
const CLIP_ALIAS := {
	"待机": "idle", "站立": "idle", "行走": "walk", "走": "walk", "移动": "walk",
	"受伤": "hurt", "受击": "hurt", "死亡": "death", "死": "death", "攻击": "attack",
}
## 缺少某个片段时依次借用的片段。
const FALLBACK := {
	"idle": ["walk"], "walk": ["idle"], "hurt": ["idle", "walk"],
	"death": ["hurt", "idle", "walk"], "attack": ["idle", "walk"],
}
## 这些前缀的素材在界面里按固定尺寸显示，替换图默认缩放到原尺寸（fit）。
const FIT_PREFIXES := ["icon.", "pickup."]


## 扫描所有替换目录。返回 {id: {"file": 路径, "meta": 路径, "dir": 路径}}，
## 另有 "_font"（字体路径）与 "_unknown"（无法对应到素材 id 的文件，供检查工具提示）。
static func scan(known: Dictionary, dirs: Array = DIRS) -> Dictionary:
	var out := {"_unknown": []}
	for root: String in dirs:
		_scan_dir(root, known, out)
	return out


static func _scan_dir(path: String, known: Dictionary, out: Dictionary) -> void:
	for name: String in list_dir(path):
		if name.begins_with(".") or name.begins_with("_"):
			continue
		var full := path.path_join(name.trim_suffix("/"))
		if name.ends_with("/"):
			var id := name.trim_suffix("/")
			if known.has(id) and known[id].get("type") == "sheet":
				var o: Dictionary = out.get(id, {})
				o.erase("file")
				o["dir"] = full
				out[id] = o
			else:
				_scan_dir(full, known, out)
			continue
		var ext := name.get_extension().to_lower()
		var base := name.get_basename()
		if base.to_lower() == "font" and ext in FONT_EXT:
			out["_font"] = full
			continue
		if name == "manifest.json" or not (ext in IMAGE_EXT or ext in AUDIO_EXT or ext == "json"):
			continue
		if not known.has(base):
			if ext != "json":
				out._unknown.append(full)
			continue
		var type: String = known[base].get("type", "")
		var o: Dictionary = out.get(base, {})
		if type == "sheet" and ext == "json":
			o["meta"] = full
		elif (type in ["sheet", "ramp"] and ext in IMAGE_EXT) or (type == "audio" and ext in AUDIO_EXT) or (type == "motion" and ext == "json"):
			o.erase("dir")
			o["file"] = full
		else:
			out._unknown.append(full)
			continue
		out[base] = o


## 列出目录内容（子目录以 / 结尾）。项目内目录在导出后只剩导入产物，这里统一还原成原始文件名。
static func list_dir(path: String) -> PackedStringArray:
	var names := {}
	if path.begins_with("res://") and DirAccess.dir_exists_absolute(path):
		for n in ResourceLoader.list_directory(path):
			names[n] = true
	var d := DirAccess.open(path)
	if d:
		for n in d.get_files():
			names[n.trim_suffix(".import").trim_suffix(".remap")] = true
		for n in d.get_directories():
			names[n + "/"] = true
	var out := PackedStringArray(names.keys())
	out.sort()
	return out


static func read_json(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


## 读取图片：已被 Godot 导入的走资源系统，新放进去还没导入的直接读文件。统一转成 RGBA8。
static func load_image(path: String) -> Image:
	var img: Image = null
	if ResourceLoader.exists(path):
		var t = load(path)
		if t is Texture2D:
			img = (t as Texture2D).get_image()
	if img == null and FileAccess.file_exists(path):
		img = Image.load_from_file(path)
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img


static func load_audio(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		var s = load(path)
		if s is AudioStream:
			return s
	match path.get_extension().to_lower():
		"wav":
			return AudioStreamWAV.load_from_file(path)
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		"mp3":
			return AudioStreamMP3.load_from_file(path)
	return null


static func load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		var f = load(path)
		if f is Font:
			return f
	var ff := FontFile.new()
	return ff if ff.load_dynamic_font(path) == OK else null


# ------------------------------------------------------------ 序列帧

## 片段名：中文别名 → 英文；去掉首尾空格与下划线。
static func clip_name(raw: String) -> String:
	var n := raw.strip_edges().trim_suffix("_").trim_suffix("-").strip_edges()
	# “bat_walk”“蝙蝠-行走”之类带前缀的名字只取最后一段
	for sep in ["_", "-", " "]:
		if n.contains(sep):
			n = n.get_slice(sep, n.get_slice_count(sep) - 1)
	return CLIP_ALIAS.get(n, n.to_lower())


## 把替换品整理成 [清单条目, 图集 Image, 问题列表]。entry 为原导出清单里的条目。
static func build_sheet(id: String, entry: Dictionary, ov: Dictionary) -> Array:
	var problems: Array[String] = []
	var meta := read_json(ov.get("meta", ""))
	if ov.has("dir"):
		meta.merge(read_json(String(ov.dir).path_join("meta.json")), true)
		return _from_frames(id, entry, ov.dir, meta, problems)
	var img := load_image(ov.get("file", ""))
	if img == null:
		problems.append("读不出图片：%s" % ov.get("file", ""))
		return [entry, null, problems]
	return _from_image(id, entry, img, meta, problems)


## 原清单的片段顺序（按行号）。
static func _clip_order(entry: Dictionary) -> Array:
	var names: Array = entry.get("clips", {}).keys()
	names.sort_custom(func(a, b): return int(entry.clips[a].row) < int(entry.clips[b].row))
	return names


static func _from_frames(id: String, entry: Dictionary, dir: String, meta: Dictionary, problems: Array[String]) -> Array:
	# 收集帧：clip → [[序号, Image], …]
	var got := {}
	var re := RegEx.create_from_string("^(.*?)[_\\-\\s]*(\\d+)$")
	for name: String in list_dir(dir):
		if name.begins_with(".") or name.begins_with("_"):
			continue
		if name.ends_with("/"):
			var clip := clip_name(name.trim_suffix("/"))
			var i := 0
			for f: String in list_dir(dir.path_join(name.trim_suffix("/"))):
				if f.get_extension().to_lower() in IMAGE_EXT:
					var m := re.search(f.get_basename())
					_add_frame(got, clip, int(m.get_string(2)) if m else i, dir.path_join(name.trim_suffix("/")).path_join(f), problems)
					i += 1
			continue
		if not (name.get_extension().to_lower() in IMAGE_EXT):
			continue
		var base := name.get_basename()
		var m := re.search(base)
		if m:
			_add_frame(got, clip_name(m.get_string(1)) if m.get_string(1) != "" else "_all", int(m.get_string(2)), dir.path_join(name), problems)
		else:
			_add_frame(got, clip_name(base), 0, dir.path_join(name), problems)
	if got.is_empty():
		problems.append("帧文件夹里没有图片：%s" % dir)
		return [entry, null, problems]
	for c in got:
		got[c].sort_custom(func(a, b): return a[0] < b[0])
	# 帧尺寸 = 所有帧中最大的宽高（设置文件可指定）；尺寸不一致时对齐摆放并提示
	var w := 0
	var h := 0
	var sizes := {}
	for c in got:
		for fr in got[c]:
			var s: Vector2i = fr[1].get_size()
			sizes[s] = true
			w = maxi(w, s.x)
			h = maxi(h, s.y)
	if sizes.size() > 1:
		problems.append("各帧尺寸不一致（%s），已按 %d×%d 对齐摆放" % [", ".join(sizes.keys().map(func(s): return "%d×%d" % [s.x, s.y])), w, h])
	if meta.has("size"):
		w = int(meta.size[0])
		h = int(meta.size[1])
	var esize := Vector2i(entry.size[0], entry.size[1]) if entry.has("size") else Vector2i(w, h)
	var epivot := Vector2i(entry.pivot[0], entry.pivot[1]) if entry.has("pivot") else Vector2i(w / 2, h - 1)
	var bottom: bool = String(meta.get("align", "bottom" if epivot.y >= esize.y - 2 else "center")) == "bottom"
	# 片段：原清单的片段一个不少（缺的借用），再加上新增的片段
	var order := _clip_order(entry)
	for c in got:
		if c != "_all" and not (c in order):
			order.append(c)
	var frames := {}
	for c: String in order:
		var src = got.get(c)
		if src == null:
			for alt in FALLBACK.get(c, []):
				if got.has(alt):
					src = got[alt]
					break
		if src == null:
			src = got.get("_all", got.values()[0])
		frames[c] = src
	var cols := 1
	for c in frames:
		cols = maxi(cols, frames[c].size())
	var atlas := Image.create(cols * w, order.size() * h, false, Image.FORMAT_RGBA8)
	var clips := {}
	var eclips: Dictionary = entry.get("clips", {})
	var mclips: Dictionary = meta.get("clips", {})
	var fps := float(meta.get("fps", entry.get("fps", 8)))
	for row in order.size():
		var c: String = order[row]
		for i in frames[c].size():
			var img: Image = frames[c][i][1]
			var s := img.get_size()
			var ox := (w - s.x) / 2
			var oy := h - s.y if bottom else (h - s.y) / 2
			atlas.blit_rect(img, Rect2i(Vector2i.ZERO, s), Vector2i(i * w + ox, row * h + oy))
		var ec: Dictionary = eclips.get(c, {})
		var mc: Dictionary = mclips.get(c, {})
		clips[c] = {
			"row": row, "frames": frames[c].size(),
			"fps": float(mc.get("fps", ec.get("fps", fps))),
			"loop": bool(mc.get("loop", ec.get("loop", c in ["idle", "walk"]))),
		}
	var e := entry.duplicate(true)
	e["size"] = [w, h]
	e["clips"] = clips
	e["fps"] = fps
	e["pivot"] = meta.get("pivot", _scaled_pivot(epivot, esize, Vector2i(w, h), bottom))
	return _finish(id, entry, e, atlas, meta, problems)


static func _add_frame(got: Dictionary, clip: String, index: int, path: String, problems: Array[String]) -> void:
	var img := load_image(path)
	if img == null:
		problems.append("读不出图片：%s" % path)
		return
	if not got.has(clip):
		got[clip] = []
	got[clip].append([index, img])


static func _from_image(id: String, entry: Dictionary, img: Image, meta: Dictionary, problems: Array[String]) -> Array:
	var W := img.get_width()
	var H := img.get_height()
	var esize := Vector2i(entry.size[0], entry.size[1])
	var epivot := Vector2i(entry.pivot[0], entry.pivot[1])
	var order := _clip_order(entry)
	var ecols := 1
	for c in order:
		ecols = maxi(ecols, int(entry.clips[c].frames))
	var erows := 0
	for c in order:
		erows = maxi(erows, int(entry.clips[c].row) + 1)
	var e := entry.duplicate(true)
	var bottom: bool = String(meta.get("align", "bottom" if epivot.y >= esize.y - 2 else "center")) == "bottom"
	if meta.has("size"):
		# 设置文件指定了帧尺寸：按原布局切
		var fs := Vector2i(int(meta.size[0]), int(meta.size[1]))
		e["size"] = [fs.x, fs.y]
		e["pivot"] = meta.get("pivot", _scaled_pivot(epivot, esize, fs, bottom))
		if meta.has("clips"):
			var clips := {}
			var row := 0
			for c: String in meta.clips:
				var mc: Dictionary = meta.clips[c]
				clips[clip_name(c)] = {"row": int(mc.get("row", row)), "frames": int(mc.get("frames", 1)), "fps": float(mc.get("fps", meta.get("fps", entry.get("fps", 8)))), "loop": bool(mc.get("loop", true))}
				row += 1
			e["clips"] = clips
	elif W == ecols * esize.x and H == erows * esize.y:
		pass   # 与原图集布局完全一致
	elif W % ecols == 0 and H % erows == 0 and (W / ecols) * esize.y == (H / erows) * esize.x:
		# 同样的布局、整体放大或缩小
		var fs := Vector2i(W / ecols, H / erows)
		e["size"] = [fs.x, fs.y]
		e["pivot"] = meta.get("pivot", _scaled_pivot(epivot, esize, fs, bottom))
	else:
		# 尺寸对不上图集：当作一张静态图，所有片段都用它
		var clips := {}
		var row := 0
		for c: String in order:
			clips[c] = {"row": 0, "frames": 1, "fps": float(entry.clips[c].get("fps", entry.get("fps", 8))), "loop": bool(entry.clips[c].get("loop", false))}
			row += 1
		e["size"] = [W, H]
		e["clips"] = clips
		e["pivot"] = meta.get("pivot", _scaled_pivot(epivot, esize, Vector2i(W, H), bottom))
	if meta.has("fps"):
		e["fps"] = float(meta.fps)
		for c in e.clips:
			e.clips[c]["fps"] = float(meta.get("clips", {}).get(c, {}).get("fps", meta.fps))
	return _finish(id, entry, e, img, meta, problems)


## 按设置缩放（scale，或 fit：缩放到原帧尺寸），并做尺寸提示。
static func _finish(id: String, entry: Dictionary, e: Dictionary, atlas: Image, meta: Dictionary, problems: Array[String]) -> Array:
	var fs := Vector2i(e.size[0], e.size[1])
	var esize := Vector2i(entry.size[0], entry.size[1]) if entry.has("size") else fs
	var k := float(meta.get("scale", 1.0))
	var fit: bool = meta.get("fit", FIT_PREFIXES.any(func(p): return id.begins_with(p)))
	if fit and fs != esize:
		k = minf(float(esize.x) / fs.x, float(esize.y) / fs.y)
	if not is_equal_approx(k, 1.0):
		var nfs := Vector2i(maxi(1, roundi(fs.x * k)), maxi(1, roundi(fs.y * k)))
		var cols := atlas.get_width() / fs.x
		var rows := atlas.get_height() / fs.y
		atlas.resize(cols * nfs.x, rows * nfs.y, Image.INTERPOLATE_NEAREST if k > 1.0 else Image.INTERPOLATE_BILINEAR)
		var pv := Vector2i(e.pivot[0], e.pivot[1])
		e["pivot"] = [roundi(pv.x * k), mini(nfs.y - 1, roundi(pv.y * k))]
		e["size"] = [nfs.x, nfs.y]
		fs = nfs
	if fs.x > esize.x * 3 or fs.y > esize.y * 3:
		problems.append("帧尺寸 %d×%d 比原素材 %d×%d 大很多，游戏里会显得很大；可在设置文件里加 \"scale\": %.2f" % [fs.x, fs.y, esize.x, esize.y, float(esize.y) / fs.y])
	return [e, atlas, problems]


## 帧尺寸变化后保持轴心的相对位置（站在地上的素材保持脚底在最下一行）。
static func _scaled_pivot(p: Vector2i, old: Vector2i, new: Vector2i, bottom: bool) -> Array:
	var x := roundi(float(p.x) / maxf(1.0, old.x) * new.x)
	var y := new.y - 1 if bottom else roundi(float(p.y) / maxf(1.0, old.y) * new.y)
	return [x, y]
