#version 120

uniform sampler2D texture;
uniform vec3 sunPosition;
uniform vec3 shadowLightPosition;
uniform float near;
uniform float far;

varying vec2 texcoord;
varying vec4 glcolor;

#include "/lib/common.glsl"

void main() {
	vec4 color = texture2D(texture, texcoord) * glcolor;
	color.rgb *= getCelestialColor() * 0.20;
/* DRAWBUFFERS:0 */
	gl_FragData[0] = color; //gcolor
}