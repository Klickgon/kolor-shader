#define BLOCKLIGHT (vec3(0.77, 0.62, 0.46) * 2)
#define SUNCOLOR (vec3(0.89, 0.80, 0.72) * 2)
#define MOONCOLOR (vec3(0.94, 0.91, 0.86) * 1.4)

#if SHADOW_FILTER_QUALITY == 0
    #define SAMPLING_PATTERN vec2[](vec2(0.0))
    #define SAMPLING_PATTERN_LENGTH 1
#endif
#if SHADOW_FILTER_QUALITY == 1
    #define SAMPLING_PATTERN vec2[](vec2(0.0), vec2(1.0223, 1.0341), vec2(-1.045, -1.012), vec2(1.0123, -1.0312), vec2(-1.053, 1.0512))
    #define SAMPLING_PATTERN_LENGTH 5
#endif
#if SHADOW_FILTER_QUALITY == 2
    #define SAMPLING_PATTERN vec2[](vec2(0.0), vec2(1.0223, 1.0341), vec2(-1.045, -1.012), vec2(1.0123, -1.0312), vec2(-1.053, 1.0512), vec2(0.25412, 0.45124), vec2(-0.25126, -0.45521), vec2(0.45521, -0.255212), vec2(-0.45521, 0.255521))
    #define SAMPLING_PATTERN_LENGTH 9
#endif
#if SHADOW_FILTER_QUALITY == 3
    #define SAMPLING_PATTERN vec2[](vec2(0.0), vec2(1.0223, 1.0341), vec2(-1.045, -1.012), vec2(1.0123, -1.0312), vec2(-1.053, 1.0512), vec2(0.25412, 0.45124), vec2(-0.25126, -0.45521), vec2(0.45521, -0.255212), vec2(-0.45521, 0.255521), vec2(-1.26132, 0.0621), vec2(1.2412, 0.0421), vec2(0.0642, -1.2521), vec2(0.0212, 1.24421))
    #define SAMPLING_PATTERN_LENGTH 13
#endif
#if SHADOW_FILTER_QUALITY == 4
    #define SAMPLING_PATTERN vec2[](vec2(0.0), vec2(1.0223, 1.0341), vec2(-1.045, -1.012), vec2(1.0123, -1.0312), vec2(-1.053, 1.0512), vec2(0.25412, 0.45124), vec2(-0.25126, -0.45521), vec2(0.45521, -0.255212), vec2(-0.45521, 0.255521), vec2(-1.26132, 0.0621), vec2(1.2412, 0.0421), vec2(0.0642, -1.2521), vec2(0.0212, 1.24421), vec2(-0.45531, 0.8512), vec2(0.45332, -0.851562), vec2(-0.85423, -0.45422), vec2(0.85422, 0.45422))
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
  ivec2 noiseCoord = ivec2(coord * vec2(viewWidth, viewHeight) * 1000000.0) % noiseTextureResolution; // wrap to range of noiseTextureResolution
  return texelFetch(noisetex, noiseCoord, 0);
}

mat2 getRotationMat2(){
    float noise = getNoise(texcoord).r;

    float theta = noise * radians(360.0); // random angle using noise value
    float cosTheta = cos(theta);
    float sinTheta = sin(theta);

    return mat2(cosTheta, -sinTheta, sinTheta, cosTheta); 
}

#ifdef PENUMBRA_SHADOWS

    float calculatePenumbra(sampler2D stex, vec4 shadowPos){
        float blockerDepth = 0.0;
        float blockerCount = 0.0;
        mat2 rotation = getRotationMat2();
        vec2 penumPattern[13] = vec2[](vec2(0.0), vec2(1.0, 1.0), vec2(-1.0, -1.0), vec2(1.0, -1.0), vec2(-1.0, 1.0), vec2(0.25, 0.45), vec2(-0.25, -0.45), vec2(0.45, -0.25), vec2(-0.45, 0.25), vec2(-1.15, 0.0), vec2(1.15, 0.0), vec2(0.0, -1.15), vec2(0.0, 1.15));
        for(int i = 0; i < 13; i++){
            vec2 samplePos = shadowPos.xy + penumPattern[i] * 20.0 * rotation / shadowMapResolution;
            float tex1 = texture(stex, samplePos).r;
            if(tex1 < shadowPos.z){
                blockerDepth += tex1;
                blockerCount += 1.0;
            }
        }
        if(blockerCount <= 0.0) return 0.0;
        blockerDepth /= blockerCount;
        if(blockerDepth <= 0.0) return 0.0;
        return clamp(((shadowPos.z - blockerDepth) * 20.0 / blockerDepth - distortFactor * 10.0), 0.0, 20.0);
    }

#endif

#if COLORED_SHADOWS != 0

    float filteredShadow(vec4 shadowPos, float samplingSpacing, float lightBrightness){
        float color = 0.0;
        vec2 pattern[SAMPLING_PATTERN_LENGTH] = SAMPLING_PATTERN;

        mat2 rotation = getRotationMat2();

        #ifdef PENUMBRA_SHADOWS
            samplingSpacing += calculatePenumbra(shadowtex0, shadowPos);
        #endif
        for(int i = 0; i < SAMPLING_PATTERN_LENGTH; i++){
            vec3 samplePos = vec3(shadowPos.xy + pattern[i] * samplingSpacing * rotation / shadowMapResolution, shadowPos.z);
            float tex1 = texture(shadowtex1, samplePos.xy).r;
            float tex0 = texture(shadowtex0, samplePos.xy).r;
            if(tex1 > tex0) {
                color += tex1 < shadowPos.z ? SHADOW_BRIGHTNESS * lmcoord.y : lmcoord.y;
            } else color += tex0 < shadowPos.z ? SHADOW_BRIGHTNESS * lmcoord.y : lightBrightness;
        }
        return color / SAMPLING_PATTERN_LENGTH;
    }

    #if COLORED_SHADOWS == 1

        vec3 filteredColoredShadow(vec4 shadowPos, float samplingQuality, float samplingSpacing, float intensitysky){
            vec3 tint = vec3(0.0);
            float coloredSamplingCount = 0.0;
            #ifdef PENUMBRA_SHADOWS
                samplingSpacing += calculatePenumbra(shadowtex0, shadowPos);
            #endif
            samplingQuality *= samplingSpacing;
            for(float x = -samplingQuality; x <= samplingQuality; x += samplingSpacing){
                for(float y = -samplingQuality; y <= samplingQuality; y += samplingSpacing){
                    vec3 samplePos = vec3(shadowPos.xy + vec2(x, y) / shadowMapResolution, shadowPos.z);
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
            return tint / coloredSamplingCount;
        }
    #endif

#else 

    float filteredShadow(vec4 shadowPos, float samplingSpacing, float lightBrightness){
        float color = 0.0;
        vec2 pattern[SAMPLING_PATTERN_LENGTH] = SAMPLING_PATTERN;
        mat2 rotation = getRotationMat2(); // matrix to rotate the offset around the original position by the angle

        #ifdef PENUMBRA_SHADOWS
            samplingSpacing += calculatePenumbra(shadowtex0, shadowPos);
        #endif
        for(int i = 0; i < SAMPLING_PATTERN_LENGTH; i++){
            vec2 samplePos = shadowPos.xy + pattern[i] * rotation * samplingSpacing / shadowMapResolution;
            color += (texture(shadowtex0, samplePos.xy).r < shadowPos.z) ? SHADOW_BRIGHTNESS * lmcoord.y : lightBrightness;
        }
        return color / SAMPLING_PATTERN_LENGTH;
    }

#endif