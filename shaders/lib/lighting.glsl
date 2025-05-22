
vec3 getCelestialColor(){
	bool isDay = sunPosition == shadowLightPosition;
	return float(isDay) * SUNCOLOR + float(!isDay) * MOONCOLOR;
}

float getLightIntensity(float x){
	return 0.2 * sin(x * PI) + 1.0;
}

#ifdef PENUMBRA_SHADOWS
    float calculatePenumbra(sampler2D stex, vec4 shadowPos, vec2 texelSize){
        float blockerDepth = 0.0;
        float blockerCount = 0.0;
        float spacing[7] = float[](10.0, 5.0, 3.0, 3.0, 5.0, 10.0, 100.0);
        int i = 0;
        for(float x = -18.0; x <= 18.0; x += spacing[i++]){
            int j = 0;
            for(float y = -18.0; y <= 18.0; y += spacing[j++]){
                vec2 samplePos = shadowPos.xy + vec2(x, y) * texelSize;
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
        float shadowSamplingCount = 0.0;
        #ifdef PENUMBRA_SHADOWS
            samplingSpacing += calculatePenumbra(shadowtex0, shadowPos, texelSize);
        #endif
        samplingQuality *= samplingSpacing;
        for(float x = -samplingQuality; x <= samplingQuality; x += samplingSpacing){
            for(float y = -samplingQuality; y <= samplingQuality; y += samplingSpacing){
                vec3 samplePos = vec3(shadowPos.xy + vec2(x, y) * texelSize, shadowPos.z);
                float tex1 = texture(shadowtex1, samplePos.xy).r;
                float tex0 = texture(shadowtex0, samplePos.xy).r;
                if(tex1 > tex0) {
                    color += tex1 < shadowPos.z ? SHADOW_BRIGHTNESS * lmcoord.y : lmcoord.y;
                } else color += tex0 < shadowPos.z ? SHADOW_BRIGHTNESS * lmcoord.y : lightBrightness;
                shadowSamplingCount += 1.0;
            }
        }
        return color / shadowSamplingCount;
    }

    #if COLORED_SHADOWS == 1

        vec3 filteredColoredShadow(vec4 shadowPos, vec2 texelSize, float samplingQuality, float samplingSpacing, float intensitysky){
            vec3 tint = vec3(0.0);
            float coloredSamplingCount = 0.0;
            #ifdef PENUMBRA_SHADOWS
                samplingSpacing += calculatePenumbra(shadowtex0, shadowPos, texelSize);
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
        return tint / coloredSamplingCount;
        }
    #endif

#else 

    float filteredShadow(vec4 shadowPos, vec2 texelSize, float samplingQuality, float samplingSpacing, float lightBrightness){
        float color = 0.0;
        float samplingCount = 0.0;
        #ifdef PENUMBRA_SHADOWS
            samplingSpacing += calculatePenumbra(shadowtex0, shadowPos, texelSize);
        #endif
        samplingQuality *= samplingSpacing;
        for(float x = -samplingQuality; x <= samplingQuality; x += samplingSpacing){
            for(float y = -samplingQuality; y <= samplingQuality; y += samplingSpacing){
                vec2 samplePos = shadowPos.xy + vec2(x, y) * texelSize;
                color += (texture(shadowtex0, samplePos.xy).r < shadowPos.z) ? SHADOW_BRIGHTNESS * lmcoord.y : lightBrightness;
                samplingCount += 1.0;
            }
        }
        return color / samplingCount;
    }

#endif