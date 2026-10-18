// 爆炸 / 落雷冲击：向外扩张的亮环 + 半透明抖动闪光 + 飞散火星。
// 内部只用半透明的棋盘抖动填充，不会把下面的怪物整个盖住。
shader_type canvas_item;
#include "res://shaders/shared/pixel.gdshaderinc"

uniform sampler2D ramp : filter_nearest, source_color;
uniform float progress = 0.0;
uniform vec2 px_size = vec2(32.0);

void fragment() {
	vec2 cell = floor(UV * px_size);
	float r = length((cell + 0.5) / px_size - 0.5) * 2.0;
	float ring_r = mix(0.25, 1.0, sqrt(progress));
	float ring = step(abs(r - ring_r), 0.1) * (1.0 - step(0.85, progress));
	// 闪光：起初实心、很快变成棋盘格、随后碎成零星像素
	float checker = mod(cell.x + cell.y, 2.0);
	float flash_fill = step(r, ring_r * 0.85) * (1.0 - step(0.45, progress));
	float solid = 1.0 - step(0.12, progress);
	float fill = flash_fill * max(solid, checker * step(hash12(cell + floor(progress * 10.0)), 1.0 - progress * 1.6));
	float sparks = step(0.94, hash12(cell + floor(progress * 6.0))) * step(r, ring_r) * (1.0 - step(0.9, progress));
	if (ring + fill + sparks <= 0.0) {
		discard;
	}
	float v = max(ring, max(fill * 0.7, sparks));
	COLOR = vec4(ramp_color(ramp, 0.3 + 0.7 * v), ring > 0.0 ? 1.0 : 0.8);
}
