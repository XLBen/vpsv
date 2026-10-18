extends RefCounted
## 剧本运行器：执行解析后的指令，通过信号驱动界面（与界面完全分离，可单独测试）。
## 变量保存在存档的剧情变量里（Save.data.flags），已读行记录在 Save.data.read_lines。

const Parser := preload("res://scripts/narrative/dialogue_parser.gd")

signal said(speaker: String, text: String, read: bool)
signal choices_shown(options: Array)        # [{text, index}]
signal background_changed(id: String)
signal portrait_shown(who: String, pos: String, expr: String)
signal portrait_hidden(who: String)         # "all" 表示全部
signal cg_changed(id: String, variant: int) # id 为 "off" 表示关闭
signal sound_requested(kind: String, id: String)
signal wait_requested(seconds: float)
signal finished

var script_id := ""
var parser := Parser.new()
var pc := 0
var running := false
var waiting_choice := false
var backlog: Array = []       # [[speaker, text], ...]
var _choices: Array = []


func load_script(id: String) -> bool:
	script_id = id
	var ok := parser.parse_file("res://content/dialogue/%s.vsd" % id)
	for e in parser.errors:
		push_error("剧本 %s：%s" % [id, e])
	return ok


func load_text(id: String, text: String) -> bool:
	script_id = id
	return parser.parse(text)


func start(label := "") -> void:
	pc = parser.labels.get(label, 0) if label != "" else 0
	running = true
	waiting_choice = false
	advance()


## 推进到下一个需要等待的指令（台词、选项、等待、结束）。
func advance() -> void:
	if not running or waiting_choice:
		return
	var guard := 0
	while running and guard < 10000:
		guard += 1
		if pc >= parser.commands.size():
			_finish()
			return
		var c: Dictionary = parser.commands[pc]
		pc += 1
		match c.op:
			"say":
				var read := _mark_read(c.line)
				var text := interpolate(c.text)
				backlog.append([c.speaker, text])
				said.emit(c.speaker, text, read)
				return
			"choice":
				_choices = []
				var shown := []
				for o: Dictionary in c.options:
					if o.cond == "" or eval_cond(o.cond):
						shown.append({"text": interpolate(o.text), "index": _choices.size()})
						_choices.append(o)
				waiting_choice = true
				choices_shown.emit(shown)
				return
			"bg":
				background_changed.emit(c.id)
			"show":
				portrait_shown.emit(c.who, c.pos, c.expr)
			"hide":
				portrait_hidden.emit(c.who)
			"cg":
				if c.id != "off":
					unlock_cg_variant(c.id)
				cg_changed.emit(c.id, c.variant)
			"set":
				set_var(c.var, eval_expr(c.expr))
			"if":
				if eval_cond(c.cond):
					pc = parser.labels.get(c.label, pc)
			"jump":
				pc = parser.labels.get(c.label, pc)
			"sfx", "bgm":
				sound_requested.emit(c.op, c.id)
			"wait":
				wait_requested.emit(c.time)
				return
			"end":
				_finish()
				return


func choose(i: int) -> void:
	if not waiting_choice or i < 0 or i >= _choices.size():
		return
	waiting_choice = false
	backlog.append(["→", interpolate(_choices[i].text)])
	pc = parser.labels.get(_choices[i].label, pc)
	advance()


func _finish() -> void:
	running = false
	Save.write()
	finished.emit()


# ------------------------------------------------------------ 变量与表达式

func get_var(name: String) -> Variant:
	return Save.flag(name, 0)


func set_var(name: String, value: Variant) -> void:
	Save.set_flag(name, value)


## 值：数字、"字符串"、true/false、变量，或 “变量 + 数字 / 变量 - 数字”。
func eval_expr(expr: String) -> Variant:
	expr = expr.strip_edges()
	for op in [" + ", " - "]:
		var i := expr.find(op)
		if i > 0:
			var a = eval_expr(expr.substr(0, i))
			var b = eval_expr(expr.substr(i + 3))
			return float(a) + float(b) if op == " + " else float(a) - float(b)
	if expr.begins_with("\"") and expr.ends_with("\""):
		return expr.substr(1, expr.length() - 2)
	if expr == "true":
		return true
	if expr == "false":
		return false
	if expr.is_valid_float():
		return float(expr)
	return get_var(expr)


func eval_cond(cond: String) -> bool:
	cond = cond.strip_edges()
	if cond.begins_with("not "):
		return not eval_cond(cond.substr(4))
	for op in ["==", "!=", ">=", "<=", ">", "<"]:
		var i := cond.find(op)
		if i > 0:
			var a = eval_expr(cond.substr(0, i))
			var b = eval_expr(cond.substr(i + op.length()))
			if (a is float or a is int) and (b is float or b is int):
				a = float(a)
				b = float(b)
			match op:
				"==": return a == b
				"!=": return a != b
				">=": return a >= b
				"<=": return a <= b
				">": return a > b
				"<": return a < b
	var v = eval_expr(cond)
	return v != null and v != false and v != 0 and v != 0.0 and v != ""


func interpolate(text: String) -> String:
	var out := text
	var guard := 0
	while out.contains("{") and guard < 32:
		guard += 1
		var a := out.find("{")
		var b := out.find("}", a)
		if b < 0:
			break
		var name := out.substr(a + 1, b - a - 1)
		var v = get_var(name)
		var s := str(int(v)) if v is float and v == floorf(v) else str(v)
		out = out.substr(0, a) + s + out.substr(b + 1)
	return out


# ------------------------------------------------------------ 已读与 CG

func _mark_read(line: int) -> bool:
	var rl: Dictionary = Save.data.read_lines
	var list: Array = rl.get(script_id, [])
	# 存档经 JSON 读回后数字是 float，按数值比较
	var was := list.any(func(x): return int(x) == line)
	if not was:
		list.append(line)
		rl[script_id] = list
	return was


func unlock_cg_variant(id: String) -> void:
	if not (id in Save.data.cg):
		Save.data.cg.append(id)
