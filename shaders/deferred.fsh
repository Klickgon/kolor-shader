#version 120

#define PI 3.1415926535897932384626433832795

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D lightmap;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D texture;
uniform sampler2D noisetex;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;

uniform mat4 shadowProjection;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform vec3 skyColor;
uniform float sunAngle;
uniform float fogStart;
uniform float fogEnd;
uniform vec3 fogColor;
uniform int worldTime;
uniform vec3 sunPosition;
uniform vec3 shadowLightPosition;
uniform int heldBlockLightValue;
uniform vec3 eyePosition;
uniform vec3 cameraPosition;
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;


varying vec2 texcoord;

#if COLORED_SHADOWS == 0
	//for normal shadows, only consider the closest thing to the sun,
	//regardless of whether or not it's opaque.
	#define TEX shadowtex0
#else
	//else consider the closest opaque thing
	#define TEX shadowtex1
#endif

float linearizeDepth(float depth) {
    return (near * far * 4.0) / (depth * (near - far * 4.0) + far * 4.0);
}

vec3 sRGB_to_Linear(vec3 color){
	return pow(color, vec3(2.2));
}

vec3 Linear_to_sRGB(vec3 color){
	return pow(color, vec3(1.0/2.2));
}

vec2 lmcoord = sRGB_to_Linear(texture(colortex1, texcoord).xyz).rg;
vec3 normal = normalize((texture(colortex2, texcoord).rgb - 0.5) * 2.0); // we normalize to make sure it is of unit length
float distortFactor = 0.0;

#include "/settings.glsl"
#include "/lib/distort.glsl"
#include "/lib/lighting.glsl"

const float shadowRenderDis = (shadowDistance * shadowDistanceRenderMul);

void main() {
	vec4 color = texture2D(colortex0, texcoord);
	vec2 lm = lmcoord;
	color.rgb = sRGB_to_Linear(color.rgb);
	float lightDot;
	if (texture(colortex1, texcoord).z >= 1.0) lightDot = 1.0;
	else lightDot = dot(normalize(shadowLightPosition), normalize(normal));

	vec3 screenPos = vec3(texcoord.xy, texture(depthtex1, texcoord).r);
	vec3 NDCPos = screenPos * 2.0 - 1.0;
	vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);
	vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
	vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
	vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);
	
	vec3 worldPos = feetPlayerPos + cameraPosition;

	float intensity = getLightIntensity(sunAngle);
	float intensitysky = (0.25 * intensity) + 0.5;
	vec3 sky = mix(skyColor, vec3(0.02), intensity - 0.5);
	float light = mix(31.0 / 32.0 * SHADOW_BRIGHTNESS, 31.0 / 32.0, sqrt(lightDot));
	vec3 tint = vec3(1.0);
	#ifdef HAND_HELD_LIGHTING
		float hand = float(heldBlockLightValue != 0) * (max((heldBlockLightValue - length(worldPos - eyePosition))/ heldBlockLightValue, 0.0));
		lm.x = mix(lm.x, 1.0, hand * hand);
	#endif

	vec3 shadowPos;
	#ifdef SCREEN_SPACE_SHADOWS
		bool sss = screenSpaceShadow(viewPos, screenPos.z);
	#else
		const bool sss = false;
	#endif
	if (lightDot > 0.05 && (!sss || lightDot == 1.0)) { //surface is facing towards shadowLightPosition
		float bias = computeBias(shadowClipPos.xyz);
		shadowClipPos.xyz = distort(shadowClipPos.xyz); //apply shadow distortion
		shadowPos.xyz = shadowClipPos.xyz * 0.5 + 0.5;

		#ifdef NORMAL_BIAS
			shadowPos.xyz += projectAndDivide(shadowProjection, normal) * bias / max(lightDot, 0.1);
		#else
			shadowPos.z -= max(bias * (1.0 - lightDot), bias);
		#endif
			
		#if COLORED_SHADOWS == 1
			vec4 coloredShadow = filteredShadow(shadowPos, SHADOW_FILTER_BLUR, intensitysky, light);
			tint = coloredShadow.rgb;
			lm.y = coloredShadow.a;
		#else 
			lm.y = filteredShadow(shadowPos, SHADOW_FILTER_BLUR, light);
		#endif
	}
	else { //surface is facing away
		lm.y *= SHADOW_BRIGHTNESS; //guaranteed to be in shadows. reduce light level.
	}
	lm.y = mix(lm.y, min(lmcoord.y, light), clamp((length(viewPos) - shadowRenderDis * (1-SHADOW_FADE_LENGTH)) / (shadowRenderDis - shadowRenderDis * (1-SHADOW_FADE_LENGTH)), 0.0, 1.0));

	float range = (lm.y - SHADOW_BRIGHTNESS * lmcoord.y) / (light - SHADOW_BRIGHTNESS * lmcoord.y);
	sky *= mix(vec3(lmcoord.y), getCelestialColor() * intensity, max(range, 0.0));

	lm.x /= (1+lmcoord.y * 1.5) * intensitysky;
	color.rgb *= mix(intensitysky * sky * tint - clamp(dot(normalize(shadowPos.xyz), normal.xyz) * 0.003, 0.0, 0.0003), BLOCKLIGHT, lm.x);

	float fogAmount = clamp((length(viewPos) - fogStart)/(fogEnd - fogStart), 0.0 , 1.0);
	color.rgb = mix(color.rgb, sRGB_to_Linear(fogColor), fogAmount * fogAmount);
	color.rgb = Linear_to_sRGB(color.rgb);
	//color.rgb = Linear_to_sRGB(vec3(screenPos.z));
	/* DRAWBUFFERS:0 */
	gl_FragData[0] = color; //gcolor
}