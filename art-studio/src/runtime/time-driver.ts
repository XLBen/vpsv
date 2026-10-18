// 确定性时间驱动：导出时暂停一切动画，再统一跳转到某一时刻。
// 支持 CSS 动画 / Web Animations API（document.getAnimations）、GSAP 时间轴、Motion 控制器。
import type { gsap } from 'gsap';

export interface Driver {
  /** 跳转到第 ms 毫秒（相对素材开始）。 */
  seek(ms: number): void;
  /** 跳转后需要等主线程帧循环渲染一次（Motion 的 JS 动画）。 */
  needsFrame?: boolean;
}

const nextFrame = () => new Promise<void>((r) => requestAnimationFrame(() => requestAnimationFrame(() => r())));

export async function seekAll(ms: number, drivers: Driver[] = []): Promise<void> {
  for (const a of document.getAnimations()) {
    a.pause();
    a.currentTime = ms;
  }
  for (const d of drivers) d.seek(ms);
  if (drivers.some((d) => d.needsFrame)) await nextFrame();
}

export function gsapDriver(tl: gsap.core.Timeline | gsap.core.Tween): Driver {
  tl.pause();
  return { seek: (ms) => void tl.seek(ms / 1000, false) };
}

interface MotionControls {
  pause(): void;
  time: number;
}

export function motionDriver(controls: MotionControls): Driver {
  controls.pause();
  return {
    needsFrame: true,
    seek: (ms) => {
      controls.time = ms / 1000;
    },
  };
}
