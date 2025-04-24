
vec3 getCelestialColor(){
	int isDay = int(worldTime <= 12000);
	return float(isDay) * SUNCOLOR + float(1 - isDay) * MOONCOLOR;
}

float getLightIntensity(float x){
	return 0.2 * sin(x * PI) + 1;
}

float filteredShadowColored(sampler2D shadowTex1, sampler2D shadowTex0, vec4 shadowPos, vec2 texelSize, float samplingQuality, float samplingSpacing){
    float lightBrightness = mix(31.0 / 32.0 * SHADOW_BRIGHTNESS, 31.0 / 32.0, sqrt(shadowPos.w));
    float color = 0.0;
    float samplingCount = 0.0;
    samplingQuality *= samplingSpacing;
    for(float x = -samplingQuality; x <= samplingQuality; x += samplingSpacing){
        for(float y = -samplingQuality; y <= samplingQuality; y += samplingSpacing){
            vec2 sampleUV = shadowPos.xy + vec2(x, y) * texelSize;
            float tex0 = texture(shadowTex0, sampleUV).r;
            float tex1 = texture(shadowTex1, sampleUV).r;
                if(tex0 <= tex1) {
                    color += tex1 < shadowPos.z ? SHADOW_BRIGHTNESS * lmcoord.y : lmcoord.y;
                } else color += tex0 < shadowPos.z ? SHADOW_BRIGHTNESS : lightBrightness;
            samplingCount += 1.0;
        }
    }
    return color / samplingCount;
}

float filteredShadow(sampler2D shadowTex0, vec4 shadowPos, vec2 texelSize, float samplingQuality, float samplingSpacing){
    float lightBrightness = mix(31.0 / 32.0 * SHADOW_BRIGHTNESS, 31.0 / 32.0, sqrt(shadowPos.w));
    float color = 0.0;
    float samplingCount = 0.0;
    samplingQuality *= samplingSpacing;
    for(float x = -samplingQuality; x <= samplingQuality; x += samplingSpacing){
        for(float y = -samplingQuality; y <= samplingQuality; y += samplingSpacing){
            vec2 sampleUV = shadowPos.xy + vec2(x, y) * texelSize;
            color += (texture(shadowTex0, sampleUV).r < shadowPos.z) ? SHADOW_BRIGHTNESS * lmcoord.y : lightBrightness;
            samplingCount += 1.0;
        }
    }
    return color / samplingCount;
}
