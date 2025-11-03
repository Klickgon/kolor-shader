#if SHADOW_FILTER_QUALITY == 0
    #define SAMPLING_PATTERN vec2[](vec2(0.0))
    #define SAMPLING_PATTERN_LENGTH 1
#elif SHADOW_FILTER_QUALITY == 1
    #define SAMPLING_PATTERN vec2[](vec2(0.0), vec2(1.0223, 1.0341), vec2(-1.045, -1.012), vec2(1.0123, -1.0312), vec2(-1.053, 1.0512))
    #define SAMPLING_PATTERN_LENGTH 5
#elif SHADOW_FILTER_QUALITY == 2
    #define SAMPLING_PATTERN vec2[](vec2(0.0), vec2(1.0223, 1.0341), vec2(-1.045, -1.012), vec2(1.0123, -1.0312), vec2(-1.053, 1.0512), vec2(0.25412, 0.45124), vec2(-0.25126, -0.45521), vec2(0.45521, -0.255212), vec2(-0.45521, 0.255521))
    #define SAMPLING_PATTERN_LENGTH 9
#elif SHADOW_FILTER_QUALITY == 3
    #define SAMPLING_PATTERN vec2[](vec2(0.0), vec2(1.0223, 1.0341), vec2(-1.045, -1.012), vec2(1.0123, -1.0312), vec2(-1.053, 1.0512), vec2(0.25412, 0.45124), vec2(-0.25126, -0.45521), vec2(0.45521, -0.255212), vec2(-0.45521, 0.255521), vec2(-1.26132, 0.0621), vec2(1.2412, 0.0421), vec2(0.0642, -1.2521), vec2(0.0212, 1.24421))
    #define SAMPLING_PATTERN_LENGTH 13
#elif SHADOW_FILTER_QUALITY == 4
    #define SAMPLING_PATTERN vec2[](vec2(0.0), vec2(1.0223, 1.0341), vec2(-1.045, -1.012), vec2(1.0123, -1.0312), vec2(-1.053, 1.0512), vec2(0.25412, 0.45124), vec2(-0.25126, -0.45521), vec2(0.45521, -0.255212), vec2(-0.45521, 0.255521), vec2(-1.26132, 0.0621), vec2(1.2412, 0.0421), vec2(0.0642, -1.2521), vec2(0.0212, 1.24421), vec2(-0.45531, 0.8512), vec2(0.45332, -0.851562), vec2(-0.85423, -0.45422), vec2(0.85422, 0.45422))
    #define SAMPLING_PATTERN_LENGTH 17
#endif

#if defined SCREEN_SPACE_SHADOWS && !defined TRANSLUCENT_PASS
    bool screenSpaceShadow(vec3 pixelViewPos, float depth, float lightDot, float surfaceDot){
        if(surfaceDot > 0.8 || lightDot < 0.01) return false;
        depth = linearizeDepth(depth);
        float bias = (1.0-lightDot) * (1.0+surfaceDot * 7.0) * depth * 0.002;
        vec3 raydir = shadowLightPosition * 0.0025;
        float offset = noise * 0.25 + 1.0;
        vec3 rayStep = raydir / 32.0 * offset;
        for(int i = 0; i < 32.0; i++){
            pixelViewPos += rayStep;
            vec3 ssPos = projectAndDivide(gbufferProjection, pixelViewPos) * 0.5 + 0.5;
            if(ssPos.x < 0.0 || ssPos.x > 1.0 || ssPos.y < 0.0 || ssPos.y > 1.0) return false;
            float delta = linearizeDepth(ssPos.z) - linearizeDepth(sampleDepthWithHandFix(depthtex0, ssPos.xy)) - bias;
            if(delta > 0.01 && delta < 0.08) return true;
        }
        return false;
    }

    #if defined DISTANT_HORIZONS
        bool screenSpaceShadowDH(vec3 pixelViewPos, float depth, float lightDot, float viewPosLength){
            if(lightDot <= 0.0) return false;
            float surfaceDot = 1.5 - (dot(vec3(0.0, 0.0, 1.0), normal) * 0.5);
            if(surfaceDot < 0.1) return false;
            depth = linearizeDepthDH(depth);
            float bias = ((1-lightDot) * surfaceDot * depth * 0.00095);

            vec3 raydir = shadowLightPosition * 0.025;
            vec3 rayStep = raydir / 32.0;
            float offset = noise * 0.20 + 1.0;
            for(int i = 0; i < 32.0; i++){
                pixelViewPos += rayStep * offset;
                vec3 ssPos = projectAndDivide(dhProjection, pixelViewPos) * 0.5 + 0.5;
                if(ssPos.x < 0.0 || ssPos.x > 1.0 || ssPos.y < 0.0 || ssPos.y > 1.0) return false;
                float delta = linearizeDepthDH(ssPos.z) - linearizeDepthDH(texture(dhDepthTex1, ssPos.xy).r) - bias;
                if(delta > 6.0 && delta < 25.0) return true;
            }
            return false;
        }
    #endif
#endif

#ifdef PENUMBRA_SHADOWS
    float calculatePenumbra(sampler2D stex, vec3 shadowPos){
        float blockerDepth = 0.0;
        float blockerCount = 0.0;
        mat2 rotation = getRotationMat2(noise);
        float noise2 = getNoise(texcoord + 0.05);
        #if SHADOW_FILTER_QUALITY == 0
            vec2 randOffset = vec2(0.0); 
        #else
            vec2 randOffset = (vec2(noise, noise2) - 0.5) * 0.5;
        #endif

        vec2 penumPattern[13] = vec2[](vec2(0.0), vec2(1.0223, 1.0341), vec2(-1.045, -1.012), vec2(1.0123, -1.0312), vec2(-1.053, 1.0512), vec2(0.25412, 0.45124), vec2(-0.25126, -0.45521), vec2(0.45521, -0.255212), vec2(-0.45521, 0.255521), vec2(-1.26132, 0.0621), vec2(1.2412, 0.0421), vec2(0.0642, -1.2521), vec2(0.0212, 1.24421));
        for(int i = 0; i < 13; i++){
            vec2 samplePos = shadowPos.xy + ((penumPattern[i] + randOffset) * 20.0 * rotation / 4096.0);
            float tex1 = texture(stex, samplePos).r;
            if(tex1 < shadowPos.z){
                blockerDepth += linearizeDepth(tex1);
                blockerCount += 1.0;
            }
        }
        if(blockerCount <= 0.0) return 0.0;
        blockerDepth /= blockerCount;
        if(blockerDepth <= 0.0) return 0.0;
        return clamp(((linearizeDepth(shadowPos.z) - blockerDepth) * 35.0 / blockerDepth - distortFactor * 10.0 * lmcoord.y), 0.0, 60.0);
    }
#endif

#if COLORED_SHADOWS == 0
    float filteredShadow(vec3 shadowPos, float samplingSpacing){
        float color = 0.0;
        float noise2 = getNoise(texcoord + 0.05);
        vec2 pattern[SAMPLING_PATTERN_LENGTH] = SAMPLING_PATTERN;
        mat2 rotation = getRotationMat2(noise); // matrix to rotate the offset around the original position by the angle
        #ifdef PENUMBRA_SHADOWS
            samplingSpacing += calculatePenumbra(shadowtex1, shadowPos);
        #endif

        #if SHADOW_FILTER_QUALITY == 0
            vec2 randOffset = vec2(0.0); 
        #else
            vec2 randOffset = (vec2(noise, noise2) - 0.5) * 0.5;
        #endif
        for(int i = 0; i < SAMPLING_PATTERN_LENGTH; i++){
            vec2 samplePos = shadowPos.xy + ((pattern[i] + randOffset) * rotation * samplingSpacing / 4096.0);
            color += float(texture(shadowtex0, samplePos.xy).r >= shadowPos.z);
        }
        return color / SAMPLING_PATTERN_LENGTH;
    }
#elif COLORED_SHADOWS == 1
        vec4 filteredShadow(vec3 shadowPos, float samplingSpacing, float intensitysky){
            float noise2 = getNoise(texcoord + 0.05);
            vec4 color = vec4(0.0);
            vec2 pattern[SAMPLING_PATTERN_LENGTH] = SAMPLING_PATTERN;
            mat2 rotation = getRotationMat2(noise); // matrix to rotate the offset around the original position by the angle
            #ifdef PENUMBRA_SHADOWS
                samplingSpacing += calculatePenumbra(shadowtex0, shadowPos);
            #endif
            #if SHADOW_FILTER_QUALITY == 0
                vec2 randOffset = vec2(0.0); 
            #else
                vec2 randOffset = (vec2(noise, noise2) - 0.5) * 0.5;
            #endif
            int lightMix = 0;
            float tintsamples = 0.0;
            for(int i = 0; i < SAMPLING_PATTERN_LENGTH; i++){
                vec2 samplePos = shadowPos.xy + (pattern[i] + randOffset) * rotation * samplingSpacing / 4096.0;
                float tex1 = texture(shadowtex1, samplePos).r;
                if (tex1 >= shadowPos.z) {
                    float tex0 = texture(shadowtex0, samplePos).r;
                    if(tex0 < shadowPos.z){
                        //surface has translucent object between it and the sun. modify its color.
                        //if the block light is high, modify the color less.
                        vec4 shadowLightColor = texture2D(shadowcolor0, samplePos.xy);
                        //make colors more intense when the shadow light color is more opaque.
                        shadowLightColor.rgb = mix(vec3(1.0), sRGB_to_Linear(shadowLightColor.rgb), shadowLightColor.a * 0.5 + 0.5);
                        //apply the color
                        color.rgb += shadowLightColor.rgb;
                        tintsamples += 1.0;
                        color.a += lmcoord.y;
                    } else {
                        color.rgb += vec3(1.0);
                        tintsamples += 1.0;
                        color.a += 1.0;
                    }
                }
            }
            if(tintsamples > 0.0) color.rgb /= tintsamples;
            else color.rgb = vec3(1.0);
            color.a /= SAMPLING_PATTERN_LENGTH;
            return color;
        }
#else 
    float filteredShadow(vec3 shadowPos, float samplingSpacing){
        float noise2 = getNoise(texcoord + 0.05);
        float color = 0.0;
        vec2 pattern[SAMPLING_PATTERN_LENGTH] = SAMPLING_PATTERN;
        mat2 rotation = getRotationMat2(noise); // matrix to rotate the offset around the original position by the angle
        #ifdef PENUMBRA_SHADOWS
            samplingSpacing += calculatePenumbra(shadowtex0, shadowPos);
        #endif

        #if SHADOW_FILTER_QUALITY == 0
            const vec2 randOffset = vec2(0.0); 
        #else
            vec2 randOffset = (vec2(noise, noise2) - 0.5) * 0.5;
        #endif
        for(int i = 0; i < SAMPLING_PATTERN_LENGTH; i++){
            vec2 samplePos = shadowPos.xy + ((pattern[i] + randOffset) * rotation * samplingSpacing / shadowMapResolution);
            color += float(texture(shadowtex1, samplePos.xy).r >= shadowPos.z);
        }
        return color / SAMPLING_PATTERN_LENGTH;
    }
#endif