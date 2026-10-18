// 导出全部素材到 ../assets：
//   pnpm export                    导出全部
//   pnpm export --only=actor.*     只导出匹配的 id（通配符 *）
//   pnpm export --no-import        导出后不调用 Godot 导入
import { createServer } from 'vite';
import { chromium, type Page } from 'playwright';
import { PNG } from 'pngjs';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { PALETTE, type ColorKey } from '../src/runtime/palette.ts';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const ASSETS = path.resolve(ROOT, '../assets');
const GEN = path.join(ASSETS, 'generated');
const MANIFEST = path.join(ASSETS, 'manifest.json');
const GODOT = '/Applications/Godot.app/Contents/MacOS/Godot';

const args = process.argv.slice(2);
const only = args.find((a) => a.startsWith('--only='))?.slice(7);
const noImport = args.includes('--no-import');
const match = (id: string) => !only || only.split(',').some((p) => new RegExp('^' + p.replace(/[.+?^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*') + '$').test(id));

// ------------------------------------------------------------ 调色板量化

const PAL = Object.values(PALETTE).map((h) => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)]);
const nearestCache = new Map<number, number[]>();
function nearest(r: number, g: number, b: number): number[] {
  const k = (r << 16) | (g << 8) | b;
  let c = nearestCache.get(k);
  if (!c) {
    let best = Infinity;
    for (const p of PAL) {
      // 加权欧氏距离，近似人眼亮度敏感度
      const d = 2 * (p[0] - r) ** 2 + 4 * (p[1] - g) ** 2 + 3 * (p[2] - b) ** 2;
      if (d < best) {
        best = d;
        c = p;
      }
    }
    nearestCache.set(k, c!);
  }
  return c!;
}

/** alpha 二值化（阈值 128）+ 吸附到调色板。 */
function quantize(png: PNG): PNG {
  const d = png.data;
  for (let i = 0; i < d.length; i += 4) {
    if (d[i + 3] < 128) {
      d[i] = d[i + 1] = d[i + 2] = d[i + 3] = 0;
      continue;
    }
    const c = nearest(d[i], d[i + 1], d[i + 2]);
    d[i] = c[0];
    d[i + 1] = c[1];
    d[i + 2] = c[2];
    d[i + 3] = 255;
  }
  return png;
}

function writePng(file: string, png: PNG) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, PNG.sync.write(png, { colorType: 6 }));
}

function writeWav(file: string, sampleRate: number, data: number[]) {
  const buf = Buffer.alloc(44 + data.length * 2);
  buf.write('RIFF', 0);
  buf.writeUInt32LE(36 + data.length * 2, 4);
  buf.write('WAVEfmt ', 8);
  buf.writeUInt32LE(16, 16);
  buf.writeUInt16LE(1, 20);
  buf.writeUInt16LE(1, 22);
  buf.writeUInt32LE(sampleRate, 24);
  buf.writeUInt32LE(sampleRate * 2, 28);
  buf.writeUInt16LE(2, 32);
  buf.writeUInt16LE(16, 34);
  buf.write('data', 36);
  buf.writeUInt32LE(data.length * 2, 40);
  data.forEach((v, i) => buf.writeInt16LE(v, 44 + i * 2));
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, buf);
}

function sameAudio(file: string, sampleRate: number, data: number[]): boolean {
  if (!fs.existsSync(file)) return false;
  const buf = fs.readFileSync(file);
  if (buf.length !== 44 + data.length * 2 || buf.readUInt32LE(24) !== sampleRate) return false;
  for (let i = 0; i < data.length; i++) if (Math.abs(buf.readInt16LE(44 + i * 2) - data[i]) > 2) return false;
  return true;
}

const rel = (f: string) => path.relative(ASSETS, f).split(path.sep).join('/');

// ------------------------------------------------------------ 各类素材

type Meta = Record<string, any>;

async function exportSheet(page: Page, s: Meta) {
  const [w, h] = s.size as [number, number];
  const clipNames = Object.keys(s.clips);
  const maxFrames = Math.max(...clipNames.map((c) => s.clips[c].frames));
  const atlas = new PNG({ width: w * maxFrames, height: h * clipNames.length });
  atlas.data.fill(0);
  const clips: Meta = {};
  for (const [row, clip] of clipNames.entries()) {
    const def = s.clips[clip];
    for (let f = 0; f < def.frames; f++) {
      await page.evaluate(([id, c, fr]) => (window as any).__studio.sheetFrame(id, c, fr), [s.id, clip, f] as const);
      const shot = await page.screenshot({ clip: { x: 0, y: 0, width: w, height: h }, omitBackground: true });
      const frame = quantize(PNG.sync.read(shot));
      PNG.bitblt(frame, atlas, 0, 0, w, h, f * w, row * h);
    }
    clips[clip] = { row, frames: def.frames, loop: def.loop ?? false, fps: def.fps ?? s.fps };
  }
  const file = path.join(GEN, 'sheets', `${s.id}.png`);
  writePng(file, atlas);
  return { type: 'sheet', file: rel(file), size: [w, h], pivot: s.pivot ?? [Math.floor(w / 2), h - 1], fps: s.fps, clips, tags: s.tags ?? [] };
}

async function exportMotion(page: Page, s: Meta) {
  const data = await page.evaluate((id) => (window as any).__studio.motion(id), s.id);
  const file = path.join(GEN, 'motion', `${s.id}.json`);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, JSON.stringify(data) + '\n');
  return { type: 'motion', file: rel(file), duration: s.duration, drive: s.drive ?? 'time' };
}

async function exportAudio(page: Page, s: Meta) {
  const { sampleRate, data } = await page.evaluate((id) => (window as any).__studio.audio(id), s.id);
  const file = path.join(GEN, 'sfx', `${s.id}.wav`);
  // Chrome 的音频渲染偶有 ±1 LSB 的浮点抖动：与已有文件相差不超过 2 时保留旧文件，导出结果保持稳定
  if (!sameAudio(file, sampleRate, data)) writeWav(file, sampleRate, data);
  return { type: 'audio', file: rel(file), duration: s.duration, tags: s.tags ?? [] };
}

function exportRamp(s: Meta) {
  const colors = s.colors as ColorKey[];
  const png = new PNG({ width: colors.length, height: 1 });
  colors.forEach((k, i) => {
    const h = PALETTE[k];
    png.data[i * 4] = parseInt(h.slice(1, 3), 16);
    png.data[i * 4 + 1] = parseInt(h.slice(3, 5), 16);
    png.data[i * 4 + 2] = parseInt(h.slice(5, 7), 16);
    png.data[i * 4 + 3] = 255;
  });
  const file = path.join(GEN, 'ramps', `${s.id}.png`);
  writePng(file, png);
  return { type: 'ramp', file: rel(file), width: colors.length };
}

// ------------------------------------------------------------ 主流程

async function main() {
  const t0 = Date.now();
  const server = await createServer({ root: ROOT, logLevel: 'error', server: { port: 0 } });
  await server.listen();
  const url = server.resolvedUrls!.local[0];
  const browser = await chromium.launch({ channel: 'chrome' }).catch(() => chromium.launch());
  const page = await browser.newPage({ viewport: { width: 1024, height: 1024 }, deviceScaleFactor: 1 });
  page.on('pageerror', (e) => console.error('页面错误:', e.message));
  await page.goto(url + 'render.html');
  await page.waitForFunction(() => (window as any).__studio);
  const list: Meta[] = await page.evaluate(() => (window as any).__studio.list());

  const manifest: Meta = fs.existsSync(MANIFEST) && only ? JSON.parse(fs.readFileSync(MANIFEST, 'utf8')) : { version: 1, assets: {} };
  manifest.palette = PALETTE;
  let count = 0;
  for (const s of list) {
    if (!match(s.id)) continue;
    let entry: Meta;
    if (s.kind === 'sheet') entry = await exportSheet(page, s);
    else if (s.kind === 'motion') entry = await exportMotion(page, s);
    else if (s.kind === 'audio') entry = await exportAudio(page, s);
    else entry = exportRamp(s);
    manifest.assets[s.id] = entry;
    count++;
    process.stdout.write(`\r已导出 ${count} 个  ${s.id.padEnd(40)}`);
  }
  // 删除清单中已不存在的素材（仅全量导出时）
  if (!only) {
    for (const id of Object.keys(manifest.assets)) if (!list.some((s) => s.id === id)) delete manifest.assets[id];
    // 清理已删除素材留下的旧文件（连同 Godot 的 .import）
    const keep = new Set(Object.values(manifest.assets).map((e: any) => path.join(ASSETS, e.file)));
    const walk = (d: string): string[] => fs.readdirSync(d, { withFileTypes: true }).flatMap((f) => (f.isDirectory() ? walk(path.join(d, f.name)) : [path.join(d, f.name)]));
    for (const f of walk(GEN)) {
      const base = f.endsWith('.import') ? f.slice(0, -7) : f;
      if (!keep.has(base)) fs.rmSync(f);
    }
  }
  manifest.assets = Object.fromEntries(Object.entries(manifest.assets).sort(([a], [b]) => a.localeCompare(b)));
  fs.writeFileSync(MANIFEST, JSON.stringify(manifest, null, 1) + '\n');
  await browser.close();
  await server.close();
  console.log(`\n完成：${count} 个素材，用时 ${((Date.now() - t0) / 1000).toFixed(1)}s → ${path.relative(process.cwd(), MANIFEST)}`);

  if (!noImport && fs.existsSync(GODOT)) {
    console.log('Godot 导入中…');
    const r = spawnSync(GODOT, ['--headless', '--path', path.resolve(ROOT, '..'), '--import'], { encoding: 'utf8' });
    const errors = (r.stdout + r.stderr).split('\n').filter((l) => /ERROR/.test(l));
    console.log(errors.length ? errors.join('\n') : 'Godot 导入完成');
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
