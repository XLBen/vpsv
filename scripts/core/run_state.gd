extends RefCounted
## 一局游戏的状态：时间、击杀、等级与经验（原版经验曲线）、金币、宝箱计数、升级操作次数。

var stage_id := ""
var character_id := ""
var time := 0.0
var kills := 0
var level := 1
var xp := 0.0
var gold := 0.0
var chests := 0
var rerolls := 0
var skips := 0
var banishes := 0
var banished := {}            # 被封禁的武器/被动 id
var revivals_used := 0
var xp_bonus := 0.0           # 临时经验加成（华美之月）
var xp_bonus_until := -1.0
var pending_levels := 0


## 从 l 级升到 l+1 级需要的经验（原版规则）：
## 2 级需要 5；20 级以内每级 +10；21–40 级每级 +13，且升到 21 级额外 +600；
## 41 级起每级 +16，且升到 41 级额外 +2400。
static func xp_to_next(l: int) -> float:
	var r := 5.0
	for i in range(2, l + 1):
		r += 10.0 if i < 20 else (13.0 if i < 40 else 16.0)
	if l == 20:
		r += 600.0
	elif l == 40:
		r += 2400.0
	return r


## 升到 21 级、41 级的那一级经验需求很高，原版在此期间给 +100% 成长。
func growth_bonus() -> float:
	var b := 1.0 if (level == 20 or level == 40) else 0.0
	if time < xp_bonus_until:
		b += xp_bonus
	return b


## 加经验，返回本次升了几级。
func add_xp(v: float, growth: float) -> int:
	xp += v * (growth + growth_bonus())
	var ups := 0
	while xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		ups += 1
	pending_levels += ups
	return ups
