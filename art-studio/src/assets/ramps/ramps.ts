// 特效色带：着色器把 0..1 的强度映射到这些颜色，所有特效因此共用同一套调色板。
import type { RampSpec } from '../../runtime/spec';

const ramp = (id: string, colors: RampSpec['colors']): RampSpec => ({ kind: 'ramp', id: `ramp.${id}`, colors });

export default [
  ramp('fire', ['wine', 'blood', 'red', 'coral', 'amber', 'gold', 'lemon', 'white']),
  ramp('ice', ['deep', 'navy', 'sky', 'ice', 'frost', 'white']),
  ramp('holy', ['amber', 'gold', 'lemon', 'cream', 'white']),
  ramp('lightning', ['plum', 'navy', 'sky', 'ice', 'frost', 'white']),
  ramp('poison', ['pine', 'moss', 'leaf', 'lime', 'sprout']),
  ramp('blood', ['wine', 'blood', 'red', 'coral', 'pink']),
  ramp('arcane', ['plum', 'violet', 'lilac', 'pink', 'paper']),
  ramp('shadow', ['ink', 'night', 'shadow', 'dusk', 'mist']),
  ramp('gold', ['bark', 'amber', 'gold', 'lemon', 'white']),
  ramp('nature', ['pine', 'moss', 'leaf', 'lime', 'sprout', 'lemon']),
  ramp('steel', ['night', 'dusk', 'mist', 'fog', 'paper', 'white']),
  ramp('water', ['deep', 'navy', 'sky', 'ice', 'frost']),
];
