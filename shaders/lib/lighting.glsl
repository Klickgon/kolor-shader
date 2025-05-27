#if SHADOW_FILTER_QUALITY == 0
    #define SAMPLING_PATTERN vec2[](vec2(0.0))
    #define SAMPLING_PATTERN_LENGTH 1
#endif
#if SHADOW_FILTER_QUALITY == 1
    #define SAMPLING_PATTERN vec2[](vec2(0.0), vec2(1.0, 1.0), vec2(-1.0, -1.0), vec2(1.0, -1.0), vec2(-1.0, 1.0))
    #define SAMPLING_PATTERN_LENGTH 5
#endif
#if SHADOW_FILTER_QUALITY == 2
    #define SAMPLING_PATTERN vec2[](vec2(0.0), vec2(1.0, 1.0), vec2(-1.0, -1.0), vec2(1.0, -1.0), vec2(-1.0, 1.0), vec2(-1.15, 0.0), vec2(1.15, 0.0), vec2(0.0, -1.15), vec2(0.0, 1.15))
    #define SAMPLING_PATTERN_LENGTH 9
#endif
#if SHADOW_FILTER_QUALITY == 3
    #define SAMPLING_PATTERN vec2[](vec2(0.0), vec2(1.0, 1.0), vec2(-1.0, -1.0), vec2(1.0, -1.0), vec2(-1.0, 1.0), vec2(-1.15, 0.0), vec2(1.15, 0.0), vec2(0.0, -1.15), vec2(0.0, 1.15), vec2(0.35, 0.85), vec2(-0.35, -0.85), vec2(0.85, -0.35), vec2(-0.85, 0.35))
    #define SAMPLING_PATTERN_LENGTH 13
#endif
#if SHADOW_FILTER_QUALITY == 4
    #define SAMPLING_PATTERN vec2[](vec2(0.0), vec2(1.0, 1.0), vec2(1.0, -1.0), vec2(-1.0, -1.0), vec2(-1.0, 1.0), vec2(-1.15, 0.0), vec2(1.15, 0.0), vec2(0.0, -1.15), vec2(0.0, 1.15), vec2(0.35, 0.85), vec2(-0.35, -0.85), vec2(0.85, -0.35), vec2(-0.85, 0.35), vec2(-0.15, 1.05), vec2(0.15, -1.05), vec2(-1.05, -0.15), vec2(1.05, 0.15))
    #define SAMPLING_PATTERN_LENGTH 17
#endif

vec3 getCelestialColor(){
	bool isDay = sunPosition == shadowLightPosition;
	return float(isDay) * SUNCOLOR + float(!isDay) * MOONCOLOR;
}

float getLightIntensity(float x){
	return 0.2 * sin(x * PI) + 1.0;
}

vec4 getNoise(vec2 coord){
  ivec2 noiseCoord = ivec2(coord * vec2(viewWidth, viewHeight)) % noiseTextureResolution; // wrap to range of noiseTextureResolution
  return texelFetch(noisetex, noiseCoord, 0);
}

#ifdef PENUMBRA_SHADOWS

    float calculatePenumbra(sampler2D stex, vec4 shadowPos){
        float blockerDepth = 0.0;
        float blockerCount = 0.0;
        float spacing[7] = float[](10.0, 5.0, 3.0, 3.0, 5.0, 10.0, 100.0);
        int i = 0;
        for(float x = -18.0; x <= 18.0; x += spacing[i++]){
            int j = 0;
            for(float y = -18.0; y <= 18.0; y += spacing[j++]){
                vec2 samplePos = shadowPos.xy + vec2(x, y) / shadowMapResolution;
                float tex1 = texture(stex, samplePos).r;
                if(tex1 < shadowPos.z){
                    blockerDepth += tex1;
                    blockerCount += 1.0;
                }
            }
        }
        if(blockerCount <= 0.0) return 0.0;
        blockerDepth /= blockerCount;
        if(blockerDepth <= 0.0) return 0.0;
        return clamp(((shadowPos.z - blockerDepth) * 20.0 / blockerDepth - distortFactor * 10.0), 0.0, 20.0);
    }

#endif

#if COLORED_SHADOWS != 0

    float filteredShadow(vec4 shadowPos, vec2 texelSize, float samplingQuality, float samplingSpacing, float lightBrightness){
        float color = 0.0;
        vec2 pattern[SAMPLING_PATTERN_LENGTH] = SAMPLING_PATTERN;

        float noise = getNoise(texcoord).r;

        float theta = noise * radians(360.0); // random angle using noise value
        float cosTheta = cos(theta);
        float sinTheta = sin(theta);

        mat2 rotation = mat2(cosTheta, -sinTheta, sinTheta, cosTheta); // matrix to rotate the offset around the original position by the angle
        #ifdef PENUMBRA_SHADOWS
            samplingSpacing += calculatePenumbra(shadowtex0, shadowPos);
        #endif
        for(int i = 0; i < SAMPLING_PATTERN_LENGTH; i++){
            vec3 samplePos = vec3(shadowPos.xy + pattern[i] * samplingSpacing / shadowMapResolution, shadowPos.z);
            float tex1 = texture(shadowtex1, samplePos.xy).r;
            float tex0 = texture(shadowtex0, samplePos.xy).r;
            if(tex1 > tex0) {
                color += tex1 < shadowPos.z ? SHADOW_BRIGHTNESS * lmcoord.y : lmcoord.y;
            } else color += tex0 < shadowPos.z ? SHADOW_BRIGHTNESS * lmcoord.y : lightBrightness;
        }
        #ifdef SHADOW_FADE
            return mix(color / SAMPLING_PATTERN_LENGTH, mix(SHADOW_BRIGHTNESS * lmcoord.y, lightBrightness, lmcoord.y), clamp((length(shadowPos.xz - viewPos3.xz) - 236.0) * 0.05, 0.0, 1.0));
        #else
            return color / SAMPLING_PATTERN_LENGTH;
        #endif
    }

    #if COLORED_SHADOWS == 1

        vec3 filteredColoredShadow(vec4 shadowPos, vec2 texelSize, float samplingQuality, float samplingSpacing, float intensitysky){
            vec3 tint = vec3(0.0);
            float coloredSamplingCount = 0.0;
            #ifdef PENUMBRA_SHADOWS
                samplingSpacing += calculatePenumbra(shadowtex0, shadowPos);
            #endif
            samplingQuality *= samplingSpacing;
            for(float x = -samplingQuality; x <= samplingQuality; x += samplingSpacing){
                for(float y = -samplingQuality; y <= samplingQuality; y += samplingSpacing){
                    vec3 samplePos = vec3(shadowPos.xy + vec2(x, y) * texelSize, shadowPos.z);
                    vec4 tex1 = texture(shadowtex1, samplePos.xy);
                    vec4 tex0 = texture(shadowtex0, samplePos.xy);
                    if (tex0.r < shadowPos.z && tex1.r > shadowPos.z) {
                        //surface has translucent object between it and the sun. modify its color.
                        //if the block light is high, modify the color less.
                        vec4 shadowLightColor = texture2D(shadowcolor0, samplePos.xy);
                        //make colors more intense when the shadow light color is more opaque.
                        shadowLightColor.rgb = mix(vec3(1.0), shadowLightColor.rgb, shadowLightColor.a);
                        //also make colors less intense when the block light level is high.
                        shadowLightColor.rgb = mix(shadowLightColor.rgb, vec3(1.0), lmcoord.x);
                        //apply the color
                        tint += shadowLightColor.rgb * intensitysky;
                    } else tint += vec3(1.0);
                    coloredSamplingCount += 1.0;
                }      
            }
        #ifdef SHADOW_FADE
            return mix(tint / coloredSamplingCount, mix(vec3(SHADOW_BRIGHTNESS * lmcoord.y), vec3(1.0), lmcoord.y), clamp((length(shadowPos.xz - viewPos3.xz) - 236.0) * 0.05, 0.0, 1.0));
        #else
            return tint / coloredSamplingCount;
        #endif
        }
    #endif

#else 

    float filteredShadow(vec4 shadowPos, vec2 texelSize, float samplingQuality, float samplingSpacing, float lightBrightness){
        float color = 0.0;
        vec2 pattern[SAMPLING_PATTERN_LENGTH] = SAMPLING_PATTERN;

        float noise = getNoise(texcoord).r;

        float theta = noise * radians(360.0); // random angle using noise value
        float cosTheta = cos(theta);
        float sinTheta = sin(theta);

        mat2 rotation = mat2(cosTheta, -sinTheta, sinTheta, cosTheta); // matrix to rotate the offset around the original position by the angle

        #ifdef PENUMBRA_SHADOWS
            samplingSpacing += calculatePenumbra(shadowtex0, shadowPos);
        #endif
        for(int i = 0; i < SAMPLING_PATTERN_LENGTH; i++){
            vec2 samplePos = shadowPos.xy + pattern[i] * rotation * samplingSpacing / shadowMapResolution;
            color += (texture(shadowtex0, samplePos.xy).r < shadowPos.z) ? SHADOW_BRIGHTNESS * lmcoord.y : lightBrightness;
        }
        #ifdef SHADOW_FADE
            return mix(color / SAMPLING_PATTERN_LENGTH, mix(SHADOW_BRIGHTNESS * lmcoord.y, lightBrightness, lmcoord.y), clamp((length(shadowPos.xz - viewPos3.xz) - 236.0) * 0.05, 0.0, 1.0));
        #else
            return color / SAMPLING_PATTERN_LENGTH;
        #endif
    }

#endif