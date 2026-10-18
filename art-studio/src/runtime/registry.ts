// 自动收集 src/assets 下的所有素材规格。
import type { Spec, SpecModule } from './spec';

const modules = import.meta.glob<SpecModule>('../assets/**/*.ts', { eager: true });

export const SPECS: Spec[] = [];
const seen = new Map<string, string>();
for (const [file, mod] of Object.entries(modules).sort(([a], [b]) => a.localeCompare(b))) {
  const list = Array.isArray(mod.default) ? mod.default : [mod.default];
  for (const s of list) {
    if (seen.has(s.id)) throw new Error(`素材 id 重复：${s.id}（${seen.get(s.id)} 与 ${file}）`);
    seen.set(s.id, file);
    SPECS.push(s);
  }
}

export function spec(id: string): Spec {
  const s = SPECS.find((x) => x.id === id);
  if (!s) throw new Error(`未知素材：${id}`);
  return s;
}
