// 界面动效：在这里用 CSS 动画 / Web Animations API / GSAP / Motion 编排，
// 导出为逐帧曲线后由 Godot 的 MotionPlayer 驱动真实界面节点（文字和数值保持实时）。
// 约定：每个 data-target 的变换原点由 targets 指定；交错延迟在 Godot 端按序号叠加。
import { gsap } from 'gsap';
import { animate } from 'motion';
import { gsapDriver, motionDriver } from '../../runtime/time-driver';
import type { MotionSpec } from '../../runtime/spec';

function box(root: HTMLElement, name: string, w: number, h: number, x: number, y: number): HTMLElement {
  const e = document.createElement('div');
  e.dataset.target = name;
  Object.assign(e.style, { position: 'absolute', left: `${x}px`, top: `${y}px`, width: `${w}px`, height: `${h}px`, background: '#463a52', border: '2px solid #f5c542', boxSizing: 'border-box' });
  root.appendChild(e);
  return e;
}

const asControls = (c: unknown) => c as { pause(): void; time: number };

/** 面板弹出（GSAP）：从略小、略低处回弹到位。 */
const panelIn: MotionSpec = {
  kind: 'motion',
  id: 'motion.ui.panel_in',
  duration: 380,
  stage: [320, 200],
  targets: { panel: [0.5, 0.5] },
  build(root) {
    const p = box(root, 'panel', 240, 140, 40, 30);
    const tl = gsap.timeline();
    tl.fromTo(p, { y: 14, scale: 0.86, opacity: 0 }, { y: 0, scale: 1, opacity: 1, duration: 0.38, ease: 'back.out(1.8)' });
    return [gsapDriver(tl)];
  },
};

/** 面板收起（GSAP）。 */
const panelOut: MotionSpec = {
  kind: 'motion',
  id: 'motion.ui.panel_out',
  duration: 200,
  stage: [320, 200],
  targets: { panel: [0.5, 0.5] },
  build(root) {
    const p = box(root, 'panel', 240, 140, 40, 30);
    const tl = gsap.timeline();
    tl.to(p, { y: 8, scale: 0.92, opacity: 0, duration: 0.2, ease: 'power2.in' });
    return [gsapDriver(tl)];
  },
};

/** 升级卡片入场（GSAP，单张卡；Godot 端按序号交错 70ms）。 */
const cardIn: MotionSpec = {
  kind: 'motion',
  id: 'motion.ui.card_in',
  duration: 450,
  stage: [240, 120],
  targets: { card: [0.5, 0.5] },
  build(root) {
    const card = box(root, 'card', 200, 40, 20, 40);
    const tl = gsap.timeline();
    tl.fromTo(card, { x: -30, opacity: 0, scale: 0.8, rotation: -3 }, { x: 0, opacity: 1, scale: 1, rotation: 0, duration: 0.45, ease: 'back.out(2.2)' });
    return [gsapDriver(tl)];
  },
};

/** 标题横幅（GSAP 时间轴）：掉落 → 压扁回弹 → 轻微摇摆。 */
const banner: MotionSpec = {
  kind: 'motion',
  id: 'motion.ui.banner_drop',
  duration: 900,
  stage: [320, 120],
  targets: { banner: [0.5, 1.0] },
  build(root) {
    const b = box(root, 'banner', 160, 30, 80, 50);
    const tl = gsap.timeline();
    tl.fromTo(b, { y: -70, opacity: 0 }, { y: 0, opacity: 1, duration: 0.35, ease: 'power2.in' })
      .to(b, { scaleY: 0.7, scaleX: 1.2, duration: 0.07, ease: 'power1.out' })
      .to(b, { scaleY: 1, scaleX: 1, duration: 0.28, ease: 'elastic.out(1.2, 0.4)' })
      .to(b, { rotation: 3, duration: 0.1, ease: 'sine.inOut' })
      .to(b, { rotation: 0, duration: 0.1, ease: 'sine.inOut' });
    return [gsapDriver(tl)];
  },
};

/** 提示条入场（Motion 弹簧）。 */
const toastIn: MotionSpec = {
  kind: 'motion',
  id: 'motion.ui.toast_in',
  duration: 500,
  stage: [240, 60],
  targets: { toast: [0.5, 0.5] },
  build(root) {
    const t = box(root, 'toast', 160, 20, 40, 20);
    const c = animate(t, { y: [-24, 0], opacity: [0, 1], scale: [0.8, 1] }, { type: 'spring', stiffness: 420, damping: 18, duration: 0.5 });
    return [motionDriver(asControls(c))];
  },
};

/** 提示条退场（Motion）。 */
const toastOut: MotionSpec = {
  kind: 'motion',
  id: 'motion.ui.toast_out',
  duration: 300,
  stage: [240, 60],
  targets: { toast: [0.5, 0.5] },
  build(root) {
    const t = box(root, 'toast', 160, 20, 40, 20);
    const c = animate(t, { y: [0, -14], opacity: [1, 0] }, { duration: 0.3, ease: 'easeIn' });
    return [motionDriver(asControls(c))];
  },
};

/** 按钮悬停（CSS 关键帧动画）：轻微放大后回落，循环呼吸。 */
const buttonHover: MotionSpec = {
  kind: 'motion',
  id: 'motion.ui.button_hover',
  duration: 600,
  stage: [160, 60],
  targets: { button: [0.5, 0.5] },
  build(root) {
    const style = document.createElement('style');
    style.textContent = `@keyframes hover-bump { 0% { transform: scale(1) } 25% { transform: scale(1.08) translateY(-1px) } 60% { transform: scale(1.03) } 100% { transform: scale(1.05) } }
      .hover-bump { animation: hover-bump 600ms cubic-bezier(.3,1.6,.5,1) both; }`;
    root.appendChild(style);
    const b = box(root, 'button', 100, 20, 30, 20);
    b.classList.add('hover-bump');
  },
};

/** 按钮按下（Web Animations API）。 */
const buttonPress: MotionSpec = {
  kind: 'motion',
  id: 'motion.ui.button_press',
  duration: 220,
  stage: [160, 60],
  targets: { button: [0.5, 0.5] },
  build(root) {
    const b = box(root, 'button', 100, 20, 30, 20);
    b.animate(
      [
        { transform: 'scale(1)' },
        { transform: 'scale(0.9) translateY(1px)', offset: 0.35 },
        { transform: 'scale(1.04)', offset: 0.7 },
        { transform: 'scale(1)' },
      ],
      { duration: 220, easing: 'ease-out', fill: 'both' },
    );
  },
};

/** 数值跳动（Web Animations API）：金币、击杀数变化时。 */
const numberPop: MotionSpec = {
  kind: 'motion',
  id: 'motion.ui.number_pop',
  duration: 260,
  stage: [120, 40],
  targets: { number: [0.0, 0.5] },
  build(root) {
    const n = box(root, 'number', 60, 12, 20, 14);
    n.animate([{ transform: 'scale(1)' }, { transform: 'scale(1.35)', offset: 0.3 }, { transform: 'scale(1)' }], { duration: 260, easing: 'ease-out', fill: 'both' });
  },
};

/** 图标抖动（Web Animations API）：新获得 / 升级的图标。 */
const iconWiggle: MotionSpec = {
  kind: 'motion',
  id: 'motion.ui.icon_wiggle',
  duration: 420,
  stage: [64, 64],
  targets: { icon: [0.5, 0.5] },
  build(root) {
    const i = box(root, 'icon', 32, 32, 16, 16);
    i.animate(
      [{ transform: 'rotate(0) scale(1)' }, { transform: 'rotate(-12deg) scale(1.25)', offset: 0.2 }, { transform: 'rotate(10deg) scale(1.15)', offset: 0.45 }, { transform: 'rotate(-5deg)', offset: 0.7 }, { transform: 'rotate(0) scale(1)' }],
      { duration: 420, easing: 'ease-out', fill: 'both' },
    );
  },
};

/** 滚动揭示（GSAP，按进度驱动）：列表项随滚动进度从右侧滑入。 */
const scrollReveal: MotionSpec = {
  kind: 'motion',
  id: 'motion.ui.scroll_reveal',
  duration: 1000,
  drive: 'progress',
  stage: [200, 60],
  targets: { item: [0.5, 0.5] },
  build(root) {
    const item = box(root, 'item', 120, 30, 40, 15);
    const tl = gsap.timeline();
    tl.fromTo(item, { x: 40, opacity: 0, scale: 0.9 }, { x: 0, opacity: 1, scale: 1, duration: 0.6, ease: 'power3.out' }).to(item, { duration: 0.4 });
    return [gsapDriver(tl)];
  },
};

export default [panelIn, panelOut, cardIn, banner, toastIn, toastOut, buttonHover, buttonPress, numberPop, iconWiggle, scrollReveal];
