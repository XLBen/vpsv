// 预览页与导出页共用的“挂载 / 跳转 / 采样 / 渲染”逻辑。
import { canvas } from './pixel';
import { seekAll, type Driver } from './time-driver';
import { SPECS, spec } from './registry';
import { meta, type AudioSpec, type MotionSpec, type SheetSpec } from './spec';
import { PALETTE } from './palette';

export interface Mounted {
  drivers: Driver[];
  seek(ms: number): Promise<void>;
}

/** 只清理 root 内部的动画与节点（预览页会同时挂多个舞台）。 */
function clear(root: HTMLElement) {
  for (const a of document.getAnimations()) {
    const t = (a.effect as KeyframeEffect | null)?.target;
    if (t && root.contains(t)) a.cancel();
  }
  root.replaceChildren();
}

/** 把序列帧素材的某个 clip 挂到 root 上；静态变体素材需要给出 frame。 */
export function mountSheet(root: HTMLElement, id: string, clip: string, frame = 0): Mounted {
  const s = spec(id) as SheetSpec;
  clear(root);
  const svg = canvas(root, s.size[0], s.size[1]);
  let drivers: Driver[] = [];
  if (s.drawFrame) s.drawFrame(svg, clip, frame);
  else drivers = s.build?.(svg, clip) || [];
  return { drivers, seek: (ms) => seekAll(ms, drivers) };
}

export function frameTime(s: SheetSpec, clip: string, frame: number): number {
  const fps = s.clips[clip].fps ?? s.fps;
  // 取帧中点稍前，避开逐帧关键帧的边界。
  return (frame * 1000) / fps + 0.5;
}

export function mountMotion(root: HTMLElement, id: string): Mounted {
  const s = spec(id) as MotionSpec;
  clear(root);
  root.style.width = `${s.stage[0]}px`;
  root.style.height = `${s.stage[1]}px`;
  const drivers = s.build(root) || [];
  // 变换原点与 Godot 端 pivot 保持一致。
  for (const [name, [px, py]] of Object.entries(s.targets)) {
    const e = root.querySelector<HTMLElement>(`[data-target="${name}"]`);
    if (e) e.style.transformOrigin = `${px * 100}% ${py * 100}%`;
  }
  return { drivers, seek: (ms) => seekAll(ms, drivers) };
}

export interface MotionTrack {
  x: number[];
  y: number[];
  sx: number[];
  sy: number[];
  rot: number[];
  alpha: number[];
}

/**
 * 合成最终变换：CSS 独立属性 translate → rotate → scale，再乘以 transform。
 * GSAP 写 transform，Motion 写独立属性，两者都要覆盖。
 */
function composedTransform(cs: CSSStyleDeclaration): DOMMatrix {
  const m = new DOMMatrix();
  if (cs.translate && cs.translate !== 'none') {
    const [x, y] = cs.translate.split(' ').map((v) => parseFloat(v) || 0);
    m.translateSelf(x, y ?? 0);
  }
  if (cs.rotate && cs.rotate !== 'none') {
    const v = cs.rotate.split(' ').pop()!;
    const deg = v.endsWith('rad') ? (parseFloat(v) * 180) / Math.PI : v.endsWith('turn') ? parseFloat(v) * 360 : parseFloat(v);
    m.rotateSelf(deg);
  }
  if (cs.scale && cs.scale !== 'none') {
    const [sx, sy] = cs.scale.split(' ').map(parseFloat);
    m.scaleSelf(sx, sy ?? sx);
  }
  if (cs.transform && cs.transform !== 'none') m.multiplySelf(new DOMMatrix(cs.transform));
  return m;
}

/** 逐帧采样所有 data-target 元素的平移、缩放、旋转（度）与不透明度。 */
export async function sampleMotion(root: HTMLElement, id: string) {
  const s = spec(id) as MotionSpec;
  const fps = s.fps ?? 60;
  const m = mountMotion(root, id);
  const frames = Math.round((s.duration / 1000) * fps) + 1;
  const tracks: Record<string, MotionTrack> = {};
  const els: Record<string, HTMLElement> = {};
  for (const name of Object.keys(s.targets)) {
    const e = root.querySelector<HTMLElement>(`[data-target="${name}"]`);
    if (!e) throw new Error(`${id}: 找不到目标 ${name}`);
    els[name] = e;
    tracks[name] = { x: [], y: [], sx: [], sy: [], rot: [], alpha: [] };
  }
  const r = (v: number, d = 1000) => Math.round(v * d) / d;
  for (let f = 0; f < frames; f++) {
    await m.seek(Math.min(s.duration, (f * 1000) / fps));
    for (const [name, e] of Object.entries(els)) {
      const mx = composedTransform(getComputedStyle(e));
      const cs = getComputedStyle(e);
      const t = tracks[name];
      t.x.push(r(mx.e, 100));
      t.y.push(r(mx.f, 100));
      t.sx.push(r(Math.hypot(mx.a, mx.b)));
      t.sy.push(r(Math.sign(mx.a * mx.d - mx.b * mx.c || 1) * Math.hypot(mx.c, mx.d)));
      t.rot.push(r((Math.atan2(mx.b, mx.a) * 180) / Math.PI, 100));
      t.alpha.push(r(parseFloat(cs.opacity)));
    }
  }
  return { id, fps, duration: s.duration, frames, drive: s.drive ?? 'time', stage: s.stage, targets: s.targets, tracks };
}

export async function renderAudio(id: string): Promise<{ sampleRate: number; data: number[] }> {
  const s = spec(id) as AudioSpec;
  const sampleRate = s.sampleRate ?? 44100;
  const ctx = new OfflineAudioContext(1, Math.ceil(s.duration * sampleRate), sampleRate);
  s.render(ctx);
  const buf = await ctx.startRendering();
  const ch = buf.getChannelData(0);
  let peak = 0;
  for (let i = 0; i < ch.length; i++) peak = Math.max(peak, Math.abs(ch[i]));
  const gain = peak > 0 ? (s.peak ?? 0.8) / peak : 1;
  const data = new Array<number>(ch.length);
  for (let i = 0; i < ch.length; i++) data[i] = Math.round(Math.max(-1, Math.min(1, ch[i] * gain)) * 32767);
  return { sampleRate, data };
}

export function listMeta() {
  return SPECS.map(meta);
}

export { PALETTE };
