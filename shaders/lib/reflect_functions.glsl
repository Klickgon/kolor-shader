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
    #define LOD_LIMIT 45.0
    vec3 brdfSSRColorSample(vec3 ssRayPos, vec3 pixelViewPos, float rayLength, float rayprogress, float roughness, vec3 normal, vec3 reflectance){
        if(rayprogress * rayLength > 0.0 && roughness > 0.01){
            vec3 screenResolution = vec3(viewWidth, viewHeight, 0.0);
            float mult = rayLength * 0.0000001 * (1+roughness);
            vec3 color = vec3(0.0);
            vec3 pos1 = ssRayPos + vec3(0.1, 0.1, 0.0) * mult;
            vec3 pos2 = ssRayPos + vec3(0.1, -0.1, 0.0) * mult;
            vec3 pos3 = ssRayPos + vec3(-0.1, -0.1, 0.0) * mult;
            vec3 pos4 = ssRayPos + vec3(-0.1, 0.1, 0.0) * mult;
            vec3 pos5 = ssRayPos + vec3(0.12, 0.0, 0.0) * mult;
            vec3 pos6 = ssRayPos + vec3(-0.12, 0.0, 0.0) * mult;
            vec3 pos7 = ssRayPos + vec3(0.0, -0.12, 0.0) * mult;
            vec3 pos8 = ssRayPos + vec3(0.0, 0.12, 0.0) * mult;
            vec3 rayPositions[9] = vec3[](ssRayPos, pos1, pos2, pos3, pos4, pos5, pos6, pos7, pos8);
            vec3 weightsum = vec3(0.0);
            for(int i = 0; i < 9; i++){
                vec3 weight = max(brdf(normalize(projectAndDivide(gbufferProjectionInverse, rayPositions[i] * 2.0 - 1.0)), -normalize(pixelViewPos), roughness, normal, vec3(0.0), 0.0, reflectance), 0.0);
                weightsum += weight;
                color += textureLod(colortex0, rayPositions[i].xy, 1.0).rgb * weight;
            }
            return color / max(weightsum, 0.00001);
        }
        return textureLod(colortex1, ssRayPos.xy, 1.0).rgb;
    }
    
    #if !defined DISTANT_HORIZONS
        #define MAX_SSR_STEPS 200
        
        vec3 screenSpaceReflections(vec3 color, vec3 sky, vec3 pixelViewPos, vec3 reflectionDirection, float roughness, vec3 normal, vec3 reflectance, bool isDH){
            reflectionDirection *= 0.01;
            const float rayLength = 1.32 * ((MAX_SSR_STEPS.0 * (MAX_SSR_STEPS.0 + 1.0)) / 2.0);
            vec2 screenResolution = vec2(viewWidth, viewHeight);

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
                depthDelta = linearizeDepth(ssRayPos.z) - linearizeDepth(sampleDepthWithHandFix(depthtex1, ssRayPos.xy));
                float rayprogress = (1.32 * ((ifloat * (ifloat + 1.0)) / 2.0) / rayLength);
                if(depthDelta > 0.00 && depthDelta < (0.01 + ifloat * 0.05)) return !isHand ? brdfSSRColorSample(ssRayPos, pixelViewPos, rayLength, rayprogress, roughness, normal, reflectance) : color;
            }
            return depthDelta < 0.0 && !isHand ? brdfSSRColorSample(ssRayPos, pixelViewPos, rayLength, 1.0, roughness, normal, reflectance) : color;
        }
    #else
        #define MAX_SSR_STEPS 250
        vec3 screenSpaceReflections(vec3 color, vec3 sky, vec3 pixelViewPos, vec3 reflectionDirection, float roughness, vec3 normal, vec3 reflectance, bool isDH){
            reflectionDirection *= 0.003;
            const float rayLength = 1.32 * ((MAX_SSR_STEPS.0 * (MAX_SSR_STEPS.0 + 1.0)) / 2.0);
            vec2 screenResolution = vec2(viewWidth, viewHeight);
            float ssraccuracy = (1.0-roughness * 0.80) * (1-abs(dot(gbufferModelView[1].xyz, reflectionDirection)));

            float distanceboost = (1+length(pixelViewPos) * 0.06);
            vec3 ray = pixelViewPos;
            vec3 rayStep = reflectionDirection * 1.32 * distanceboost / ssraccuracy;
            rayStep *= 1.0 + dhRenderDistance * 0.001;
            vec3 ssRayPos;
            float depthDelta;
            
            int steps = int(MAX_SSR_STEPS * ssraccuracy);
            float deltaMult = 0.05 * (1.5-ssraccuracy * 0.5) * distanceboost;

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
                    depthDelta -= linearizeDepthDH(texture(dhDepthTex1, ssRayPos.xy).r);
                } else {
                    depth = texture(depthtex1, ssRayPos.xy).r;
                    depthDelta -= linearizeDepth(depth);
                }
                if(!isDH && depth >= 1.0 && ssRayPos.z >= 1.0) continue;
                float rayprogress = (1.32 * ((ifloat * (ifloat + 1.0)) / 2.0) / rayLength);
                if(depthDelta > 0.00 && depthDelta < (0.01 + ifloat * deltaMult)) return mix(brdfSSRColorSample(ssRayPos, pixelViewPos, rayLength, rayprogress, roughness, normal, reflectance), color, isHand ? 1.0 : pow((ifloat / float(steps)), 16.0));
            }
            return depthDelta < 0.0 ? sky : color;
        }

    #endif
#endif