// 刀光：按亮度映射到色带；随 progress 从尾部开始像素化溶解。
shader_type canvas_item;
#include "res://shaders/shared/pixel.gdshaderinc"

uniform sampler2D ramp : filter_nearest, source_color;
uniform float progress = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a < 0.5) {
		discard;
	}
	float l = luma(c.rgb);
	c.rgb = ramp_color(ramp, 0.3 + l * 0.7);
	vec2 texel = floor(UV / TEXTURE_PIXEL_SIZE);
	float n = hash12(texel);
	// 越靠左（起手处）越早消失
	float cut = progress * 1.4 - (1.0 - UV.x) * 0.4;
	if (n < cut) {
		discard;
	}
	COLOR = c * COLOR;
}
