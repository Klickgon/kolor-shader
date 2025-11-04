#include "/./settings.glsl"
#define REFLECTIONS
#if defined TRANSLUCENT_PASS
	#define CTEX1 colortex7
	uniform sampler2D colortex0;
#else
	#define CTEX1 colortex0
#endif
#define LTEX2 colortex1
#define NTEX3 colortex2
#define NMTEX4 colortex3
#define ETEX5 colortex4
#define STEX6 colortex5
#define STTEX7 colortex6

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
uniform sampler2D STTEX7;

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

#include "/lib/sky_and_fog_functions.glsl"
#include "/lib/reflect_functions.glsl"

void main() {
	vec4 color = texture(CTEX1, texcoord);
	vec4 precolor = color;
	float maskInfo = extraInfo.r;
    #if defined TRANSLUCENT_PASS
		if(maskInfo <= DH_MASK_SOLID || maskInfo == HAND_MASK_SOLID){ // mask
			discard;
		}
    #endif

	if(maskInfo == 1.0){ // mask
		discard;
	}

	vec3 screenPos;
	#if defined DISTANT_HORIZONS
		isDH = maskInfo == DH_MASK_SOLID || maskInfo == 3.0/15.0;
		
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
    
    vec3 normalizedViewPos = normalize(viewPos);
    float surfaceDot = dot(normalizedViewPos, normal);
    float shadow = extraInfo.b;
    vec3 tint = texture(STTEX7, texcoord).rgb;
	float roughness = pow(1 - specularMaps.r, 2.0);
	
	if(specularMaps.g > 0.0 || roughness < 1.0) {
		vec3 reflectionVec = reflect(normalizedViewPos, NMAP);

		#if defined END
			const vec3 skyColor = END_SKY_COLOR;
			vec3 reflectionColor = skyColor;
		#elif defined NETHER
			const vec3 skyColor = NETHER_SKY_COLOR;
			vec3 reflectionColor = skyColor;
		#else
			vec3 skyColor = sRGB_to_Linear(calcSkyColor(reflectionVec));
			vec3 reflectionColor = skyColor * clamp((cameraPosition.y - 45.0) * 0.1 * lmcoord.y, 0.0, 1.0);
		#endif

		float metallic = float(specularMaps.g * 255.0 > 229.0);
		float f0 = specularMaps.g * (0.2+0.8*metallic);
		float smoothness = (1-roughness);
		float fresnel = pow(clamp(1.0+surfaceDot, 0.0, 1.0), 5.0) * smoothness;
		float reflectStrength = clamp(f0+(1.0-f0) * fresnel * smoothness, 0.0, 1.0);
		reflectStrength *= reflectStrength;
		#ifdef SCREEN_SPACE_REFLECTIONS
			bool ssr = reflectStrength > 0.001 + RGBluminance(color.rgb) * 0.09 && roughness < 0.95;
			if(ssr) reflectionColor = screenSpaceReflections(reflectionColor, skyColor, viewPos, reflectionVec, 1-smoothness *0.95, NMAP, metallic == 1.0 ? color.rgb : vec3(specularMaps.g), isDH);
			
		#endif
		if(metallic > 0.5){
			reflectionColor *= pow(color.rgb, vec3(2.0));
			reflectStrength *= 0.5;
		}
		else reflectStrength *= pow(RGBluminance(reflectionColor), 1.0/3.0);
		color.rgb = mix(color.rgb, reflectionColor, clamp(reflectStrength, 0.0, 1.0));

		if(shadow > 0.0) {
			#if SPECULAR_LIGHT_QUALITY == 1
				float lightDot = lightPassthrough ? 1.0 : dot(normalizedShadowLightPos, NMAP);
				color.rgb += getSpecularHighlight(normalizedViewPos, lightDot, roughness) * celestialColor * tint * shadow  * (1.0 - 0.9*float(sunAngle != shadowAngle));
			#else	
				vec3 reflectance = metallic == 1.0 ? color.rgb : vec3(specularMaps.g);
				color.rgb += max(brdf(normalizedShadowLightPos, -normalizedViewPos, 1-smoothness *0.95, NMAP, color.rgb, metallic, reflectance) * celestialColor * tint * shadow * (0.2 - 0.1*float(sunAngle != shadowAngle)), 0.0);
			#endif
		}
		//color.rgb = vec3(ssr);
	}
	gl_FragData[0] = color; 
}