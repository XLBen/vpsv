// 大蒜光环：像素化的圆形光环 + 向外扩散的波纹，颜色来自色带。
shader_type canvas_item;
#include "res://shaders/shared/pixel.gdshaderinc"

uniform sampler2D ramp : filter_nearest, source_color;
uniform float progress = 0.0;        // 0..1 循环（脉动相位）
uniform vec2 px_size = vec2(48.0);

void fragment() {
	vec2 uv = snap_uv(UV, px_size) - 0.5;
	float r = length(uv) * 2.0;
	if (r > 1.0) {
		discard;
	}
	float edge = step(0.86, r);
	float wave = step(0.92, fract(r * 1.5 - progress * 1.5));
	float dither = step(0.5, hash12(floor(UV * px_size) + floor(TIME * 4.0)));
	float body = step(0.6, r) * dither * 0.35;
	float v = max(edge, max(wave * 0.8, body));
	if (v <= 0.0) {
		discard;
	}
	COLOR = vec4(ramp_color(ramp, 0.4 + 0.5 * v), 0.25 + 0.35 * v);
}
