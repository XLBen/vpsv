// 局内屏幕效果：受击时四角短暂泛红、低血量时心跳暗角、全屏冻结时冰蓝色调。
// 只作用于屏幕最外圈，强度克制，避免遮挡战场；按 4 像素格量化保持像素风。
shader_type canvas_item;
#include "res://shaders/shared/pixel.gdshaderinc"

uniform float hurt = 0.0;          // 0..1
uniform float low_hp = 0.0;        // 0..1（血量越低越大）
uniform float freeze = 0.0;        // 0/1
uniform vec4 hurt_color : source_color = vec4(0.62, 0.157, 0.208, 1.0);
uniform vec4 freeze_color : source_color = vec4(0.455, 0.765, 0.91, 1.0);

void fragment() {
	vec2 screen = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 cell = floor(FRAGCOORD.xy / 4.0) * 4.0 + 2.0;
	vec2 uv = cell / screen - 0.5;
	// 用到屏幕边缘的距离（而不是到中心的椭圆距离），只染最外一圈
	vec2 edge_d = (0.5 - abs(uv)) * screen;          // 到最近边的像素数
	float edge = 1.0 - clamp(min(edge_d.x, edge_d.y) / 36.0, 0.0, 1.0);
	edge = posterize(edge * edge, 3.0);
	float beat = 0.5 + 0.5 * sin(TIME * 7.0);
	float a = edge * (hurt * 0.45 + low_hp * (0.2 + 0.25 * beat));
	vec4 c = vec4(hurt_color.rgb, a);
	if (freeze > 0.5) {
		c = vec4(freeze_color.rgb, max(a, 0.12 + edge * 0.25));
	}
	COLOR = c;
}
