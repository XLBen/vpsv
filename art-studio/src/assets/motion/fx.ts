// 世界内小物件的动效曲线：环绕书本 / 护盾的出现与收起、伤害数字的弹跳。
// Godot 端用 MotionPlayer.sample() 逐帧取样（位置由游戏代码决定，只取缩放、透明度和偏移）。
import { gsap } from 'gsap';
import { gsapDriver } from '../../runtime/time-driver';
import type { MotionSpec } from '../../runtime/spec';

function box(root: HTMLElement, name: string): HTMLElement {
  const e = document.createElement('div');
  e.dataset.target = name;
  Object.assign(e.style, { position: 'absolute', left: '40px', top: '40px', width: '24px', height: '24px', background: '#f5c542' });
  root.appendChild(e);
  return e;
}

/** 弹出：从 0 回弹放大到 1（GSAP back.out）。 */
const popIn: MotionSpec = {
  kind: 'motion',
  id: 'motion.fx.pop_in',
  duration: 180,
  stage: [104, 104],
  targets: { item: [0.5, 0.5] },
  build(root) {
    const b = box(root, 'item');
    const tl = gsap.timeline();
    tl.fromTo(b, { scale: 0, opacity: 0 }, { scale: 1, duration: 0.18, ease: 'back.out(2.6)' }).to(b, { opacity: 1, duration: 0.06 }, 0);
    return [gsapDriver(tl)];
  },
};

/** 收起：先胀一下再缩没，同时淡出。 */
const popOut: MotionSpec = {
  kind: 'motion',
  id: 'motion.fx.pop_out',
  duration: 160,
  stage: [104, 104],
  targets: { item: [0.5, 0.5] },
  build(root) {
    const b = box(root, 'item');
    const tl = gsap.timeline();
    tl.to(b, { scale: 1.25, duration: 0.05, ease: 'power1.out' })
      .to(b, { scale: 0, duration: 0.11, ease: 'power2.in' })
      .to(b, { opacity: 0, duration: 0.11, ease: 'none' }, 0.05);
    return [gsapDriver(tl)];
  },
};

/** 伤害数字：向上弹起、轻微回落，然后缓慢上飘并在末尾淡出（总长 = feel.json 的 number_life）。 */
const damageNumber: MotionSpec = {
  kind: 'motion',
  id: 'motion.fx.damage_number',
  duration: 600,
  stage: [104, 104],
  targets: { number: [0.5, 1.0] },
  build(root) {
    const b = box(root, 'number');
    const tl = gsap.timeline();
    tl.fromTo(b, { y: 3 }, { y: -8, duration: 0.12, ease: 'power3.out' })
      .to(b, { y: -6, duration: 0.06, ease: 'sine.in' })
      .to(b, { y: -14, duration: 0.42, ease: 'none' })
      .fromTo(b, { opacity: 1 }, { opacity: 0, duration: 0.18, ease: 'power1.in' }, 0.42);
    return [gsapDriver(tl)];
  },
};

export default [popIn, popOut, damageNumber] satisfies MotionSpec[];
