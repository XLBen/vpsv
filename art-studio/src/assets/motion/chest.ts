// 宝箱开启演出（老虎机式）：抖动蓄力 → 弹开 → 物品依次弹出 → 金币滚动。
import { gsap } from 'gsap';
import { gsapDriver } from '../../runtime/time-driver';
import type { MotionSpec } from '../../runtime/spec';

function box(root: HTMLElement, name: string, w: number, h: number, x: number, y: number): HTMLElement {
  const e = document.createElement('div');
  e.dataset.target = name;
  Object.assign(e.style, { position: 'absolute', left: `${x}px`, top: `${y}px`, width: `${w}px`, height: `${h}px`, background: '#a0603f', border: '2px solid #f5c542', boxSizing: 'border-box' });
  root.appendChild(e);
  return e;
}

/** 宝箱抖动蓄力（GSAP）：越抖越快、越抖越大，最后向上一跳。 */
const shake: MotionSpec = {
  kind: 'motion',
  id: 'motion.chest.shake',
  duration: 1400,
  stage: [200, 160],
  targets: { chest: [0.5, 1.0] },
  build(root) {
    const c = box(root, 'chest', 64, 64, 68, 60);
    const tl = gsap.timeline();
    const steps = 12;
    for (let i = 0; i < steps; i++) {
      const k = i / steps;
      const amp = 1 + k * 4;
      tl.to(c, { rotation: (i % 2 ? -1 : 1) * amp, x: (i % 2 ? -1 : 1) * amp * 0.5, duration: 0.1 - k * 0.06, ease: 'sine.inOut' });
    }
    tl.to(c, { rotation: 0, x: 0, scaleY: 0.8, scaleX: 1.15, duration: 0.08 })
      .to(c, { y: -18, scaleY: 1.15, scaleX: 0.9, duration: 0.14, ease: 'power2.out' })
      .to(c, { y: 0, scaleY: 1, scaleX: 1, duration: 0.2, ease: 'bounce.out' });
    return [gsapDriver(tl)];
  },
};

/** 物品从宝箱中弹出（GSAP，单个物品；Godot 端按序号交错）。 */
const itemPop: MotionSpec = {
  kind: 'motion',
  id: 'motion.chest.item_pop',
  duration: 700,
  stage: [200, 200],
  targets: { item: [0.5, 0.5] },
  build(root) {
    const it = box(root, 'item', 32, 32, 84, 84);
    const tl = gsap.timeline();
    tl.fromTo(it, { y: 60, scale: 0.2, opacity: 0, rotation: -180 }, { y: -10, scale: 1.4, opacity: 1, rotation: 0, duration: 0.4, ease: 'back.out(2)' })
      .to(it, { y: 0, scale: 1, duration: 0.3, ease: 'bounce.out' });
    return [gsapDriver(tl)];
  },
};

/** 头奖横幅（5 件时）。 */
const jackpot: MotionSpec = {
  kind: 'motion',
  id: 'motion.chest.jackpot',
  duration: 1000,
  stage: [240, 80],
  targets: { banner: [0.5, 0.5] },
  build(root) {
    const b = box(root, 'banner', 160, 24, 40, 28);
    const tl = gsap.timeline();
    tl.fromTo(b, { scale: 3, opacity: 0, rotation: -10 }, { scale: 1, opacity: 1, rotation: 0, duration: 0.3, ease: 'power3.in' })
      .to(b, { scale: 1.15, duration: 0.12, yoyo: true, repeat: 3, ease: 'sine.inOut' })
      .to(b, { rotation: 2, duration: 0.1 })
      .to(b, { rotation: 0, duration: 0.1 });
    return [gsapDriver(tl)];
  },
};

export default [shake, itemPop, jackpot];
