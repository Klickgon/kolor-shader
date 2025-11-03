#version 120

uniform sampler2D texture;

varying vec2 texcoord;
varying vec4 glcolor;

#define END_SKY_COLOR vec3(0.3, 0.05, 0.3)
/* RENDERTARGETS: 0,4 */
layout(location = 1) out vec4 extraInfo;

void main() {
	vec4 color = texture2D(texture, texcoord) * glcolor;
	color.rgb = pow(color.rgb, vec3(2.2)) * END_SKY_COLOR;
	gl_FragData[0] = color; //gcolor
	extraInfo = vec4(1.0, 0.0, 0.0, 1.0);
}