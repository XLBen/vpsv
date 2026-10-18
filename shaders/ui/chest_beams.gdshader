// 宝箱开启光柱：从中心向外旋转的放射光束，按像素格量化，颜色取自金色色带。
shader_type canvas_item;
#include "res://shaders/shared/pixel.gdshaderinc"

uniform sampler2D ramp : filter_nearest, source_color;
uniform float progress = 0.0;      // 0..1 展开程度
uniform float rays = 8.0;
uniform float time_offset = 0.0;
uniform vec2 px_size = vec2(110.0);  // 像素格数量（控件尺寸的一半 → 2 倍像素）

void fragment() {
	vec2 uv = snap_uv(UV, px_size) - 0.5;
	float r = length(uv) * 2.0;
	float a = atan(uv.y, uv.x);
	float spin = time_offset * 0.9;
	float beam = step(0.55, fract((a + spin) / TAU * rays));
	float glow = 1.0 - smoothstep(0.0, 1.0, r / max(progress, 0.001));
	float core = 1.0 - smoothstep(0.0, 0.35, r);
	float v = clamp(beam * glow * 0.8 + core * progress, 0.0, 1.0);
	v = posterize(v, 4.0);
	vec3 c = ramp_color(ramp, v);
	COLOR = vec4(c, step(0.05, v) * progress * 0.9);
}
