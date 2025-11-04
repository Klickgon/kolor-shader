#version 120

uniform sampler2D texture;
uniform vec3 shadowLightPosition;
uniform mat4 gbufferProjectionInverse;
uniform float viewWidth;
uniform float viewHeight;

varying vec2 texcoord;
varying vec4 glcolor;

#define END_SKY_COLOR vec3(0.3, 0.05, 0.3)
/* RENDERTARGETS: 0,4 */
layout(location = 1) out vec4 extraInfo;

void main() {
	vec4 color = texture2D(texture, texcoord) * glcolor;
	color.rgb = pow(color.rgb, vec3(2.2)) * END_SKY_COLOR;
	vec4 pos = vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight) * 2.0 - 1.0, 1.0, 1.0);
	pos.xyz = normalize((gbufferProjectionInverse * pos).xyz);
	float shadowDot = dot(pos.xyz, shadowLightPosition * 0.01);

	float glowMix = clamp(shadowDot * 10.0 - 9.0, 0.0, 1.0);
	glowMix *= glowMix;
	color.rgb = mix(color.rgb, END_SKY_COLOR, glowMix);

	float blackHoleMix = clamp(shadowDot * 120.0 - 115.0, 0.0, 1.0);
	blackHoleMix *= blackHoleMix;
	color.rgb = mix(color.rgb, vec3(0.0), blackHoleMix);
	
	gl_FragData[0] = color; //gcolor
	extraInfo = vec4(1.0, 0.0, 0.0, 1.0);
}