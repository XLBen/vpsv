// 场上拾取物与地图道具：经验宝石、金币、钱袋、烤鸡、念珠、吸尘器、怀表、小四叶草、宝箱、光源。
import { Grid } from '../../runtime/grid';
import { frameSteps, group, pivot, pixels, tr } from '../../runtime/pixel';
import { shine } from '../../runtime/shine';
import type { ColorKey } from '../../runtime/palette';
import type { SheetSpec } from '../../runtime/spec';

type Keys = Record<string, ColorKey>;
const base: Keys = { o: 'ink', z: 'white' };

function shiny(id: string, size: [number, number], keys: Keys, paint: (g: Grid) => void, tags: string[] = ['pickup']): SheetSpec {
  return {
    kind: 'sheet',
    id,
    size,
    pivot: [Math.floor(size[0] / 2), size[1] - 1],
    fps: 10,
    clips: { idle: { frames: 8, loop: true } },
    tags,
    build(root) {
      const g = new Grid(size[0], size[1]);
      paint(g);
      shine(root, pixels(root, g.rows(), { ...base, ...keys }), size[0], size[1], 10);
    },
  };
}

function gem(tier: string, m: ColorKey, d: ColorKey, l: ColorKey): SheetSpec {
  return {
    kind: 'sheet',
    id: `pickup.gem.${tier}`,
    size: [8, 10],
    pivot: [4, 9],
    fps: 10,
    clips: { idle: { frames: 6, loop: true } },
    tags: ['pickup', 'gem'],
    build(root) {
      const g = new Grid(8, 10);
      g.tri(4, 0.5, 0.8, 5, 7.2, 5, 'm').tri(0.8, 5, 7.2, 5, 4, 9.5, 'd').set(3, 3, 'l').set(3, 4, 'l');
      const body = pixels(root, g.rows(), { ...base, m, d, l });
      const spark = group(root);
      pixels(spark, ['.z.', 'zzz', '.z.'], base, 4, 0);
      frameSteps(spark, [0, 0, 0, 1, 1, 0].map((o) => ({ opacity: o })), 10);
      frameSteps(body, [tr(0, 0), tr(0, 0), tr(0, -1), tr(0, -1), tr(0, 0), tr(0, 0)], 10);
    },
  };
}

const coin: SheetSpec = {
  kind: 'sheet',
  id: 'pickup.coin',
  size: [8, 8],
  pivot: [4, 7],
  fps: 10,
  clips: { idle: { frames: 6, loop: true } },
  tags: ['pickup', 'gold'],
  build(root) {
    const g = new Grid(8, 8).ellipse(4, 4, 3.5, 3.5, 'm').ellipse(4, 4, 2, 2, 'l').rect(3.5, 2.5, 1, 3, 'd');
    const c = pivot(pixels(root, g.rows(), { ...base, m: 'gold', l: 'lemon', d: 'amber' }), '50% 50%');
    frameSteps(c, [1, 0.75, 0.35, 0.75, 1, 1].map((s) => ({ transform: `scaleX(${s})` })), 10);
  },
};

const vacuum: SheetSpec = {
  kind: 'sheet',
  id: 'pickup.vacuum',
  size: [12, 12],
  pivot: [6, 11],
  fps: 10,
  clips: { idle: { frames: 4, loop: true } },
  tags: ['pickup'],
  build(root) {
    const g = new Grid(12, 12).ring(6, 6, 5.5, 3.6, 'm').ring(6, 6, 2.6, 1, 'l');
    g.shade((x, y) => x > 6 && y < 6, 'd', 'm').shade((x, y) => x < 5 && y > 6, 'd', 'm');
    const c = pivot(pixels(root, g.rows(), { ...base, m: 'sky', d: 'navy', l: 'frost' }), '50% 50%');
    frameSteps(c, [0, 90, 180, 270].map((r) => ({ transform: `rotate(${r}deg)` })), 10);
  },
};

const chest: SheetSpec = {
  kind: 'sheet',
  id: 'prop.chest',
  size: [16, 16],
  pivot: [8, 15],
  fps: 10,
  clips: { idle: { frames: 8, loop: true }, open: { frames: 6 } },
  tags: ['prop', 'chest'],
  build(root, clip) {
    const keys: Keys = { ...base, m: 'clay', d: 'wood', a: 'gold', l: 'lemon', k: 'bark' };
    const box = new Grid(16, 16).rect(1, 7, 14, 8, 'm').rect(1, 13, 14, 2, 'd').rect(1, 9, 14, 1, 'a').rect(7, 8, 2, 4, 'a').set(7, 10, 'k');
    const lid = new Grid(16, 16).rect(1, 3, 14, 4, 'd').rect(2, 2, 12, 1, 'd').rect(1, 5, 14, 1, 'a').rect(2, 3, 12, 1, 'm');
    const glow = new Grid(16, 16).tri(8, 7, 3, -1, 13, -1, 'l');
    const light = group(root);
    pixels(light, glow.rows(false), keys);
    const body = pixels(root, box.rows(), keys);
    const top = pivot(pixels(root, lid.rows(), keys), '0% 100%');
    if (clip === 'idle') {
      light.style.opacity = '0';
      shine(root, body, 16, 16, 10);
    } else {
      frameSteps(top, [tr(0, 0), tr(0, -1), tr(0, -2, 'rotate(-12deg)'), tr(-1, -3, 'rotate(-25deg)'), tr(-1, -4, 'rotate(-35deg)'), tr(-1, -4, 'rotate(-35deg)')], 10, false);
      frameSteps(light, [0, 0, 0, 1, 1, 1].map((o) => ({ opacity: o })), 10, false);
    }
  },
};

/** 光源（火盆 / 烛台）：idle 火焰闪烁，break 碎裂。 */
function lightSource(id: string, keys: Keys, paintBase: (g: Grid) => void, flameY: number): SheetSpec {
  return {
    kind: 'sheet',
    id,
    size: [16, 24],
    pivot: [8, 23],
    fps: 8,
    clips: { idle: { frames: 4, loop: true }, break: { frames: 4 } },
    tags: ['prop', 'light'],
    build(root, clip) {
      const b = new Grid(16, 24);
      paintBase(b);
      const k = { ...base, f: 'red', g: 'gold', y: 'lemon', ...keys } as Keys;
      const flames = [0, 1, 2, 3].map((i) => {
        const f = new Grid(16, 24);
        const sway = [0, 1, 0, -1][i];
        const tall = [6, 7, 5, 7][i];
        f.ellipse(8 + sway * 0.5, flameY - 1, 3, 3, 'f').tri(5, flameY - 1, 8 + sway, flameY - tall - 1, 11, flameY - 1, 'f');
        f.ellipse(8, flameY, 1.8, 2, 'g').set(8, flameY - 2, 'y');
        const gr = group(root);
        pixels(gr, f.rows(false), k);
        return gr;
      });
      const stand = pivot(pixels(root, b.rows(), k));
      if (clip === 'idle') {
        flames.forEach((f, i) => frameSteps(f, [0, 1, 2, 3].map((j) => ({ opacity: j === i ? 1 : 0 })), 8));
      } else {
        flames.forEach((f, i) => frameSteps(f, [i === 0 ? 1 : 0, 0, 0, 0].map((o) => ({ opacity: o })), 8, false));
        frameSteps(stand, [tr(0, 0), tr(0, 1, 'scale(1.1, 0.8)'), tr(0, 2, 'scale(1.25, 0.5)'), tr(0, 3, 'scale(1.4, 0.2)')], 8, false);
      }
    },
  };
}

export default [
  gem('blue', 'sky', 'navy', 'frost'),
  gem('green', 'lime', 'leaf', 'sprout'),
  gem('red', 'red', 'blood', 'pink'),
  coin,
  shiny('pickup.coin_bag', [12, 12], { m: 'clay', d: 'wood', a: 'gold' }, (g) => {
    g.ellipse(6, 8, 5, 4, 'm').tri(3, 5, 6, 1, 9, 5, 'm').rect(4, 4, 4, 1, 'a').set(6, 8, 'a');
  }),
  shiny('pickup.rich_coin_bag', [12, 12], { m: 'violet', d: 'plum', a: 'gold' }, (g) => {
    g.ellipse(6, 8, 5, 4, 'm').tri(3, 5, 6, 1, 9, 5, 'm').rect(4, 4, 4, 1, 'a').rect(5, 7, 2, 3, 'a');
  }),
  shiny('pickup.floor_chicken', [16, 12], { m: 'clay', l: 'tan', b: 'paper' }, (g) => {
    g.ellipse(9.5, 6.5, 5.5, 4.5, 'm').ellipse(8.5, 5, 3, 2, 'l').rect(1, 6, 4, 2, 'b').rect(0, 5, 2, 1, 'b').rect(0, 8, 2, 1, 'b');
  }),
  shiny('pickup.rosary', [12, 12], { m: 'gold', b: 'paper' }, (g) => {
    g.ring(6, 4, 3.6, 2.6, 'b').rect(5, 5, 2, 7, 'm').rect(3, 7, 6, 2, 'm');
  }),
  vacuum,
  shiny('pickup.orologion', [12, 12], { m: 'gold', l: 'frost', k: 'ink' }, (g) => {
    g.ellipse(6, 7, 5, 5, 'm').ellipse(6, 7, 3.4, 3.4, 'l').rect(5, 0, 2, 2, 'm').line(6, 7, 6, 4, 'k').line(6, 7, 8, 8, 'k');
  }),
  shiny('pickup.little_clover', [12, 12], { m: 'leaf', d: 'moss', l: 'sprout' }, (g) => {
    g.ellipse(4, 4, 2.4, 2.4, 'm').ellipse(8, 4, 2.4, 2.4, 'm').ellipse(4, 8, 2.4, 2.4, 'm').ellipse(8, 8, 2.4, 2.4, 'm').line(6, 7, 9, 11, 'd').set(3, 3, 'l');
  }),
  chest,
  lightSource('prop.brazier', { m: 'mist', d: 'dusk', l: 'fog' }, (g) => {
    g.rect(3, 12, 10, 3, 'm').rect(4, 15, 8, 1, 'd').rect(7, 16, 2, 6, 'd').rect(4, 22, 8, 1, 'd').rect(3, 12, 10, 1, 'l');
  }, 11),
  lightSource('prop.candelabra', { m: 'gold', d: 'amber', l: 'cream' }, (g) => {
    g.rect(6, 10, 4, 4, 'l').rect(7, 14, 2, 8, 'm').rect(4, 22, 8, 1, 'd').rect(5, 14, 6, 1, 'd');
  }, 9),
] satisfies SheetSpec[];
