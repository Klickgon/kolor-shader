#define FOG_SUNCOLOR_MORNING (vec3(1.0, 0.591, 0.309))
#define FOG_SUNCOLOR_NOON (vec3(1.0, 0.67, 0.408))
#define FOG_SUNCOLOR_EVENING (vec3(1.0, 0.037, 0.89))

#define FOG_MOONCOLOR_EARLY (vec3(0.901, 0.929, 1.0) * 0.3)
#define FOG_MOONCOLOR_MIDNIGHT (vec3(0.822 , 0.871, 1.0) * 0.1)
#define FOG_MOONCOLOR_LATE (vec3(0.901, 0.929, 1.0) * 0.1)

#define WATER_FOG_COLOR vec3(0.0, 0.44, 0.27)
#define DAY_FOG_COLOR vec3(0.9)
#define NIGHT_FOG_COLOR vec3(0.01)

#define END_SKY_COLOR vec3(0.3, 0.05, 0.3)
#define NETHER_SKY_COLOR vec3(0.075, 0.01, 0.01)

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
	color = mix(color, FOG_MOONCOLOR_EARLY, clamp(((worldTime % 24000) - 12200) * 0.002, 0.0, 1.0));
	return mix(color, FOG_SUNCOLOR_MORNING, clamp(((worldTime % 24000) - 22500) * 0.001, 0.0, 1.0));
}

vec3 getFogColor(vec3 viewPos){
	vec3 normalFogColor = sunAngle == shadowAngle ? DAY_FOG_COLOR : NIGHT_FOG_COLOR;
	float shadowDot = clamp(exp(dot(shadowLightPosition * 0.01, gbufferModelView[1].xyz)) - 1.2, 0.0, 1.0);
	return mix(getCelestialFogColor(), normalFogColor, shadowDot);
}

float fogify(float x, float w) {
	return w / (x * x + w);
}

vec3 calcSkyColor(vec3 pos) {
	float upDot = dot(pos, gbufferModelView[1].xyz);
	return mix(pow(skyColor, vec3(2.2)), isEyeInWater == 1 ? WATER_FOG_COLOR : getFogColor(pos), fogify(max(upDot, 0.0), 0.25));
}