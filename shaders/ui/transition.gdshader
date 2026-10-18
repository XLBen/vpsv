// 像素转场：用工作室导出的阈值图案（菱形扩散）平铺全屏，progress 越大遮住的格子越多。
shader_type canvas_item;

uniform sampler2D pattern : filter_nearest, repeat_enable;
uniform float progress = 0.0;
uniform float cell = 16.0;          // 图案在屏幕上的像素尺寸
uniform vec4 color : source_color = vec4(0.078, 0.063, 0.11, 1.0);

void fragment() {
	vec2 px = FRAGCOORD.xy / cell;
	float threshold = dot(texture(pattern, fract(px)).rgb, vec3(0.299, 0.587, 0.114));
	// 叠加一个全屏的从左到右的梯度，让菱形依次扫过
	float sweep = SCREEN_UV.x * 0.5;
	float v = step(threshold * 0.5 + sweep, progress * 1.5);
	COLOR = vec4(color.rgb, v);
}
