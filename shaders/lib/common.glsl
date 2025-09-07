#define PI 3.1415926535897932384626433832795
#define BLOCKLIGHT (vec3(0.66, 0.34, 0.15) * 3.0)

#define SUNCOLOR_MORNING (vec3(0.71, 0.42, 0.22) * 13)
#define SUNCOLOR_NOON (vec3(0.71, 0.49, 0.29) * 9)
#define SUNCOLOR_EVENING (vec3(0.89, 0.30, 0.05) * 25)

#define MOONCOLOR_EARLY (vec3(0.64, 0.66, 0.71))
#define MOONCOLOR_MIDNIGHT (vec3(0.51, 0.54, 0.62) * 19)
#define MOONCOLOR_LATE (vec3(0.64, 0.66, 0.71) * 3)

float getLightIntensity(float x){
	return 0.10 * sin(x * PI) + 1.0;
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


