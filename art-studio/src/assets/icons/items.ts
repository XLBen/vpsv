// 武器、进化武器、被动道具图标（16×16）。idle：8 帧光泽扫过。
// 形状用 Grid 图元画，配色键：m 主色 · d 暗部 · l 高光 · a 点缀 · k 木柄/金属
import { Grid } from '../../runtime/grid';
import { pixels } from '../../runtime/pixel';
import { shine } from '../../runtime/shine';
import type { ColorKey } from '../../runtime/palette';
import type { SheetSpec } from '../../runtime/spec';

type Pal = Partial<Record<'m' | 'd' | 'l' | 'a' | 'k', ColorKey>>;
type Painter = (g: Grid) => void;

const P: Record<string, Painter> = {
  whip(g) {
    g.ring(9.5, 6.5, 5.5, 3.2, 'm').shade((x, y) => y > 7, 'd', 'm');
    g.line(5, 8, 3, 11, 'm', 2);
    g.rect(2, 11, 2, 4, 'k');
  },
  magic_wand(g) {
    g.line(3, 13, 10, 6, 'k', 2);
    g.rect(10, 2, 3, 3, 'a').set(11, 1, 'l').set(11, 5, 'l').set(9, 3, 'l').set(13, 3, 'l').set(11, 3, 'l');
  },
  knife(g) {
    g.line(6, 9, 13, 2, 'l', 2).line(7, 10, 13, 4, 'm');
    g.line(4, 8, 7, 11, 'a');
    g.line(2, 13, 5, 10, 'k', 2);
  },
  axe(g) {
    g.ellipse(10.5, 5.5, 4.5, 4.5, 'l').shade((x) => x < 9, '.').shade((x, y) => y > 6, 'm', 'l');
    g.line(4, 14, 10, 3, 'k', 2);
  },
  cross(g) {
    g.rect(6, 1, 4, 14, 'm').rect(2, 5, 12, 4, 'm');
    g.shade((x, y) => x < 7 || y < 6, 'l', 'm');
    g.rect(7, 6, 2, 2, 'a');
  },
  king_bible(g) {
    g.rect(3, 2, 10, 12, 'm').rect(11, 3, 2, 10, 'l').rect(3, 12, 10, 2, 'd');
    g.rect(6, 4, 2, 7, 'a').rect(4, 6, 6, 2, 'a');
  },
  fire_wand(g) {
    g.line(3, 14, 8, 9, 'k', 2);
    g.ellipse(10.5, 5.5, 4, 4, 'm').ellipse(10.5, 6, 2.5, 2.5, 'a').ellipse(10.5, 6.5, 1.2, 1.2, 'l');
    g.tri(8, 3, 10, -1, 12, 3, 'm');
  },
  garlic(g) {
    g.ellipse(8, 10, 5.5, 4.5, 'm').tri(6, 7, 8, 1, 10, 7, 'm');
    g.shade((x) => x === 6 || x === 9, 'd', 'm');
    g.rect(6, 14, 4, 1, 'k');
  },
  santa_water(g) {
    g.ellipse(8, 10, 5, 4.5, 'm').rect(7, 2, 2, 4, 'l').rect(6, 1, 4, 2, 'k');
    g.shade((x, y) => y < 9, 'l', 'm');
    g.rect(7, 9, 2, 4, 'a').rect(6, 10, 4, 1, 'a');
  },
  runetracer(g) {
    g.tri(8, 0.5, 1.5, 8, 14.5, 8, 'm').tri(1.5, 8, 14.5, 8, 8, 15.5, 'd');
    g.tri(8, 4, 5, 8, 11, 8, 'l').tri(5, 8, 11, 8, 8, 12, 'a');
  },
  lightning_ring(g) {
    g.ring(8, 8, 6.5, 4.6, 'm').shade((x, y) => x + y > 17, 'd', 'm');
    g.line(9, 3, 6, 8, 'a').line(6, 8, 10, 8, 'a').line(10, 8, 7, 13, 'a');
  },
  pentagram(g) {
    g.ring(8, 8, 7, 5.8, 'm');
    const pts = [0, 1, 2, 3, 4].map((i) => [8 + 5.5 * Math.sin((i * 4 * Math.PI) / 5), 8 - 5.5 * Math.cos((i * 4 * Math.PI) / 5)]);
    for (let i = 0; i < 5; i++) g.line(pts[i][0], pts[i][1], pts[(i + 1) % 5][0], pts[(i + 1) % 5][1], 'a');
  },
  peachone(g) {
    g.ellipse(7, 9, 5, 3.5, 'm').ellipse(11, 6, 2.5, 2.5, 'm');
    g.tri(2, 9, 8, 7, 5, 2, 'l');
    g.rect(13, 6, 2, 1, 'a').set(11, 5, 'k');
  },
  clock_lancet(g) {
    g.ring(8, 9, 6, 4.3, 'm').ellipse(8, 9, 4.3, 4.3, 'l');
    g.line(8, 9, 8, 6, 'k').line(8, 9, 10, 10, 'k');
    g.rect(7, 1, 2, 2, 'a');
  },
  laurel(g) {
    for (let i = 0; i < 6; i++) {
      const a = Math.PI * (0.65 + i * 0.13);
      g.ellipse(8 + 6 * Math.cos(a), 9 - 6 * Math.sin(a) * -1 - 2, 1.8, 1.2, 'm');
      g.ellipse(8 - 6 * Math.cos(a), 9 - 6 * Math.sin(a) * -1 - 2, 1.8, 1.2, 'm');
    }
    g.shade((x, y) => y > 10, 'd', 'm');
    g.rect(7, 13, 2, 2, 'a');
  },
  // ---- 被动
  spinach(g) {
    g.ellipse(6, 8, 4, 5.5, 'm').ellipse(10.5, 7, 3.5, 5, 'l').line(8, 14, 8, 6, 'd');
  },
  armor(g) {
    g.rect(3, 4, 10, 9, 'm').ellipse(3.5, 4.5, 2.5, 2, 'l').ellipse(12.5, 4.5, 2.5, 2, 'l');
    g.rect(5, 12, 6, 2, 'd').rect(7, 5, 2, 7, 'd');
  },
  hollow_heart(g) {
    g.ellipse(5.5, 6, 3.8, 3.8, 'm').ellipse(10.5, 6, 3.8, 3.8, 'm').tri(1.8, 7, 14.2, 7, 8, 14.5, 'm');
    g.ellipse(5.5, 6.5, 1.8, 1.8, 'd').ellipse(10.5, 6.5, 1.8, 1.8, 'd').tri(4, 7.5, 12, 7.5, 8, 11.5, 'd');
    g.set(4, 4, 'l');
  },
  pummarola(g) {
    g.ellipse(8, 9.5, 6, 5, 'm').shade((x, y) => x < 6 && y < 9, 'l', 'm');
    g.tri(5, 4, 8, 6, 11, 4, 'a').rect(7, 2, 2, 3, 'a');
  },
  empty_tome(g) {
    g.rect(2, 3, 12, 10, 'm').rect(3, 4, 4, 8, 'l').rect(9, 4, 4, 8, 'l').rect(7, 3, 2, 10, 'd');
  },
  candelabrador(g) {
    g.rect(7, 6, 2, 8, 'k').rect(4, 14, 8, 1, 'k').rect(3, 8, 10, 1, 'k');
    for (const x of [3, 7, 11]) g.rect(x, 4, 2, 4, 'l').set(x, 2, 'a').set(x + 1, 3, 'a');
  },
  bracer(g) {
    g.rect(4, 2, 8, 12, 'm').rect(4, 4, 8, 2, 'a').rect(4, 10, 8, 2, 'a').rect(5, 6, 2, 4, 'l');
  },
  spellbinder(g) {
    g.rect(3, 3, 10, 10, 'm').rect(3, 7, 10, 2, 'k').rect(6, 6, 4, 4, 'a').set(7, 7, 'd');
  },
  duplicator(g) {
    g.ring(8, 9, 5, 3, 'm').ellipse(8, 3.5, 2.5, 2.5, 'a').set(7, 3, 'l');
  },
  wings(g) {
    g.ellipse(9, 8, 5.5, 4, 'm').tri(2, 4, 9, 6, 6, 12, 'm');
    g.line(5, 8, 13, 8, 'd').line(6, 10, 12, 10, 'd');
  },
  attractorb(g) {
    g.ellipse(8, 8, 5.5, 5.5, 'm').ellipse(6.5, 6.5, 2, 2, 'l').ring(8, 8, 7.4, 6.6, 'a');
  },
  clover(g) {
    g.ellipse(5.5, 5.5, 3, 3, 'm').ellipse(10.5, 5.5, 3, 3, 'm').ellipse(5.5, 10, 3, 3, 'm').ellipse(10.5, 10, 3, 3, 'm');
    g.line(8, 9, 11, 15, 'd').set(5, 4, 'l');
  },
  crown(g) {
    g.rect(2, 8, 12, 5, 'm').tri(2, 9, 2, 3, 6, 9, 'm').tri(6, 9, 8, 2, 10, 9, 'm').tri(10, 9, 14, 3, 14, 9, 'm');
    g.rect(2, 11, 12, 1, 'd').set(5, 10, 'a').set(8, 10, 'a').set(11, 10, 'a');
  },
  stone_mask(g) {
    g.ellipse(8, 8, 5.5, 6.5, 'm').shade((x) => x > 10, 'd', 'm');
    g.rect(5, 6, 2, 2, 'k').rect(9, 6, 2, 2, 'k').rect(6, 11, 4, 1, 'k');
  },
  skull_omaniac(g) {
    g.ellipse(8, 7, 5.5, 5, 'm').rect(5, 11, 6, 3, 'm');
    g.rect(5, 6, 2, 3, 'k').rect(9, 6, 2, 3, 'k').set(8, 10, 'k').rect(6, 13, 1, 1, 'd').rect(9, 13, 1, 1, 'd');
  },
  reroll(g) {
    g.rect(3, 3, 10, 10, 'm').rect(3, 12, 10, 1, 'd').rect(12, 3, 1, 10, 'd');
    for (const [x, y] of [[5, 5], [10, 5], [7, 8], [5, 10], [10, 10]]) g.set(x, y, 'k');
  },
  skip(g) {
    g.tri(2, 3, 2, 13, 8, 8, 'm').tri(8, 3, 8, 13, 14, 8, 'm').shade((x, y) => y > 8, 'd', 'm');
  },
  banish(g) {
    g.ring(8, 8, 6.5, 4.5, 'm').line(4, 12, 12, 4, 'm', 2).shade((x, y) => x + y > 16, 'd', 'm');
  },
  tiragisu(g) {
    g.tri(2, 13, 14, 13, 14, 5, 'm').rect(2, 13, 12, 2, 'd');
    g.shade((x, y) => y === 9 || y === 11, 'l', 'm');
    g.set(13, 5, 'a').set(12, 6, 'a');
  },
};

interface IconDef {
  id: string;
  painter: string;
  pal: Pal;
  /** 进化武器：外加一圈闪光像素。 */
  evolved?: boolean;
}

const W = (id: string, pal: Pal, painter = id): IconDef => ({ id: `icon.weapon.${id}`, painter, pal });
const E = (id: string, painter: string, pal: Pal): IconDef => ({ id: `icon.weapon.${id}`, painter, pal, evolved: true });
const S = (id: string, pal: Pal): IconDef => ({ id: `icon.passive.${id}`, painter: id, pal });

const DEFS: IconDef[] = [
  W('whip', { m: 'clay', d: 'wood', k: 'bark' }),
  W('magic_wand', { k: 'wood', a: 'sky', l: 'frost' }),
  W('knife', { l: 'paper', m: 'mist', a: 'gold', k: 'wood' }),
  W('axe', { k: 'wood', l: 'fog', m: 'mist' }),
  W('cross', { m: 'gold', l: 'lemon', a: 'red' }),
  W('king_bible', { m: 'violet', l: 'cream', d: 'plum', a: 'gold' }),
  W('fire_wand', { k: 'wood', m: 'red', a: 'coral', l: 'lemon' }),
  W('garlic', { m: 'paper', d: 'fog', k: 'clay' }),
  W('santa_water', { m: 'sky', l: 'ice', k: 'wood', a: 'paper' }),
  W('runetracer', { m: 'ice', d: 'sky', l: 'frost', a: 'navy' }),
  W('lightning_ring', { m: 'gold', d: 'amber', a: 'frost' }),
  W('pentagram', { m: 'fog', a: 'lilac' }),
  W('peachone', { m: 'paper', l: 'fog', a: 'gold', k: 'ink' }),
  W('ebony_wings', { m: 'shadow', l: 'night', a: 'red', k: 'paper' }, 'peachone'),
  W('clock_lancet', { m: 'gold', l: 'frost', k: 'ink', a: 'ice' }),
  W('laurel', { m: 'leaf', d: 'moss', a: 'gold' }),
  // 进化
  E('bloody_tear', 'whip', { m: 'red', d: 'blood', k: 'bark' }),
  E('holy_wand', 'magic_wand', { k: 'gold', a: 'lemon', l: 'white' }),
  E('thousand_edge', 'knife', { l: 'frost', m: 'ice', a: 'gold', k: 'navy' }),
  E('death_spiral', 'axe', { k: 'night', l: 'lilac', m: 'violet' }),
  E('heaven_sword', 'cross', { m: 'paper', l: 'white', a: 'gold' }),
  E('unholy_vespers', 'king_bible', { m: 'night', l: 'pink', d: 'ink', a: 'red' }),
  E('hellfire', 'fire_wand', { k: 'bark', m: 'blood', a: 'red', l: 'gold' }),
  E('soul_eater', 'garlic', { m: 'lilac', d: 'violet', k: 'plum' }),
  E('la_borra', 'santa_water', { m: 'navy', l: 'sky', k: 'gold', a: 'gold' }),
  E('no_future', 'runetracer', { m: 'dusk', d: 'night', l: 'pink', a: 'red' }),
  E('thunder_loop', 'lightning_ring', { m: 'ice', d: 'sky', a: 'white' }),
  E('gorgeous_moon', 'pentagram', { m: 'gold', a: 'lemon' }),
  E('vandalier', 'peachone', { m: 'fog', l: 'shadow', a: 'gold', k: 'red' }),
  // 被动
  S('spinach', { m: 'leaf', l: 'lime', d: 'moss' }),
  S('armor', { m: 'mist', l: 'fog', d: 'dusk' }),
  S('hollow_heart', { m: 'red', d: 'wine', l: 'pink' }),
  S('pummarola', { m: 'red', l: 'coral', a: 'leaf' }),
  S('empty_tome', { m: 'lilac', l: 'paper', d: 'violet' }),
  S('candelabrador', { k: 'gold', l: 'cream', a: 'coral' }),
  S('bracer', { m: 'clay', a: 'gold', l: 'tan' }),
  S('spellbinder', { m: 'navy', k: 'mist', a: 'gold', d: 'ink' }),
  S('duplicator', { m: 'gold', a: 'red', l: 'pink' }),
  S('wings', { m: 'paper', d: 'fog' }),
  S('attractorb', { m: 'sky', l: 'frost', a: 'ice' }),
  S('clover', { m: 'leaf', d: 'moss', l: 'sprout' }),
  S('crown', { m: 'gold', d: 'amber', a: 'red' }),
  S('stone_mask', { m: 'mist', d: 'dusk', k: 'ink' }),
  S('skull_omaniac', { m: 'paper', d: 'fog', k: 'ink' }),
  S('tiragisu', { m: 'cream', d: 'wood', l: 'tan', a: 'red' }),
  { id: 'icon.ui.reroll', painter: 'reroll', pal: { m: 'paper', d: 'fog', k: 'ink' } },
  { id: 'icon.ui.skip', painter: 'skip', pal: { m: 'ice', d: 'sky' } },
  { id: 'icon.ui.banish', painter: 'banish', pal: { m: 'red', d: 'blood' } },
];

const FPS = 10;

function makeSpec(d: IconDef): SheetSpec {
  return {
    kind: 'sheet',
    id: d.id,
    size: [16, 16],
    pivot: [8, 8],
    fps: FPS,
    clips: { idle: { frames: 8, loop: true } },
    tags: ['icon', d.evolved ? 'evolved' : d.id.split('.')[1]],
    build(root) {
      const g = new Grid(16, 16);
      P[d.painter](g);
      if (d.evolved) for (const [x, y] of [[1, 1], [14, 1], [1, 14], [14, 14]]) g.set(x, y, 'z');
      const keys = { m: 'mist', d: 'dusk', l: 'paper', a: 'gold', k: 'wood', ...d.pal, o: 'ink', z: 'lemon' } as Record<string, ColorKey>;
      const shape = pixels(root, g.rows(), keys);
      shine(root, shape, 16, 16, FPS);
    },
  };
}

export default DEFS.map(makeSpec);
