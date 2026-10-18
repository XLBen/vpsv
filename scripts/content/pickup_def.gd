extends Resource
## 拾取物。effect 由 scripts/combat/pickup_system.gd 解释。

@export var id := ""
@export var order := 0                         ## 列表排序（小的在前）
@export var name := ""
@export var sprite := ""
## xp · gold · heal · freeze · clear · vacuum · luck · chest
@export var effect := ""
@export var value := 0.0
@export var min_level := 0                    ## 光源掉落要求的玩家等级
@export var luck_affected := true
@export var sfx := ""
