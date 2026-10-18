extends RefCounted
## 手感参数（content/feel.json）：闪白、击退、命中火花、死亡碎屑、伤害数字、投射物消散……
## 和 audio.json 一样，改数值不用改代码。各武器自己的手感字段在 WeaponDef 的「手感」分组里。

const PATH := "res://content/feel.json"

static var _data := {}


static func v(key: String, default: Variant = null) -> Variant:
	if _data.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = d if d is Dictionary else {"_empty": true}
	return _data.get(key, default)


static func f(key: String, default := 0.0) -> float:
	return float(v(key, default))


## 重新读取（调参时热更新用）。
static func reload() -> void:
	_data = {}
