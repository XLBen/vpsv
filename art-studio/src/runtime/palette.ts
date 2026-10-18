// 全项目统一调色板（暖色、低饱和，星露谷式）。
// 导出时所有像素都会被吸附到这里最近的颜色；美术改色只需改这张表并重新导出。

export const PALETTE = {
  // 中性 / 描边
  ink: '#14101c',
  night: '#2b2233',
  shadow: '#463a52',
  dusk: '#6b5d78',
  mist: '#9a8ca3',
  fog: '#c9bfcf',
  paper: '#f4ecf0',
  white: '#ffffff',
  // 肤色 / 木头 / 土
  bark: '#3d2621',
  wood: '#6b3d2e',
  clay: '#a0603f',
  tan: '#d08b5b',
  skin: '#f0c08a',
  cream: '#fbe3b5',
  // 红 / 粉
  wine: '#5a1a2b',
  blood: '#9e2835',
  red: '#d9443e',
  coral: '#f2785c',
  pink: '#f7a8b8',
  // 绿
  pine: '#1f3326',
  moss: '#2f5a35',
  leaf: '#4c8a3c',
  lime: '#86b84a',
  sprout: '#c6dc6c',
  // 蓝
  deep: '#1c2a4f',
  navy: '#2d4f8a',
  sky: '#3f86c4',
  ice: '#74c3e8',
  frost: '#bfeefa',
  // 紫
  plum: '#3a2257',
  violet: '#6a3d8f',
  lilac: '#a46bc6',
  // 黄 / 金
  amber: '#c27a1f',
  gold: '#f5c542',
  lemon: '#fff08a',
} as const;

export type ColorKey = keyof typeof PALETTE;

export const PALETTE_HEX: string[] = Object.values(PALETTE);

export function hex(key: ColorKey | string): string {
  return key in PALETTE ? PALETTE[key as ColorKey] : key;
}
