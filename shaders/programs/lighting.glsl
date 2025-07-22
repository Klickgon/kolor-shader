

#include "/settings.glsl"


#define CTEX1 colortex0
#define LTEX2 colortex1
#define NEX3 colortex2
#if TRANSLUCENT_PASS == 1
 	#define DTEX depthtex0
#else
	#define DTEX depthtex1
#endif


uniform sampler2D CTEX1;
uniform sampler2D LTEX2;
uniform sampler2D NEX3;
uniform sampler2D colortex3;


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

#include "/lib/common.glsl"

vec2 lmcoord = sRGB_to_Linear(texture(LTEX2, texcoord).xyz).rg;
vec3 normal = normalize((texture(NEX3, texcoord).rgb - 0.5) * 2.0); // we normalize to make sure it is of unit length
float distortFactor = 0.0;

vec4 getNoise(vec2 coord){
  ivec2 noiseCoord = ivec2(coord * vec2(viewWidth, viewHeight)) % noiseTextureResolution; // wrap to range of noiseTextureResolution
  return texelFetch(noisetex, noiseCoord, 0);
}

vec4 noise = getNoise(texcoord);
const float shadowRenderDis = (shadowDistance * shadowDistanceRenderMul);

#include "/lib/distort.glsl"
#include "/lib/shadows.glsl"

void main() {
	vec4 color = texture2D(CTEX1, texcoord);
    #if TRANSLUCENT_PASS == 1
		if(texture(colortex3, texcoord).r < 0.1){
			gl_FragData[0] = color;
			return;
		}
    #endif

	vec3 screenPos = vec3(texcoord.xy, texture(DTEX, texcoord).r);
	if(screenPos.z == 1.0){
		gl_FragData[0] = color;
		return;
	}

	vec2 lm = lmcoord;
	color.rgb = sRGB_to_Linear(color.rgb);
	float lightDot = texture(LTEX2, texcoord).z;
	
	vec3 NDCPos = screenPos * 2.0 - 1.0;
	vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);
	vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
	vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
	vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);
	
	vec3 worldPos = feetPlayerPos + cameraPosition;

	float intensity = getLightIntensity(sunAngle);
	float intensitysky = (0.25 * intensity) + 0.5;
	vec3 sky = mix(skyColor, vec3(0.02), intensity - 0.5);
	float lightDotSqrt = sqrt(lightDot);
	float light = mix(31.0 / 32.0 * SHADOW_BRIGHTNESS, 31.0 / 32.0, lightDotSqrt);

	vec3 tint = vec3(1.0);
	#ifdef HAND_HELD_LIGHTING
		float blockLightValue = heldBlockLightValue * 0.65;
		float hand = float(heldBlockLightValue != 0) * (max((blockLightValue - length(worldPos - eyePosition)) / blockLightValue, 0.0));
		hand *= hand;
		lm.x = mix(lm.x, 1.0, hand * hand);
	#endif

	vec3 shadowPos;
	#ifdef SCREEN_SPACE_SHADOWS
		#if TRANSLUCENT_PASS != 1
			bool sss = screenSpaceShadow(viewPos, screenPos.z, lightDot);
		#else
			const bool sss = false;
		#endif
	#else
		const bool sss = false;
	#endif
	float shadow;
	bool surfaceFacingLight = lightDot > 0.0015;
	if (surfaceFacingLight && (!sss || lightDot == 1.0)) { 
		//surface is facing towards shadowLightPosition
		float bias = computeBias(shadowClipPos.xyz);
		shadowClipPos.xyz = distort(shadowClipPos.xyz); //apply shadow distortion
		shadowPos.xyz = shadowClipPos.xyz * 0.5 + 0.5;
		
		float lightLeak = min(0.5*(lmcoord.y - 0.15), 1.0);
		#ifdef NORMAL_BIAS
			shadowPos.xyz += normalize(projectAndDivide(shadowProjection, normal)) * bias / max(lightDot, 0.25) * lightLeak;
		#else
			shadowPos.z -= max(bias * (1.0 - lightDot), bias) * lightLeak;
		#endif
		//shadowPos.z += lightLeak; //light leak prevention
			
		#if COLORED_SHADOWS == 1
			vec4 coloredShadow = filteredShadow(shadowPos, SHADOW_FILTER_BLUR, intensitysky);
			tint = coloredShadow.rgb;
			shadow = coloredShadow.a;
		#else 
			shadow = filteredShadow(shadowPos, SHADOW_FILTER_BLUR);
		#endif
	}
	else { //surface is facing away
		shadow = 0.0; //guaranteed to be in shadows. reduce light level.
	}
	lm.y = mix(lmcoord.y * SHADOW_BRIGHTNESS, light, shadow * lightDotSqrt);
	float viewPosLength = length(viewPos);
	lm.y = mix(lm.y, mix(SHADOW_BRIGHTNESS * lmcoord.y, light, (clamp(lmcoord.y * 3.0 - 1.95, 0.0, 1.0) * lightDotSqrt) - float(!surfaceFacingLight)), clamp((viewPosLength - shadowRenderDis * (1-SHADOW_FADE_LENGTH)) / (shadowRenderDis - shadowRenderDis * (1-SHADOW_FADE_LENGTH)), 0.0, 1.0));
	float range = (lm.y - SHADOW_BRIGHTNESS * lmcoord.y) / (light - SHADOW_BRIGHTNESS * lmcoord.y);
	sky *= mix(vec3(lmcoord.y * clamp(dot(normalize(shadowLightPosition), normal), 0.5, 1.0)), getCelestialColor() * intensity * tint, max(range, 0.0));
 	
	lm.x /= (1+lm.y*lmcoord.y*2) * intensitysky;
	color.rgb *= intensitysky * sky + BLOCKLIGHT * lm.x;

	float fogAmount = clamp((viewPosLength - fogStart * FOG_START_MULTIPLIER)/(fogEnd - fogStart * FOG_START_MULTIPLIER), 0.0, 1.0);
	color.rgb = mix(color.rgb, sRGB_to_Linear(fogColor), fogAmount * fogAmount);
	color.rgb = Linear_to_sRGB(color.rgb);
	//color.rgb = vec3(lightDot);
	/* DRAWBUFFERS:0 */
	gl_FragData[0] = color; //gcolor
}