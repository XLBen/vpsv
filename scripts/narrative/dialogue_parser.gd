extends RefCounted
## 剧本解析器（.vsd 纯文本格式），输出指令列表与标签表。
##
## 语法：
##   // 注释
##   # 标签名
##   角色: 台词            （台词中可用 {变量} 插值；角色可写角色 id 或任意名字）
##   : 旁白                （冒号前为空即旁白；没有冒号的普通行也视为旁白）
##   ? 选项文字 -> 标签     （连续的 ? 行组成一组选项；可加条件：? [变量 >= 1] 文字 -> 标签）
##   @bg 素材id | none
##   @show 角色 left|center|right [表情]
##   @hide 角色 | all
##   @cg 素材id [差分序号] | off
##   @set 变量 = 值         （值：数字 / "字符串" / true / false / 变量 + 数字）
##   @if 条件 -> 标签       （条件：变量 / not 变量 / 变量 ==|!=|>=|<=|>|< 值）
##   @jump 标签
##   @sfx 音效id   @bgm 音乐id | stop   @wait 秒
##   @end

var commands: Array = []
var labels := {}
var errors: Array[String] = []


func parse_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		errors.append("找不到剧本：%s" % path)
		return false
	return parse(FileAccess.get_file_as_string(path))


func parse(text: String) -> bool:
	commands.clear()
	labels.clear()
	errors.clear()
	var lines := text.split("\n")
	var pending_choices: Array = []
	for i in lines.size():
		var raw := lines[i].strip_edges()
		var ln := i + 1
		if raw.begins_with("?"):
			pending_choices.append(_parse_choice(raw.substr(1).strip_edges(), ln))
			continue
		if not pending_choices.is_empty():
			commands.append({"op": "choice", "options": pending_choices, "line": ln - 1})
			pending_choices = []
		if raw == "" or raw.begins_with("//"):
			continue
		if raw.begins_with("#"):
			labels[raw.substr(1).strip_edges()] = commands.size()
		elif raw.begins_with("@"):
			_parse_command(raw.substr(1).strip_edges(), ln)
		else:
			var idx := raw.find(":")
			var idx_cn := raw.find("：")
			if idx < 0 or (idx_cn >= 0 and idx_cn < idx):
				idx = idx_cn
			if idx >= 0:
				commands.append({"op": "say", "speaker": raw.substr(0, idx).strip_edges(), "text": raw.substr(idx + 1).strip_edges(), "line": ln})
			else:
				commands.append({"op": "say", "speaker": "", "text": raw, "line": ln})
	if not pending_choices.is_empty():
		commands.append({"op": "choice", "options": pending_choices, "line": lines.size()})
	_validate()
	return errors.is_empty()


func _parse_choice(s: String, ln: int) -> Dictionary:
	var cond := ""
	if s.begins_with("["):
		var close := s.find("]")
		cond = s.substr(1, close - 1).strip_edges()
		s = s.substr(close + 1).strip_edges()
	var parts := s.split("->")
	if parts.size() != 2:
		errors.append("第 %d 行：选项需要写成 “? 文字 -> 标签”" % ln)
		return {"text": s, "label": "", "cond": cond}
	return {"text": parts[0].strip_edges(), "label": parts[1].strip_edges(), "cond": cond}


func _parse_command(s: String, ln: int) -> void:
	var words := s.split(" ", false)
	var op := words[0]
	var args := words.slice(1)
	match op:
		"bg":
			commands.append({"op": "bg", "id": args[0] if args.size() > 0 else "none", "line": ln})
		"show":
			if args.size() < 2:
				errors.append("第 %d 行：@show 需要 角色 位置 [表情]" % ln)
				return
			commands.append({"op": "show", "who": args[0], "pos": args[1], "expr": args[2] if args.size() > 2 else "normal", "line": ln})
		"hide":
			commands.append({"op": "hide", "who": args[0] if args.size() > 0 else "all", "line": ln})
		"cg":
			var id: String = args[0] if args.size() > 0 else "off"
			commands.append({"op": "cg", "id": id, "variant": int(args[1]) if args.size() > 1 else 0, "line": ln})
		"set":
			var expr := s.substr(4)
			var eq := expr.find("=")
			if eq < 0:
				errors.append("第 %d 行：@set 需要 “变量 = 值”" % ln)
				return
			commands.append({"op": "set", "var": expr.substr(0, eq).strip_edges(), "expr": expr.substr(eq + 1).strip_edges(), "line": ln})
		"if":
			var parts := s.substr(3).split("->")
			if parts.size() != 2:
				errors.append("第 %d 行：@if 需要 “条件 -> 标签”" % ln)
				return
			commands.append({"op": "if", "cond": parts[0].strip_edges(), "label": parts[1].strip_edges(), "line": ln})
		"jump":
			commands.append({"op": "jump", "label": args[0] if args.size() > 0 else "", "line": ln})
		"sfx", "bgm":
			commands.append({"op": op, "id": args[0] if args.size() > 0 else "stop", "line": ln})
		"wait":
			commands.append({"op": "wait", "time": float(args[0]) if args.size() > 0 else 0.5, "line": ln})
		"end":
			commands.append({"op": "end", "line": ln})
		_:
			errors.append("第 %d 行：未知指令 @%s" % [ln, op])


func _validate() -> void:
	for c: Dictionary in commands:
		var targets := []
		if c.op in ["jump", "if"]:
			targets.append(c.label)
		elif c.op == "choice":
			for o: Dictionary in c.options:
				targets.append(o.label)
		for t: String in targets:
			if t != "" and not labels.has(t):
				errors.append("第 %d 行：找不到标签 “%s”" % [c.line, t])
