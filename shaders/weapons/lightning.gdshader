// 闪电：从顶部劈到底部的锯齿光柱，2 像素主干 + 外圈辉光，随 progress 熄灭。
shader_type canvas_item;
#include "res://shaders/shared/pixel.gdshaderinc"

uniform sampler2D ramp : filter_nearest, source_color;
uniform float progress = 0.0;
uniform float seed = 0.0;
uniform vec2 px_size = vec2(40.0, 250.0);

void fragment() {
	vec2 cell = floor(UV * px_size);
	// 每 12 像素一个折点，折点之间线性连接
	float seg = 12.0;
	float k = floor(cell.y / seg);
	float a = hash12(vec2(k, seed)) - 0.5;
	float b = hash12(vec2(k + 1.0, seed)) - 0.5;
	float x_off = mix(a, b, fract(cell.y / seg)) * px_size.x * 0.6;
	float d = abs(cell.x - (px_size.x * 0.5 + x_off));
	float core = step(d, 1.0);
	float glow = step(d, 3.0) * 0.5;
	float flicker = step(0.3, hash12(vec2(floor(TIME * 30.0), seed)));
	float v = max(core, glow) * (1.0 - step(0.75, progress)) * mix(0.6, 1.0, flicker);
	if (v <= 0.0) {
		discard;
	}
	COLOR = vec4(ramp_color(ramp, 0.5 + 0.5 * core), v);
}
