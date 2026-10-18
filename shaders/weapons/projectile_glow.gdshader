// 投射物通用：把灰阶造型按亮度映射到武器色带（同一张图换色带即得进化版配色），
// 并在外围加 1px 发光描边，描边亮度随时间脉动。
shader_type canvas_item;
#include "res://shaders/shared/pixel.gdshaderinc"

uniform sampler2D ramp : filter_nearest, source_color;
uniform float glow = 1.0;
uniform float dissolve = 0.0;        // 0..1：寿命末尾按像素随机消散

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a > 0.5) {
		float l = luma(c.rgb);
		// 描边（墨色）保持原样，其余按亮度上色
		if (l > 0.12) {
			c.rgb = ramp_color(ramp, 0.25 + l * 0.75);
		}
	} else if (glow > 0.0) {
		float n = texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a + texture(TEXTURE, UV - vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a
			+ texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a + texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a;
		float pulse = step(0.5, fract(TIME * 6.0));
		if (n > 0.5) {
			c = vec4(ramp_color(ramp, 0.6), 0.45 + 0.25 * pulse);
		}
	}
	if (dissolve > 0.0 && hash12(floor(UV / TEXTURE_PIXEL_SIZE)) < dissolve) {
		discard;
	}
	COLOR = c * COLOR;
}
