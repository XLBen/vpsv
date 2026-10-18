// 角色 / 怪物 / 首领的占位素材。
// 统一的动画片段约定（美术替换时保持同名、同帧数即可）：
//   idle 4 帧循环 · walk 6 帧循环 · hurt 2 帧 · death 6 帧 · attack 4 帧（仅首领）
// 朝向统一面向右侧，游戏内水平翻转得到左侧。
import { Grid } from '../../runtime/grid';
import { frameSteps, group, letter, pivot, pixels, tr } from '../../runtime/pixel';
import type { ColorKey } from '../../runtime/palette';
import type { SheetSpec } from '../../runtime/spec';

type Body = 'hero' | 'biped' | 'brute' | 'flyer' | 'ghost' | 'blob' | 'plant' | 'wall' | 'reaper';

interface ActorDef {
  id: string;
  size: [number, number];
  body: Body;
  main: ColorKey;
  dark: ColorKey;
  accent: ColorKey;
  mark: string;
  boss?: boolean;
}

const DEFS: ActorDef[] = [
  // 可选角色
  { id: 'actor.hero.whip', size: [16, 24], body: 'hero', main: 'red', dark: 'blood', accent: 'navy', mark: 'W' },
  { id: 'actor.hero.mage', size: [16, 24], body: 'hero', main: 'violet', dark: 'plum', accent: 'gold', mark: 'M' },
  { id: 'actor.hero.knife', size: [16, 24], body: 'hero', main: 'leaf', dark: 'moss', accent: 'tan', mark: 'K' },
  { id: 'actor.hero.rune', size: [16, 24], body: 'hero', main: 'sky', dark: 'navy', accent: 'cream', mark: 'R' },
  // 普通怪物
  { id: 'actor.enemy.bat', size: [16, 16], body: 'flyer', main: 'violet', dark: 'plum', accent: 'red', mark: 'B' },
  { id: 'actor.enemy.zombie', size: [16, 24], body: 'biped', main: 'leaf', dark: 'moss', accent: 'red', mark: 'Z' },
  { id: 'actor.enemy.skeleton', size: [16, 24], body: 'biped', main: 'paper', dark: 'mist', accent: 'ink', mark: 'S' },
  { id: 'actor.enemy.ghost', size: [16, 16], body: 'ghost', main: 'frost', dark: 'ice', accent: 'night', mark: 'G' },
  { id: 'actor.enemy.mudman', size: [16, 16], body: 'blob', main: 'clay', dark: 'wood', accent: 'gold', mark: 'U' },
  { id: 'actor.enemy.werewolf', size: [24, 24], body: 'brute', main: 'dusk', dark: 'shadow', accent: 'gold', mark: 'W' },
  { id: 'actor.enemy.mummy', size: [16, 24], body: 'biped', main: 'cream', dark: 'tan', accent: 'gold', mark: 'M' },
  { id: 'actor.enemy.big_mummy', size: [24, 32], body: 'biped', main: 'tan', dark: 'clay', accent: 'gold', mark: 'M' },
  { id: 'actor.enemy.venus', size: [16, 24], body: 'plant', main: 'lime', dark: 'leaf', accent: 'pink', mark: 'V' },
  { id: 'actor.enemy.flower_wall', size: [16, 16], body: 'wall', main: 'moss', dark: 'pine', accent: 'pink', mark: 'F' },
  { id: 'actor.enemy.book', size: [16, 16], body: 'flyer', main: 'wood', dark: 'bark', accent: 'cream', mark: 'K' },
  { id: 'actor.enemy.skull', size: [16, 16], body: 'flyer', main: 'paper', dark: 'fog', accent: 'red', mark: 'X' },
  { id: 'actor.enemy.dullahan', size: [16, 24], body: 'biped', main: 'navy', dark: 'deep', accent: 'ice', mark: 'D' },
  { id: 'actor.enemy.witch', size: [16, 24], body: 'hero', main: 'lilac', dark: 'violet', accent: 'night', mark: 'H' },
  // 首领
  { id: 'actor.boss.glowing_bat', size: [24, 24], body: 'flyer', main: 'gold', dark: 'amber', accent: 'red', mark: 'B', boss: true },
  { id: 'actor.boss.giant_bat', size: [32, 32], body: 'flyer', main: 'plum', dark: 'night', accent: 'red', mark: 'B', boss: true },
  { id: 'actor.boss.mantichana', size: [32, 32], body: 'brute', main: 'red', dark: 'wine', accent: 'gold', mark: 'X', boss: true },
  { id: 'actor.boss.giant_werewolf', size: [32, 32], body: 'brute', main: 'shadow', dark: 'night', accent: 'gold', mark: 'W', boss: true },
  { id: 'actor.boss.giant_mummy', size: [32, 40], body: 'biped', main: 'tan', dark: 'clay', accent: 'gold', mark: 'M', boss: true },
  { id: 'actor.boss.giant_venus', size: [32, 40], body: 'plant', main: 'sky', dark: 'navy', accent: 'pink', mark: 'V', boss: true },
  { id: 'actor.boss.blood_lord', size: [32, 40], body: 'brute', main: 'blood', dark: 'wine', accent: 'cream', mark: 'L', boss: true },
  { id: 'actor.boss.reaper', size: [32, 40], body: 'reaper', main: 'night', dark: 'ink', accent: 'paper', mark: 'R', boss: true },
];

interface Parts {
  body: Grid;
  legL?: Grid;
  legR?: Grid;
  wingL?: Grid;
  wingR?: Grid;
  mark: [number, number];
}

// ------------------------------------------------------------ 形体绘制（按尺寸比例）

function hero(w: number, h: number): Parts {
  const cx = w / 2;
  const u = h / 24;
  const body = new Grid(w, h);
  body.rect(cx - 4 * u, 10 * u, 8 * u, 7 * u, 'm'); // 躯干
  body.rect(cx - 5 * u, 10 * u, 1 * u, 8 * u, 'd'); // 披风
  body.rect(cx - 4 * u, 16 * u, 8 * u, 1, 'a'); // 腰带
  body.ellipse(cx, 7.5 * u, 3.5 * u, 3 * u, 's'); // 头
  body.rect(cx - 4 * u, 2 * u, 8 * u, 2.5 * u, 'a'); // 帽顶
  body.rect(cx - 5 * u, 4.5 * u, 10 * u, 1, 'a'); // 帽檐
  body.set(cx + 1.5 * u, 7.5 * u, 'e');
  body.rect(cx + 4 * u, 12 * u, 2 * u, 2 * u, 's'); // 手
  const legL = new Grid(w, h).rect(cx - 3 * u, 17 * u, 2 * u, 5 * u, 'k');
  const legR = new Grid(w, h).rect(cx + 1 * u, 17 * u, 2 * u, 5 * u, 'k');
  return { body, legL, legR, mark: [Math.round(cx - 1.5), Math.round(10.5 * u)] };
}

function biped(w: number, h: number): Parts {
  const cx = w / 2;
  const u = h / 24;
  const body = new Grid(w, h);
  body.rect(cx - 4 * u, 9 * u, 8 * u, 8 * u, 'm');
  body.shade((x) => x < cx - 2 * u, 'd', 'm');
  body.ellipse(cx, 6 * u, 3.5 * u, 3.5 * u, 'm');
  body.rect(cx + 3 * u, 10 * u, 4 * u, 2 * u, 'd'); // 前伸的手臂
  body.set(cx + 1 * u, 6 * u, 'e').set(cx + 2.5 * u, 6 * u, 'e');
  const legL = new Grid(w, h).rect(cx - 3 * u, 17 * u, 2 * u, 5 * u, 'd');
  const legR = new Grid(w, h).rect(cx + 1 * u, 17 * u, 2 * u, 5 * u, 'd');
  return { body, legL, legR, mark: [Math.round(cx - 1.5), Math.round(10.5 * u)] };
}

function brute(w: number, h: number): Parts {
  const cx = w / 2;
  const u = h / 24;
  const body = new Grid(w, h);
  body.ellipse(cx - 1 * u, 12 * u, 7 * u, 6 * u, 'm'); // 弓背的身体
  body.shade((x, y) => y > 14 * u, 'd', 'm');
  body.ellipse(cx + 5 * u, 7 * u, 4 * u, 3.5 * u, 'm'); // 头
  body.tri(cx + 2 * u, 4 * u, cx + 4 * u, 0.5 * u, cx + 5 * u, 4 * u, 'd'); // 耳
  body.tri(cx + 6 * u, 4 * u, cx + 8 * u, 0.5 * u, cx + 8.5 * u, 4.5 * u, 'd');
  body.set(cx + 6 * u, 7 * u, 'e').set(cx + 7.5 * u, 7 * u, 'e');
  body.rect(cx + 6 * u, 13 * u, 4 * u, 2 * u, 'a'); // 爪
  const legL = new Grid(w, h).rect(cx - 5 * u, 17 * u, 3 * u, 5 * u, 'd');
  const legR = new Grid(w, h).rect(cx + 1 * u, 17 * u, 3 * u, 5 * u, 'd');
  return { body, legL, legR, mark: [Math.round(cx - 3), Math.round(9 * u)] };
}

function flyer(w: number, h: number): Parts {
  const cx = w / 2;
  const cy = h / 2;
  const u = w / 16;
  const body = new Grid(w, h).ellipse(cx, cy, 4 * u, 4 * u, 'm');
  body.shade((x, y) => y > cy + 1 * u, 'd', 'm');
  body.set(cx + 1 * u, cy - 1 * u, 'e').set(cx + 2.5 * u, cy - 1 * u, 'e');
  const wingL = new Grid(w, h).tri(cx - 2 * u, cy - 1 * u, 0.5, cy - 4 * u, cx - 3 * u, cy + 3 * u, 'd');
  const wingR = new Grid(w, h).tri(cx + 2 * u, cy - 1 * u, w - 0.5, cy - 4 * u, cx + 3 * u, cy + 3 * u, 'd');
  return { body, wingL, wingR, mark: [Math.round(cx - 1.5), Math.round(cy - 2)] };
}

function ghost(w: number, h: number): Parts {
  const cx = w / 2;
  const u = w / 16;
  const body = new Grid(w, h);
  body.ellipse(cx, 7 * u, 6 * u, 6 * u, 'm');
  body.rect(cx - 6 * u, 7 * u, 12 * u, 5 * u, 'm');
  for (let i = 0; i < 3; i++) body.ellipse(cx - 4 * u + i * 4 * u, 12 * u, 2 * u, 2.5 * u, 'm');
  body.shade((x) => x < cx - 3 * u, 'd', 'm');
  body.rect(cx + 1 * u, 5 * u, 1 * u, 2 * u, 'e').rect(cx + 3.5 * u, 5 * u, 1 * u, 2 * u, 'e');
  return { body, mark: [Math.round(cx - 2), Math.round(8 * u)] };
}

function blob(w: number, h: number): Parts {
  const cx = w / 2;
  const u = w / 16;
  const body = new Grid(w, h);
  body.ellipse(cx, 10 * u, 7 * u, 6 * u, 'm');
  body.rect(cx - 7 * u, 10 * u, 14 * u, 4 * u, 'm');
  body.shade((x, y) => y > 12 * u, 'd', 'm');
  body.set(cx + 1 * u, 7 * u, 'e').set(cx + 3.5 * u, 7 * u, 'e');
  return { body, mark: [Math.round(cx - 2), Math.round(8 * u)] };
}

function plant(w: number, h: number): Parts {
  const cx = w / 2;
  const u = h / 24;
  const body = new Grid(w, h);
  body.rect(cx - 1 * u, 10 * u, 2 * u, 12 * u, 'd'); // 茎
  body.ellipse(cx - 4 * u, 17 * u, 3.5 * u, 1.5 * u, 'd'); // 叶
  body.ellipse(cx + 4 * u, 15 * u, 3.5 * u, 1.5 * u, 'd');
  body.ellipse(cx, 7 * u, 5.5 * u, 5 * u, 'm'); // 花头
  body.tri(cx + 1 * u, 7 * u, cx + 6 * u, 5 * u, cx + 6 * u, 9 * u, 'a'); // 张开的嘴
  body.set(cx - 1 * u, 5 * u, 'e');
  return { body, mark: [Math.round(cx - 3.5), Math.round(4.5 * u)] };
}

function wall(w: number, h: number): Parts {
  const cx = w / 2;
  const u = w / 16;
  const body = new Grid(w, h);
  body.ellipse(cx, 9 * u, 7 * u, 6.5 * u, 'm');
  body.shade((x, y) => (x + y) % 5 === 0, 'd', 'm');
  for (const [x, y] of [[4, 6], [10, 5], [7, 11], [12, 10]]) body.rect(x * u, y * u, 2 * u, 2 * u, 'a');
  return { body, mark: [Math.round(cx - 1.5), Math.round(6 * u)] };
}

function reaper(w: number, h: number): Parts {
  const cx = w / 2;
  const u = h / 24;
  const body = new Grid(w, h);
  body.tri(cx, 3 * u, cx - 7 * u, 22 * u, cx + 7 * u, 22 * u, 'm'); // 长袍
  body.ellipse(cx, 6 * u, 3.5 * u, 3.5 * u, 'm'); // 兜帽
  body.ellipse(cx + 0.5 * u, 6.5 * u, 2 * u, 2 * u, 'e'); // 阴影中的脸
  body.set(cx + 1 * u, 6 * u, 'r');
  body.rect(cx + 6 * u, 1 * u, 1 * u, 21 * u, 'k'); // 镰刀柄
  body.tri(cx + 6.5 * u, 1 * u, cx - 4 * u, 3 * u, cx + 6.5 * u, 4 * u, 'a'); // 刀刃
  return { body, mark: [Math.round(cx - 1.5), Math.round(12 * u)] };
}

const PAINTERS: Record<Body, (w: number, h: number) => Parts> = { hero, biped, brute, flyer, ghost, blob, plant, wall, reaper };

// ------------------------------------------------------------ 动画

const FPS = 8;

function makeSpec(d: ActorDef): SheetSpec {
  const [w, h] = d.size;
  const keys: Record<string, ColorKey> = { m: d.main, d: d.dark, a: d.accent, s: 'skin', e: 'ink', k: 'night', o: 'ink', r: 'red' };
  const clips: SheetSpec['clips'] = {
    idle: { frames: 4, loop: true },
    walk: { frames: 6, loop: true },
    hurt: { frames: 2 },
    death: { frames: 6 },
  };
  if (d.boss) clips.attack = { frames: 4 };

  return {
    kind: 'sheet',
    id: d.id,
    size: [w, h],
    pivot: [Math.floor(w / 2), h - 1],
    fps: FPS,
    clips,
    tags: ['placeholder', d.boss ? 'boss' : d.id.startsWith('actor.hero') ? 'hero' : 'enemy'],
    build(root, clip) {
      const p = PAINTERS[d.body](w, h);
      const whole = pivot(group(root));
      const back = group(whole);
      const legL = p.legL && pivot(pixels(back, p.legL.rows(), keys));
      const legR = p.legR && pivot(pixels(back, p.legR.rows(), keys));
      const wingL = p.wingL && pivot(pixels(back, p.wingL.rows(), keys), '100% 50%');
      const wingR = p.wingR && pivot(pixels(back, p.wingR.rows(), keys), '0% 50%');
      const body = pivot(pixels(whole, p.body.rows(), keys));
      letter(body, d.mark, p.mark[0], p.mark[1], 'paper');
      const flying = !!wingL;

      const flap = (n: number) => {
        const v = Array.from({ length: n }, (_, i) => ({ transform: `scaleY(${[1, 0.5, -0.2, 0.5][i % 4]})` }));
        if (wingL) frameSteps(wingL, v, FPS);
        if (wingR) frameSteps(wingR, v, FPS);
      };

      switch (clip) {
        case 'idle':
          frameSteps(whole, [tr(0, 0), tr(0, 0), tr(0, flying ? -1 : 0), tr(0, flying ? -1 : 0)], FPS);
          frameSteps(body, [tr(0, 0), tr(0, 1), tr(0, 1), tr(0, 0)], FPS);
          flap(4);
          break;
        case 'walk':
          if (flying) {
            frameSteps(whole, [tr(0, 0), tr(0, -1), tr(0, -2), tr(0, -1), tr(0, 0), tr(0, 1)], FPS);
            flap(6);
          } else if (d.body === 'ghost' || d.body === 'reaper') {
            frameSteps(whole, [tr(0, 0), tr(1, -1), tr(1, -1), tr(0, 0), tr(-1, -1), tr(-1, -1)], FPS);
          } else if (d.body === 'blob' || d.body === 'wall' || d.body === 'plant') {
            frameSteps(body, ['scale(1,1)', 'scale(1.1,0.9)', 'scale(1.15,0.85)', 'scale(1,1)', 'scale(0.9,1.1)', 'scale(1,1)'].map((t) => ({ transform: t })), FPS);
          } else {
            frameSteps(body, [tr(0, 0), tr(0, -1), tr(0, 0), tr(0, 0), tr(0, -1), tr(0, 0)], FPS);
            if (legL) frameSteps(legL, [tr(0, 0), tr(1, -1), tr(1, -1), tr(0, 0), tr(-1, 0), tr(-1, 0)], FPS);
            if (legR) frameSteps(legR, [tr(0, 0), tr(-1, 0), tr(-1, 0), tr(0, 0), tr(1, -1), tr(1, -1)], FPS);
          }
          break;
        case 'hurt':
          frameSteps(whole, [tr(-2, 0, 'scale(1.1, 0.9)'), tr(-1, 0)], FPS, false);
          break;
        case 'death':
          frameSteps(
            whole,
            [1, 0.85, 0.65, 0.45, 0.25, 0.1].map((s, i) => ({ transform: `scale(${1 + i * 0.06}, ${s})` })),
            FPS,
            false,
          );
          break;
        case 'attack':
          frameSteps(whole, [tr(0, 0), tr(-1, 0, 'scale(1.05)'), tr(3, 0, 'scale(1.12)'), tr(1, 0)], FPS, false);
          flap(4);
          break;
      }
    },
  };
}

export default DEFS.map(makeSpec);
