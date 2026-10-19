extends SceneTree
## 素材替换工具：
##   godot --headless --path . -s res://tools/assets_tool.gd -- <命令> [参数]
## 命令：
##   list [前缀]          列出素材 id、中文说明、尺寸与动画片段（例如 list actor.enemy）
##   unpack <id|前缀*>    把现有素材拆成单帧 PNG，放进 assets/overrides/<分类>/<id>/，直接改这些图即可替换
##                        （音效、色带、动效曲线复制一份同名文件）。已存在的不覆盖，加 --force 覆盖。
##   check                检查替换目录：哪些素材被替换了、整理结果、尺寸问题、认不出的文件名
##   catalog              重新生成 assets/素材清单.md（全部素材的 id、说明、尺寸、片段）

const Overrides := preload("res://scripts/assets/overrides.gd")
const OUT_ROOT := "res://assets/overrides"
const CATALOG := "res://assets/素材清单.md"
const CLIP_CN := {"idle": "待机", "walk": "行走", "hurt": "受伤", "death": "死亡", "attack": "攻击", "normal": "常态", "open": "打开", "break": "破碎"}

## id 前缀 → 分类文件夹（unpack 放到这里，清单按它分组）。按顺序匹配，越具体越靠前。
const CATEGORIES := [
	["actor.hero.", "角色"], ["actor.enemy.", "怪物"], ["actor.boss.", "首领"],
	["icon.weapon.", "武器图标"], ["icon.passive.", "被动图标"], ["icon.ui.", "界面图标"],
	["pickup.", "拾取物"], ["prop.", "场景道具"], ["vfx.", "武器特效"], ["tile.", "地面"],
	["ui.", "界面边框"], ["portrait.", "立绘"], ["cg.", "CG"], ["bg.", "对话背景"],
	["ramp.", "特效色带"], ["motion.", "动效曲线"], ["bgm.", "音乐"], ["sfx.", "音效"],
]
const PREFIX_DESC := {
	"ui.frame.": "界面边框（九宫格，四周 margin 像素不拉伸）", "ui.pattern.": "界面底纹",
	"icon.ui.": "升级界面按钮图标", "prop.chest": "宝箱", "prop.brazier": "可破坏光源：火盆",
	"prop.candelabra": "可破坏光源：烛台", "ramp.": "特效色带（着色器按亮度取色）",
	"motion.ui.": "界面动效曲线", "motion.chest.": "宝箱演出动效曲线", "motion.fx.": "特效动效曲线",
	"sfx.ui.": "界面音效", "sfx.chest.": "宝箱演出音效", "sfx.enemy.": "怪物音效", "sfx.player.": "玩家音效",
	"sfx.pickup.": "拾取音效", "sfx.hit.": "命中音效", "sfx.prop.": "光源破碎音效",
	"cg.": "CG", "bg.": "对话背景", "portrait.": "立绘", "vfx.hit.": "命中火花",
}

var _desc := {}
var _frame := 0


func _process(_dt: float) -> bool:
	_frame += 1
	if _frame < 3:
		return false   # 等自动加载就绪
	var args := Array(OS.get_cmdline_user_args())
	var force := args.has("--force")
	args.erase("--force")
	_build_desc()
	match args[0] if not args.is_empty() else "":
		"list":
			_list(args[1] if args.size() > 1 else "")
		"unpack":
			if args.size() < 2:
				print("用法：unpack <素材 id 或 前缀*>，例如 unpack actor.enemy.bat 或 unpack actor.enemy.*")
			else:
				_unpack(args[1], force)
		"check":
			_check()
		"catalog":
			_catalog()
		_:
			print("命令：list [前缀] · unpack <id|前缀*> [--force] · check · catalog（详见 tools/assets_tool.gd 文件头）")
	quit()
	return true


func _assets() -> Node:
	return root.get_node("Assets")


static func category(id: String) -> String:
	for c in CATEGORIES:
		if id.begins_with(c[0]):
			return c[1]
	return "其它"


## 素材的中文说明：从内容数据（角色、怪物、武器……）里反查谁在用它。
func _build_desc() -> void:
	var reg: Node = root.get_node("Registry")
	var add := func(id: String, text: String) -> void:
		if id == "":
			return
		if not _desc.has(id):
			_desc[id] = []
		if not (text in _desc[id]):
			_desc[id].append(text)
	for d in reg.all("characters"):
		add.call(d.sprite, "角色：" + d.name)
		add.call(d.get("portrait") if d.get("portrait") else "", "立绘：" + d.name)
	for d in reg.all("enemies"):
		add.call(d.sprite, ("首领：" if d.boss else "怪物：") + d.name)
	for d in reg.all("weapons"):
		add.call(d.icon, "武器图标：" + d.name)
		for role in d.vfx:
			add.call(d.vfx[role], "%s 的特效造型（%s）" % [d.name, role])
		add.call(d.sfx, "%s 出手音效" % d.name)
	for d in reg.all("passives"):
		add.call(d.icon, "被动图标：" + d.name)
	for d in reg.all("pickups"):
		add.call(d.sprite, "拾取物：" + d.name)
		add.call(d.sfx, "拾取音效：" + d.name)
	for d in reg.all("stages"):
		add.call(d.tileset, "地面图块：" + d.name)
		add.call(d.bgm, "背景音乐：" + d.name)


func describe(id: String) -> String:
	if _desc.has(id):
		return "、".join(_desc[id])
	var best := ""
	for p: String in PREFIX_DESC:
		if id.begins_with(p) and p.length() > best.length():
			best = p
	return PREFIX_DESC.get(best, "")


func _shape(id: String, e: Dictionary) -> String:
	match e.get("type"):
		"sheet":
			var parts := []
			var clips: Dictionary = e.get("clips", {})
			var names := clips.keys()
			names.sort_custom(func(a, b): return int(clips[a].row) < int(clips[b].row))
			for c in names:
				parts.append("%s %d 帧" % [CLIP_CN.get(c, c), int(clips[c].frames)])
			return "%d×%d，%s" % [e.size[0], e.size[1], " · ".join(parts)]
		"audio":
			return "音频"
		"motion":
			return "动效曲线"
		"ramp":
			return "色带"
	return ""


func _ids(prefix: String) -> Array:
	var ids: Array = _assets().manifest.keys()
	ids.sort()
	if prefix.ends_with("*"):
		prefix = prefix.trim_suffix("*")
		return ids.filter(func(i): return i.begins_with(prefix))
	if _assets().manifest.has(prefix):
		return [prefix]
	return ids.filter(func(i): return i.begins_with(prefix))


func _list(prefix: String) -> void:
	for id in _ids(prefix):
		var e: Dictionary = _assets().manifest[id]
		print("%-30s %-24s %s" % [id, describe(id), _shape(id, e)])


# ------------------------------------------------------------ 拆帧

func _unpack(pattern: String, force: bool) -> void:
	var ids := _ids(pattern)
	if ids.is_empty():
		print("没有找到素材：%s（用 list 查看全部 id）" % pattern)
		return
	for id: String in ids:
		var e: Dictionary = _assets().manifest[id]
		var dir := OUT_ROOT.path_join(category(id))
		match e.get("type"):
			"sheet":
				_unpack_sheet(id, e, dir.path_join(id), force)
			_:
				var src: String = _assets().resolve(e.file)
				var dst := dir.path_join(id + "." + String(e.file).get_extension())
				if FileAccess.file_exists(dst) and not force:
					print("跳过 %s：已存在 %s（加 --force 覆盖）" % [id, dst])
					continue
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
				var bytes := FileAccess.get_file_as_bytes(src)
				if bytes.is_empty() and ResourceLoader.exists(src):
					# 已导入的资源（导出后的游戏里没有原文件）：图片可以重新存成 PNG
					var t = load(src)
					if t is Texture2D:
						(t as Texture2D).get_image().save_png(ProjectSettings.globalize_path(dst))
						print("已拆出 %s → %s" % [id, dst])
						continue
				var f := FileAccess.open(dst, FileAccess.WRITE)
				f.store_buffer(bytes)
				f.close()
				print("已复制 %s → %s" % [id, dst])
	print("改完图片后直接运行游戏即可看到效果；想恢复原样就删掉对应文件或文件夹。用 check 命令检查。")


func _unpack_sheet(id: String, e: Dictionary, dir: String, force: bool) -> void:
	if DirAccess.dir_exists_absolute(dir) and not force:
		print("跳过 %s：已存在 %s（加 --force 覆盖）" % [id, dir])
		return
	var info = _assets().sheet(id)
	var img: Image = info.texture.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var n := 0
	for c: String in info.clips:
		var clip: Dictionary = info.clips[c]
		for i in int(clip.frames):
			var fr := img.get_region(Rect2i(Vector2i(i * info.size.x, int(clip.row) * info.size.y), info.size))
			fr.save_png(ProjectSettings.globalize_path(dir.path_join("%s_%d.png" % [c, i])))
			n += 1
	var txt := FileAccess.open(dir.path_join("说明.txt"), FileAccess.WRITE)
	txt.store_string("""素材：%s
用途：%s
原尺寸：每帧 %d×%d 像素，轴心（脚底 / 中心）在 (%d, %d)
动画片段：%s

怎么改：
- 直接修改这些 PNG。文件名是「片段_序号.png」，片段名也可以写中文：待机 / 行走 / 受伤 / 死亡 / 攻击。
- 可以增删帧（序号连续即可），也可以整体换成别的尺寸；各帧尺寸最好一致。
- 只想用一张静态图：删掉其它帧，只留一张，所有动作都会用它。
- 缺少的动作会自动借用其它动作（受伤 → 待机，死亡 → 受伤 …）。
- 帧率、轴心、缩放等可以在本文件夹放 meta.json，例如：{"fps": 10, "scale": 0.5}
- 删掉整个文件夹即可恢复原素材。
""" % [id, describe(id), info.size.x, info.size.y, info.pivot.x, info.pivot.y, _shape(id, e)])
	txt.close()
	print("已拆出 %s：%d 帧 → %s" % [id, n, dir])


# ------------------------------------------------------------ 检查

func _check() -> void:
	var A := _assets()
	var ids: Array = A.overrides.keys().filter(func(k): return not k.begins_with("_"))
	ids.sort()
	print("替换目录：%s" % ", ".join(A.override_dirs.map(func(d): return ProjectSettings.globalize_path(d))))
	if ids.is_empty() and A.overrides._unknown.is_empty() and not A.overrides.has("_font"):
		print("还没有任何替换品。用 unpack <素材 id> 拆出一份开始改，或直接放入以素材 id 命名的文件 / 文件夹。")
	var bad := 0
	for id: String in ids:
		var e: Dictionary = A.manifest[id]
		var ov: Dictionary = A.overrides[id]
		var how := "帧文件夹" if ov.has("dir") else "文件"
		var where: String = ov.get("dir", ov.get("file", ""))
		var result := ""
		match e.get("type"):
			"sheet":
				var info = A.sheet(id)
				var shown := {"size": [info.size.x, info.size.y], "clips": info.clips, "type": "sheet"}
				result = _shape(id, shown) + "，轴心 (%d, %d)" % [info.pivot.x, info.pivot.y]
				if not info.replaced:
					result = "未能使用（见下方问题），仍用原素材"
			"audio":
				result = "可播放" if A.sound(id) != null else "读不出音频"
			"motion":
				result = "可读取" if not A.motion(id).is_empty() else "读不出曲线"
			"ramp":
				result = "%d 色" % A.texture(id).get_width()
		var problems: Array = A.override_problems.get(id, [])
		var mark := "✓" if problems.is_empty() and not result.begins_with("未能") and not result.begins_with("读不出") else "!"
		if mark == "!":
			bad += 1
		print("%s %s（%s）\n    %s：%s\n    结果：%s" % [mark, id, describe(id), how, where, result])
		for p in problems:
			print("    问题：%s" % p)
	if A.overrides.has("_font"):
		print("✓ 字体：%s" % A.overrides._font)
	for path: String in A.overrides._unknown:
		var base := path.get_file().get_basename()
		var best := ""
		var score := 0.0
		for id: String in A.manifest:
			var s := base.similarity(id)
			if s > score:
				score = s
				best = id
		bad += 1
		print("? 认不出：%s\n    文件名要和素材 id 完全一致%s" % [path, "，是不是想写 %s？" % best if score > 0.5 else "（用 list 查看全部 id）"])
	print("共 %d 个替换品，%d 处需要注意。" % [ids.size(), bad])


# ------------------------------------------------------------ 清单

func _catalog() -> void:
	var A := _assets()
	var groups := {}
	var ids: Array = A.manifest.keys()
	ids.sort()
	for id: String in ids:
		var c := category(id)
		if not groups.has(c):
			groups[c] = []
		groups[c].append(id)
	var lines := PackedStringArray()
	lines.append("# 素材清单")
	lines.append("")
	lines.append("由 `tools/assets_tool.gd catalog` 生成，请勿手改。替换方法见 [assets/overrides/说明.md](overrides/说明.md)。")
	lines.append("")
	lines.append("把文件或文件夹命名为下表的「素材 id」，放进 `assets/overrides/`（可以建子文件夹整理）即可替换。")
	lines.append("")
	for c in CATEGORIES.map(func(x): return x[1]) + ["其它"]:
		if not groups.has(c):
			continue
		lines.append("## %s（%d）" % [c, groups[c].size()])
		lines.append("")
		lines.append("| 素材 id | 说明 | 规格 |")
		lines.append("| --- | --- | --- |")
		for id: String in groups[c]:
			lines.append("| `%s` | %s | %s |" % [id, describe(id), _shape(id, A.manifest[id])])
		lines.append("")
	var f := FileAccess.open(CATALOG, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	print("已生成 %s（%d 个素材）" % [CATALOG, ids.size()])
