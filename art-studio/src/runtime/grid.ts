// 程序化像素网格：用几何图元画出像素图（字符矩阵），再交给 pixels() 渲染。
import { outline } from './pixel';

export class Grid {
  readonly cells: string[][];
  constructor(readonly w: number, readonly h: number) {
    this.cells = Array.from({ length: h }, () => Array(w).fill('.'));
  }

  set(x: number, y: number, c: string): this {
    x = Math.round(x);
    y = Math.round(y);
    if (x >= 0 && y >= 0 && x < this.w && y < this.h) this.cells[y][x] = c;
    return this;
  }

  rect(x: number, y: number, w: number, h: number, c: string): this {
    for (let j = 0; j < Math.round(h); j++) for (let i = 0; i < Math.round(w); i++) this.set(x + i, y + j, c);
    return this;
  }

  /** 填充椭圆，(cx, cy) 为像素坐标系中心（可为小数）。 */
  ellipse(cx: number, cy: number, rx: number, ry: number, c: string): this {
    for (let y = 0; y < this.h; y++)
      for (let x = 0; x < this.w; x++) {
        const dx = (x + 0.5 - cx) / rx;
        const dy = (y + 0.5 - cy) / ry;
        if (dx * dx + dy * dy <= 1) this.set(x, y, c);
      }
    return this;
  }

  /** 填充三角形（重心坐标判定）。 */
  tri(ax: number, ay: number, bx: number, by: number, cx: number, cy: number, c: string): this {
    const s = (px: number, py: number, qx: number, qy: number, rx: number, ry: number) => (px - rx) * (qy - ry) - (qx - rx) * (py - ry);
    for (let y = 0; y < this.h; y++)
      for (let x = 0; x < this.w; x++) {
        const px = x + 0.5;
        const py = y + 0.5;
        const d1 = s(px, py, ax, ay, bx, by);
        const d2 = s(px, py, bx, by, cx, cy);
        const d3 = s(px, py, cx, cy, ax, ay);
        const neg = d1 < 0 || d2 < 0 || d3 < 0;
        const pos = d1 > 0 || d2 > 0 || d3 > 0;
        if (!(neg && pos)) this.set(x, y, c);
      }
    return this;
  }

  /** 粗细为 th 的直线（Bresenham）。 */
  line(x0: number, y0: number, x1: number, y1: number, c: string, th = 1): this {
    x0 = Math.round(x0); y0 = Math.round(y0); x1 = Math.round(x1); y1 = Math.round(y1);
    const dx = Math.abs(x1 - x0), sx = x0 < x1 ? 1 : -1;
    const dy = -Math.abs(y1 - y0), sy = y0 < y1 ? 1 : -1;
    let err = dx + dy;
    for (;;) {
      this.rect(x0 - Math.floor((th - 1) / 2), y0 - Math.floor((th - 1) / 2), th, th, c);
      if (x0 === x1 && y0 === y1) break;
      const e2 = 2 * err;
      if (e2 >= dy) { err += dy; x0 += sx; }
      if (e2 <= dx) { err += dx; y0 += sy; }
    }
    return this;
  }

  /** 圆环：外椭圆减去内椭圆。 */
  ring(cx: number, cy: number, r: number, inner: number, c: string): this {
    for (let y = 0; y < this.h; y++)
      for (let x = 0; x < this.w; x++) {
        const d = Math.hypot(x + 0.5 - cx, y + 0.5 - cy);
        if (d <= r && d > inner) this.set(x, y, c);
      }
    return this;
  }

  /** 只替换已填充的像素（用于在形状内加阴影、高光）。 */
  shade(pred: (x: number, y: number) => boolean, c: string, only?: string): this {
    for (let y = 0; y < this.h; y++)
      for (let x = 0; x < this.w; x++) {
        const cur = this.cells[y][x];
        if (cur !== '.' && (!only || only.includes(cur)) && pred(x, y)) this.cells[y][x] = c;
      }
    return this;
  }

  rows(withOutline = true): string[] {
    const r = this.cells.map((row) => row.join(''));
    return withOutline ? outline(r, 'o') : r;
  }
}
