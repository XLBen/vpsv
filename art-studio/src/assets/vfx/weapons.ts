// 武器特效的“造型层”：投射物、刀光、飞鸟等像素序列帧。
// 颜色只用中性亮色（白 / 浅灰），具体色调由 Godot 端着色器按色带重新上色，
// 这样同一张图可以给普通版和进化版（不同色带）复用。
import { Grid } from '../../runtime/grid';
import { frameSteps, pivot, pixels, svgEl, tr } from '../../runtime/pixel';
import type { ColorKey } from '../../runtime/palette';
import type { SheetSpec } from '../../runtime/spec';

// 灰阶键：1 最暗 … 4 最亮（着色器把亮度映射到色带）
const GRAY: Record<string, ColorKey> = { '1': 'dusk', '2': 'mist', '3': 'fog', '4': 'white', o: 'ink' };

function still(id: string, size: [number, number], paint: (g: Grid) => void, outline = true): SheetSpec {
  return {
    kind: 'sheet',
    id,
    size,
    pivot: [Math.floor(size[0] / 2), Math.floor(size[1] / 2)],
    fps: 8,
    clips: { idle: { frames: 1, loop: true } },
    tags: ['vfx'],
    build(root) {
      const g = new Grid(size[0], size[1]);
      paint(g);
      pixels(root, g.rows(outline), GRAY);
    },
  };
}

/** 刀光：一道新月形弧线从左到右扫出，随后变细消散（SVG 路径 + WAAPI 描边动画）。 */
const slash: SheetSpec = {
  kind: 'sheet',
  id: 'vfx.whip.slash',
  size: [64, 16],
  pivot: [32, 8],
  fps: 20,
  clips: { idle: { frames: 6 } },
  tags: ['vfx'],
  build(root) {
    const outer = svgEl('path', { d: 'M 2 12 Q 32 -4 62 10', fill: 'none', stroke: '#f4ecf0', 'stroke-width': 5, 'stroke-linecap': 'round', pathLength: 100 }, root);
    const core = svgEl('path', { d: 'M 4 12 Q 32 -2 60 10', fill: 'none', stroke: '#ffffff', 'stroke-width': 2, 'stroke-linecap': 'round', pathLength: 100 }, root);
    for (const [p, w] of [[outer, 5], [core, 2]] as const) {
      p.style.strokeDasharray = '100';
      frameSteps(
        p,
        [
          { strokeDashoffset: '70', strokeWidth: `${w}` },
          { strokeDashoffset: '30', strokeWidth: `${w}` },
          { strokeDashoffset: '0', strokeWidth: `${w}` },
          { strokeDashoffset: '0', strokeWidth: `${Math.max(1, w - 1)}` },
          { strokeDashoffset: '-30', strokeWidth: `${Math.max(1, w - 2)}` },
          { strokeDashoffset: '-70', strokeWidth: '1' },
        ],
        20,
        false,
      );
    }
  },
};

/** 魔法弹：脉动的光球。 */
const bolt: SheetSpec = {
  kind: 'sheet',
  id: 'vfx.wand.bolt',
  size: [10, 10],
  pivot: [5, 5],
  fps: 12,
  clips: { idle: { frames: 4, loop: true } },
  tags: ['vfx'],
  build(root) {
    const g = new Grid(10, 10).ellipse(5, 5, 3.5, 3.5, '2').ellipse(5, 5, 2.4, 2.4, '3').ellipse(4.5, 4.5, 1.2, 1.2, '4');
    const orb = pivot(pixels(root, g.rows(false), GRAY), '50% 50%');
    frameSteps(orb, [1, 1.15, 1.25, 1.1].map((s) => ({ transform: `scale(${s})` })), 12);
  },
};

/** 火球：头部亮、尾焰向后飘动（朝右）。 */
const fireball: SheetSpec = {
  kind: 'sheet',
  id: 'vfx.fire.ball',
  size: [14, 10],
  pivot: [9, 5],
  fps: 12,
  clips: { idle: { frames: 4, loop: true } },
  tags: ['vfx'],
  build(root) {
    const tails = [0, 1, 2, 3].map((i) => {
      const g = new Grid(14, 10);
      const wob = [0, 1, 0, -1][i];
      g.tri(9, 2, 9, 8, 1, 5 + wob, '1').tri(9, 3, 9, 7, 3, 5 - wob * 0.5, '2');
      const gr = pixels(root, g.rows(false), GRAY);
      frameSteps(gr, [0, 1, 2, 3].map((j) => ({ opacity: j === i ? 1 : 0 })), 12);
      return gr;
    });
    void tails;
    const head = new Grid(14, 10).ellipse(9.5, 5, 3.5, 3.5, '3').ellipse(10, 4.5, 2, 2, '4');
    pixels(root, head.rows(false), GRAY);
  },
};

/** 符文：菱形，内部光点流转。 */
const rune: SheetSpec = {
  kind: 'sheet',
  id: 'vfx.rune.diamond',
  size: [10, 10],
  pivot: [5, 5],
  fps: 12,
  clips: { idle: { frames: 4, loop: true } },
  tags: ['vfx'],
  build(root) {
    const g = new Grid(10, 10).tri(5, 0.5, 0.5, 5, 9.5, 5, '3').tri(0.5, 5, 9.5, 5, 5, 9.5, '2');
    pixels(root, g.rows(false), GRAY);
    const dot = pixels(root, ['4'], GRAY, 5, 2);
    frameSteps(dot, [tr(0, 0), tr(2, 3), tr(0, 5), tr(-2, 3)], 12);
  },
};

/** 飞鸟：拍翅 4 帧（白 / 黑两种，羽色固定，不走色带）。 */
function bird(id: string, body: ColorKey, wing: ColorKey, beak: ColorKey): SheetSpec {
  return {
    kind: 'sheet',
    id,
    size: [16, 12],
    pivot: [8, 6],
    fps: 10,
    clips: { idle: { frames: 4, loop: true } },
    tags: ['vfx'],
    build(root) {
      const keys = { m: body, w: wing, b: beak, o: 'ink' as ColorKey, e: 'ink' as ColorKey };
      const g = new Grid(16, 12).ellipse(7, 7, 4.5, 2.6, 'm').ellipse(11, 5.5, 2.2, 2.2, 'm').rect(13, 5, 2, 1, 'b').set(11, 5, 'e').tri(1, 7, 4, 6, 3, 9, 'm');
      pixels(root, g.rows(), keys);
      const wingG = new Grid(16, 12).tri(5, 6, 10, 6, 6, 0.5, 'w');
      const wg = pivot(pixels(root, wingG.rows(), keys), '50% 100%');
      frameSteps(wg, [1, 0.4, -0.6, 0.4].map((s) => ({ transform: `scaleY(${s})` })), 10);
    },
  };
}

export default [
  slash,
  bolt,
  fireball,
  rune,
  still('vfx.knife.blade', [14, 6], (g) => {
    g.rect(5, 2, 7, 2, '3').tri(11, 1.5, 11, 4.5, 14, 3, '4').rect(4, 1, 1, 4, '2').rect(1, 2, 3, 2, '1');
  }),
  still('vfx.axe.spin', [16, 16], (g) => {
    g.line(4, 14, 11, 3, '1', 2);
    g.ellipse(10.5, 5.5, 4.5, 4.5, '3').shade((x) => x < 9, '.').shade((x, y) => y > 6, '2', '3');
    g.line(4, 14, 9, 7, '1', 2);
  }),
  still('vfx.cross.spin', [12, 12], (g) => {
    g.rect(4, 1, 4, 10, '3').rect(1, 4, 10, 4, '3').shade((x, y) => x < 5 || y < 5, '4', '3').rect(5, 5, 2, 2, '2');
  }),
  still('vfx.bible.book', [10, 12], (g) => {
    g.rect(1, 1, 8, 10, '2').rect(7, 2, 2, 8, '4').rect(1, 9, 8, 2, '1').rect(3, 3, 2, 5, '3').rect(2, 4, 4, 2, '3');
  }),
  still('vfx.water.bottle', [8, 10], (g) => {
    g.ellipse(4, 6.5, 3.2, 3, '3').rect(3, 1, 2, 3, '4').rect(2.5, 0, 3, 1, '1');
  }),
  still('vfx.clock.beam', [16, 4], (g) => {
    g.rect(0, 1, 16, 2, '3').rect(4, 1, 12, 1, '4');
  }, false),
  bird('vfx.bird.white', 'paper', 'fog', 'gold'),
  bird('vfx.bird.black', 'shadow', 'night', 'red'),
] satisfies SheetSpec[];
