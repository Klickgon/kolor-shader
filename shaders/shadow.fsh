#version 120

#include "/settings.glsl"

uniform sampler2D lightmap;
uniform sampler2D texture;
uniform mat4 shadowModelView;

uniform float frameTimeCounter;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying float distortFactor;
flat varying float blockEntity;
varying vec3 worldPos;

#if defined SHADER_WATER && COLORED_SHADOWS == 1
	#define WATER_COLOR vec4(0.0, 0.65, 0.76, 0.9)

    #include "/lib/noise.glsl"

    vec3 getWaveNormal(vec3 worldPos){
        float wave1 = frameTimeCounter * 0.2;
        const float wno = 0.01;
        float h1 = fractalNoise(worldPos.xz * 0.7 + wave1, 1.34,  0.74);
        float h2 = fractalNoise(worldPos.xz * 0.7 + wave1 + vec2(wno, 0.0), 1.34, 0.74);
        float h3 = fractalNoise(worldPos.xz * 0.7 + wave1 + vec2(0.0, wno), 1.34,  0.74);

        return vec3(h2-h1, h3-h1, 1.0) * 0.5 + 0.5;
    }
#endif

void main() {
	vec4 color;
	#if defined SHADER_WATER && COLORED_SHADOWS == 1
	if(blockEntity == 2.0){
		vec3 normal = normalize(getWaveNormal(worldPos));
		float causticStrength = clamp((1.0-clamp(dot(normal, vec3(0.0, 1.0, 0.0)), 0.0, 1.0)) * 20.0 - 11.0, 0.0, 1.0);
		causticStrength = pow(causticStrength, 8.0) + 0.1;
		color = WATER_COLOR;
		color.rgb = mix(pow(color.rgb, vec3(2.2)), pow(glcolor.rgb, vec3(2.2)), 0.2);
		color.rgb *= causticStrength;
		//color.rgb = vec3(causticStrength);
		color.rgb = pow(color.rgb, vec3(1.0/2.2));
	} else {
	#endif
	color = texture(texture, texcoord);
	color.rgb = pow(pow(color.rgb, vec3(2.2)) * pow(glcolor.rgb, vec3(2.2)), vec3(1.0/2.2));
	#ifdef SHADER_WATER
		}
	#endif
	gl_FragData[0] = color;
}