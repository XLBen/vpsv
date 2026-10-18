# 美术工作室

用网页技术制作素材，再导出给 Godot 使用：

| 素材种类 | 制作方式 | 导出结果 |
| --- | --- | --- |
| 序列帧（角色、怪物、图标、特效造型、界面边框、地面图块） | SVG + CSS / Web Animations API / GSAP | 像素图集 PNG（一行一个动画片段） |
| 动效曲线（界面入场、悬停、宝箱演出、滚动揭示……） | CSS 关键帧、WAAPI、GSAP 时间轴、Motion 弹簧 | JSON 逐帧曲线，Godot 的 `MotionPlayer` 应用到实时界面节点 |
| 音效 / 占位音乐 | Web Audio（OfflineAudioContext） | 16 位 WAV |
| 特效色带 | 调色板颜色列表 | N×1 PNG，着色器用它上色 |

## 命令

```bash
pnpm install
```

```bash
pnpm dev
```

`pnpm dev` 打开预览器：可浏览全部素材、实时播放、对照导出结果。

```bash
pnpm export
```

`pnpm export` 全量导出到 `../assets` 并调用 Godot 导入；`pnpm export --only='icon.*'` 只导出匹配的 id。

## 规则

- 每个文件 `src/assets/**/*.ts` 默认导出一个或一组 `Spec`（类型见 `src/runtime/spec.ts`），id 全局唯一。
- **确定性**：导出时所有动画暂停，再逐帧跳转（`src/runtime/time-driver.ts`）。
  - CSS / WAAPI 动画会自动处理。
  - GSAP 时间轴用 `gsapDriver(tl)` 返回。
  - Motion 的 `animate()` 用 `motionDriver(controls)` 返回。
  - 不要用 `setTimeout` 或 `requestAnimationFrame` 推进动画。
- **像素化**：
  - 按原尺寸渲染，SVG 关闭抗锯齿。
  - 导出后 alpha 以 128 为阈值二值化，颜色吸附到 `src/runtime/palette.ts` 的统一调色板。
  - 改调色板会影响全部素材。
- **约定**：
  - 角色和怪物的动画片段固定为 `idle`(4) `walk`(6) `hurt`(2) `death`(6)，首领多一个 `attack`(4)，统一朝右。
  - 立绘的 clip 名就是表情名。
  - 九宫格边框在 tags 里写 `margin:N`。
- **特效造型**：只用灰阶，由 Godot 着色器按色带上色。这样普通版和进化版可以共用一张图。
- **音频**：导出时峰值归一化（`peak`，默认 0.8）。游戏里的实际音量、间隔、复音和连拾音阶在 `../content/audio.json` 里调。
- 两次全量导出的结果是字节级一致的，可以放心提交。
