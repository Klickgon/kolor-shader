#version 120

uniform sampler2D texture;
uniform float sunAngle;
uniform float shadowAngle;

varying vec2 texcoord;
varying vec4 glcolor;

#define SUNCOLOR_MORNING vec3(1.0, 0.591, 0.309)
#define SUNCOLOR_NOON vec3(1.0, 0.67, 0.408)
#define SUNCOLOR_EVENING vec3(1.0, 0.337, 0.056)

#define MOONCOLOR_EARLY vec3(0.901, 0.929, 1.0)
#define MOONCOLOR_MIDNIGHT vec3(0.822 , 0.871, 1.0)
#define MOONCOLOR_LATE vec3(0.901, 0.929, 1.0)

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

void main() {
	vec4 color = texture2D(texture, texcoord) * glcolor;
	color.rgb *= getCelestialColor();
/* DRAWBUFFERS:0 */
	gl_FragData[0] = color; //gcolor
}