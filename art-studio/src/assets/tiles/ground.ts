// 地面图块变体（16×16）。游戏用它们按种子随机拼出可平铺的地面。
// 每个 clip 是一组静态变体，帧号即变体编号。
import { Grid } from '../../runtime/grid';
import { pixels } from '../../runtime/pixel';
import type { ColorKey } from '../../runtime/palette';
import type { SheetSpec } from '../../runtime/spec';

function rng(seed: number) {
  return () => {
    seed |= 0;
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

type Painter = (g: Grid, r: () => number) => void;

function tileSet(id: string, keys: Record<string, ColorKey>, clips: Record<string, Painter[]>): SheetSpec {
  return {
    kind: 'sheet',
    id,
    size: [16, 16],
    pivot: [0, 0],
    fps: 1,
    clips: Object.fromEntries(Object.entries(clips).map(([k, v]) => [k, { frames: v.length }])),
    tags: ['tile'],
    drawFrame(root, clip, frame) {
      const g = new Grid(16, 16);
      clips[clip][frame](g, rng(frame * 977 + clip.length * 131 + id.length));
      pixels(root, g.rows(false), keys);
    },
  };
}

// ---- 森林
const speckle = (n: number, c: string): Painter => (g, r) => {
  g.rect(0, 0, 16, 16, 'b');
  for (let i = 0; i < n; i++) g.set(Math.floor(r() * 16), Math.floor(r() * 16), r() < 0.6 ? c : 'd');
};
const tuft: Painter = (g, r) => {
  speckle(4, 'l')(g, r);
  const x = 4 + Math.floor(r() * 8);
  const y = 9 + Math.floor(r() * 4);
  g.line(x, y, x - 2, y - 4, 't').line(x, y, x, y - 5, 'l').line(x, y, x + 2, y - 3, 't');
};
const flowers: Painter = (g, r) => {
  speckle(4, 'l')(g, r);
  for (let i = 0; i < 3; i++) {
    const x = 2 + Math.floor(r() * 12);
    const y = 2 + Math.floor(r() * 12);
    const c = r() < 0.5 ? 'p' : 'w';
    g.set(x - 1, y, c).set(x + 1, y, c).set(x, y - 1, c).set(x, y + 1, c).set(x, y, 'y');
  }
};
const stone: Painter = (g, r) => {
  speckle(4, 'l')(g, r);
  const x = 5 + r() * 6;
  const y = 6 + r() * 5;
  g.ellipse(x, y, 3.5, 2.5, 's').ellipse(x - 0.5, y - 0.8, 2, 1.2, 'h').rect(x - 3, y + 2, 6, 1, 'd');
};
const dirt: Painter = (g, r) => {
  speckle(4, 'l')(g, r);
  g.ellipse(8, 8, 4 + r() * 2, 3 + r() * 1.5, 'c');
  for (let i = 0; i < 6; i++) g.set(3 + Math.floor(r() * 10), 5 + Math.floor(r() * 6), 'e');
};

// ---- 图书馆
const plank: Painter = (g, r) => {
  g.rect(0, 0, 16, 16, 'b');
  for (const y of [0, 4, 8, 12]) {
    g.rect(0, y + 3, 16, 1, 'd');
    const seam = Math.floor(r() * 14) + 1;
    g.rect(seam, y, 1, 3, 'd');
    if (r() < 0.5) g.set(Math.floor(r() * 16), y + 1, 'l');
  }
};
const carpet: Painter = (g, r) => {
  g.rect(0, 0, 16, 16, 'c');
  for (let i = 0; i < 10; i++) g.set(Math.floor(r() * 16), Math.floor(r() * 16), 'e');
};
const rug: Painter = (g) => {
  g.rect(0, 0, 16, 16, 'c').rect(0, 0, 16, 2, 'a').rect(0, 14, 16, 2, 'a');
  for (let x = 1; x < 16; x += 4) g.set(x, 7, 'a').set(x + 1, 8, 'a');
};
const crack: Painter = (g, r) => {
  plank(g, r);
  g.line(3, 2, 7, 7, 'k').line(7, 7, 6, 12, 'k');
};

export default [
  tileSet(
    'tile.forest',
    { b: 'leaf', d: 'moss', l: 'lime', t: 'moss', p: 'pink', w: 'paper', y: 'gold', s: 'mist', h: 'fog', c: 'clay', e: 'wood' },
    {
      grass: [speckle(4, 'l'), speckle(6, 'l'), speckle(3, 'l'), speckle(5, 'd')],
      deco: [tuft, tuft, tuft, tuft, flowers, flowers, stone, dirt],
    },
  ),
  tileSet(
    'tile.library',
    { b: 'clay', d: 'wood', l: 'tan', c: 'blood', e: 'wine', a: 'gold', k: 'bark' },
    {
      floor: [plank, plank, plank, plank],
      deco: [carpet, carpet, rug, rug, crack, crack],
    },
  ),
] satisfies SheetSpec[];
