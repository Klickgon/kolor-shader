#define PI 3.1415926535897932384626433832795
#define BLOCKLIGHT (vec3(0.69, 0.48, 0.32) * 3.0)

#define SUNCOLOR_MORNING (vec3(0.71, 0.42, 0.22) * 10)
#define SUNCOLOR_NOON (vec3(0.71, 0.52, 0.35) * 10)
#define SUNCOLOR_EVENING (vec3(0.89, 0.30, 0.05) * 15)

#define MOONCOLOR_EARLY (vec3(0.64, 0.66, 0.85) * 3)
#define MOONCOLOR_MIDNIGHT (vec3(0.64, 0.66, 0.85) * 10)
#define MOONCOLOR_LATE (vec3(0.64, 0.66, 0.85) * 3)

vec3 getCelestialColor(){
	bool isDay = sunAngle == shadowAngle;
	vec3 color;
	if(isDay){
		float mixer = clamp(sunAngle * 25.0, 0.0, 1.0);
		color = mix(SUNCOLOR_MORNING, SUNCOLOR_NOON, mixer);
		mixer = clamp((sunAngle - 0.45) * 7.5, 0.0, 1.0);
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

float linearizeDepth(float depth) {
    return (near * far * 4.0) / (depth * (near - far * 4.0) + far * 4.0);
}

vec3 sRGB_to_Linear(vec3 color){
	return pow(color, vec3(2.2));
}

vec3 Linear_to_sRGB(vec3 color){
	return pow(color, vec3(1.0/2.2));
}

vec3 viewSpace_to_shadowClipSpace(vec3 viewPos){
	vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
	vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
	vec3 shadowClipPos = (shadowProjection * vec4(shadowViewPos, 1.0)).xyz;
	return shadowClipPos;
}
