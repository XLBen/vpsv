// 占位背景音乐：简单的芯片风循环（低音 + 琶音 + 鼓），之后可直接用正式曲目替换同名文件。
import { n, noise, out, tone } from '../../runtime/synth';
import type { AudioSpec } from '../../runtime/spec';

function loop(id: string, roots: string[], bpm: number, scale: number[], lead: string): AudioSpec {
  const beat = 60 / bpm;
  const bars = roots.length;
  const duration = bars * 4 * beat;
  return {
    kind: 'audio',
    id,
    duration,
    sampleRate: 22050,
    peak: 0.6,
    tags: ['bgm', 'placeholder'],
    render(c) {
      const o = out(c, 0.6);
      roots.forEach((root, bar) => {
        const t0 = bar * 4 * beat;
        const f = n(root);
        for (let b = 0; b < 8; b++) {
          tone(c, o, { type: 'triangle', freq: f / 2, t: t0 + b * beat * 0.5, dur: beat * 0.45, vol: 0.22 });
          const step = scale[(b * 3 + bar) % scale.length];
          tone(c, o, { type: lead === 'square' ? 'square' : 'sawtooth', freq: f * 2 * Math.pow(2, step / 12), t: t0 + b * beat * 0.5, dur: beat * 0.3, vol: 0.05 });
        }
        for (let b = 0; b < 4; b++) {
          noise(c, o, { t: t0 + b * beat, dur: 0.08, vol: b % 2 === 0 ? 0.25 : 0.12, lp: b % 2 === 0 ? 300 : 6000 });
          noise(c, o, { t: t0 + b * beat + beat * 0.5, dur: 0.03, vol: 0.06, hp: 8000 });
        }
      });
    },
  };
}

export default [
  loop('bgm.forest', ['A3', 'F3', 'G3', 'E3', 'A3', 'F3', 'G3', 'E3'], 132, [0, 3, 7, 10, 12, 7], 'square'),
  loop('bgm.library', ['D3', 'A#2', 'C3', 'A2', 'D3', 'G2', 'A2', 'A2'], 116, [0, 3, 5, 7, 10, 12], 'saw'),
];
