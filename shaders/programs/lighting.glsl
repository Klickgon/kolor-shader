#include "/settings.glsl"

/*
const int colortex4Format = RGB16;
*/

#define CTEX1 colortex0
#define LTEX2 colortex1
#define NTEX3 colortex2
#define ETEX4 colortex3
#define NMTEX5 colortex4

#if defined TRANSLUCENT_PASS
 	#define DTEX depthtex0
#else
	#define DTEX depthtex1
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
uniform sampler2D ETEX4;
uniform sampler2D NMTEX5;

uniform sampler2D lightmap;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;
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
uniform float near;
uniform float far;

varying vec2 texcoord;

#include "/lib/common.glsl"

vec2 lmcoord = sRGB_to_Linear(texture(LTEX2, texcoord).xyz).rg;
vec3 normal = normalize((texture(NTEX3, texcoord).rgb - 0.5) * 2.0);
#ifdef NORMAL_MAPPING
	vec3 normalMaps = normalize((texture(NMTEX5, texcoord).rgb - 0.5) * 2.0);
#endif
float distortFactor = 0.0;
float vertexLightDot = texture(LTEX2, texcoord).z * (1.0+(1.0/16.0));
bool lightPassthrough = vertexLightDot > 1.0;
float vanillaAO = texture(ETEX4, texcoord).g;


vec4 getNoise(vec2 coord){
  ivec2 noiseCoord = ivec2(coord * vec2(viewWidth, viewHeight)) % noiseTextureResolution; 
  return texelFetch(noisetex, noiseCoord, 0);
}

vec4 noise = getNoise(texcoord);
const float shadowRenderDis = (shadowDistance * shadowDistanceRenderMul);

#include "/lib/distort.glsl"
#include "/lib/shadows.glsl"

void main() {
	vec4 color = texture2D(CTEX1, texcoord);
    #if defined TRANSLUCENT_PASS
		if(texture(ETEX4, texcoord).r < 0.5){ // mask
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
	
	vec3 NDCPos = screenPos * 2.0 - 1.0;
	vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);
	vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
	
	vec3 worldPos = feetPlayerPos + cameraPosition;

	float intensity = getLightIntensity(sunAngle);
	float intensitysky = (0.25 * intensity) + 0.5;
	vec3 sky = mix(skyColor, vec3(0.02), intensity - 0.5);
	vertexLightDot = clamp(vertexLightDot, 0.0, 1.0);
	
	float lightDot = clamp(dot(normalize(shadowLightPosition), NMAP), 0.0, 1.0);
	float lightDotSqrt = lightPassthrough ? 1.0 : sqrt(lightDot);
	float light = mix(31.0 / 32.0 * SHADOW_BRIGHTNESS, 31.0 / 32.0, lightDotSqrt);

	vec3 tint = vec3(1.0);
	#ifdef HAND_HELD_LIGHTING
		float blockLightValue = heldBlockLightValue * 0.65;
		float hand = float(heldBlockLightValue != 0) * (max((blockLightValue - length(worldPos - eyePosition)) / blockLightValue, 0.0));
		hand *= hand;
		lm.x = mix(lm.x, 1.0, hand * hand);
	#endif

	vec3 shadowScreen;
	#ifdef SCREEN_SPACE_SHADOWS
		#if !defined TRANSLUCENT_PASS
			bool sss = screenSpaceShadow(viewPos, screenPos.z, vertexLightDot);
		#else
			const bool sss = false;
		#endif
	#else
		const bool sss = false;
	#endif
	float shadow;
	float viewPosLength = length(viewPos);
	bool surfaceFacingLight = vertexLightDot > 0.0;
	float shadowRange = clamp((viewPosLength - shadowRenderDis * (1-SHADOW_FADE_LENGTH)) / (shadowRenderDis - shadowRenderDis * (1-SHADOW_FADE_LENGTH)), 0.0, 1.0);

	if (shadowRange < 1.0 && surfaceFacingLight && (lightPassthrough || !sss)) {
		float shadowViewLength = length((shadowModelView * vec4(feetPlayerPos, 1.0)).xy);
		vec3 shadowClipShadow = viewSpace_to_shadowClipSpace(viewPos + (normal * SHADOW_NORMAL_OFFSET * (1.0+shadowViewLength*0.15)));
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
		shadow = 0.0; //guaranteed to be in shadows.
	}

	shadow = mix(shadow * lightDotSqrt, (clamp(lmcoord.y * 5.0 - 3.5, 0.0, 1.0) * float(surfaceFacingLight)) * lightDotSqrt, shadowRange);

	float lightFadeOut = clamp((shadowAngle > 0.25 ? abs(shadowAngle - 0.5) : abs(shadowAngle)) * 100.0, 0.0, 1.0);
	lightFadeOut *= lightFadeOut;
	shadow = mix(0.0, shadow, lightFadeOut);
	lightDot = mix(0.0, lightDot, lightFadeOut);

	lm.y = mix(lmcoord.y * SHADOW_BRIGHTNESS, light, shadow);

	sky *= mix(vec3(lm.y * clamp(lightDot * 0.5 + 0.5, 0.5, 1.0)), getCelestialColor() * intensity * tint, shadow);
 	
	lm.x /= max((1+lm.y*lmcoord.y*2) * intensitysky, 0.0001);
	color.rgb *= intensitysky * sky + BLOCKLIGHT * lm.x;

	float fogAmount = clamp((viewPosLength - (far-10.0) * FOG_START_MULTIPLIER) / max(far - (far-10.0) * FOG_START_MULTIPLIER, 0.001), 0.0, 1.0);
	color.rgb = mix(color.rgb, sRGB_to_Linear(fogColor), fogAmount * fogAmount);
	color.rgb = Linear_to_sRGB(color.rgb);
	#if DRAW_SHADOW_MAP != 0
		color = texture(DRAWMAP, texcoord);
	#endif
	/* DRAWBUFFERS:0 */
	gl_FragData[0] = color; 
}