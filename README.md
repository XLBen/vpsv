# 夜幕幸存者（开发中）

Godot 4.7 的类吸血鬼幸存者项目。画面是 640×360 的星露谷式像素风，按整数倍放大显示。

- 美术与音频全部和代码解耦：游戏代码只用逻辑 id（如 `actor.enemy.bat`、`sfx.pickup.gem`）。
- 素材在 `art-studio/` 里用 CSS / SVG / Web Animations API / GSAP / Motion / Web Audio 制作，导出为像素序列帧、动效曲线和 WAV。
- 武器特效、受伤效果等动态效果用 Godot 着色器实现。

## 运行

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

操作：WASD / 方向键 / 手柄移动，Esc / P / 手柄 Start 暂停；升级时按 1–4 选择；手机上按住拖动。

## 目录

| 位置 | 内容 |
| --- | --- |
| `art-studio/` | 美术工作室（Node + Vite + TS），只在开发时用，见其 README |
| `assets/generated/` | 工作室导出的序列帧、动效曲线、音效、色带（不要手改） |
| `assets/overrides/` | **美术手绘覆盖**：放入与 `generated/` 同路径的文件即替换，无需改代码 |
| `assets/manifest.json` | 导出清单：素材 id → 文件、尺寸、动画片段 |
| `assets/fonts/` | Fusion Pixel 12px 中文像素字体（OFL，许可证在 licenses/） |
| `content/` | 纯数据（.tres，可在 Godot 检查器中编辑）：武器、被动、角色、敌人、关卡、拾取物、局外强化、CG |
| `content/audio.json` | 每个音效的播放规则：间隔、复音、音高随机、音量、连拾音阶 |
| `content/feel.json` | 手感参数：闪白、击退、命中火花、死亡碎屑、伤害数字、投射物消散、怪物描边、顿帧 |
| `content/dialogue/*.vsd` | galgame 剧本（纯文本，语法见 `scripts/narrative/dialogue_parser.gd` 文件头） |
| `scripts/core/` | 总控 `game.gd`、属性 `stats.gd`、经验 `run_state.gd`、注册表、存档、解锁、输入 |
| `scripts/weapons/` | `weapon_base.gd` + 每把武器一个行为脚本（进化形态复用行为、换参数） |
| `scripts/combat/` | 敌人（MultiMesh 批量渲染）、投射物与区域、拾取物与光源、空间网格 |
| `scripts/stage/spawner.gd` | 按分钟波次刷怪、首领、蝙蝠群 / 幽灵群 / 花墙事件、死神 |
| `scripts/render/` | 序列帧批量渲染、特效、地面、绘制层级 `layers.gd`、判定框调试层 `debug_overlay.gd` |
| `scripts/ui/` | HUD、升级、宝箱演出、暂停、结算、标题、选角选关、商店、图鉴、设置、MotionPlayer |
| `scripts/narrative/` | 对话解析 / 运行 / 界面、CG 登记与画廊（**已内置，暂未接入玩法**） |
| `shaders/` | `sprite_batch`（受击闪白、冻结、溶解、首领描边）、`player`、`weapons/*`、`screen/vignette`、`ui/*`、`fx/*` |
| `tools/` | 自动试玩 `autoplay.gd`、单元测试 `tests/run_tests.gd`、对话冒烟测试 |

## 常见改动

- **换图 / 换音效**：把同名文件放进 `assets/overrides/`（例如 `assets/overrides/sheets/actor.enemy.bat.png`）。帧数或尺寸也要变时，在 `assets/overrides/manifest.json` 里写同 id 的条目覆盖清单。
- **改数值**：在 Godot 里打开 `content/weapons/whip.tres` 等资源直接改；武器升级表是 `levels` 数组。
- **调手感**：全局参数在 `content/feel.json`；每把武器在检查器的「手感」分组里有消散时长 `fade_out`、命中火花 `hit_fx`、命中音效 `hit_sfx`、命中屏震 `hit_shake`。偏小的投射物可在 `params` 里加 `visual_scale` 放大外观。
- **绘制层级**：世界内节点的 z 统一取自 `scripts/render/layers.gd`。贴地的特效（火池、光环）挂到 `game.ground_fx`，否则会盖住怪物。
- **判定**：投射物与近战判定对怪物的身体中心 `Enemy.center()`，贴地区域对脚底 `Enemy.pos`。跟随角色、有生效窗口的近战攻击用 `make_strike()`。
- **加武器**：在 `scripts/weapons/` 写一个继承 `weapon_base.gd` 的脚本（只写 `fire_one` / `fire` / `update`），再在 `content/weapons/` 新建 `WeaponDef` 资源指向它。注册表会自动发现。
- **加关卡**：新建 `content/stages/*.tres`，填写分钟波次 `waves`、事件 `events`、光源掉落表 `drops`。
- **剧情**（暂不使用）：写 `content/dialogue/xxx.vsd`，在任意界面 `add_child(DialogueView.new())` 后调用 `play("xxx")`；CG 在 `content/cg/` 登记。

## 测试

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tools/tests/run_tests.gd
```

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 20 -s res://tools/autoplay.gd -- --god --seconds=600
```

自动试玩的全部参数（截图、指定角色关卡、直接给武器等）见 `tools/autoplay.gd` 文件头。测试与自动试玩都不会写入真实存档。

**检查难度**：`--bot=kite` 用像真人一样的走位（躲开贴近的怪、扫宝石、走廊里一直朝一个方向跑），`--log` 每分钟打印等级、生命、怪数与武器，结束时打印受到伤害最多的怪物。

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 20 -s res://tools/autoplay.gd -- --bot=kite --log --seconds=1800 --character=imele --stage=library
```

**检查武器手感**：游戏中按 F3 显示判定框。也可以用武器实验室：不刷怪，只摆一片木桩，连拍拼成一张联系表。

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 -s res://tools/autoplay.gd -- --lab=whip:8 --lab-move=right --hitbox --burst=0.28:0.034:12 --seconds=0.8 --shot=/tmp/whip.png
```

## 导出

`export_presets.cfg` 已有 macOS 和 Windows 两个预设：
- 已包含非资源文件 `*.json, *.vsd`（素材清单、动效曲线、音效规则、手感参数、剧本）。
- 已排除 `tools/` 与 `art-studio/`。

打完整安装包需要先在 Godot 编辑器里安装导出模板。只打数据包（`.pck`）不需要模板：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-pack "macOS" build/vpsy.pck
```
