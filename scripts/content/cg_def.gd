extends Resource
## galgame CG 条目。图片都是素材 id，由 Assets 解析，可放占位图。

@export var id := ""
@export var title := ""
@export var thumbnail := ""
@export var variants: Array[String] = []      ## 差分图素材 id
@export var order := 0
@export var hidden_until_unlocked := true
