#version 120

#define PI 3.1415926535897932384626433832795

uniform sampler2D lightmap;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D texture;

uniform mat4 shadowProjection;
uniform mat4 shadowModelView;
uniform mat4 gbufferModelViewInverse;

uniform vec3 skyColor;
uniform float sunAngle;
uniform float fogStart;
uniform float fogEnd;
uniform vec3 fogColor;
uniform int worldTime;
uniform int blockEntityId;
uniform int isEyeInWater;
uniform vec3 sunPosition;
uniform vec3 shadowLightPosition;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying vec4 shadowPos;
varying vec3 normal;
varying vec3 viewPos3;
varying vec3 glNormal;
varying float distortFactor;

//fix artifacts when colored shadows are enabled
const bool shadowcolor0Nearest = true;
const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;

#include "/settings.glsl"
#include "/lib/lighting.glsl"

void main() {
	vec4 color = texture2D(texture, texcoord) * glcolor;
	float intensity = getLightIntensity(sunAngle);
	vec2 lm = lmcoord;
	float intensitysky = (0.25 * intensity) + 0.5;
	vec3 sky = mix(skyColor, vec3(1), intensity - 0.5);
	float light = mix(31.0 / 32.0 * SHADOW_BRIGHTNESS, 31.0 / 32.0, sqrt(shadowPos.w));
	vec3 tint = vec3(1.0);
	if (shadowPos.w > 0.0) {
		//surface is facing towards shadowLightPosition
		#if COLORED_SHADOWS == 0
			//for normal shadows, only consider the closest thing to the sun,
			//regardless of whether or not it's opaque.
			lm.y = filteredShadow(shadowPos, 1.0 / textureSize(shadowtex0, 0), SHADOW_FILTER_QUALITY, 0.5, light);
			tint = vec3(lm.y);
			sky *= mix(vec3(1.0), getCelestialColor() * intensity, lm.y);
		#else
			//for invisible and colored shadows, first check the closest OPAQUE thing to the sun.
			lm.y = filteredShadow(shadowPos, 1.0 / textureSize(shadowtex1, 0), SHADOW_FILTER_QUALITY, 0.5, light);
			sky *= mix(vec3(1.0), getCelestialColor() * intensity, lm.y);
			#if COLORED_SHADOWS == 1
				tint = filteredColoredShadow(shadowPos, 1.0 / textureSize(shadowtex0, 0), SHADOW_FILTER_QUALITY, 0.5, intensitysky);
			#endif
		#endif
	}
	color *= texture2D(lightmap, lm);
	lm.x /= (lmcoord.y * lmcoord.y) + 1; 
	color.rgb *= BLOCKLIGHT * lm.x + mix(intensitysky * sky, vec3(1.0), lm.x) + clamp((dot(normalize(shadowPos.xyz), normal) * 0.3), 0., .05);
	float fogAmount = clamp((length(viewPos3) - fogStart)/(fogEnd - fogStart), 0. , 1.);
	color.rgb = mix(color.rgb * tint, fogColor, fogAmount);
	/* DRAWBUFFERS:0 */
	gl_FragData[0] = color; //gcolor
}