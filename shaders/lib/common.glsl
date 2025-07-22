#define PI 3.1415926535897932384626433832795
#define BLOCKLIGHT (vec3(0.69, 0.48, 0.32) * 2.5)
#define SUNCOLOR (vec3(0.71, 0.52, 0.35) * 10)
#define MOONCOLOR (vec3(0.64, 0.66, 0.85) * 7)

vec3 getCelestialColor(){
	bool isDay = sunPosition == shadowLightPosition;
	return mix(MOONCOLOR, SUNCOLOR, float(isDay));
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
