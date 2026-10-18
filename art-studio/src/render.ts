// 导出页：只给 scripts/export.ts 通过 Playwright 调用。
import { listMeta, mountSheet, frameTime, sampleMotion, renderAudio, type Mounted } from './runtime/studio';
import { spec } from './runtime/registry';
import type { SheetSpec } from './runtime/spec';

const stage = document.getElementById('stage')!;
let current: { id: string; clip: string; m: Mounted } | null = null;

const api = {
  list: listMeta,
  /** 挂载并跳到某一帧；动画素材同一 clip 只挂载一次。 */
  async sheetFrame(id: string, clip: string, frame: number): Promise<[number, number]> {
    const s = spec(id) as SheetSpec;
    if (s.drawFrame) {
      mountSheet(stage, id, clip, frame);
      current = null;
    } else {
      if (!current || current.id !== id || current.clip !== clip) current = { id, clip, m: mountSheet(stage, id, clip) };
      await current.m.seek(frameTime(s, clip, frame));
    }
    return s.size;
  },
  motion: (id: string) => sampleMotion(stage, id),
  audio: renderAudio,
};

(window as unknown as { __studio: typeof api }).__studio = api;
