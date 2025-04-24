#version 120

#define PI 3.1415926535897932384626433832795

uniform sampler2D lightmap;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D texture;
uniform vec3 skyColor;

uniform float sunAngle;
uniform float fogStart;
uniform float fogEnd;
uniform vec3 fogColor;
uniform int worldTime;
uniform int blockEntityId;
uniform int isEyeInWater;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying vec4 shadowPos;
varying vec3 normal;
varying vec3 viewPos3;

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
	float shadow;
	if (shadowPos.w > 0.0) {
		//surface is facing towards shadowLightPosition
		#if COLORED_SHADOWS == 0
			//for normal shadows, only consider the closest thing to the sun,
			//regardless of whether or not it's opaque.
			lm.y = filteredShadow(shadowtex0, shadowPos, 1.0 / textureSize(shadowtex0, 0), 2, 0.5);
			sky *= mix(vec3(1.0), getCelestialColor() * intensity, lm.y);
		#else
			//for invisible and colored shadows, first check the closest OPAQUE thing to the sun.
			lm.y = filteredShadowColored(shadowtex1, shadowtex0, shadowPos, 1.0 / textureSize(shadowtex1, 0), 2, 0.5);
			sky *= mix(vec3(1.0), getCelestialColor() * intensity, lm.y);
		#endif
			#if COLORED_SHADOWS == 1
				//when colored shadows are enabled and there's nothing OPAQUE between us and the sun,
				//perform a 2nd check to see if there's anything translucent between us and the sun.
				float tex0 = texture2D(shadowtex0, shadowPos.xy).r;
				float tex1 = texture2D(shadowtex1, shadowPos.xy).r;
				if (tex1 > shadowPos.z && tex0 < shadowPos.z) {
					//surface has translucent object between it and the sun. modify its color.
					//if the block light is high, modify the color less.
					vec4 shadowLightColor = texture2D(shadowcolor0, shadowPos.xy);
					//make colors more intense when the shadow light color is more opaque.
					shadowLightColor.rgb = mix(vec3(1.0), shadowLightColor.rgb, shadowLightColor.a);
					//also make colors less intense when the block light level is high.
					//apply the color
					color.rgb *= mix(shadowLightColor.rgb, vec3(1), lm.x);
				}
				
			#endif
	}
	color *= texture2D(lightmap, lm);
	lm.x /= (0.5 * lmcoord.y) + 0.8; 
	color.rgb *= BLOCKLIGHT * lm.x  + mix(intensitysky * sky * lm.y , vec3(1), lm.x) + clamp((dot(normalize(shadowPos.xyz), normal) * 0.003), 0., .05);
	float fogAmount = clamp((length(viewPos3) - fogStart)/(fogEnd - fogStart), 0. , 1.);
	color.rgb = mix(color.rgb, fogColor, fogAmount);
	/* DRAWBUFFERS:0 */
	gl_FragData[0] = color; //gcolor
}