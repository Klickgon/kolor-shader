#version 120

#define M_PI 3.1415926535897932384626433832795

uniform sampler2D lightmap;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D texture;
uniform vec3 skyColor;
uniform float sunAngle;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying vec4 shadowPos;
varying vec3 normal;

//fix artifacts when colored shadows are enabled
const bool shadowcolor0Nearest = true;
const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;

#include "/settings.glsl"

float getLightIntensity(float x){
	return 0.5 * sin(x * M_PI * 2) - 0.5;
}

void main() {
	vec4 color = texture2D(texture, texcoord) * glcolor;
	float intensity = getLightIntensity(sunAngle);
	vec2 lm = lmcoord;
	float intensitysky = 0.05 * intensity + 1;
	intensity = intensity > 0 ? 0 : -intensity;
	vec3 sky =  mix(skyColor, vec3(1.0), intensity);
	if (shadowPos.w > 0.0) {
		//surface is facing towards shadowLightPosition
		#if COLORED_SHADOWS == 0
			//for normal shadows, only consider the closest thing to the sun,
			//regardless of whether or not it's opaque.
			if (texture2D(shadowtex0, shadowPos.xy).r < shadowPos.z) {
		#else
			//for invisible and colored shadows, first check the closest OPAQUE thing to the sun.
			if (texture2D(shadowtex1, shadowPos.xy).r < shadowPos.z) {
		#endif
			//surface is in shadows. reduce light level.
			lm.y = SHADOW_BRIGHTNESS;
		}
		else {
			//surface is in direct sunlight. increase light level.
			lm.y = mix(31.0 / 32.0 * SHADOW_BRIGHTNESS, 31.0 / 32.0, sqrt(shadowPos.w));
			#if COLORED_SHADOWS == 1
				//when colored shadows are enabled and there's nothing OPAQUE between us and the sun,
				//perform a 2nd check to see if there's anything translucent between us and the sun.
				if (texture2D(shadowtex0, shadowPos.xy).r < shadowPos.z) {
					//surface has translucent object between it and the sun. modify its color.
					//if the block light is high, modify the color less.
					vec4 shadowLightColor = texture2D(shadowcolor0, shadowPos.xy);
					//make colors more intense when the shadow light color is more opaque.
					shadowLightColor.rgb = mix(vec3(1.0), shadowLightColor.rgb, shadowLightColor.a) * (intensitysky + 1);
					//also make colors less intense when the block light level is high.
					shadowLightColor.rgb = mix(shadowLightColor.rgb, vec3(1.0), lm.x);
					//apply the color
					color.rgb *= shadowLightColor.rgb;
				} else sky = vec3(1.0);
				
			#endif
		}
		
	}
	vec3 blocklight = vec3(.5, 0.35, 0.1);
	color.rgb *= blocklight * lm.x + mix(lmcoord.y * sky.rgb * intensitysky, vec3(1.0), lm.x) + clamp((dot(normalize(shadowPos.xyz), normal) * 0.03), 0.0, 1.0);
	color *= texture2D(lightmap, lm);

	/* DRAWBUFFERS:0 */
	gl_FragData[0] = color; //gcolor
}