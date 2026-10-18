// 过渡用的像素阈值图案：着色器按 progress 与图案灰度比较，逐格显隐，得到像素风转场。
// 这里用 SVG 画出 16×16 的菱形扩散图案（中心最先出现）。
import { svgEl } from '../../runtime/pixel';
import type { SheetSpec } from '../../runtime/spec';

const diamond: SheetSpec = {
  kind: 'sheet',
  id: 'ui.pattern.diamond',
  size: [16, 16],
  pivot: [0, 0],
  fps: 1,
  clips: { idle: { frames: 1 } },
  tags: ['ui', 'pattern'],
  drawFrame(root) {
    // 灰度 = 曼哈顿距离，导出时会吸附到调色板上的灰阶（ink → white）
    const ramp = ['#14101c', '#2b2233', '#463a52', '#6b5d78', '#9a8ca3', '#c9bfcf', '#f4ecf0', '#ffffff'];
    for (let y = 0; y < 16; y++)
      for (let x = 0; x < 16; x++) {
        const d = Math.abs(x - 7.5) + Math.abs(y - 7.5);
        const k = Math.min(7, Math.floor((d / 15) * 8));
        svgEl('rect', { x, y, width: 1, height: 1, fill: ramp[k] }, root);
      }
  },
};

export default [diamond];
