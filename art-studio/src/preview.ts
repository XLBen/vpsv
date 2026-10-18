// 美术预览器：浏览所有素材，实时播放 / 拖动时间轴，并对照导出结果。
import { SPECS } from './runtime/registry';
import { mountSheet, mountMotion, renderAudio } from './runtime/studio';
import { PALETTE } from './runtime/palette';
import type { MotionSpec, RampSpec, SheetSpec, AudioSpec, Spec } from './runtime/spec';

const list = document.getElementById('list')!;
const main = document.getElementById('main')!;
const filter = document.getElementById('filter') as HTMLInputElement;
let raf = 0;
let selected = new URLSearchParams(location.hash.slice(1)).get('id') || '';

function renderList() {
  const q = filter.value.trim().toLowerCase();
  list.replaceChildren();
  const groups = new Map<string, Spec[]>();
  for (const s of SPECS) {
    if (q && !s.id.toLowerCase().includes(q)) continue;
    const g = s.id.split('.').slice(0, 2).join('.');
    if (!groups.has(g)) groups.set(g, []);
    groups.get(g)!.push(s);
  }
  for (const [g, specs] of groups) {
    const h = document.createElement('h3');
    h.textContent = `${g} (${specs.length})`;
    list.appendChild(h);
    for (const s of specs) {
      const b = document.createElement('button');
      b.textContent = s.id.slice(g.length + 1) || s.id;
      b.className = s.id === selected ? 'on' : '';
      b.onclick = () => select(s.id);
      list.appendChild(b);
    }
  }
}

function header(s: Spec, extra: string) {
  main.innerHTML = `<h1>${s.id}</h1><div class="meta">${s.kind} · ${extra}</div>`;
}

function exportedImage(file: string, scale: number): HTMLElement {
  const wrap = document.createElement('div');
  wrap.className = 'exported';
  wrap.innerHTML = `<div class="clip-title">导出结果（调色板量化后）</div>`;
  const img = new Image();
  img.src = `/__assets/${file}?t=${Date.now()}`;
  img.onload = () => {
    img.style.width = `${img.naturalWidth * scale}px`;
  };
  img.onerror = () => (wrap.innerHTML += '<span class="hint">尚未导出</span>');
  wrap.appendChild(img);
  return wrap;
}

async function showSheet(s: SheetSpec) {
  const scale = Math.max(2, Math.floor(160 / Math.max(...s.size)));
  header(s, `${s.size.join('×')} · ${s.fps} fps · 轴心 ${(s.pivot ?? []).join(',') || '底部中点'}`);
  const live: Array<{ anims: Animation[]; frames: number; fps: number; loop: boolean }> = [];
  for (const [clip, def] of Object.entries(s.clips)) {
    const box = document.createElement('div');
    box.className = 'clip';
    box.innerHTML = `<div class="clip-title">${clip} · ${def.frames} 帧${def.loop ? ' · 循环' : ''}</div>`;
    main.appendChild(box);
    const count = s.drawFrame ? def.frames : 1;
    for (let f = 0; f < count; f++) {
      const st = document.createElement('div');
      st.className = 'stage';
      st.style.marginRight = '6px';
      box.appendChild(st);
      mountSheet(st, s.id, clip, f);
      const svg = st.querySelector('svg')!;
      svg.style.width = `${s.size[0] * scale}px`;
      svg.style.height = `${s.size[1] * scale}px`;
      if (!s.drawFrame) {
        const anims = document.getAnimations().filter((a) => svg.contains((a.effect as KeyframeEffect).target as Node));
        live.push({ anims, frames: def.frames, fps: def.fps ?? s.fps, loop: !!def.loop });
      }
    }
  }
  // 统一按真实时间推进；非循环片段播完后停顿一下再重播。
  const t0 = performance.now();
  const tick = () => {
    const now = performance.now() - t0;
    for (const c of live) {
      const len = (c.frames * 1000) / c.fps;
      const t = c.loop ? now % len : Math.min(now % (len + 600), len - 1);
      for (const a of c.anims) {
        a.pause();
        a.currentTime = t;
      }
    }
    raf = requestAnimationFrame(tick);
  };
  if (live.length) tick();
  const manifest = await fetch('/__assets/manifest.json').then((r) => r.json()).catch(() => null);
  const entry = manifest?.assets?.[s.id];
  if (entry) main.appendChild(exportedImage(entry.file, scale));
}

function showMotion(s: MotionSpec) {
  header(s, `${s.duration}ms · ${s.drive ?? 'time'} · 目标 ${Object.keys(s.targets).join(', ')}`);
  const bar = document.createElement('div');
  bar.className = 'toolbar';
  bar.innerHTML = `<button id="play">暂停</button><label>时间 <input id="scrub" type="range" min="0" max="${s.duration}" value="0" style="width:320px"></label><span id="tv" class="hint"></span>`;
  main.appendChild(bar);
  const st = document.createElement('div');
  st.className = 'motion-stage';
  main.appendChild(st);
  const m = mountMotion(st, s.id);
  const scrub = bar.querySelector<HTMLInputElement>('#scrub')!;
  const tv = bar.querySelector<HTMLElement>('#tv')!;
  let playing = true;
  bar.querySelector<HTMLButtonElement>('#play')!.onclick = (e) => {
    playing = !playing;
    (e.target as HTMLButtonElement).textContent = playing ? '暂停' : '播放';
  };
  const t0 = performance.now();
  const tick = async () => {
    const t = playing ? (performance.now() - t0) % (s.duration + 500) : +scrub.value;
    const tt = Math.min(t, s.duration);
    if (playing) scrub.value = String(tt);
    tv.textContent = `${Math.round(tt)} ms`;
    await m.seek(tt);
    raf = requestAnimationFrame(tick);
  };
  tick();
}

function showRamp(s: RampSpec) {
  header(s, `${s.colors.length} 色`);
  const sw = document.createElement('div');
  sw.className = 'swatches';
  for (const c of s.colors) {
    const d = document.createElement('div');
    d.style.background = PALETTE[c];
    d.title = c;
    sw.appendChild(d);
  }
  main.appendChild(sw);
}

function showAudio(s: AudioSpec) {
  header(s, `${s.duration}s`);
  const b = document.createElement('button');
  b.textContent = '▶ 播放';
  b.onclick = async () => {
    const { sampleRate, data } = await renderAudio(s.id);
    const ctx = new AudioContext();
    const buf = ctx.createBuffer(1, data.length, sampleRate);
    buf.getChannelData(0).set(data.map((v) => v / 32767));
    const src = ctx.createBufferSource();
    src.buffer = buf;
    src.connect(ctx.destination);
    src.start();
  };
  main.appendChild(b);
}

function select(id: string) {
  selected = id;
  location.hash = `id=${encodeURIComponent(id)}`;
  cancelAnimationFrame(raf);
  for (const a of document.getAnimations()) a.cancel();
  main.replaceChildren();
  const s = SPECS.find((x) => x.id === id);
  renderList();
  if (!s) return;
  if (s.kind === 'sheet') void showSheet(s);
  else if (s.kind === 'motion') showMotion(s);
  else if (s.kind === 'ramp') showRamp(s);
  else showAudio(s);
}

filter.oninput = renderList;
window.addEventListener('hashchange', () => {
  const id = new URLSearchParams(location.hash.slice(1)).get('id');
  if (id && id !== selected) select(id);
});
renderList();
if (selected) select(selected);
