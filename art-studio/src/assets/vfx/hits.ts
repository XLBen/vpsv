// 命中火花：打中敌人瞬间在命中点播放的短序列帧（4 帧，约 0.2 秒）。
// 统一朝右绘制，Godot 端旋转到击退方向；只用灰阶，由武器色带上色（同 weapons.ts 约定）。
import { Grid } from '../../runtime/grid';
import { frameSteps, pixels } from '../../runtime/pixel';
import type { ColorKey } from '../../runtime/palette';
import type { SheetSpec } from '../../runtime/spec';

const GRAY: Record<string, ColorKey> = { '1': 'dusk', '2': 'mist', '3': 'fog', '4': 'white' };
const FPS = 20;

/** 每帧一张像素图，用不透明度逐帧切换（与火球尾焰同样的做法）。 */
function frames(id: string, size: [number, number], paint: Array<(g: Grid) => void>): SheetSpec {
  return {
    kind: 'sheet',
    id,
    size,
    pivot: [Math.floor(size[0] / 2), Math.floor(size[1] / 2)],
    fps: FPS,
    clips: { idle: { frames: paint.length } },
    tags: ['vfx', 'hit'],
    build(root) {
      paint.forEach((draw, i) => {
        const g = new Grid(size[0], size[1]);
        draw(g);
        const layer = pixels(root, g.rows(false), GRAY);
        frameSteps(layer, paint.map((_, j) => ({ opacity: j === i ? 1 : 0 })), FPS, false);
      });
    },
  };
}

/** 钝器 / 火焰：十字核心炸开，碎点向前方（右侧）飞散。 */
const spark = frames('vfx.hit.spark', [12, 12], [
  (g) => g.rect(5, 5, 2, 2, '4').set(4, 5, '3').set(7, 6, '3').set(5, 4, '3').set(6, 7, '3'),
  (g) => g.rect(5, 5, 2, 2, '4').line(7, 5, 10, 4, '3').line(7, 6, 10, 8, '3').line(4, 6, 2, 6, '2').set(6, 3, '3').set(5, 8, '3'),
  (g) => g.set(10, 3, '3').set(11, 8, '3').set(8, 2, '2').set(8, 10, '2').set(2, 5, '2').rect(5, 5, 2, 2, '2'),
  (g) => g.set(11, 2, '2').set(11, 9, '1').set(9, 1, '1').set(1, 6, '1'),
]);

/** 斩击：一道横向的亮线劈过，然后断成两截消散。 */
const slashHit = frames('vfx.hit.slash', [16, 8], [
  (g) => g.line(5, 5, 11, 3, '4'),
  (g) => g.line(1, 6, 15, 2, '3', 2).line(3, 5, 13, 3, '4'),
  (g) => g.line(1, 6, 6, 5, '2').line(10, 4, 15, 2, '3').set(8, 4, '2'),
  (g) => g.set(1, 6, '1').set(15, 2, '2').set(12, 3, '1'),
]);

/** 魔法：扩张的像素光环 + 四角闪点。 */
const magic = frames('vfx.hit.magic', [12, 12], [
  (g) => g.ring(6, 6, 2.5, 1, '4'),
  (g) => g.ring(6, 6, 4, 2.8, '3').set(6, 6, '4'),
  (g) => g.ring(6, 6, 5.5, 4.5, '2').set(2, 2, '4').set(9, 9, '3').set(9, 2, '3').set(2, 9, '3'),
  (g) => g.set(1, 1, '2').set(10, 10, '1').set(10, 1, '1').set(1, 10, '1'),
]);

export default [spark, slashHit, magic] satisfies SheetSpec[];
