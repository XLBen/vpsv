// 界面九宫格边框（星露谷式木框 + 深色底）。Godot 端用 StyleBoxTexture 九宫格拉伸，
// 每个素材的 tags 里记录九宫格边距：margin:<像素>。
import { Grid } from '../../runtime/grid';
import { pixels } from '../../runtime/pixel';
import type { ColorKey } from '../../runtime/palette';
import type { SheetSpec } from '../../runtime/spec';

interface FrameStyle {
  outer: ColorKey;   // 最外圈描边
  frame: ColorKey;   // 边框主体
  light: ColorKey;   // 边框高光（左上）
  dark: ColorKey;    // 边框暗部（右下）
  fill: ColorKey;    // 内部
  inner?: ColorKey;  // 内侧一圈细线
  corner?: ColorKey; // 四角铆钉
}

/** 画一个带斜面的像素边框：描边 1 + 边框 bw + 内侧线 1。 */
function frame(g: Grid, w: number, h: number, s: FrameStyle, bw: number) {
  g.rect(0, 0, w, h, 'O');
  g.rect(1, 1, w - 2, h - 2, 'F');
  g.rect(1, 1, w - 2, 1, 'L').rect(1, 1, 1, h - 2, 'L');
  g.rect(1, h - 2, w - 2, 1, 'D').rect(w - 2, 1, 1, h - 2, 'D');
  g.rect(1 + bw, 1 + bw, w - 2 - bw * 2, h - 2 - bw * 2, s.inner ? 'I' : 'B');
  if (s.inner) g.rect(2 + bw, 2 + bw, w - 4 - bw * 2, h - 4 - bw * 2, 'B');
  // 去掉最外圈四个角，做成圆角
  g.set(0, 0, '.').set(w - 1, 0, '.').set(0, h - 1, '.').set(w - 1, h - 1, '.');
  if (s.corner) for (const [x, y] of [[2, 2], [w - 3, 2], [2, h - 3], [w - 3, h - 3]]) g.set(x, y, 'C');
}

function keys(s: FrameStyle): Record<string, ColorKey> {
  return { O: s.outer, F: s.frame, L: s.light, D: s.dark, B: s.fill, I: s.inner ?? s.fill, C: s.corner ?? s.light };
}

/** 多状态九宫格：每个 clip 一帧（静态）。 */
function frameSet(id: string, size: number, bw: number, margin: number, states: Record<string, FrameStyle>): SheetSpec {
  return {
    kind: 'sheet',
    id,
    size: [size, size],
    pivot: [0, 0],
    fps: 1,
    clips: Object.fromEntries(Object.keys(states).map((k) => [k, { frames: 1 }])),
    tags: ['ui', `margin:${margin}`],
    drawFrame(root, clip) {
      const g = new Grid(size, size);
      frame(g, size, size, states[clip], bw);
      pixels(root, g.cells.map((r) => r.join('')), keys(states[clip]));
    },
  };
}

const wood: FrameStyle = { outer: 'ink', frame: 'clay', light: 'tan', dark: 'wood', fill: 'night', inner: 'bark', corner: 'gold' };
const card: FrameStyle = { outer: 'ink', frame: 'shadow', light: 'dusk', dark: 'night', fill: 'night', inner: 'ink' };
const cardHot: FrameStyle = { outer: 'ink', frame: 'amber', light: 'gold', dark: 'clay', fill: 'shadow', inner: 'ink' };
const btn: FrameStyle = { outer: 'ink', frame: 'clay', light: 'tan', dark: 'wood', fill: 'wood' };
const btnHot: FrameStyle = { outer: 'ink', frame: 'tan', light: 'cream', dark: 'clay', fill: 'clay' };
const btnDown: FrameStyle = { outer: 'ink', frame: 'wood', light: 'bark', dark: 'tan', fill: 'bark' };
const btnOff: FrameStyle = { outer: 'ink', frame: 'shadow', light: 'dusk', dark: 'night', fill: 'night' };
const slot: FrameStyle = { outer: 'ink', frame: 'shadow', light: 'dusk', dark: 'night', fill: 'ink' };
const bar: FrameStyle = { outer: 'ink', frame: 'shadow', light: 'dusk', dark: 'night', fill: 'ink' };

export default [
  frameSet('ui.frame.panel', 24, 3, 8, { normal: wood }),
  frameSet('ui.frame.card', 24, 2, 6, { normal: card, hover: cardHot }),
  frameSet('ui.frame.button', 16, 2, 5, { normal: btn, hover: btnHot, pressed: btnDown, disabled: btnOff }),
  frameSet('ui.frame.slot', 12, 1, 4, { normal: slot }),
  frameSet('ui.frame.bar', 8, 1, 3, { normal: bar }),
] satisfies SheetSpec[];
