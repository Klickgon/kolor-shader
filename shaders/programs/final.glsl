#version 120

#include "/./settings.glsl"

uniform sampler2D texture;

varying vec2 texcoord;
uniform float screenBrightness;
uniform ivec2 eyeBrightnessSmooth;

float grayScale(vec3 color){
    return (color.r + color.g + color.b) / 3.0;
}

void main() {
	vec4 color = texture2D(texture, texcoord);
	color.rgb += screenBrightness * 0.005;
	#ifdef EXPOSURE
		float exposure = 8.5 - (float(max(eyeBrightnessSmooth.x, eyeBrightnessSmooth.y)) / 35.0);
		color.rgb = vec3(1.0) - exp(-color.rgb * exposure);
	#endif
	color.rgb = pow(color.rgb, vec3(1.0/2.12));
/* RENDERTARGETS:0 */
	gl_FragData[0] = color;
}