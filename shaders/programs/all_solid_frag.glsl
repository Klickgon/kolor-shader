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
uniform vec3 eyeCameraPosition;
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
#if TEXTURED != 1
	varying vec4 normal;
#endif
varying vec3 viewPos;
varying vec3 playerPos;
varying vec3 worldPos;
varying float distortFactor;


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
	#ifdef HAND_HELD_LIGHTING
		lm.x = mix(lm.x, 1.0, float(heldBlockLightValue != 0) * (max((heldBlockLightValue - length(worldPos - eyePosition))/ heldBlockLightValue, 0.0)));
	#endif
	if (shadowPos.w > 0.0) {
		//surface is facing towards shadowLightPosition
		#if COLORED_SHADOWS == 1
			vec4 coloredShadow = filteredShadow(shadowPos, SHADOW_FILTER_BLUR, intensitysky, light);
			tint = coloredShadow.rgb;
			lm.y = coloredShadow.a;
		#else 
			lm.y = filteredShadow(shadowPos, SHADOW_FILTER_BLUR, light);
		#endif
	}
	float shadowRenderDis = (shadowDistance * shadowDistanceRenderMul);
	lm.y = mix(lm.y, min(lmcoord.y, light), clamp((length(viewPos) - shadowRenderDis * (1-SHADOW_FADE_LENGTH)) / (shadowRenderDis - shadowRenderDis * (1-SHADOW_FADE_LENGTH)), 0.0, 1.0));
	float range = (lm.y - SHADOW_BRIGHTNESS * lmcoord.y) / (light - SHADOW_BRIGHTNESS * lmcoord.y);
	sky *= mix(vec3(1.0), getCelestialColor() * intensity, max(range, 0.0));
	color *= texture2D(lightmap, lm);
	lm.x = max(lm.x - lmcoord.y * max(intensity - 0.75, 0.0), 0.0);
	#if TEXTURED == 1
		color.rgb *= mix(intensitysky * sky, BLOCKLIGHT, lm.x);
	#else
		color.rgb *= mix(intensitysky * sky - clamp(dot(normalize(shadowPos.xyz), normal.xyz) * 0.003, 0.0, 0.0003), BLOCKLIGHT, lm.x);
	#endif
	float fogAmount = clamp((length(viewPos) - fogStart)/(fogEnd - fogStart), 0.0 , 1.0);
	color.rgb = mix(color.rgb, fogColor, fogAmount);
	color.rgb = pow(color.rgb, vec3(2.2));
	color.rgb *= tint;
	color.rgb = pow(color.rgb, vec3(1.0/2.2));
	/* DRAWBUFFERS:0 */
	gl_FragData[0] = color; //gcolor
}