// 战斗音效：武器出手、命中、敌人死亡、玩家受伤、首领与死神。
// 都很短（< 0.4s），游戏端再做音高随机与复音限制（content/audio.json）。
import { bell, coin, noise, out, tone } from '../../runtime/synth';
import type { AudioSpec } from '../../runtime/spec';

const sfx = (id: string, duration: number, render: AudioSpec['render']): AudioSpec => ({ kind: 'audio', id, duration, render, tags: ['sfx'] });

export default [
  // ---- 武器
  sfx('sfx.weapon.whip', 0.18, (c) => {
    const o = out(c);
    noise(c, o, { dur: 0.16, vol: 0.5, bp: 1800, q: 1.5, sweepTo: 5000 });
    tone(c, o, { type: 'sawtooth', freq: 900, slideTo: 300, dur: 0.08, vol: 0.12 });
  }),
  sfx('sfx.weapon.wand', 0.2, (c) => {
    const o = out(c);
    tone(c, o, { type: 'triangle', freq: 1320, slideTo: 2600, dur: 0.12, vol: 0.25 });
    tone(c, o, { type: 'sine', freq: 2640, slideTo: 3500, dur: 0.15, vol: 0.12, t: 0.02 });
  }),
  sfx('sfx.weapon.knife', 0.12, (c) => {
    const o = out(c);
    noise(c, o, { dur: 0.08, vol: 0.4, hp: 3000, sweepTo: 9000 });
    tone(c, o, { type: 'square', freq: 1900, slideTo: 1200, dur: 0.04, vol: 0.06 });
  }),
  sfx('sfx.weapon.axe', 0.3, (c) => {
    const o = out(c);
    noise(c, o, { dur: 0.25, vol: 0.35, bp: 600, q: 2, sweepTo: 1600 });
    tone(c, o, { type: 'triangle', freq: 220, slideTo: 440, dur: 0.2, vol: 0.2 });
  }),
  sfx('sfx.weapon.cross', 0.3, (c) => {
    const o = out(c);
    bell(c, o, 1760, 0, 0.25, 0.18);
    noise(c, o, { dur: 0.2, vol: 0.2, bp: 3000, q: 4, sweepTo: 1500 });
  }),
  sfx('sfx.weapon.bible', 0.5, (c) => {
    const o = out(c);
    for (const [f, t] of [[523, 0], [659, 0.06], [784, 0.12]] as const) tone(c, o, { type: 'sine', freq: f * 2, t, dur: 0.3, vol: 0.15 });
  }),
  sfx('sfx.weapon.fire', 0.35, (c) => {
    const o = out(c);
    noise(c, o, { dur: 0.3, vol: 0.45, lp: 1200, sweepTo: 300 });
    tone(c, o, { type: 'sawtooth', freq: 160, slideTo: 80, dur: 0.25, vol: 0.12 });
  }),
  sfx('sfx.weapon.garlic', 0.25, (c) => {
    const o = out(c);
    tone(c, o, { type: 'sine', freq: 300, slideTo: 180, dur: 0.2, vol: 0.18 });
    noise(c, o, { dur: 0.12, vol: 0.1, lp: 800 });
  }),
  sfx('sfx.weapon.water', 0.25, (c) => {
    const o = out(c);
    tone(c, o, { type: 'sine', freq: 700, slideTo: 1400, dur: 0.18, vol: 0.15 });
  }),
  sfx('sfx.weapon.water_splash', 0.4, (c) => {
    const o = out(c);
    noise(c, o, { dur: 0.35, vol: 0.4, bp: 2500, q: 1, sweepTo: 600 });
    bell(c, o, 1200, 0.02, 0.2, 0.08);
  }),
  sfx('sfx.weapon.rune', 0.3, (c) => {
    const o = out(c);
    tone(c, o, { type: 'square', freq: 880, slideTo: 1760, dur: 0.1, vol: 0.08 });
    bell(c, o, 2093, 0.03, 0.25, 0.12);
  }),
  sfx('sfx.weapon.lightning', 0.5, (c) => {
    const o = out(c);
    noise(c, o, { dur: 0.45, vol: 0.6, hp: 400, sweepTo: 80 });
    tone(c, o, { type: 'square', freq: 2400, slideTo: 200, dur: 0.12, vol: 0.12 });
  }),
  sfx('sfx.weapon.pentagram', 1.2, (c) => {
    const o = out(c);
    for (let i = 0; i < 6; i++) bell(c, o, 523 * Math.pow(2, i / 5), i * 0.05, 0.9, 0.12);
    noise(c, o, { dur: 1.0, vol: 0.3, lp: 3000, sweepTo: 200 });
  }),
  sfx('sfx.weapon.bird', 0.3, (c) => {
    const o = out(c);
    noise(c, o, { dur: 0.25, vol: 0.45, lp: 900, sweepTo: 200 });
    tone(c, o, { type: 'sine', freq: 140, slideTo: 60, dur: 0.25, vol: 0.3 });
  }),
  sfx('sfx.weapon.clock', 0.3, (c) => {
    const o = out(c);
    tone(c, o, { type: 'square', freq: 3000, dur: 0.02, vol: 0.1 });
    bell(c, o, 2637, 0.02, 0.25, 0.15);
  }),
  sfx('sfx.weapon.laurel', 0.6, (c) => {
    const o = out(c);
    for (const [f, t] of [[784, 0], [1047, 0.08], [1319, 0.16]] as const) bell(c, o, f, t, 0.4, 0.12);
  }),
  // ---- 敌人
  sfx('sfx.enemy.hit', 0.08, (c) => {
    const o = out(c);
    noise(c, o, { dur: 0.06, vol: 0.35, bp: 1200, q: 1 });
    tone(c, o, { type: 'square', freq: 220, slideTo: 110, dur: 0.05, vol: 0.08 });
  }),
  sfx('sfx.enemy.die', 0.15, (c) => {
    const o = out(c);
    tone(c, o, { type: 'square', freq: 440, slideTo: 90, dur: 0.12, vol: 0.12 });
    noise(c, o, { dur: 0.1, vol: 0.2, lp: 2000 });
  }),
  sfx('sfx.enemy.dash', 0.4, (c) => {
    const o = out(c);
    tone(c, o, { type: 'sawtooth', freq: 120, slideTo: 500, dur: 0.35, vol: 0.2 });
    noise(c, o, { dur: 0.35, vol: 0.25, bp: 800, sweepTo: 3000 });
  }),
  sfx('sfx.enemy.boss_appear', 1.2, (c) => {
    const o = out(c);
    for (let i = 0; i < 3; i++) tone(c, o, { type: 'sawtooth', freq: 110, dur: 0.3, t: i * 0.35, vol: 0.25 });
    tone(c, o, { type: 'square', freq: 220, slideTo: 207, dur: 1.0, vol: 0.08 });
  }),
  sfx('sfx.enemy.boss_down', 1.0, (c) => {
    const o = out(c);
    noise(c, o, { dur: 0.8, vol: 0.6, lp: 1500, sweepTo: 60 });
    tone(c, o, { type: 'sine', freq: 90, slideTo: 30, dur: 0.8, vol: 0.4 });
  }),
  sfx('sfx.enemy.reaper', 2.0, (c) => {
    const o = out(c);
    tone(c, o, { type: 'sawtooth', freq: 55, dur: 1.8, vol: 0.3, attack: 0.3 });
    tone(c, o, { type: 'sawtooth', freq: 58, dur: 1.8, vol: 0.2, attack: 0.3 });
    bell(c, o, 196, 0.2, 1.6, 0.25);
  }),
  sfx('sfx.prop.break', 0.25, (c) => {
    const o = out(c);
    noise(c, o, { dur: 0.2, vol: 0.5, bp: 2500, q: 1.2 });
    coin(c, o, 1800, 0.01, 0.15);
  }),
  // ---- 玩家
  sfx('sfx.player.hurt', 0.25, (c) => {
    const o = out(c);
    tone(c, o, { type: 'sawtooth', freq: 180, slideTo: 70, dur: 0.2, vol: 0.3 });
    noise(c, o, { dur: 0.12, vol: 0.25, lp: 1200 });
  }),
  sfx('sfx.player.revive', 1.2, (c) => {
    const o = out(c);
    for (let i = 0; i < 8; i++) bell(c, o, 523 * Math.pow(2, i / 7), i * 0.07, 0.6, 0.12);
  }),
] satisfies AudioSpec[];
