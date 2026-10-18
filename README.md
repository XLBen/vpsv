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
| `content/dialogue/*.vsd` | galgame 剧本（纯文本，语法见 `scripts/narrative/dialogue_parser.gd` 文件头） |
| `scripts/core/` | 总控 `game.gd`、属性 `stats.gd`、经验 `run_state.gd`、注册表、存档、解锁、输入 |
| `scripts/weapons/` | `weapon_base.gd` + 每把武器一个行为脚本（进化形态复用行为、换参数） |
| `scripts/combat/` | 敌人（MultiMesh 批量渲染）、投射物与区域、拾取物与光源、空间网格 |
| `scripts/stage/spawner.gd` | 按分钟波次刷怪、首领、蝙蝠群 / 幽灵群 / 花墙事件、死神 |
| `scripts/render/` | 序列帧批量渲染、特效、地面 |
| `scripts/ui/` | HUD、升级、宝箱演出、暂停、结算、标题、选角选关、商店、图鉴、设置、MotionPlayer |
| `scripts/narrative/` | 对话解析 / 运行 / 界面、CG 登记与画廊（**已内置，暂未接入玩法**） |
| `shaders/` | `sprite_batch`（受击闪白、冻结、溶解、首领描边）、`player`、`weapons/*`、`screen/vignette`、`ui/*`、`fx/*` |
| `tools/` | 自动试玩 `autoplay.gd`、单元测试 `tests/run_tests.gd`、对话冒烟测试 |

## 常见改动

- **换图 / 换音效**：把同名文件放进 `assets/overrides/`（例如 `assets/overrides/sheets/actor.enemy.bat.png`）。帧数或尺寸也要变时，在 `assets/overrides/manifest.json` 里写同 id 的条目覆盖清单。
- **改数值**：在 Godot 里打开 `content/weapons/whip.tres` 等资源直接改；武器升级表是 `levels` 数组。
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

## 导出注意

`assets/manifest.json`、`assets/generated/motion/*.json`、`content/audio.json`、`content/dialogue/*.vsd` 是非资源文件。导出时要在导出预设的「过滤器 → 非资源文件」里加入 `*.json, *.vsd`。
