// galgame 系统的占位素材：立绘（每个表情一个 clip）、CG（含差分）、对话背景。
// 正式美术替换时保持同名 id 与 clip 名即可（立绘 clip = 表情名）。
import { Grid } from '../../runtime/grid';
import { group, letter, pixels, rect } from '../../runtime/pixel';
import type { ColorKey } from '../../runtime/palette';
import type { SheetSpec } from '../../runtime/spec';

const EXPRESSIONS = ['normal', 'smile', 'angry', 'sad', 'surprised'];

/** 半身立绘占位：64×96 剪影 + 表情（眉 / 嘴）+ 角色字母。 */
function portrait(id: string, main: ColorKey, dark: ColorKey, hair: ColorKey, mark: string): SheetSpec {
  return {
    kind: 'sheet',
    id: `portrait.${id}`,
    size: [64, 96],
    pivot: [32, 95],
    fps: 1,
    clips: Object.fromEntries(EXPRESSIONS.map((e) => [e, { frames: 1 }])),
    tags: ['narrative', 'portrait', 'placeholder'],
    drawFrame(root, clip) {
      const g = new Grid(64, 96);
      g.ellipse(32, 92, 26, 22, 'm').rect(6, 80, 52, 16, 'm'); // 肩膀与躯干
      g.shade((x) => x < 18 || x > 46, 'd', 'm');
      g.rect(27, 56, 10, 10, 's'); // 脖子
      g.ellipse(32, 40, 15, 18, 's'); // 脸
      g.ellipse(32, 28, 17, 12, 'h').rect(15, 28, 4, 22, 'h').rect(45, 28, 4, 22, 'h'); // 头发
      g.set(25, 41, 'e').set(26, 41, 'e').set(38, 41, 'e').set(39, 41, 'e'); // 眼睛
      const brow = { normal: 0, smile: 0, angry: 1, sad: -1, surprised: -2 }[clip] ?? 0;
      g.line(23, 37 - Math.max(0, -brow), 27, 37 + Math.max(0, brow), 'h').line(41, 37 - Math.max(0, -brow), 37, 37 + Math.max(0, brow), 'h');
      if (clip === 'smile') g.line(28, 48, 32, 50, 'r').line(32, 50, 36, 48, 'r');
      else if (clip === 'sad') g.line(28, 50, 32, 48, 'r').line(32, 48, 36, 50, 'r');
      else if (clip === 'angry') g.rect(28, 49, 8, 1, 'r');
      else if (clip === 'surprised') g.ellipse(32, 49, 2, 2.5, 'r');
      else g.rect(30, 49, 5, 1, 'r');
      const keys = { m: main, d: dark, h: hair, s: 'skin', e: 'ink', r: 'blood', o: 'ink' } as Record<string, ColorKey>;
      pixels(root, g.rows(), keys);
      const tag = group(root);
      rect(tag, 26, 82, 13, 9, 'night');
      letter(tag, mark, 28, 84, 'paper');
      letter(tag, clip[0], 33, 84, 'gold');
    },
  };
}

/** CG 占位：320×180 场景，左上角写编号，差分用不同的天空颜色和角色位置。 */
function cg(id: string, label: string, sky: ColorKey, ground: ColorKey, variant: number): SheetSpec {
  return {
    kind: 'sheet',
    id,
    size: [320, 180],
    pivot: [0, 0],
    fps: 1,
    clips: { idle: { frames: 1 } },
    tags: ['narrative', 'cg', 'placeholder'],
    drawFrame(root) {
      rect(root, 0, 0, 320, 180, sky);
      for (let i = 0; i < 6; i++) rect(root, 0, 100 + i * 4, 320, 4, i % 2 ? ground : 'moss');
      rect(root, 0, 124, 320, 56, ground);
      const moonX = variant === 0 ? 250 : 60;
      const moon = new Grid(40, 40).ellipse(20, 20, 16, 16, 'm');
      pixels(root, moon.rows(false), { m: 'cream' }, moonX, 14);
      const fig = new Grid(30, 60).ellipse(15, 10, 7, 8, 'f').rect(7, 18, 16, 30, 'f').rect(8, 48, 5, 12, 'f').rect(17, 48, 5, 12, 'f');
      pixels(root, fig.rows(), { f: 'night', o: 'ink' }, variant === 0 ? 120 : 180, 80);
      const g = group(root, { transform: 'scale(4)' });
      [...label].forEach((ch, i) => letter(g, ch, 2 + i * 4, 2, 'paper'));
    },
  };
}

function bg(id: string, top: ColorKey, mid: ColorKey, bottom: ColorKey): SheetSpec {
  return {
    kind: 'sheet',
    id,
    size: [320, 180],
    pivot: [0, 0],
    fps: 1,
    clips: { idle: { frames: 1 } },
    tags: ['narrative', 'bg', 'placeholder'],
    drawFrame(root) {
      rect(root, 0, 0, 320, 70, top);
      rect(root, 0, 70, 320, 50, mid);
      rect(root, 0, 120, 320, 60, bottom);
      for (let x = 0; x < 320; x += 24) rect(root, x, 60 + ((x * 7) % 13), 14, 60, 'pine');
    },
  };
}

export default [
  portrait('lorenzo', 'red', 'blood', 'bark', 'L'),
  portrait('imele', 'violet', 'plum', 'gold', 'I'),
  portrait('gina', 'leaf', 'moss', 'clay', 'G'),
  portrait('pasca', 'sky', 'navy', 'paper', 'P'),
  cg('cg._dev_01', 'CG01', 'navy', 'leaf', 0),
  cg('cg._dev_01b', 'CG01B', 'plum', 'moss', 1),
  bg('bg._dev_forest', 'deep', 'navy', 'moss'),
] satisfies SheetSpec[];
