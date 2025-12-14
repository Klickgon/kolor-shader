#if SHADOW_FILTER_QUALITY == 0
    const vec2[1] samplingPattern = vec2[](vec2(0.0));
    #define SAMPLING_PATTERN_LENGTH 1
#elif SHADOW_FILTER_QUALITY == 1
    const vec2[8] samplingPattern = vec2[](vec2(0.06687, 0.240889), vec2(-0.36724, -0.22941),
                                            vec2(0.549656, -0.101872), vec2(-0.39813, 0.5281935),
                                            vec2(-0.07168, -0.746566), vec2(0.615957, 0.555064),
                                            vec2(-0.90135, 0.007376), vec2(0.70857, -0.659861));
    #define SAMPLING_PATTERN_LENGTH 8
#elif SHADOW_FILTER_QUALITY == 2
    const vec2[16] samplingPattern = vec2[](vec2(0.0472875, 0.1703346), vec2(-0.259682, -0.162218),
                                    vec2(0.388665, -0.072034), vec2(-0.28152, 0.373489),
                                    vec2(-0.05068, -0.527902), vec2(0.4355474, 0.392490),
                                    vec2(-0.637356, 0.0052161), vec2(0.5010402, -0.46659262),
                                    vec2(-0.0577776, 0.7265753), vec2(-0.4738224, -0.607653),
                                    vec2(0.798837, 0.1345704), vec2(-0.7115804, 0.4608722),
                                    vec2(0.2224667, -0.855428), vec2(0.4300271, 0.8116813),
                                    vec2(-0.896849, -0.3192340), vec2(0.9066841, -0.3829802));
    #define SAMPLING_PATTERN_LENGTH 16
#elif SHADOW_FILTER_QUALITY == 3
    const vec2[24] samplingPattern = vec2[](vec2(0.038610, 0.13907764), vec2(-0.21202, -0.1324512), 
                                        vec2(0.317344, -0.058816), vec2(-0.22986, 0.304952), 
                                        vec2(-0.04138, -0.431030), vec2(0.355623, 0.320466), 
                                        vec2(-0.52039, 0.004258), vec2(0.409097, -0.38097), 
                                        vec2(-0.04717, 0.593246), vec2(-0.38687, -0.496146), 
                                        vec2(0.652247, 0.109876), vec2(-0.58100, 0.376300), 
                                        vec2(0.181643, -0.69845), vec2(0.351115,  0.662735), 
                                        vec2(-0.732274, -0.26065), vec2(0.7403045, -0.312702), 
                                        vec2(-0.34527, 0.7538461), vec2(-0.26222, -0.812653), 
                                        vec2(0.763207, 0.433989), vec2(-0.878750, 0.2007437), 
                                        vec2(0.5253358, -0.760387), vec2(0.1293109, 0.9376097), 
                                        vec2(-0.745449, -0.617903), vec2(0.9883157, 0.0489749));
    #define SAMPLING_PATTERN_LENGTH 24
#elif SHADOW_FILTER_QUALITY == 4
    const vec2[32] samplingPattern = vec2[](vec2(0.0334373, 0.12044477), vec2(-0.1836232, -0.1147061),
                                            vec2(0.27482813, -0.0509361), vec2(0.199067, 0.26409675), 
                                            vec2(-0.035840, -0.3732833), vec2(0.307978, 0.277532341), 
                                            vec2(-0.450678, 0.00368838), vec2(0.354288, -0.329930), 
                                            vec2(-0.04085, 0.5137663), vec2(-0.335043, -0.4296756), 
                                            vec2(0.5648631, 0.09515570), vec2(-0.50316, 0.3258858),
                                            vec2(0.1573077, -0.6048795), vec2(0.3040751, 0.5739453),
                                            vec2(-0.634168, -0.2257325), vec2(0.641122, 0.2708079),
                                            vec2(-0.29901, 0.6528498), vec2(-0.227090, -0.7037789), 
                                            vec2(0.660957, 0.3758463), vec2(-0.7610, 0.1738491),
                                            vec2(0.45495, -0.658514), vec2(0.11198, 0.811993), 
                                            vec2(-0.64557, 0.535119), vec2(0.855906, 0.042413), 
                                            vec2(-0.61515, 0.622262), vec2(0.033935, -0.892033), 
                                            vec2(0.58875, 0.6938987), vec2(-0.9197, -0.116092), 
                                            vec2(0.77023, -0.545315), vec2(-0.20306, 0.9384249),
                                            vec2(-0.49230, 0.843066), vec2(0.947656, 0.293805));
    #define SAMPLING_PATTERN_LENGTH 32
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
            vec2 samplePos = shadowPos.xy + ((samplingPattern[i] + randOffset) * rotation * samplingSpacing / 4096.0);
            color += float(texture(shadowtex0, samplePos.xy).r >= shadowPos.z);
        }
        return color / SAMPLING_PATTERN_LENGTH;
    }
#elif COLORED_SHADOWS == 1
        vec4 filteredShadow(vec3 shadowPos, float samplingSpacing, float intensitysky){
            float noise2 = getNoise(texcoord + 0.05);
            vec4 color = vec4(0.0);
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
                vec2 samplePos = shadowPos.xy + (samplingPattern[i] + randOffset) * rotation * samplingSpacing / 4096.0;
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
            vec2 samplePos = shadowPos.xy + ((samplingPattern[i] + randOffset) * rotation * samplingSpacing / shadowMapResolution);
            color += float(texture(shadowtex1, samplePos.xy).r >= shadowPos.z);
        }
        return color / SAMPLING_PATTERN_LENGTH;
    }
#endif