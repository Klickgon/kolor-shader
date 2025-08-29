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

float fogify(float x, float w) {
	return w / (x * x + w);
}

vec3 calcSkyColor(vec3 pos) {
	float upDot = dot(pos, gbufferModelView[1].xyz);
	return mix(skyColor, fogColor, fogify(max(upDot, 0.0), 0.25));
}