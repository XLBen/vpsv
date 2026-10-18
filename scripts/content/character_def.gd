extends Resource
## 可选角色。

@export var id := ""
@export var order := 0                         ## 列表排序（小的在前）
@export var name := ""
@export_multiline var desc := ""
@export var sprite := ""                      ## 素材 id，例如 actor.hero.whip
@export var portrait := ""                    ## 对话立绘 id（可空）
@export var start_weapon := ""
@export var stats := {}                       ## 属性加成，例如 {"max_hp": 20, "might": 0.1}
## 成长：每 every 级给 stat 加 amount，最多 cap。
@export var growth_stat := ""
@export var growth_every := 10
@export var growth_amount := 0.1
@export var growth_cap := 0.5
@export var unlock := ""                      ## 解锁条件 id（空表示默认解锁），见 scripts/core/unlocks.gd
@export var unlock_desc := ""
