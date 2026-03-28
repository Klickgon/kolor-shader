#include "/./settings.glsl"
#if !defined MASK
    #define MASK 0.0
#endif

#define BASE_SPECULAR vec4(0.15, 0.0, 0.2, 1.0)

uniform sampler2D texture;
uniform sampler2D depthtex0;
uniform sampler2D noisetex;

uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform int entityId;
uniform float frameTime;
uniform float wetness;
uniform float rainfall;


#if !defined DH
    #ifdef NORMAL_MAPPING
        uniform sampler2D normals;
    #endif
    #if SPECULAR_MAPPING == 2
        uniform sampler2D specular;
    #endif
#endif

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying vec3 vertexNormal;


#if defined NORMAL_MAPPING && !defined(DH)
    varying vec3 tangent;
    varying vec3 bitangent;
#endif

varying vec3 worldPos;
varying float vertexLightDot;
varying float viewPosLength;
varying float vanillaAO;

varying float upDot;
varying float sideDot;

#include "/./lib/noise.glsl"

float getNoise(vec2 coord){
  return mod(52.9829189 * mod(0.06711056*coord.x + 0.00583715*coord.y, 1.0), 1.0);
}

/* RENDERTARGETS: 0,1,2,3,4,5 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 lightmapData;
layout(location = 2) out vec4 encodedNormal;
layout(location = 3) out vec4 encodedNormalMap;
layout(location = 4) out vec4 extraInfo;
layout(location = 5) out vec4 specularMap;

void main() {
    #ifdef DISTANT_HORIZONS
        #if defined DH
            if(viewPosLength < far * 0.80) discard;
            vec2 ssCoord = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
            if(texture(depthtex0, ssCoord).r < 1.0) discard;
        #else
            if(max((viewPosLength - far * 0.95) * 0.05, 0.0) > getNoise(gl_FragCoord.xy)) discard;
        #endif
    #endif
    
    vec4 precolor = texture(gtexture, texcoord);
    if (precolor.a < 0.1) discard;
    
    #if defined DH
        vec2 worldTex = abs(upDot) > 0.99 ? worldPos.xz : (sideDot > 0.99 ? worldPos.yz : worldPos.yx);
        ivec2 noisepos = ivec2((worldTex+0.001) * 3.0) % 512;
        precolor.rgb *= 1 - texelFetch(noisetex, noisepos, 0).x * 0.09;
    #endif
        precolor.rgb = pow(precolor.rgb, vec3(2.2)) * pow(glcolor.rgb, vec3(2.2));
    #endif
    outColor = precolor;
    
    #ifdef NORMAL_MAPPING
        vec3 normalMaps = vertexNormal;
        #if !defined(DH)
            mat3 tbn = mat3(tangent, bitangent, vertexNormal);
            normalMaps = texture(normals, texcoord).rgb;
            normalMaps.z = sqrt(1.0 - dot(normalMaps.xy, normalMaps.xy));
            normalMaps = mix(vec3(0.5, 0.5, 1.0), normalMaps, NORMAL_MAP_STRENGTH * clamp(0.7-viewPosLength * 0.01, 0.0, 1.0));
            normalMaps = clamp(normalMaps * 2.0 - 1.0, -0.5, 1.0);
            normalMaps = normalize(tbn * normalMaps);
        #endif
    #endif

    lightmapData = vec4(lmcoord, vertexLightDot, 1.0);
    encodedNormal = vec4(vertexNormal * 0.5 + 0.5, 1.0);
    #ifdef NORMAL_MAPPING
        encodedNormalMap = vec4(normalMaps * 0.5 + 0.5, 1.0);
    #endif 
    #if !defined DH
        #if SPECULAR_MAPPING == 2
            specularMap = vec4(texture(specular, texcoord).rgb, 1.0);
        #elif SPECULAR_MAPPING == 1
            specularMap = BASE_SPECULAR;
        #endif
    #elif SPECULAR_MAPPING != 0
        specularMap = BASE_SPECULAR;
    #endif

    #ifdef PUDDLES 
        #if defined TERRAIN && SPECULAR_MAPPING != 0
            const float amplitude = 6.0;
            const float frequency = 0.15;
            if(upDot > 0.995 && wetness > 0.0){
                float indoors = clamp(lmcoord.y * 24.0 - 23.0, 0.0, 1.0);
                float puddle = clamp(fractalNoise(worldPos.xz, amplitude, frequency) - (1.0 - wetness) * 6.0, wetness * 0.05, 1.0) * indoors;
                specularMap.r = mix(specularMap.r, max(specularMap.r, 1.0), sqrt(puddle));
                specularMap.g = mix(specularMap.g, max(specularMap.g, 0.5), puddle);
            }
        #endif
    #endif
    extraInfo = vec4(MASK, vanillaAO, 0.0, 1.0);
}