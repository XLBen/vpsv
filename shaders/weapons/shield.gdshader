// 桂冠护盾：环绕角色的像素泡泡，边缘闪烁的叶片光点。
shader_type canvas_item;
#include "res://shaders/shared/pixel.gdshaderinc"

uniform sampler2D ramp : filter_nearest, source_color;
uniform float progress = 0.0;
uniform vec2 px_size = vec2(28.0);

void fragment() {
	vec2 cell = floor(UV * px_size);
	vec2 uv = (cell + 0.5) / px_size - 0.5;
	float r = length(uv) * 2.0;
	float a = atan(uv.y, uv.x);
	float rim = step(abs(r - 0.92), 0.08);
	float leaves = step(0.8, fract(a / 6.2832 * 10.0 + TIME * 0.8)) * rim;
	float v = max(rim * 0.6, leaves);
	if (v <= 0.0) {
		discard;
	}
	COLOR = vec4(ramp_color(ramp, 0.4 + 0.6 * leaves), 0.5 + 0.4 * leaves);
}
