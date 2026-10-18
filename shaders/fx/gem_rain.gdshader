// 升级演出：宝石雨。像素菱形从屏幕顶部落下，颜色在蓝 / 绿 / 红三档宝石间随机。
shader_type canvas_item;
#include "res://shaders/shared/pixel.gdshaderinc"

uniform float elapsed = 0.0;       // 演出开始后的秒数
uniform float duration = 1.2;
uniform vec4 c1 : source_color = vec4(0.247, 0.525, 0.769, 1.0);
uniform vec4 c2 : source_color = vec4(0.525, 0.722, 0.29, 1.0);
uniform vec4 c3 : source_color = vec4(0.851, 0.267, 0.243, 1.0);

void fragment() {
	vec2 px = floor(FRAGCOORD.xy);
	float col = floor(px.x / 12.0);
	float h = hash12(vec2(col, 3.1));
	float speed = 220.0 + h * 160.0;
	float y0 = -20.0 - h * 160.0 + elapsed * speed;
	vec2 local = vec2(mod(px.x, 12.0) - 6.0, px.y - y0);
	float diamond = step(abs(local.x) + abs(local.y) * 0.75, 3.0);
	float shine = step(abs(local.x + 1.0) + abs(local.y + 1.0), 1.0);
	float visible = step(h, 0.55) * (1.0 - step(duration, elapsed));
	if (diamond * visible < 0.5) {
		discard;
	}
	float pick = hash12(vec2(col, 7.7));
	vec3 c = pick < 0.6 ? c1.rgb : (pick < 0.9 ? c2.rgb : c3.rgb);
	COLOR = vec4(mix(c, vec3(1.0), shine), 1.0);
}
