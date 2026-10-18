// 像素绘制工具：ASCII 像素图 → SVG 矩形；自动描边；逐帧 WAAPI 动画。
import { hex, type ColorKey } from './palette';
import { glyphPixels } from './font3x5';

const NS = 'http://www.w3.org/2000/svg';

export type Attrs = Record<string, string | number>;

export function svgEl<K extends keyof SVGElementTagNameMap>(tag: K, attrs: Attrs = {}, parent?: Element): SVGElementTagNameMap[K] {
  const e = document.createElementNS(NS, tag);
  for (const [k, v] of Object.entries(attrs)) e.setAttribute(k, String(v));
  parent?.appendChild(e);
  return e;
}

/** 在 root 中创建一个 w×h 的像素画布（SVG，关闭抗锯齿）。 */
export function canvas(root: Element, w: number, h: number): SVGSVGElement {
  const s = svgEl('svg', { width: w, height: h, viewBox: `0 0 ${w} ${h}`, 'shape-rendering': 'crispEdges' }, root);
  s.style.display = 'block';
  s.style.overflow = 'visible';
  return s;
}

export function group(parent: Element, attrs: Attrs = {}): SVGGElement {
  return svgEl('g', attrs, parent);
}

export function rect(parent: Element, x: number, y: number, w: number, h: number, color: ColorKey | string): SVGRectElement {
  return svgEl('rect', { x, y, width: w, height: h, fill: hex(color) }, parent);
}

/** 解析多行 ASCII 像素图：去掉首尾空行与公共缩进，'.' 与空格表示透明。 */
export function parseArt(art: string): string[] {
  const lines = art.replace(/\t/g, '    ').split('\n');
  while (lines.length && !lines[0].trim()) lines.shift();
  while (lines.length && !lines[lines.length - 1].trim()) lines.pop();
  const indent = Math.min(...lines.filter((l) => l.trim()).map((l) => l.match(/^ */)![0].length));
  const rows = lines.map((l) => l.slice(indent).replace(/ /g, '.'));
  const w = Math.max(...rows.map((r) => r.length));
  return rows.map((r) => r.padEnd(w, '.'));
}

/** 给像素图加一圈 1px 描边（四邻域），描边使用字符 key。 */
export function outline(rows: string[], key = 'o'): string[] {
  const h = rows.length;
  const w = rows[0]?.length ?? 0;
  const filled = (x: number, y: number) => x >= 0 && y >= 0 && x < w && y < h && rows[y][x] !== '.';
  return rows.map((r, y) =>
    [...r]
      .map((c, x) => {
        if (c !== '.') return c;
        return filled(x - 1, y) || filled(x + 1, y) || filled(x, y - 1) || filled(x, y + 1) ? key : '.';
      })
      .join(''),
  );
}

/** 把像素图画成 SVG（同色横向连续像素合并成一个矩形）。 */
export function pixels(parent: Element, rows: string[], keys: Record<string, ColorKey | string>, ox = 0, oy = 0): SVGGElement {
  const g = group(parent);
  rows.forEach((row, y) => {
    let x = 0;
    while (x < row.length) {
      const c = row[x];
      let n = 1;
      while (x + n < row.length && row[x + n] === c) n++;
      if (c !== '.' && keys[c] !== undefined) rect(g, ox + x, oy + y, n, 1, keys[c]);
      x += n;
    }
  });
  return g;
}

/** 3×5 字母标记。 */
export function letter(parent: Element, ch: string, x: number, y: number, color: ColorKey | string): SVGGElement {
  const g = group(parent);
  for (const [px, py] of glyphPixels(ch)) rect(g, x + px, y + py, 1, 1, color);
  return g;
}

/** 让元素以自身包围盒为参照做 CSS 变换。origin 例如 '50% 100%'（脚底）。 */
export function pivot<T extends SVGElement>(e: T, origin = '50% 100%'): T {
  e.style.transformBox = 'fill-box';
  e.style.transformOrigin = origin;
  return e;
}

/**
 * 逐帧动画（Web Animations API）：values[i] 精确地停留在第 i 帧，
 * 帧与帧之间不插值，保证像素对齐。
 */
export function frameSteps(e: Element, values: Keyframe[], fps: number, loop = true): Animation {
  const n = values.length;
  const kf: Keyframe[] = values.map((v, i) => ({ ...v, offset: i / n, easing: 'steps(1, end)' }));
  kf.push({ ...values[n - 1], offset: 1 });
  return e.animate(kf, { duration: (n * 1000) / fps, iterations: loop ? Infinity : 1, fill: 'both' });
}

/** 平移简写：返回整数像素的 transform 关键帧。 */
export const tr = (x: number, y = 0, extra = ''): Keyframe => ({ transform: `translate(${x}px, ${y}px) ${extra}`.trim() });
