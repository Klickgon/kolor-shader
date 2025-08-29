#include "/settings.glsl"

/*
const int colortex2Format = RGB16;
const int colortex3Format = RGB16;
const bool colortex3MipmapEnabled = true;
*/

#define CTEX1 colortex0
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
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D texture;
uniform sampler2D noisetex;
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

#if defined DISTANT_HORIZONS
	uniform int dhRenderDistance;
	uniform float dhNearPlane;
	uniform float dhFarPlane;
#endif


uniform float near;
uniform float far;

varying vec2 texcoord;

#include "/lib/common.glsl"

vec2 lmcoord = sRGB_to_Linear(texture(LTEX2, texcoord).xyz).rg;
vec3 normal = normalize((texture(NTEX3, texcoord).rgb - 0.5) * 2.0);
#if SPECULAR_MAPPING != 0
	vec4 specularMaps = texture(STEX6, texcoord);
#endif
float distortFactor = 0.0;
float vertexLightDot = texture(LTEX2, texcoord).z * (1.0+(1.0/16.0));
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
vec3 celestialColor = getCelestialColor();


vec4 getNoise(vec2 coord){
  ivec2 noiseCoord = ivec2(coord * vec2(viewWidth, viewHeight)) % noiseTextureResolution; 
  return texelFetch(noisetex, noiseCoord, 0);
}

vec4 noise = getNoise(texcoord);
const float shadowRenderDis = (shadowDistance * shadowDistanceRenderMul);

#include "/lib/distort.glsl"
#include "/lib/shadows.glsl"
#include "/lib/reflections.glsl"

void main() {
	vec4 color = texture2D(CTEX1, texcoord);
	vec4 precolor = color;
	float maskInfo = extraInfo.r;
    #if defined TRANSLUCENT_PASS
		if(maskInfo <= 1.0/15.0){ // mask
			gl_FragData[0] = color;
			return;
		}
    #endif

	vec3 screenPos;
	#if defined DISTANT_HORIZONS
		isDH = maskInfo == 1.0/15.0 || maskInfo == 3.0/15.0;
		
		if(isDH){
			screenPos = vec3(texcoord.xy, texture(DTEXDH, texcoord).r);
		}
		else 
	#endif
	screenPos = vec3(texcoord.xy, texture(DTEX, texcoord).r);
	

	vec3 viewPos;
	#if defined DISTANT_HORIZONS
		
		if(isDH) viewPos = screenSpace_to_viewSpaceDH(screenPos);
		else
	#endif

	viewPos = screenSpace_to_viewSpace(screenPos);
	float viewPosLength = length(viewPos);
	normalMaps = isDH ? normal : normalize((textureLod(NMTEX4, texcoord, screenPos.z * 0.1).rgb - 0.5) * 2.0);
	screenPos = viewSpace_to_screenSpace(viewPos);

	if(maskInfo == 1.0){
		gl_FragData[0] = color;
		return;
	}

	vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
	vec3 worldPos = feetPlayerPos + cameraPosition;

	vec2 lm = lmcoord;
	color.rgb = sRGB_to_Linear(color.rgb);

	vec3 normalizedViewPos = normalize(viewPos);
	float intensity = getLightIntensity(sunAngle);
	float intensitysky = (0.25 * intensity) + 0.5;
	vec3 sky = mix(skyColor, vec3(0.02), intensity - 0.5);
	vertexLightDot = clamp(vertexLightDot, 0.0, 1.0);
	
	float lightDot = lightPassthrough ? 1.0 : dot(normalizedShadowLightPos, isDH ? normal : NMAP);
	float lightDotSqrt = sqrt(clamp(lightDot, 0.0, 1.0));
	float light = mix(31.0 / 32.0 * SHADOW_BRIGHTNESS, 31.0 / 32.0, lightDotSqrt);

	vec3 tint = vec3(1.0);
	#ifdef HAND_HELD_LIGHTING
		float blockLightValue = heldBlockLightValue * 0.65;
		float hand = float(heldBlockLightValue != 0) * (max((blockLightValue - length(worldPos - eyePosition)) / blockLightValue, 0.0));
		hand *= hand;
		lm.x = mix(lm.x, 1.0, hand * hand);
	#endif

	float surfaceDot = dot(normalizedViewPos, normal);
	vec3 shadowScreen;
	#ifdef SCREEN_SPACE_SHADOWS
		#if !defined TRANSLUCENT_PASS
			bool sss = vertexLightDot <= 0.0 || lightPassthrough || !screenSpaceShadow(viewPos, screenPos.z, vertexLightDot, surfaceDot * 0.5 + 0.5);
		#else
			const bool sss = true;
		#endif
	#else
		const bool sss = true;
	#endif
	float shadow;
	
	bool surfaceFacingLight = lightDot > 0.0;
	float shadowRange = clamp((viewPosLength - shadowRenderDis * (1-SHADOW_FADE_LENGTH)) / (shadowRenderDis - shadowRenderDis * (1-SHADOW_FADE_LENGTH)), 0.0, 1.0);

	if (sss && shadowRange < 1.0 && surfaceFacingLight) {
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
		shadow = 0.0; //guaranteed to be in shadows.
	}
	#if defined DISTANT_HORIZONS && defined SCREEN_SPACE_SHADOWS && !defined TRANSLUCENT_PASS
		float outsideShadow = isDH ? min(float(!screenSpaceShadowDH(viewPos, screenPos.z, vertexLightDot, viewPosLength)), clamp(lmcoord.y * 5.0 - 0.5, 0.0, 1.0)) : clamp(lmcoord.y * 5.0 - 3.5, 0.0, 1.0);
	#else
		float outsideShadow = clamp(lmcoord.y * 5.0 - 3.5, 0.0, 1.0);
	#endif

	shadow = mix(shadow * lightDotSqrt, (outsideShadow * float(surfaceFacingLight)) * lightDotSqrt, shadowRange);

	float lightFadeOut = clamp((shadowAngle > 0.25 ? abs(shadowAngle - 0.5) : abs(shadowAngle)) * 100.0, 0.0, 1.0);
	lightFadeOut *= lightFadeOut;
	shadow = mix(0.0, shadow, lightFadeOut);
	lightDot = mix(0.0, lightDot, lightFadeOut);

	
	color.rgb *= mix(pow(vanillaAO, 1.5), vanillaAO, shadow);
	lm.y = mix(lmcoord.y * SHADOW_BRIGHTNESS, light, shadow);

	sky *= mix(vec3(lm.y * clamp(lightDot * 0.1 + 2.0, 0.9, 1.1)), celestialColor * intensity * tint, shadow);
 	
	lm.x /= max((1+lmcoord.y*lmcoord.y*2) * intensitysky, 0.0001);
	
	
	
	color.rgb *= intensitysky * sky + BLOCKLIGHT * lm.x;
	#if SPECULAR_MAPPING != 0
		vec3 skyReflection = vec3(0.05);
		if(cameraPosition.y > 45.0){
			vec3 reflectionVec = reflect(normalizedViewPos, NMAP);
			skyReflection = mix(skyReflection, sRGB_to_Linear(calcSkyColor(reflectionVec)), clamp((cameraPosition.y - 45.0) * 0.1 * lmcoord.y, 0.0, 1.0));
		}
		float roughness = pow(1 - specularMaps.r, 2.0);
		float metallic = float(specularMaps.g * 255.0 > 229.0);
		float f0 = specularMaps.g * (0.2+0.8*metallic);
		if(metallic > 0.5) skyReflection *= pow(color.rgb, vec3(0.57));
		float smoothness = (1-roughness);
		float fresnel = pow(clamp(1.0+surfaceDot, 0.0, 1.0), 10.0) * smoothness;
		float reflectStrength = f0+(1.0-f0)*fresnel*smoothness;
		color.rgb = mix(color.rgb, skyReflection, reflectStrength * reflectStrength * RGBluminance(skyReflection));

		if(shadow > 0.0) {
			#if SPECULAR_LIGHT_QUALITY == 1
				float specularHighlight = getSpecularHighlight(normalizedViewPos, lightDot, roughness);
				color.rgb += specularHighlight * celestialColor * tint * shadow * intensity;
			#else	
				vec3 reflectance = metallic == 1.0 ? color.rgb : vec3(specularMaps.g);
				color.rgb += max(brdf(normalizedShadowLightPos, -normalizedViewPos, 1-smoothness*0.9, NMAP, color.rgb, metallic, reflectance) * celestialColor * intensity * tint * shadow * 0.1, 0.0);
			#endif
		}
	#endif

	#if defined DISTANT_HORIZONS
		float fogEnd = dhRenderDistance;
	#else
		float fogEnd = far;	
	#endif

	float fogStart = (fogEnd-10.0) * FOG_START_MULTIPLIER;

	float fogAmount = clamp((viewPosLength - fogStart) / (fogEnd - fogStart), 0.0, 1.0);

	color.rgb = mix(color.rgb, sRGB_to_Linear(fogColor), fogAmount * fogAmount);
	//color.rgb = vec3(specularMaps.r);
	color.rgb = Linear_to_sRGB(color.rgb);
	#if DRAW_SHADOW_MAP != 0
		color = texture(DRAWMAP, texcoord);
	#endif
	/* DRAWBUFFERS:0 */
	gl_FragData[0] = color; 
}