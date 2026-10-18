// 五芒星：全屏闪光，中心浮现像素五芒星图案后整体褪去。
shader_type canvas_item;
#include "res://shaders/shared/pixel.gdshaderinc"

uniform sampler2D ramp : filter_nearest, source_color;
uniform float progress = 0.0;
uniform vec2 px_size = vec2(640.0, 360.0);

float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	// 以 2 像素为一格
	vec2 cell = floor(UV * px_size / 2.0) * 2.0;
	vec2 p = (cell - px_size * 0.5) / px_size.y;
	float d = 1.0;
	for (int i = 0; i < 5; i++) {
		float a0 = -1.5708 + float(i) * 2.5133;
		float a1 = -1.5708 + float(i + 1) * 2.5133;
		d = min(d, seg_dist(p, vec2(cos(a0), sin(a0)) * 0.35, vec2(cos(a1), sin(a1)) * 0.35));
	}
	float ring = abs(length(p) - 0.38);
	float lines = step(min(d, ring), 0.008);
	float flash = 1.0 - smoothstep(0.0, 0.35, progress);
	float v = max(lines * (1.0 - progress), flash * 0.6);
	COLOR = vec4(ramp_color(ramp, 0.5 + 0.5 * lines), v);
}
