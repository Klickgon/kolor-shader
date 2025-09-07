float fogify(float x, float w) {
	return w / (x * x + w);
}

vec3 calcSkyColor(vec3 pos) {
	float upDot = dot(pos, gbufferModelView[1].xyz);
	return mix(skyColor, fogColor, fogify(max(upDot, 0.0), 0.25));
}

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

#define MAX_SSR_STEPS 200

vec3 screenSpaceReflections(vec3 color, vec3 pixelViewPos, vec3 reflectionDirection, float roughness){
    vec2 screenResolution = vec2(viewWidth, viewHeight);
    vec2 pixelStart = (projectAndDivide(gbufferProjection, pixelViewPos) * 0.5 + 0.5).xy * screenResolution;
    vec3 rayDirection = reflectionDirection * 100.0;

    vec2 pixelEnd = (projectAndDivide(gbufferProjection, pixelViewPos + rayDirection) * 0.5 + 0.5).xy;
    pixelEnd = clamp(pixelEnd, vec2(0.0), vec2(1.0)) * screenResolution;

    vec2 deltas = pixelEnd - pixelStart;
    int pixelCoverage = max(int(max(abs(deltas.x), abs(deltas.y))) * 10, 1);

    int steps = min(pixelCoverage, MAX_SSR_STEPS);

    vec3 ray = pixelViewPos;
    vec3 rayStep = rayDirection / steps;
    vec3 ssRayPos;
    float depthDelta;
    
    for(int i = 0; i < steps; i++){
        ray += rayStep;
        ssRayPos = projectAndDivide(gbufferProjection, ray) * 0.5 + 0.5; 
        if(ssRayPos.x < 0.0 || ssRayPos.x > 1.0 || ssRayPos.y < 0.0 || ssRayPos.y > 1.0) return color;
        depthDelta = linearizeDepth(ssRayPos.z) - linearizeDepth(texture(depthtex2, ssRayPos.xy).r);
        if(depthDelta > -0.1 && depthDelta < 0.46) return textureLod(CTEX1, ssRayPos.xy, (float(i) / float(steps)) * 15.0 * roughness).rgb;
    }
    return depthDelta < 0.0 ? textureLod(CTEX1, pixelEnd / screenResolution, 15.0 * roughness).rgb : color;
}