float getSpecularHighlight(vec3 viewPos, float lightDot, float roughness){
    vec3 reflectionDirection = reflect(-normalizedShadowLightPos, NMAP);
    roughness *= 0.5;
    float smoothness = (1-roughness);
    float specular = smoothness * clamp(dot(reflectionDirection, -viewPos), 0.0, 1.0);
    float diffuse = roughness * clamp(1-lightDot, 0.0, 0.95);
    return (diffuse * 0.01 + pow(specular, mix(100.0, 10.0, roughness))) * (0.5+roughness);
}

vec3 brdf(vec3 lightDir, vec3 viewDir, float roughness, vec3 normal, vec3 albedo, float metallic, vec3 reflectance) {
    
    float alpha = pow(roughness, 2.0);

    vec3 H = normalize(lightDir + viewDir);
    
    //dot products
    float NdotV = clamp(dot(normal, viewDir), 0.001, 1.0);
    float NdotL = clamp(dot(normal, lightDir), 0.001, 1.0);
    float NdotH = clamp(dot(normal,H), 0.001, 1.0);
    float VdotH = clamp(dot(viewDir, H), 0.001, 1.0);

    // Fresnel
    vec3 F0 = reflectance;
    vec3 fresnelReflectance = F0 + (1.0 - F0) * pow(1.0 - VdotH, 5.0); //Schlick's Approximation

    //phong diffuse
    //vec3 rhoD = albedo;
    //rhoD *= (vec3(1.0)- fresnelReflectance); //energy conservation - light that doesn't reflect adds to diffuse

    //rhoD *= (1-metallic); //diffuse is 0 for metals

    // Geometric attenuation
    float k = alpha/2;
    float geometry = (NdotL / (NdotL*(1-k)+k)) * (NdotV / ((NdotV*(1-k)+k)));

    // Distribution of Microfacets
    float lowerTerm = pow(NdotH,2) * (pow(alpha,2) - 1.0) + 1.0;
    float normalDistributionFunctionGGX = pow(alpha,2) / (3.14159 * pow(lowerTerm,2));

    //vec3 phongDiffuse = rhoD;
    vec3 cookTorrance = (fresnelReflectance*normalDistributionFunctionGGX*geometry)/(4*NdotL*NdotV);
    
    //vec3 BRDF = (phongDiffuse+cookTorrance)*NdotL;
    vec3 BRDF = (cookTorrance)*NdotL;
    
    return BRDF;
}

#ifdef SCREEN_SPACE_REFLECTIONS
    const vec2 rayCoords[9] = vec2[](vec2(0.01178, 0.000011),
                                     vec2(-0.015065, 0.01377),
                                     vec2(0.002330, -0.02624),
                                     vec2(0.018946, 0.0247638),
                                     vec2(-0.03480, -0.006193),
                                     vec2(0.03300, -0.0209459),
                                     vec2(-0.01107, 0.041023),
                                     vec2(-0.02099, -0.040527),
                                     vec2(0.045626, 0.016714));

    vec3 brdfSSRColorSample(vec3 ray, vec3 pixelViewPos, float rayLength, float rayProgress, float roughness, vec3 normal, vec3 reflectance){
        if(rayProgress * rayLength > 1.0 && roughness > 0.01){
            vec3 screenResolution = vec3(viewWidth, viewHeight, 0.0);
            float mult = (1+roughness * 20.0) * rayLength * rayProgress * 0.000005;
            mat2 rotation = getRotationMat2(noise);
            vec3 color = vec3(0.0);
            vec3 weightsum = vec3(0.0);
            for(int i = 0; i < 9; i++){
                vec3 currentRay = ray + vec3(rayCoords[i] * rotation, 0.0) * mult;
                vec3 weight = max(brdf(normalize(currentRay), -normalize(pixelViewPos), roughness, normal, vec3(0.0), 0.0, reflectance), 0.0);
                weightsum += weight;
                color += textureLod(colortex0,(projectAndDivide(gbufferProjection, currentRay) * 0.5 + 0.5).xy, 0.5).rgb * weight;
            }
            return color / max(weightsum, 0.01);
        }
        return textureLod(colortex0,(projectAndDivide(gbufferProjection, ray) * 0.5 + 0.5).xy, 0.5).rgb;
    }
    
    #if !defined DISTANT_HORIZONS
        #define MAX_SSR_STEPS 200
        
        vec3 screenSpaceReflections(vec3 color, vec3 sky, vec3 pixelViewPos, vec3 reflectionDirection, float roughness, vec3 normal, vec3 reflectance, bool isDH){
            reflectionDirection *= 0.01;
            const float rayLength = 1.32 * ((MAX_SSR_STEPS.0 * (MAX_SSR_STEPS.0 + 1.0)) / 2.0);

            vec3 ray = pixelViewPos;
            vec3 rayStep = reflectionDirection * 1.32;
            vec3 ssRayPos;
            float depthDelta;
            bool isHand;
            for(int i = 1; i <= MAX_SSR_STEPS; i++){
                float ifloat = float(i);
                ray += rayStep * ifloat;
                ssRayPos = projectAndDivide(gbufferProjection, ray) * 0.5 + 0.5;
                if(ssRayPos.x < 0.0 || ssRayPos.x > 1.0 || ssRayPos.y < 0.0 || ssRayPos.y > 1.0 || ssRayPos.z <= 0.0) return color;
                float mask = texture(ETEX5, ssRayPos.xy).r;
	            isHand = mask == HAND_MASK_SOLID || mask == HAND_MASK_TRANSLUCENT;
                depthDelta = linearizeDepth(ssRayPos.z) - linearizeDepth(sampleDepthWithHandFixLOD(depthtex1, ssRayPos.xy, 0.5));
                float rayprogress = (1.32 * ((ifloat * (ifloat + 1.0)) / 2.0) / rayLength);
                if(depthDelta > 0.00 && depthDelta < (0.01 + ifloat * 0.05)) return !isHand ? brdfSSRColorSample(ray, pixelViewPos, rayLength, rayprogress, roughness, normal, reflectance) : color;
            }
            return depthDelta < 0.0 && !isHand ? brdfSSRColorSample(ray, pixelViewPos, rayLength, 1.0, roughness, normal, reflectance) : color;
        }
    #else
        #define MAX_SSR_STEPS 250
        #define SSR_RAY_BASE_LENGTH 1.15
        vec3 screenSpaceReflections(vec3 color, vec3 sky, vec3 pixelViewPos, vec3 reflectionDirection, float roughness, vec3 normalMap, vec3 reflectance, bool isDH){
            const float rayLength = SSR_RAY_BASE_LENGTH * ((MAX_SSR_STEPS.0 * (MAX_SSR_STEPS.0 + 1.0)) / 2.0);
            float ssraccuracy = (1.0-roughness * 0.80) * (1+abs(dot(gbufferModelView[1].xyz, reflectionDirection)));
            reflectionDirection *= 0.001;
            reflectionDirection += (noiseVec * 2.0 - 1.0) * roughness * 0.00002;
            float distanceboost = (1+length(pixelViewPos) * 0.06);
            vec3 ray = pixelViewPos;
            vec3 rayStep = reflectionDirection * SSR_RAY_BASE_LENGTH * distanceboost / (ssraccuracy * 1.75);
            rayStep *= 1.0 + dhRenderDistance * 0.001;
            vec3 ssRayPos;
            float depthDelta;
            
            int steps = int(MAX_SSR_STEPS * ssraccuracy);
            float deltaMin = 0.1 + (1-abs(dot(reflectionDirection, normal))) * 0.05;
            float deltaMult = 0.01 * ssraccuracy * pow(distanceboost, 1.5);

            for(int i = 1; i <= steps; i++){
                float ifloat = float(i);
                ray += rayStep * ifloat;
                ssRayPos = projectAndDivide(gbufferProjection, ray) * 0.5 + 0.5;
                if(ssRayPos.x < 0.0 || ssRayPos.x > 1.0 || ssRayPos.y < 0.0 || ssRayPos.y > 1.0) return color;
                float mask = texture(ETEX5, ssRayPos.xy).r;
	            bool isHand = mask == HAND_MASK_SOLID || mask == HAND_MASK_TRANSLUCENT;
                bool isDH = mask == DH_MASK_SOLID || mask == DH_MASK_TRANSLUCENT;
                depthDelta = linearizeDepth(ssRayPos.z);
                float depth = 0.0;
                if(isDH){
                    depth = 0.0;
                    depthDelta -= linearizeDepthDH(textureLod(dhDepthTex1, ssRayPos.xy, 1.0).r);
                } else {
                    depth = textureLod(depthtex1, ssRayPos.xy, 1.0).r;
                    depthDelta -= linearizeDepth(depth);
                }
                if(!isDH && depth >= 1.0 && ssRayPos.z >= 1.0) continue;
                float rayprogress = (SSR_RAY_BASE_LENGTH * ((ifloat * (ifloat + 1.0))) / 2.0) / rayLength;
                if(depthDelta > deltaMin && depthDelta < (0.1 + ifloat * deltaMult)) return !isHand ? brdfSSRColorSample(ray, pixelViewPos, rayLength, rayprogress, roughness, normalMap, reflectance) : color;
            }
            ray = normalize(ray) * 10000;
            return depthDelta < 0.0 ? brdfSSRColorSample(ray, pixelViewPos, 10000, 1.0, roughness, normalMap, reflectance) : color;
        }

    #endif
#endif