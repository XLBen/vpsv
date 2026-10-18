// 像素风特效共用函数：哈希噪声、亮度、色带采样、UV 像素对齐。

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// 把 0..1 的强度映射到调色板色带（色带贴图为 N×1，最近邻采样 → 颜色只取色带里的值）。
vec3 ramp_color(sampler2D ramp, float t) {
	return texture(ramp, vec2(clamp(t, 0.0, 0.999), 0.5)).rgb;
}

// 把 UV 吸附到 px 网格（px = 以像素计的尺寸），让程序化特效也呈现方块像素。
vec2 snap_uv(vec2 uv, vec2 px) {
	return (floor(uv * px) + 0.5) / px;
}

// 量化到 n 级，制造像素风的色阶。
float posterize(float v, float n) {
	return floor(v * n + 0.5) / n;
}
