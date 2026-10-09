shader_type canvas_item;
// Recolours masked regions of a painted character (milestone 5D). Only pixels inside the mask
// change; their painted shading is kept by mapping the original luminance onto a dark/mid/light
// palette of the target colour, so strands, highlights and line art survive.
// Used for hair colour now; the same pattern takes skin or fabric masks later.

uniform sampler2D hair_mask : filter_linear_mipmap, repeat_disable;
uniform bool hair_enabled = false;
uniform vec3 hair_dark : source_color = vec3(0.1, 0.06, 0.05);
uniform vec3 hair_mid : source_color = vec3(0.4, 0.25, 0.18);
uniform vec3 hair_light : source_color = vec3(0.75, 0.6, 0.5);
// Luminance of the original hair's shadows and highlights (5th..95th percentile), from the manifest.
uniform vec2 hair_lum = vec2(0.04, 0.4);

void fragment() {
	vec4 c = COLOR;
	if (hair_enabled) {
		float m = texture(hair_mask, UV).r;
		if (m > 0.002) {
			float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
			float t = smoothstep(hair_lum.x, hair_lum.y, l);
			vec3 g = t < 0.5 ? mix(hair_dark, hair_mid, t * 2.0) : mix(hair_mid, hair_light, t * 2.0 - 1.0);
			c.rgb = mix(c.rgb, g, m);
		}
	}
	COLOR = c;
}
