#define PI 3.1415926535897932384626433832795

uniform sampler2D lightmap;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D texture;
uniform sampler2D noisetex;

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
uniform int heldBlockLightValue;
uniform vec3 eyePosition;
uniform float viewWidth;
uniform float viewHeight;


#if COLORED_SHADOWS == 0
	//for normal shadows, only consider the closest thing to the sun,
	//regardless of whether or not it's opaque.
	#define TEX shadowtex0
#else
	//else consider the closest opaque thing
	#define TEX shadowtex1
#endif

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying vec4 shadowPos;
varying vec4 normal;
varying vec3 viewPos3;
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
	vec3 sky = mix(skyColor, vec3(1.0), intensity - 0.5);
	float light = mix(31.0 / 32.0 * SHADOW_BRIGHTNESS, 31.0 / 32.0, sqrt(shadowPos.w));
	vec3 tint = vec3(1.0);
	if (shadowPos.w > 0.0) {
		//surface is facing towards shadowLightPosition
		lm.y = filteredShadow(shadowPos, 1.0 / textureSize(TEX, 0), SHADOW_FILTER_QUALITY, SHADOW_FILTER_BLUR, light);
		#ifdef HAND_HELD_LIGHTING
			lm.x =  mix(lm.x, 1.0, float(heldBlockLightValue == 0) * (max((heldBlockLightValue - length(eyePosition - shadowPos.xyz)) / heldBlockLightValue, 0.0)));
		#endif
        float range = ((lm.y - SHADOW_BRIGHTNESS * lmcoord.y) / (light - SHADOW_BRIGHTNESS * lmcoord.y));
		sky *= mix(vec3(1.0), getCelestialColor() * intensity, range);
		#if COLORED_SHADOWS == 1
			tint = filteredColoredShadow(shadowPos, 1.0 / textureSize(TEX, 0), SHADOW_FILTER_QUALITY, SHADOW_FILTER_BLUR, intensitysky);
		#endif
	}
	color *= texture2D(lightmap, lm);
	lm.x = max(lm.x - lmcoord.y * max(intensity - 0.75, 0.0), 0.0);
	//color.rgb *= mix(intensitysky * sky - clamp(dot(normalize(shadowPos.xyz), normal.xyz) * 0.003, 0.0, 0.03), vec3(0.0), lm.x) + BLOCKLIGHT * lm.x;
	color.rgb *= mix(intensitysky * sky - clamp(dot(normalize(shadowPos.xyz), normal.xyz) * 0.003, 0.0, 0.03), BLOCKLIGHT, lm.x);
	float fogAmount = clamp((length(viewPos3) - fogStart)/(fogEnd - fogStart), 0.0 , 1.0);
	color.rgb = mix(color.rgb * tint, fogColor, fogAmount);
	/* DRAWBUFFERS:0 */
	gl_FragData[0] = color; //gcolor
}