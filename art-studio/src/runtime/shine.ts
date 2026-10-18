// 通用“光泽扫过”动画：一条斜向亮带只在图形内部扫过（clipPath + WAAPI）。
import { frameSteps, group, rect, svgEl } from './pixel';

let uid = 0;

/** 给 shape 加扫光。frames 帧中前一半静止，后一半亮带从左扫到右。 */
export function shine(root: SVGSVGElement, shape: SVGGElement, w: number, h: number, fps: number, frames = 8): void {
  const id = `shine-${++uid}`;
  shape.id = `${id}-shape`;
  const clip = svgEl('clipPath', { id }, svgEl('defs', {}, root));
  svgEl('use', { href: `#${shape.id}` }, clip);
  const band = group(group(root, { 'clip-path': `url(#${id})` }), { opacity: 0.65 });
  for (let i = 0; i < h + 4; i++) rect(band, -6 + i * 0.5, i - 2, 2, 1, 'paper');
  const quiet = Math.floor(frames / 2);
  const moving = frames - quiet;
  const xs = [...Array(quiet).fill(-w - 8), ...Array.from({ length: moving }, (_, i) => -w / 2 + ((i + 1) * (w * 1.6)) / moving)];
  frameSteps(band, xs.map((x) => ({ transform: `translate(${Math.round(x)}px, 0px)` })), fps);
}
