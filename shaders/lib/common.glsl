#define PI 3.1415926535897932384626433832795
const float GoldenAngle = PI * (3.0 - sqrt(5.0));
#define BLOCKLIGHT (vec3(1.0, 0.27, 0.05) * 3.0)

#define SUNCOLOR_MORNING (vec3(1.0, 0.591, 0.309) * 20.0)
#define SUNCOLOR_NOON (vec3(1.0, 0.67, 0.408) * 8.0)
#define SUNCOLOR_EVENING (vec3(1.0, 0.337, 0.056) * 12.0)

#define MOONCOLOR_EARLY (vec3(0.901, 0.929, 1.0) * 3.0)
#define MOONCOLOR_MIDNIGHT (vec3(0.822 , 0.871, 1.0) * 3.0)
#define MOONCOLOR_LATE (vec3(0.901, 0.929, 1.0) * 3.0)

#define WATER_COLOR vec4(0.0, 0.44, 0.27, 0.50)
#define WATER_PBR vec4(1.0, 0.89, 1.0, 1.0)

#define MASK_SOLID 0.0
#define DH_MASK_SOLID 1.0/15.0
#define MASK_TRANSLUCENT 2.0/15.0
#define DH_MASK_TRANSLUCENT 3.0/15.0
#define HAND_MASK_SOLID 4.0/15.0
#define HAND_MASK_TRANSLUCENT 5.0/15.0

float getLightIntensity(){
	return sin(sunAngle * PI * 2) * 0.5 + 0.5;
}

mat2 getRotationMat2(float noise){
    float theta = noise * radians(360.0); // random angle using noise value
    float cosTheta = cos(theta);
    float sinTheta = sin(theta);

    return mat2(cosTheta, -sinTheta, sinTheta, cosTheta); 
}

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position){
  vec4 homPos = projectionMatrix * vec4(position, 1.0);
  return homPos.xyz / homPos.w;
}

vec3 getCelestialColor(){
	bool isDay = sunAngle == shadowAngle;
	vec3 color;
	if(isDay){
		float mixer = clamp(sunAngle * 20.0, 0.0, 1.0);
		color = mix(SUNCOLOR_MORNING, SUNCOLOR_NOON, mixer);
		mixer = clamp((sunAngle - 0.45) * 8.5, 0.0, 1.0);
		color = mix(color, SUNCOLOR_EVENING, mixer);
	}
	else {
		float mixer = clamp((sunAngle - 0.5) * 25.0, 0.0, 1.0);
		color = mix(MOONCOLOR_EARLY, MOONCOLOR_MIDNIGHT, mixer);
		mixer = clamp((sunAngle - 0.95) * 20.0, 0.0, 1.0);
		color = mix(color, MOONCOLOR_LATE, mixer);
	}
	return color;
}

float RGBluminance(vec3 color){
 return (0.299*color.r + 0.587*color.g + 0.114*color.b);
}

float fixHandDepth(float screenDepth) {
	return ((screenDepth * 2.0 - 1.0) / MC_HAND_DEPTH) * 0.5 + 0.5;
}

float sampleDepthWithHandFix(sampler2D dtex, vec2 coord){
	float mask = texture(ETEX5, coord).r;
	bool isHand = mask == HAND_MASK_SOLID || mask == HAND_MASK_TRANSLUCENT;
	float depth = texture(dtex, coord).r;
	return isHand ? fixHandDepth(depth) : depth;
}

float sampleDepthWithHandFixLOD(sampler2D dtex, vec2 coord, float lod){
	float mask = texture(ETEX5, coord).r;
	bool isHand = mask == HAND_MASK_SOLID || mask == HAND_MASK_TRANSLUCENT;
	float depth = textureLod(dtex, coord, lod).r;
	return isHand ? fixHandDepth(depth) : depth;
}

float linearizeDepth(float depth) {
	float farPlane = far * 4.0;
    return (near * farPlane) / (depth * (near - farPlane) + farPlane);
}

#if defined DISTANT_HORIZONS
	float linearizeDepthDH(float depth) {
		return (dhNearPlane * dhFarPlane) / (depth * (dhNearPlane - dhFarPlane) + dhFarPlane);
	}
#endif

vec3 sRGB_to_Linear(vec3 color){
	return pow(color, vec3(2.2));
}

vec3 Linear_to_sRGB(vec3 color){
	return pow(color, vec3(1.0/2.2));
}

vec3 screenSpace_to_viewSpace(vec3 screenPos){
	return projectAndDivide(gbufferProjectionInverse, screenPos * 2.0 - 1.0);
}

float grayScale(vec3 color){
    return (color.r + color.g + color.b) / 3.0;
}

vec3 viewSpace_to_screenSpace(vec3 viewPos){
	return projectAndDivide(gbufferProjection, viewPos) * 0.5 + 0.5;
}

#if defined DISTANT_HORIZONS
	vec3 screenSpace_to_viewSpaceDH(vec3 screenPos){
		return projectAndDivide(dhProjectionInverse, screenPos * 2.0 - 1.0);
	}
#endif

vec3 viewSpace_to_shadowClipSpace(vec3 viewPos){
	vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
	vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
	vec3 shadowClipPos = (shadowProjection * vec4(shadowViewPos, 1.0)).xyz;
	return shadowClipPos;
}


