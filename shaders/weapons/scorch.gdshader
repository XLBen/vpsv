// 焦痕：落雷 / 爆炸在地面留下的抖动暗斑，随 progress 逐格褪去。
shader_type canvas_item;
#include "res://shaders/shared/pixel.gdshaderinc"

uniform sampler2D ramp : filter_nearest, source_color;
uniform float progress = 0.0;
uniform vec2 px_size = vec2(24.0, 12.0);

void fragment() {
	vec2 cell = floor(UV * px_size);
	vec2 uv = (cell + 0.5) / px_size - 0.5;
	float r = length(uv) * 2.0;
	float n = hash12(cell);
	if (r > 1.0 || n > 1.0 - r * 0.6 || n < progress) {
		discard;
	}
	float ember = step(0.9, hash12(cell + floor(TIME * 8.0))) * step(r, 0.5) * (1.0 - step(0.4, progress));
	COLOR = ember > 0.0 ? vec4(ramp_color(ramp, 0.8), 1.0) : vec4(0.08, 0.06, 0.1, 0.45);
}
