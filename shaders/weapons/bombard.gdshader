// 鸟群轰炸：与爆炸同一结构（复制后可独立调整）。
shader_type canvas_item;
#include "res://shaders/shared/pixel.gdshaderinc"

uniform sampler2D ramp : filter_nearest, source_color;
uniform float progress = 0.0;
uniform vec2 px_size = vec2(32.0);

void fragment() {
	vec2 cell = floor(UV * px_size);
	float r = length((cell + 0.5) / px_size - 0.5) * 2.0;
	float ring_r = mix(0.2, 1.0, sqrt(progress));
	float ring = step(abs(r - ring_r), 0.12);
	float fill = step(r, ring_r * 0.8) * (1.0 - progress * 1.6);
	float sparks = step(0.93, hash12(cell + floor(progress * 6.0))) * step(r, ring_r);
	float v = clamp(max(ring * (1.0 - progress), max(fill, sparks)), 0.0, 1.0);
	if (v <= 0.05) {
		discard;
	}
	COLOR = vec4(ramp_color(ramp, 0.3 + 0.7 * v), 1.0);
}
