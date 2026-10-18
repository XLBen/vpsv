// 玩家：受击闪红、无敌闪烁、护盾描边。
shader_type canvas_item;
#include "res://shaders/shared/pixel.gdshaderinc"

uniform float flash = 0.0;
uniform float invuln = 0.0;
uniform float shield = 0.0;
uniform vec4 hurt_color : source_color = vec4(0.851, 0.267, 0.243, 1.0);
uniform vec4 shield_color : source_color = vec4(0.776, 0.863, 0.424, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	// 受击：前半段整片染红，硬切换
	c.rgb = mix(c.rgb, hurt_color.rgb, step(0.5, flash) * 0.85);
	// 无敌：按时间整格闪烁（半透明）
	float blink = step(0.5, fract(TIME * 12.0));
	c.a *= mix(1.0, 0.35 + 0.65 * blink, invuln);
	// 护盾：透明像素若邻接实心像素则描一圈亮绿
	if (shield > 0.0 && c.a < 0.5) {
		float n = texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a + texture(TEXTURE, UV - vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a
			+ texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a + texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a;
		if (n > 0.5) {
			c = vec4(shield_color.rgb, step(0.5, fract(TIME * 6.0)) * 0.5 + 0.5);
		}
	}
	COLOR = c;
}
