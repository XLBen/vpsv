// 圣水区域：圆内跳动的像素火苗。前 75% 寿命满火，最后 25% 逐格熄灭。
shader_type canvas_item;
#include "res://shaders/shared/pixel.gdshaderinc"

uniform sampler2D ramp : filter_nearest, source_color;
uniform float progress = 0.0;        // 0..1 寿命进度
uniform vec2 px_size = vec2(36.0);

void fragment() {
	vec2 cell = floor(UV * px_size);
	vec2 uv = (cell + 0.5) / px_size - 0.5;
	float r = length(uv * vec2(1.0, 1.6)) * 2.0;   // 压扁成地面上的椭圆
	if (r > 1.0) {
		discard;
	}
	// 火苗：噪声沿 y 向上滚动
	float n = value_noise(vec2(cell.x * 0.35, cell.y * 0.35 + TIME * 6.0));
	float flame = n * (1.0 - r * 0.7);
	float burn_out = clamp((progress - 0.75) / 0.25, 0.0, 1.0);
	float alive = step(burn_out, hash12(cell) * 0.98);
	float v = posterize(clamp(flame * 1.4, 0.0, 1.0), 4.0) * alive;
	if (v < 0.2) {
		discard;
	}
	COLOR = vec4(ramp_color(ramp, v), 0.75);
}
