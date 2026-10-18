// 序列帧批量渲染（MultiMesh）。每个实例的 INSTANCE_CUSTOM：
//   x 列（帧号） · y 行（动画片段）
//   z 闪白（1 纯白 / 0.5 色调）+ 冻结（+2）+ 溶解种子 ×4（每只怪固定）
//   w 溶解（0..1）+ 首领描边（+2）
shader_type canvas_item;
#include "res://shaders/shared/pixel.gdshaderinc"

uniform vec2 grid = vec2(1.0);
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 tint_color : source_color = vec4(1.0, 0.55, 0.45, 1.0);   // 闪白之后的第二段受击色调
uniform vec4 freeze_color : source_color = vec4(0.455, 0.765, 0.91, 1.0);
uniform vec4 outline_color : source_color = vec4(0.961, 0.773, 0.259, 1.0);   // 首领描边
uniform vec4 edge_color : source_color = vec4(0.08, 0.06, 0.11, 1.0);         // 普通描边（提高与地面的对比度）
uniform bool edge = false;
uniform sampler2D dissolve_ramp : filter_nearest, source_color;

varying vec4 inst;

void vertex() {
	inst = INSTANCE_CUSTOM;
	UV = (UV + inst.xy) / grid;
}

void fragment() {
	vec2 frame_px = 1.0 / (TEXTURE_PIXEL_SIZE * grid);
	vec2 frame_origin = floor(UV * grid) / grid;
	vec4 c = texture(TEXTURE, UV);

	float seed = floor(inst.z / 4.0 + 0.01);
	float rest = inst.z - seed * 4.0;
	float frozen = step(1.5, rest);
	float flash = clamp(rest - frozen * 2.0, 0.0, 1.0);
	float boss = step(1.5, inst.w);
	float dissolve = clamp(inst.w - boss * 2.0, 0.0, 1.0);

	// 1px 描边：首领金色，其余为深色（edge 打开时）；只在本帧范围内取邻居，避免串帧
	if ((boss > 0.5 || edge) && c.a < 0.5) {
		vec2 lo = frame_origin;
		vec2 hi = frame_origin + 1.0 / grid - TEXTURE_PIXEL_SIZE;
		float n = texture(TEXTURE, clamp(UV + vec2(TEXTURE_PIXEL_SIZE.x, 0.0), lo, hi)).a
			+ texture(TEXTURE, clamp(UV - vec2(TEXTURE_PIXEL_SIZE.x, 0.0), lo, hi)).a
			+ texture(TEXTURE, clamp(UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y), lo, hi)).a
			+ texture(TEXTURE, clamp(UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y), lo, hi)).a;
		if (n > 0.5) {
			c = vec4(boss > 0.5 ? outline_color.rgb : edge_color.rgb, 1.0);
		}
	}

	// 冻结：整体染成冰色，保留明暗
	c.rgb = mix(c.rgb, freeze_color.rgb * (0.55 + 0.6 * luma(c.rgb)), frozen * 0.85);

	// 受击：先纯白，再一段色调（硬切换，保持像素风）
	c.rgb = mix(c.rgb, flash_color.rgb, step(0.75, flash));
	c.rgb = mix(c.rgb, c.rgb * 0.5 + tint_color.rgb * 0.6, step(0.25, flash) * (1.0 - step(0.75, flash)));

	// 死亡溶解：按像素格随机消失，边缘一圈染成色带的亮色
	if (dissolve > 0.0) {
		vec2 texel = floor((UV - frame_origin) * grid * frame_px);
		float n = hash12(texel + seed * 17.0);
		if (n < dissolve) {
			discard;
		}
		if (n < dissolve + 0.15) {
			c.rgb = texture(dissolve_ramp, vec2(0.85, 0.5)).rgb;
		}
	}
	COLOR = c * COLOR;
}
