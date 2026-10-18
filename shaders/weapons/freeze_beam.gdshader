// 冻结光束：冰蓝色带上色，表面有流动的冰晶闪点。
shader_type canvas_item;
#include "res://shaders/shared/pixel.gdshaderinc"

uniform sampler2D ramp : filter_nearest, source_color;
uniform float dissolve = 0.0;        // 0..1：寿命末尾按像素随机消散

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a < 0.5) {
		discard;
	}
	vec2 texel = floor(UV / TEXTURE_PIXEL_SIZE);
	if (hash12(texel) < dissolve) {
		discard;
	}
	float sparkle = step(0.85, hash12(texel + floor(TIME * 12.0)));
	c.rgb = ramp_color(ramp, 0.4 + 0.4 * luma(c.rgb) + 0.3 * sparkle);
	COLOR = c * COLOR;
}
