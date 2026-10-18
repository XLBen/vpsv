extends RefCounted
## 解锁与成就条件。条件 id 写在角色 / 关卡数据的 unlock 字段里；空表示默认解锁。

## 条件 id → 说明文字（界面显示用）
const CONDITION_TEXT := {
	"survive_10": "在任意关卡存活 10 分钟",
	"survive_30": "在任意关卡存活 30 分钟",
	"kills_100": "累计击败 100 个敌人",
	"kills_3000": "累计击败 3000 个敌人",
	"forest_reach_lv_20": "在疯狂森林达到 20 级",
	"evolve_any": "进化任意一把武器",
	"gold_5000": "累计获得 5000 金币",
}

## 成就：id → [名称, 条件 id]
const ACHIEVEMENTS := {
	"first_blood": ["初次狩猎", "kills_100"],
	"survivor_10": ["夜幕行者", "survive_10"],
	"survivor_30": ["破晓", "survive_30"],
	"slayer": ["屠戮者", "kills_3000"],
	"evolver": ["蜕变", "evolve_any"],
	"rich": ["富甲一方", "gold_5000"],
}


static func is_unlocked(kind: String, def: Resource) -> bool:
	if def.unlock == "":
		return true
	return Save.is_unlocked(kind, def.id)


## 判定条件是否已达成（基于存档统计与本局结果）。
static func check(cond: String, result: Dictionary = {}) -> bool:
	var st: Dictionary = Save.data.stats
	match cond:
		"survive_10":
			return result.get("time", 0.0) >= 600.0 or _best_time() >= 600.0
		"survive_30":
			return result.get("time", 0.0) >= 1800.0 or _best_time() >= 1800.0
		"kills_100":
			return int(st.get("kills", 0)) >= 100
		"kills_3000":
			return int(st.get("kills", 0)) >= 3000
		"forest_reach_lv_20":
			return int(st.get("best_level", {}).get("forest", 0)) >= 20
		"evolve_any":
			for id: String in Save.data.seen.weapons:
				var d: Resource = Registry.weapon(id)
				if d != null and d.is_evolution:
					return true
			return false
		"gold_5000":
			return int(st.get("gold_earned", 0)) >= 5000
	return false


static func _best_time() -> float:
	var best := 0.0
	for k in Save.data.stats.get("best_time", {}):
		best = maxf(best, float(Save.data.stats.best_time[k]))
	return best


## 结算后调用：记录统计，返回新解锁的内容描述列表。
static func apply_result(result: Dictionary) -> Array:
	var st: Dictionary = Save.data.stats
	st.kills = int(st.get("kills", 0)) + int(result.kills)
	st.runs = int(st.get("runs", 0)) + 1
	st.gold_earned = int(st.get("gold_earned", 0)) + int(result.gold)
	var bt: Dictionary = st.get("best_time", {})
	bt[result.stage] = maxf(float(bt.get(result.stage, 0.0)), float(result.time))
	st.best_time = bt
	var bl: Dictionary = st.get("best_level", {})
	bl[result.stage] = maxi(int(bl.get(result.stage, 0)), int(result.level))
	st.best_level = bl
	Save.data.gold = int(Save.data.gold) + int(result.gold)
	var news := []
	for kind: String in ["characters", "stages"]:
		for def in Registry.all(kind):
			if def.unlock != "" and not Save.is_unlocked(kind, def.id) and check(def.unlock, result):
				Save.unlock(kind, def.id)
				news.append("解锁：" + def.name)
	for id: String in ACHIEVEMENTS:
		if not (id in Save.data.achievements) and check(ACHIEVEMENTS[id][1], result):
			Save.data.achievements.append(id)
			news.append("成就：" + ACHIEVEMENTS[id][0])
	Save.write()
	return news
