#include "/settings.glsl"

#ifdef SHADOW_DISTORT_ENABLED
	vec3 distort(vec3 pos) {
		float factor = length(pos.xy) + SHADOW_DISTORT_FACTOR;
		return vec3(pos.xy / factor, pos.z * 0.5);
	}

	//returns the reciprocal of the derivative of our distort function,
	//multiplied by SHADOW_BIAS.
	//if a texel in the shadow map contains a bigger area,
	//then we need more bias. therefore, we need to know how much
	//bigger or smaller a pixel gets as a result of applying distortion.
	float computeBias(vec3 pos) {
		//square(length(pos.xy) + SHADOW_DISTORT_FACTOR) / SHADOW_DISTORT_FACTOR
		float numerator = length(pos.xy) + SHADOW_DISTORT_FACTOR;
		numerator *= numerator;
		return SHADOW_BIAS / shadowMapResolution * numerator / SHADOW_DISTORT_FACTOR;
	}
#else
	vec3 distort(vec3 pos) {
		return vec3(pos.xy, pos.z * 0.5);
	}

	float computeBias(vec3 pos) {
		return SHADOW_BIAS / shadowMapResolution;
	}
#endif