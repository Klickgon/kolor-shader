#include "/./settings.glsl"

#if defined TRANSLUCENT_PASS
	#define CTEX1 colortex7
	#define OUTPUT transparentOutColor
#else
	#define CTEX1 colortex0
	#define OUTPUT outColor
#endif

#define LTEX2 colortex1
#define NTEX3 colortex2
#define NMTEX4 colortex3
#define ETEX5 colortex4
#define STEX6 colortex5

#if defined TRANSLUCENT_PASS
 	#define DTEX depthtex0
	#define DTEXDH dhDepthTex0
#else
	#define DTEX depthtex1
	#define DTEXDH dhDepthTex1
#endif

#if DRAW_SHADOW_MAP == 1
	#define DRAWMAP shadowtex0
#elif DRAW_SHADOW_MAP == 2
	#define DRAWMAP shadowtex1
#elif DRAW_SHADOW_MAP == 3
	#define DRAWMAP shadowcolor0
#elif DRAW_SHADOW_MAP == 4
	#define DRAWMAP shadowcolor1
#endif

#ifdef NORMAL_MAPPING
	#define NMAP normalMaps
#else 
	#define NMAP normal
#endif

uniform sampler2D CTEX1;
uniform sampler2D LTEX2;
uniform sampler2D NTEX3;
uniform sampler2D NMTEX4;
uniform sampler2D ETEX5;
uniform sampler2D STEX6;

uniform sampler2D lightmap;
#if !defined NETHER
	uniform sampler2D shadowcolor0;
	uniform sampler2D shadowcolor1;
	uniform sampler2D shadowtex0;
	uniform sampler2D shadowtex1;
#endif
uniform sampler2D texture;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
#if defined DISTANT_HORIZONS
	uniform sampler2D dhDepthTex0;
	uniform sampler2D dhDepthTex1;
#endif

uniform mat4 shadowProjection;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
#if defined DISTANT_HORIZONS
	uniform mat4 dhProjectionInverse;
	uniform mat4 dhProjection;
	uniform mat4 dhPreviousProjection;
#endif

uniform int isEyeInWater;
uniform vec3 skyColor;
uniform float sunAngle;
uniform float shadowAngle;
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
uniform float wetness;
uniform float screenBrightness;

#if defined DISTANT_HORIZONS
	uniform int dhRenderDistance;
	uniform float dhNearPlane;
	uniform float dhFarPlane;
#endif


uniform float near;
uniform float far;

varying vec2 texcoord;

#include "/lib/common.glsl"

vec3 lightingInfo = texture(LTEX2, texcoord).rgb;
vec2 lmcoord = sRGB_to_Linear(lightingInfo).rg;
vec3 normal = normalize((texture(NTEX3, texcoord).rgb - 0.5) * 2.0);
#if SPECULAR_MAPPING != 0
	vec4 specularMaps = texture(STEX6, texcoord);
#endif
float distortFactor = 0.0;
float vertexLightDot = lightingInfo.b * (1.0+(1.0/16.0));
bool lightPassthrough = vertexLightDot > 1.0;
vec3 extraInfo = texture(ETEX5, texcoord).rgb;
float vanillaAO = extraInfo.g;
#if defined DISTANT_HORIZONS
	bool isDH = false;
#else
	const bool isDH = false;
#endif
#ifdef NORMAL_MAPPING
	vec3 normalMaps;
#endif
vec3 normalizedShadowLightPos = shadowLightPosition * 0.01;
#if defined END
	const vec3 celestialColor = vec3(0.5, 0.1, 0.5) * 2.0;
#else
	vec3 celestialColor = getCelestialColor();
#endif

float getNoise(vec2 coord){
  vec2 pixel = coord * vec2(viewWidth, viewHeight);
  return mod(52.9829189 * mod(0.06711056*pixel.x + 0.00583715*pixel.y, 1.0), 1.0);
}

float noise = getNoise(texcoord);
float shadowRenderDis = min(shadowDistance * shadowDistanceRenderMul, far);

#include "/lib/distort.glsl"
#if !defined NETHER
	#include "/lib/shadows.glsl"
#endif
#include "/lib/sky_and_fog_functions.glsl"

/* RENDERTARGETS:0,4,6,7 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 extraInfoBuffer;
layout(location = 2) out vec4 shadowTint;
layout(location = 3) out vec4 transparentOutColor;

void main() {
	vec4 color = texture(CTEX1, texcoord);
	vec4 precolor = color;
	float maskInfo = extraInfo.r;
    #if defined TRANSLUCENT_PASS
		if(maskInfo <= DH_MASK_SOLID || maskInfo == HAND_MASK_SOLID){ // mask
			extraInfoBuffer = vec4(extraInfo, 1.0);
			shadowTint = vec4(1.0);
			OUTPUT = color;
			return;
		}
    #endif

	if(maskInfo == 1.0 ){ // mask || specularMaps.g * 255.0 > 229.0
		extraInfoBuffer = vec4(extraInfo, 1.0);
		shadowTint = vec4(1.0);
		OUTPUT = color;
		return;
	}

	vec3 screenPos;
	#if defined DISTANT_HORIZONS
		isDH = maskInfo == DH_MASK_SOLID || maskInfo == DH_MASK_TRANSLUCENT;
		if(isDH){
			screenPos = vec3(texcoord.xy, texture(DTEXDH, texcoord).r);
		}
		else 
	#endif
	screenPos = vec3(texcoord.xy, sampleDepthWithHandFix(DTEX, texcoord));

	vec3 viewPos;
	#if defined DISTANT_HORIZONS
		if(isDH) viewPos = screenSpace_to_viewSpaceDH(screenPos);
		else
	#endif
	viewPos = screenSpace_to_viewSpace(screenPos);
	
	float viewPosLength = length(viewPos);
	#ifdef NORMAL_MAPPING
		normalMaps = normalize((texture(NMTEX4, texcoord).rgb - 0.5) * 2.0);
	#endif
	screenPos = viewSpace_to_screenSpace(viewPos);

	vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
	vec3 worldPos = feetPlayerPos + cameraPosition;
	lmcoord.x *= lmcoord.x;
	vec2 lm;
	lm.x = lmcoord.x;
	lm.y = max(0.01, lmcoord.y);
	#if defined NETHER || defined END
		lm.y = lm.y * 0.95 + 0.05;
		const float intensity = 1.0;
	#else
		float intensity = getLightIntensity();
	#endif
	float intensitysky = intensity * 0.05 + 1.0;

	vec3 normalizedViewPos = normalize(viewPos);

	#if defined NETHER
	 	vec3 sky = NETHER_SKY_COLOR;
	#elif defined END
		vec3 sky = END_SKY_COLOR;
	#else
		vec3 sky = mix(vec3(0.01), calcSkyColor(normalize((gbufferModelView * vec4(2.0, 1.0, 0.0, 1.0)).xyz)) * 0.35, clamp(intensity * 10.0 - 5.0, 0.3, 1.0));
	#endif

	vertexLightDot = clamp(vertexLightDot, 0.0, 1.0);
	
	float lightDot = lightPassthrough ? 1.0 : dot(normalizedShadowLightPos, NMAP);
	float lightDotSqrt = sqrt(clamp(lightDot, 0.0, 1.0));

	#ifdef HAND_HELD_LIGHTING
		float blockLightValue = heldBlockLightValue * 0.65;
		float hand = float(heldBlockLightValue != 0) * (max((blockLightValue - length(worldPos - eyePosition)) / blockLightValue, 0.0));
		hand *= hand;
		lm.x = mix(lm.x, 1.0, hand * hand);
	#endif
	
	float surfaceDot = dot(normalizedViewPos, normal);
	vec3 shadowScreen;
	#ifdef SCREEN_SPACE_SHADOWS
		#if !defined TRANSLUCENT_PASS && !defined NETHER
			bool sss = vertexLightDot <= 0.0 || lightPassthrough || viewPosLength > 45.0 || !screenSpaceShadow(viewPos, screenPos.z, vertexLightDot, surfaceDot * 0.5 + 0.5);
		#else
			const bool sss = true;
		#endif
	#else
		const bool sss = true;
	#endif
	float shadow;
	vec3 tint = vec3(1.0);
	#if !defined NETHER
		bool surfaceFacingLight = lightDot > 0.0;
		float shadowRange = isDH ? 1.0 : clamp((viewPosLength - shadowRenderDis * (1-SHADOW_FADE_LENGTH)) / (shadowRenderDis - shadowRenderDis * (1-SHADOW_FADE_LENGTH)), 0.0, 1.0);
		if (!isDH && sss && shadowRange < 1.0 && surfaceFacingLight) {
			float shadowViewLength = length((shadowModelView * vec4(feetPlayerPos, 1.0)).xy);
			vec3 shadowClipShadow = viewSpace_to_shadowClipSpace(viewPos + (normal * SHADOW_NORMAL_OFFSET * (1.0+shadowViewLength*0.15))); // Apply normal offset
			float bias = computeBias(shadowClipShadow);

			shadowClipShadow = distort(shadowClipShadow); //apply shadow distortion
			shadowScreen = shadowClipShadow * 0.5 + 0.5;
			
			shadowScreen.z -= max(bias * (1 - vertexLightDot), bias); // Usual Shadow bias for good measure

			#if COLORED_SHADOWS == 1
				vec4 coloredShadow = filteredShadow(shadowScreen, SHADOW_FILTER_BLUR, intensitysky);
				tint = coloredShadow.rgb;
				shadow = coloredShadow.a;
			#else 
				shadow = filteredShadow(shadowScreen, SHADOW_FILTER_BLUR);
			#endif
		}
		else { //surface is facing away
			shadow = float(isDH); //guaranteed to be in shadows.
		}
		shadowTint = vec4(tint, 1.0);
		
		#if defined DISTANT_HORIZONS && defined SCREEN_SPACE_SHADOWS && !defined TRANSLUCENT_PASS
			float outsideShadow =  min(isDH ? float(!screenSpaceShadowDH(viewPos, screenPos.z, vertexLightDot, viewPosLength)) : 1.0, clamp(lmcoord.y * 5.0 - 3.5, 0.0, 1.0));
		#else
			float outsideShadow = clamp(lmcoord.y * 5.0 - 3.5, 0.0, 1.0);
		#endif
		
		shadow = mix(shadow * lightDotSqrt, outsideShadow * float(surfaceFacingLight) * lightDotSqrt, shadowRange);
		float preshadow = shadow;
	#elif
	 	shadow = 0.0;
		shadowTint = vec4(1.0)
	#endif
	float lightFadeOut = clamp((shadowAngle > 0.25 ? abs(shadowAngle - 0.5) : abs(shadowAngle)) * 100.0, 0.0, 1.0);
	lightFadeOut *= lightFadeOut;
	shadow = mix(0.0, shadow, lightFadeOut);
	lightDot = mix(0.0, lightDot, lightFadeOut);
	extraInfoBuffer = vec4(extraInfo.rg, shadow, 1.0);
	
	color.rgb *= mix(pow(vanillaAO, 1.5), vanillaAO, shadow);
	#if !defined NETHER
		lm.y = mix(SHADOW_BRIGHTNESS * lm.y, lm.y, shadow);
		lm.x /= 1.0 + RGBluminance(sky) * lmcoord.y * 16.0;
		sky *= mix(vec3(lm.y), celestialColor * tint, shadow) * clamp(lightDot * 0.1 + 1.0, 0.9, 1.0);
	#endif

	color.rgb *= intensitysky * sky + BLOCKLIGHT * lm.x;

	#if defined DISTANT_HORIZONS
		float fogEnd = isEyeInWater >= 1 ? 60.0 : dhRenderDistance * (1-wetness * 0.65);
	#else
		float fogEnd = isEyeInWater >= 1 ? 60.0 : far * (1-wetness * 0.65);	
	#endif

	float fogStart = isEyeInWater >= 1 ? 20.0 : (fogEnd-10.0) * FOG_START_MULTIPLIER ;

	#if defined DISTANT_HORIZONS
		fogStart *= 0.25 * (1-wetness * 0.97);
	#endif
	#if defined NETHER || defined END
		vec3 borderFog = sky;
	#else 
		vec3 borderFog = pow(calcSkyColor(normalizedViewPos), vec3(2.2));
	#endif
	float borderFogAmount = clamp((viewPosLength - fogStart) / (fogEnd - fogStart), 0.0, 1.0);

	color.rgb = mix(color.rgb, borderFog, borderFogAmount * borderFogAmount);

	#if DRAW_SHADOW_MAP != 0
		color = texture(DRAWMAP, texcoord);
	#endif
	
	OUTPUT = color;
}