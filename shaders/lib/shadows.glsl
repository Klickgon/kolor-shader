#define BLOCKLIGHT (vec3(0.66, 0.52, 0.41) * 3)
#define SUNCOLOR (vec3(0.71, 0.48, 0.32) * 15)
#define MOONCOLOR (vec3(0.64, 0.66, 0.85) * 4)

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

mat2 getRotationMat2(float noise){
    float theta = noise * radians(360.0); // random angle using noise value
    float cosTheta = cos(theta);
    float sinTheta = sin(theta);

    return mat2(cosTheta, -sinTheta, sinTheta, cosTheta); 
}

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position){
  vec4 homPos = projectionMatrix * vec4(position, 1.0);
  return homPos.xyz / homPos.w;
}

#ifdef SCREEN_SPACE_SHADOWS
    bool screenSpaceShadow(vec3 pixelViewPos, float depth, float lightDot){
        depth = linearizeDepth(depth);
        vec3 raydir = normalize(shadowLightPosition - pixelViewPos) * 0.25;
        vec3 rayStep = raydir / 64.0;
        for(int i = 0; i < 64.0; i++){
            pixelViewPos += rayStep;
            vec3 ssPos = projectAndDivide(gbufferProjection, pixelViewPos) * 0.5 + 0.5;
            if(ssPos.x < 0.0 || ssPos.x > 1.0 || ssPos.y < 0.0 || ssPos.y > 1.0) return false;
            float delta = linearizeDepth(ssPos.z) - linearizeDepth(texture(DTEX, ssPos.xy).r) - (0.005 * depth);
            if(delta > 0.0 && delta < 0.08) return true;
        }
        return false;
    }
#endif

#ifdef PENUMBRA_SHADOWS
    float calculatePenumbra(sampler2D stex, vec3 shadowPos){
        float blockerDepth = 0.0;
        float blockerCount = 0.0;
        mat2 rotation = getRotationMat2(noise.r);
        vec2 randOffset = (vec2(noise.g, noise.b) - 0.5) * 0.5; 
        vec2 penumPattern[13] = vec2[](vec2(0.0), vec2(1.0, 1.0), vec2(-1.0, -1.0), vec2(1.0, -1.0), vec2(-1.0, 1.0), vec2(0.25, 0.45), vec2(-0.25, -0.45), vec2(0.45, -0.25), vec2(-0.45, 0.25), vec2(-1.15, 0.0), vec2(1.15, 0.0), vec2(0.0, -1.15), vec2(0.0, 1.15));
        for(int i = 0; i < 13; i++){
            vec2 samplePos = shadowPos.xy + ((penumPattern[i] + randOffset) * 20.0 * rotation / 4096);
            float tex1 = texture(stex, samplePos).r;
            if(tex1 < shadowPos.z){
                blockerDepth += tex1;
                blockerCount += 1.0;
            }
        }
        if(blockerCount <= 0.0) return 0.0;
        blockerDepth /= blockerCount;
        if(blockerDepth <= 0.0) return 0.0;
        return clamp(((shadowPos.z - blockerDepth) * 20.0 / blockerDepth - distortFactor * 10.0), 0.0, 100.0);
    }
#endif

#if COLORED_SHADOWS == 0
    float filteredShadow(vec3 shadowPos, float samplingSpacing, float lightBrightness){
        float color = 0.0;
        vec2 pattern[SAMPLING_PATTERN_LENGTH] = SAMPLING_PATTERN;
        mat2 rotation = getRotationMat2(noise.r); // matrix to rotate the offset around the original position by the angle

        #ifdef PENUMBRA_SHADOWS
            samplingSpacing += calculatePenumbra(shadowtex1, shadowPos, noise);
        #endif
        vec2 randOffset = (vec2(noise.g, noise.b) - 0.5) * 0.5; 
        for(int i = 0; i < SAMPLING_PATTERN_LENGTH; i++){
            vec2 samplePos = shadowPos.xy + ((pattern[i] + randOffset) * rotation * samplingSpacing / 4096);
            color += (texture(shadowtex0, samplePos.xy).r < shadowPos.z) ? SHADOW_BRIGHTNESS * lmcoord.y : lightBrightness;
        }
        return color / SAMPLING_PATTERN_LENGTH;
    }
#elif COLORED_SHADOWS == 1
        vec4 filteredShadow(vec3 shadowPos, float samplingSpacing, float intensitysky, float lightBrightness){
            vec4 color = vec4(0.0);
            vec2 pattern[SAMPLING_PATTERN_LENGTH] = SAMPLING_PATTERN;
            mat2 rotation = getRotationMat2(noise.r); // matrix to rotate the offset around the original position by the angle
            #ifdef PENUMBRA_SHADOWS
                samplingSpacing += calculatePenumbra(shadowtex0, shadowPos);
            #endif
            vec2 randOffset = (vec2(noise.g, noise.b) - 0.5) * 0.5;
            for(int i = 0; i < SAMPLING_PATTERN_LENGTH; i++){
                vec2 samplePos = shadowPos.xy + (pattern[i] + randOffset) * rotation * samplingSpacing / 4096;
                float tex1 = texture(shadowtex1, samplePos).r;
                if (tex1 < shadowPos.z) {  
                    color.rgb += vec3(1.0);
                    color.a += SHADOW_BRIGHTNESS * lmcoord.y;
                } else {
                    float tex0 = texture(shadowtex0, samplePos).r;
                    if(tex0 < shadowPos.z){
                        //surface has translucent object between it and the sun. modify its color.
                        //if the block light is high, modify the color less.
                        vec4 shadowLightColor = texture2D(shadowcolor0, samplePos.xy);
                        //make colors more intense when the shadow light color is more opaque.
                        shadowLightColor.rgb = mix(vec3(1.0), shadowLightColor.rgb, shadowLightColor.a);
                        //also make colors less intense when the block light level is high.
                        //shadowLightColor.rgb = mix(shadowLightColor.rgb, vec3(1.0), lmcoord.x);
                        //apply the color
                        color.rgb += shadowLightColor.rgb * intensitysky;
                        color.a += lightBrightness * lmcoord.y;
                    } else {
                        color.rgb += vec3(1.0);
                        color.a += lightBrightness;
                    }
                }
            }      
        
        return color / SAMPLING_PATTERN_LENGTH;;
    }
#else 
    float filteredShadow(vec3 shadowPos, float samplingSpacing, float lightBrightness){
        vec4 noise = getNoise(texcoord);
        float color = 0.0;
        vec2 pattern[SAMPLING_PATTERN_LENGTH] = SAMPLING_PATTERN;
        mat2 rotation = getRotationMat2(noise.r); // matrix to rotate the offset around the original position by the angle

        #ifdef PENUMBRA_SHADOWS
            samplingSpacing += calculatePenumbra(shadowtex0, shadowPos, noise);
        #endif
        vec2 randOffset = (vec2(noise.g, noise.b) - 0.5) * 0.5; 
        for(int i = 0; i < SAMPLING_PATTERN_LENGTH; i++){
            vec2 samplePos = shadowPos.xy + ((pattern[i] + randOffset) * rotation * samplingSpacing / shadowMapResolution);
            color += (texture(shadowtex1, samplePos.xy).r < shadowPos.z) ? SHADOW_BRIGHTNESS * lmcoord.y : lightBrightness;
        }
        return color / SAMPLING_PATTERN_LENGTH;
    }
#endif