#version 120

#include "/settings.glsl"



uniform int isEyeInWater;
uniform int worldTime;
uniform float viewHeight;
uniform float viewWidth;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform vec3 shadowLightPosition;
uniform vec3 fogColor;
uniform vec3 skyColor;
uniform float shadowAngle;
uniform float sunAngle;
uniform vec3 sunPosition;


varying vec4 starData; //rgb = star color, a = flag for weather or not this pixel is a star.

#include "/./lib/sky_and_fog_functions.glsl"

/* RENDERTARGETS: 0,4 */
layout(location = 1) out vec4 extraInfo;

void main() {
	vec3 color;
	if (starData.a > 0.5) {
		color = starData.rgb;
	}
	else {
		vec4 pos = vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight) * 2.0 - 1.0, 1.0, 1.0);
		pos = gbufferProjectionInverse * pos;
		color = calcSkyColor(normalize(pos.xyz));
	}

	color.rgb = pow(color.rgb, vec3(2.2));
	//color.rgb = vec3(clamp(((worldTime % 24000) - 22500) * 0.001, 0.0, 1.0));
	gl_FragData[0] = vec4(color, 1.0); //gcolor
	extraInfo = vec4(1.0, 0.0, 0.0, 1.0);
}