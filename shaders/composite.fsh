#version 120

#define TRANSLUCENT_PASS 1

/*
uniform sampler2D colortex0;

varying vec2 texcoord;

void main() {
	vec4 color = texture2D(colortex0, texcoord);
	gl_FragData[0] = color; //gcolor
}
*/

#include "/programs/lighting.glsl"