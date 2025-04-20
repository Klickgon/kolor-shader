
vec3 getCelestialColor(){
	int isDay = int(worldTime <= 12000);
	return float(isDay) * SUNCOLOR + float(1 - isDay) * MOONCOLOR;
}

float getLightIntensity(float x){
	return 0.2 * sin(x * PI) + 1;
}

float filteredShadow(sampler2D tex, vec2 uv, vec2 texelSize, int filterSize, float depth, float shadowBrightness, float lightBrightness){
    float color = 0.0;
    for(int x = -filterSize; x <= filterSize; x++){
        for(int y = -filterSize; y <= filterSize; y++){
            color += (texture2D(tex, uv + vec2(x, y) * texelSize).r < depth) ? shadowBrightness : lightBrightness;
        }
    }
    float filterSizeF = filterSize * 2 + 1;
    return color / (filterSizeF * filterSizeF);
}
