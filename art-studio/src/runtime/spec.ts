// 素材规格。src/assets/**/*.ts 的默认导出是一个或一组 Spec。
import type { Driver } from './time-driver';
import type { ColorKey } from './palette';

export interface ClipDef {
  frames: number;
  loop?: boolean;
  /** 覆盖素材默认帧率。 */
  fps?: number;
}

/** 像素序列帧：每个 clip 导出为图集中的一行。 */
export interface SheetSpec {
  kind: 'sheet';
  id: string;
  size: [number, number];
  /** 轴心点（像素），默认底部中点。 */
  pivot?: [number, number];
  fps: number;
  clips: Record<string, ClipDef>;
  tags?: string[];
  /**
   * 动画式素材：为某个 clip 搭建场景并返回驱动器（可选）。
   * 导出器按 frame / fps 计算时间并 seek。
   */
  build?(root: SVGSVGElement, clip: string): Driver[] | void;
  /** 静态变体式素材（例如地面图块）：直接画第 frame 帧。 */
  drawFrame?(root: SVGSVGElement, clip: string, frame: number): void;
}

/** UI 动效曲线：对 data-target 元素逐帧采样变换与透明度。 */
export interface MotionSpec {
  kind: 'motion';
  id: string;
  /** 毫秒 */
  duration: number;
  fps?: number;
  /** 预览/采样舞台尺寸（Godot 像素）。 */
  stage: [number, number];
  /** time：按时间播放；progress：由滚动进度等 0..1 的值驱动。 */
  drive?: 'time' | 'progress';
  /** 目标名 → 变换原点（0..1），Godot 端据此设置 pivot_offset。 */
  targets: Record<string, [number, number]>;
  build(root: HTMLElement): Driver[] | void;
}

/** 音效：在 OfflineAudioContext 中合成。 */
export interface AudioSpec {
  kind: 'audio';
  id: string;
  /** 秒 */
  duration: number;
  sampleRate?: number;
  /** 导出时把峰值归一化到这个值（默认 0.8；背景音乐建议 0.6）。实际音量在 content/audio.json 里调。 */
  peak?: number;
  tags?: string[];
  render(ctx: OfflineAudioContext): void;
}

/** 调色板色带：着色器用它把强度映射为颜色，保证特效与像素调色板一致。 */
export interface RampSpec {
  kind: 'ramp';
  id: string;
  colors: ColorKey[];
}

export type Spec = SheetSpec | MotionSpec | AudioSpec | RampSpec;
export type SpecModule = { default: Spec | Spec[] };

/** 导出器与预览器使用的可序列化元信息。 */
export function meta(s: Spec): Record<string, unknown> {
  const { build: _b, drawFrame: _d, render: _r, ...rest } = s as unknown as Record<string, unknown>;
  return { ...rest, static: 'drawFrame' in s && !!(s as SheetSpec).drawFrame };
}
