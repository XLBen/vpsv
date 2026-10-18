// 赌场风奖励音效：宝石连拾（游戏端按音阶升调）、金币、拾取物、升级、宝箱开启三档结尾。
import { bell, coin, melody, n, noise, out, tone } from '../../runtime/synth';
import type { AudioSpec } from '../../runtime/spec';

const sfx = (id: string, duration: number, render: AudioSpec['render']): AudioSpec => ({ kind: 'audio', id, duration, render, tags: ['sfx', 'casino'] });

/** 方波号角声部（老虎机赢钱乐句）。 */
const brass = (c: BaseAudioContext, o: AudioNode) => (f: number, t: number, d: number) => {
  tone(c, o, { type: 'square', freq: f, t, dur: d * 0.95, vol: 0.12, attack: 0.005 });
  tone(c, o, { type: 'square', freq: f * 1.003, t, dur: d * 0.95, vol: 0.08 });
};

/** 硬币瀑布：count 枚硬币在 dur 秒内随机落下。 */
function cascade(c: BaseAudioContext, o: AudioNode, t0: number, dur: number, count: number) {
  for (let i = 0; i < count; i++) {
    const r = ((i * 7919) % 1000) / 1000;
    coin(c, o, 2000 + r * 1600, t0 + (i / count) * dur + r * 0.03, 0.12);
  }
}

export default [
  // 宝石：清脆的钟铃。游戏端在 0.4s 窗口内按大调音阶逐次升调，形成“吐币”般的连响。
  sfx('sfx.pickup.gem', 0.3, (c) => {
    const o = out(c);
    bell(c, o, n('C6'), 0, 0.28, 0.35);
  }),
  sfx('sfx.pickup.coin', 0.25, (c) => coin(c, out(c), 2400, 0, 0.35)),
  sfx('sfx.pickup.coin_bag', 0.6, (c) => cascade(c, out(c), 0, 0.4, 8)),
  sfx('sfx.pickup.heal', 0.5, (c) => {
    const o = out(c);
    melody(c, o, [['C5', 1], ['E5', 1], ['G5', 2]], 0, 0.08, (f, t, d) => bell(c, o, f, t, d * 3, 0.2));
  }),
  sfx('sfx.pickup.freeze', 0.8, (c) => {
    const o = out(c);
    for (let i = 0; i < 6; i++) bell(c, o, n('E6') * Math.pow(2, -i / 12), i * 0.05, 0.5, 0.12);
    noise(c, o, { dur: 0.7, vol: 0.2, hp: 5000 });
  }),
  sfx('sfx.pickup.rosary', 1.0, (c) => {
    const o = out(c);
    noise(c, o, { dur: 0.9, vol: 0.5, lp: 2500, sweepTo: 100 });
    bell(c, o, n('A5'), 0, 0.9, 0.3);
  }),
  sfx('sfx.pickup.vacuum', 0.8, (c) => {
    const o = out(c);
    tone(c, o, { type: 'sine', freq: 200, slideTo: 1600, dur: 0.7, vol: 0.25 });
    noise(c, o, { dur: 0.7, vol: 0.25, bp: 500, sweepTo: 4000 });
  }),
  sfx('sfx.pickup.item', 0.4, (c) => {
    const o = out(c);
    bell(c, o, n('G5'), 0, 0.3, 0.2);
    bell(c, o, n('C6'), 0.08, 0.3, 0.2);
  }),
  // 升级：老虎机赢钱式上行琶音 + 落下的宝石雨（高频钟铃点缀）
  sfx('sfx.ui.level_up', 1.3, (c) => {
    const o = out(c);
    melody(c, o, [['C5', 1], ['E5', 1], ['G5', 1], ['C6', 1], ['E6', 1], ['G6', 3]], 0, 0.06, brass(c, o));
    for (let i = 0; i < 10; i++) bell(c, o, n('C6') * Math.pow(2, ((i * 5) % 12) / 12), 0.35 + i * 0.07, 0.3, 0.07);
  }),
  // 宝箱：发现宝藏 → 转轮滴答（游戏端越播越快）→ 弹开 → 物品 → 三档结尾
  sfx('sfx.chest.found', 0.9, (c) => {
    const o = out(c);
    melody(c, o, [['G4', 1], ['C5', 1], ['E5', 1], ['G5', 2], ['E5', 1], ['G5', 4]], 0, 0.07, brass(c, o));
  }),
  sfx('sfx.chest.tick', 0.05, (c) => {
    const o = out(c);
    noise(c, o, { dur: 0.03, vol: 0.4, bp: 3500, q: 6 });
    tone(c, o, { type: 'square', freq: 1500, dur: 0.02, vol: 0.05 });
  }),
  sfx('sfx.chest.open', 0.6, (c) => {
    const o = out(c);
    noise(c, o, { dur: 0.3, vol: 0.4, lp: 1500 });
    for (let i = 0; i < 5; i++) bell(c, o, n('C5') * Math.pow(2, (i * 4) / 12), i * 0.04, 0.4, 0.15);
  }),
  sfx('sfx.chest.item', 0.5, (c) => {
    const o = out(c);
    bell(c, o, n('E6'), 0, 0.4, 0.25);
    coin(c, o, 2600, 0.03, 0.15);
  }),
  // A：1 件 —— 短促的 I–V–I
  sfx('sfx.chest.end_a', 1.2, (c) => {
    const o = out(c);
    const end = melody(c, o, [['C5', 1], ['G5', 1], ['C6', 3]], 0, 0.1, brass(c, o));
    tone(c, o, { type: 'triangle', freq: n('C3'), t: 0, dur: end, vol: 0.2 });
  }),
  // B：3 件 —— 更长的乐句 + 硬币声
  sfx('sfx.chest.end_b', 2.0, (c) => {
    const o = out(c);
    const end = melody(c, o, [['C5', 1], ['E5', 1], ['G5', 1], ['C6', 1], ['A5', 1], ['C6', 1], ['E6', 4]], 0, 0.1, brass(c, o));
    tone(c, o, { type: 'triangle', freq: n('C3'), dur: end, vol: 0.2 });
    tone(c, o, { type: 'triangle', freq: n('G2'), t: 0.6, dur: end - 0.6, vol: 0.15 });
    cascade(c, o, 0.6, 1.0, 14);
  }),
  // C：5 件 —— 头奖：急速上行琶音 × 3、铃声齐鸣、硬币瀑布
  sfx('sfx.chest.end_c', 3.2, (c) => {
    const o = out(c);
    let t = 0;
    for (const root of ['C5', 'F5', 'G5']) {
      const base = n(root);
      for (let i = 0; i < 8; i++) {
        const f = base * Math.pow(2, [0, 4, 7, 12, 16, 19, 24, 28][i] / 12);
        tone(c, o, { type: 'square', freq: f, t: t + i * 0.035, dur: 0.08, vol: 0.08 });
      }
      t += 0.32;
    }
    melody(c, o, [['C6', 1], ['C6', 1], ['C6', 1], ['E6', 2], ['G6', 6]], t, 0.09, brass(c, o));
    for (let i = 0; i < 12; i++) bell(c, o, n('C6') * Math.pow(2, ((i * 7) % 24) / 12), t + i * 0.08, 0.5, 0.08);
    cascade(c, o, t, 1.8, 36);
    tone(c, o, { type: 'triangle', freq: n('C3'), t: 0, dur: 3.0, vol: 0.2 });
  }),
  // 界面
  sfx('sfx.ui.hover', 0.05, (c) => tone(c, out(c), { type: 'square', freq: 1800, dur: 0.03, vol: 0.06 })),
  sfx('sfx.ui.confirm', 0.15, (c) => {
    const o = out(c);
    tone(c, o, { type: 'square', freq: 880, dur: 0.05, vol: 0.1 });
    tone(c, o, { type: 'square', freq: 1320, t: 0.05, dur: 0.08, vol: 0.1 });
  }),
  sfx('sfx.ui.pick', 0.4, (c) => {
    const o = out(c);
    bell(c, o, n('G5'), 0, 0.3, 0.2);
    bell(c, o, n('D6'), 0.07, 0.3, 0.2);
  }),
  sfx('sfx.ui.deny', 0.25, (c) => {
    const o = out(c);
    tone(c, o, { type: 'square', freq: 220, dur: 0.1, vol: 0.12 });
    tone(c, o, { type: 'square', freq: 165, t: 0.1, dur: 0.12, vol: 0.12 });
  }),
  sfx('sfx.ui.banish', 0.35, (c) => {
    const o = out(c);
    noise(c, o, { dur: 0.15, vol: 0.6, lp: 900 });
    tone(c, o, { type: 'sine', freq: 120, slideTo: 50, dur: 0.25, vol: 0.4 });
  }),
  sfx('sfx.ui.buy', 0.6, (c) => {
    const o = out(c);
    cascade(c, o, 0, 0.25, 5);
    bell(c, o, n('C6'), 0.2, 0.4, 0.2);
  }),
  sfx('sfx.ui.coin_tick', 0.08, (c) => coin(c, out(c), 3000, 0, 0.15)),
  sfx('sfx.ui.game_over', 2.0, (c) => {
    const o = out(c);
    melody(c, o, [['E5', 2], ['D#5', 2], ['D5', 2], ['C#5', 6]], 0, 0.13, (f, t, d) => tone(c, o, { type: 'square', freq: f, t, dur: d, vol: 0.1 }));
  }),
  sfx('sfx.ui.victory', 2.4, (c) => {
    const o = out(c);
    const end = melody(c, o, [['C5', 1], ['C5', 1], ['C5', 1], ['C5', 3], ['G#4', 3], ['A#4', 3], ['C5', 2], ['A#4', 1], ['C5', 6]], 0, 0.08, brass(c, o));
    cascade(c, o, 0.5, end - 0.5, 20);
  }),
] satisfies AudioSpec[];
