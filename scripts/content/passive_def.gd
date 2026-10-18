extends Resource
## 被动道具：每级给某个玩家属性加固定值（见 scripts/core/stats.gd 的属性名）。

@export var id := ""
@export var order := 0                         ## 列表排序（小的在前）
@export var name := ""
@export var icon := ""
@export_range(1, 100) var rarity := 100
@export_range(1, 9) var max_level := 5
@export var stat := ""
@export var per_level := 0.1
@export var desc := ""                        ## 例如 “伤害 +10%”
@export var hidden := false
