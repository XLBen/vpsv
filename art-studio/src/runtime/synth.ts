// Web Audio 合成小工具：在 OfflineAudioContext 里搭音色，导出为 WAV。
// 赌场风的关键音色：钟铃（宝石 / 中奖）、金属硬币、短促的转轮滴答、方波号角。

export type Ctx = BaseAudioContext;

export function out(ctx: Ctx, vol = 0.8): GainNode {
  const g = ctx.createGain();
  g.gain.value = vol;
  // 轻微压缩，避免叠加时爆音
  const comp = ctx.createDynamicsCompressor();
  comp.threshold.value = -12;
  comp.ratio.value = 4;
  g.connect(comp).connect(ctx.destination);
  return g;
}

interface ToneOpts {
  type?: OscillatorType;
  freq: number;
  t?: number;
  dur: number;
  vol?: number;
  attack?: number;
  slideTo?: number;
  detune?: number;
}

/** 单个振荡器音：线性起音 + 指数衰减。 */
export function tone(ctx: Ctx, dst: AudioNode, o: ToneOpts): void {
  const t = o.t ?? 0;
  const osc = ctx.createOscillator();
  const g = ctx.createGain();
  osc.type = o.type ?? 'sine';
  osc.frequency.setValueAtTime(o.freq, t);
  if (o.slideTo) osc.frequency.exponentialRampToValueAtTime(Math.max(20, o.slideTo), t + o.dur);
  if (o.detune) osc.detune.value = o.detune;
  g.gain.setValueAtTime(0, t);
  g.gain.linearRampToValueAtTime(o.vol ?? 0.5, t + (o.attack ?? 0.004));
  g.gain.exponentialRampToValueAtTime(0.0001, t + o.dur);
  osc.connect(g).connect(dst);
  osc.start(t);
  osc.stop(t + o.dur + 0.02);
}

/** 钟铃：非谐波泛音叠加（1、2.76、5.4、8.93 倍），清脆的“叮”。 */
export function bell(ctx: Ctx, dst: AudioNode, freq: number, t = 0, dur = 0.5, vol = 0.4): void {
  const partials: Array<[number, number, number]> = [
    [1, 1, 1],
    [2.76, 0.45, 0.6],
    [5.4, 0.25, 0.35],
    [8.93, 0.12, 0.2],
  ];
  for (const [ratio, amp, len] of partials) tone(ctx, dst, { freq: freq * ratio, t, dur: dur * len, vol: vol * amp, attack: 0.002 });
}

/** 硬币：金属泛音 + 极短的高频敲击。 */
export function coin(ctx: Ctx, dst: AudioNode, freq = 2400, t = 0, vol = 0.3): void {
  for (const [ratio, amp, d] of [[1, 1, 0.18], [1.48, 0.6, 0.12], [2.31, 0.35, 0.08]] as const) {
    tone(ctx, dst, { type: 'triangle', freq: freq * ratio, t, dur: d, vol: vol * amp, attack: 0.001 });
  }
  noise(ctx, dst, { t, dur: 0.015, vol: vol * 0.6, hp: 6000 });
}

interface NoiseOpts {
  t?: number;
  dur: number;
  vol?: number;
  lp?: number;
  hp?: number;
  bp?: number;
  q?: number;
  sweepTo?: number;
}

/** 滤波噪声：打击、爆炸、风声。 */
export function noise(ctx: Ctx, dst: AudioNode, o: NoiseOpts): void {
  const t = o.t ?? 0;
  const len = Math.ceil(o.dur * ctx.sampleRate);
  const buf = ctx.createBuffer(1, len, ctx.sampleRate);
  const d = buf.getChannelData(0);
  // 固定种子的伪随机，保证导出结果可复现
  let s = 1234567 + Math.floor(t * 1000) + len;
  for (let i = 0; i < len; i++) {
    s = (s * 1103515245 + 12345) & 0x7fffffff;
    d[i] = (s / 0x7fffffff) * 2 - 1;
  }
  const src = ctx.createBufferSource();
  src.buffer = buf;
  let node: AudioNode = src;
  const filt = (type: BiquadFilterType, f: number) => {
    const b = ctx.createBiquadFilter();
    b.type = type;
    b.frequency.setValueAtTime(f, t);
    if (o.sweepTo) b.frequency.exponentialRampToValueAtTime(o.sweepTo, t + o.dur);
    if (o.q) b.Q.value = o.q;
    node.connect(b);
    node = b;
  };
  if (o.hp) filt('highpass', o.hp);
  if (o.lp) filt('lowpass', o.lp);
  if (o.bp) filt('bandpass', o.bp);
  const g = ctx.createGain();
  g.gain.setValueAtTime(o.vol ?? 0.4, t);
  g.gain.exponentialRampToValueAtTime(0.0001, t + o.dur);
  node.connect(g).connect(dst);
  src.start(t);
  src.stop(t + o.dur);
}

/** 音名转频率（A4 = 440），例如 n('C5')。 */
export function n(name: string): number {
  const m = name.match(/^([A-G])(#|b)?(-?\d)$/)!;
  const base: Record<string, number> = { C: -9, D: -7, E: -5, F: -4, G: -2, A: 0, B: 2 };
  let semi = base[m[1]] + (m[2] === '#' ? 1 : m[2] === 'b' ? -1 : 0) + (parseInt(m[3]) - 4) * 12;
  return 440 * Math.pow(2, semi / 12);
}

/** 依次演奏音符：[音名, 时值(拍)]，tempo 为每拍秒数。返回结束时间。 */
export function melody(ctx: Ctx, dst: AudioNode, notes: Array<[string | null, number]>, t0: number, beat: number, voice: (f: number, t: number, d: number) => void): number {
  let t = t0;
  for (const [note, len] of notes) {
    if (note) voice(n(note), t, len * beat);
    t += len * beat;
  }
  return t;
}
