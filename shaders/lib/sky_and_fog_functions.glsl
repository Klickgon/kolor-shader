#define FOG_SUNCOLOR_MORNING (vec3(1.0, 0.591, 0.309))
#define FOG_SUNCOLOR_NOON (vec3(1.0, 0.67, 0.408))
#define FOG_SUNCOLOR_EVENING (vec3(1.0, 0.337, 0.056))

#define FOG_MOONCOLOR_EARLY (vec3(0.901, 0.929, 1.0) * 0.5)
#define FOG_MOONCOLOR_MIDNIGHT (vec3(0.822 , 0.871, 1.0) * 0.2)
#define FOG_MOONCOLOR_LATE (vec3(0.901, 0.929, 1.0) * 0.2)

#define WATER_FOG_COLOR vec3(0.0, 0.32, 0.21)
#define DAY_FOG_COLOR vec3(0.9)
#define NIGHT_FOG_COLOR vec3(0.01)

vec3 getCelestialFogColor(){
	vec3 color;
	if(sunAngle == shadowAngle){
		float mixer = clamp(sunAngle * 20.0, 0.0, 1.0);
		color = mix(FOG_SUNCOLOR_MORNING, FOG_SUNCOLOR_NOON, mixer);
		mixer = clamp((sunAngle - 0.45) * 8.5, 0.0, 1.0);
		color = mix(color, FOG_SUNCOLOR_EVENING, mixer);
	} else {
		float mixer = clamp((sunAngle - 0.5) * 25.0, 0.0, 1.0);
		color = mix(FOG_MOONCOLOR_EARLY, FOG_MOONCOLOR_MIDNIGHT, mixer);
		mixer = clamp((sunAngle - 0.95) * 20.0, 0.0, 1.0);
		color = mix(color, FOG_MOONCOLOR_LATE, mixer);
	}
	color = mix(color, FOG_MOONCOLOR_EARLY, clamp(((worldTime % 24000) - 12500) * 0.005, 0.0, 1.0));
	return mix(color, FOG_SUNCOLOR_MORNING, clamp(((worldTime % 24000) - 22500) * 0.001, 0.0, 1.0));
}

vec3 getFogColor(vec3 viewPos){
	vec3 normalFogColor = sunAngle == shadowAngle ? DAY_FOG_COLOR : NIGHT_FOG_COLOR;
	float shadowDot = clamp(exp(dot(shadowLightPosition * 0.01, gbufferModelView[1].xyz)) - 1.0, 0.0, 1.0);
	return mix(getCelestialFogColor(), normalFogColor, shadowDot);
}

float fogify(float x, float w) {
	return w / (x * x + w);
}

vec3 calcSkyColor(vec3 pos) {
	float upDot = dot(pos, gbufferModelView[1].xyz);
	return mix(skyColor, isEyeInWater == 1 ? pow(WATER_FOG_COLOR, vec3(1.0/2.2)) : getFogColor(pos), fogify(max(upDot, 0.0), 0.25));
}