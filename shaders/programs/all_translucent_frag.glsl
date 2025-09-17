#include "/settings.glsl"

#if !defined MASK
    #define MASK 2.0/15.0
#endif

#define WATER_COLOR vec4(0.0, 0.65, 0.76, 0.5)
#define WATER_PBR vec4(1.0, 0.25, 1.0, 1.0)

uniform sampler2D texture;
uniform sampler2D depthtex0;
uniform sampler2D noisetex;

uniform vec3 cameraPosition;
uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform float frameTimeCounter;

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
varying vec3 normal;

#ifdef NORMAL_MAPPING && !defined(DH)
    varying vec3 tangent;
    varying vec3 bitangent;
#endif

#if !defined DH
	flat varying vec4 blockEntity;
#else
	flat varying int dhID;
#endif
varying float vertexLightDot;
varying vec3 viewPos;
varying float viewPosLength;
varying float vanillaAO;

float getNoise(vec2 coord){
  return mod(52.9829189 * mod(0.06711056*coord.x + 0.00583715*coord.y, 1.0), 1.0);
}

#if defined SHADER_WATER && defined WATER
    #include "/lib/noise.glsl"

    vec3 getWaveNormal(vec3 worldPos){
        float wave1 = frameTimeCounter * 0.2;
        const float wno = 0.01;
        float h1 = fractalNoise(worldPos.xz * 0.7 + wave1, 1.34,  0.74);
        float h2 = fractalNoise(worldPos.xz * 0.7 + wave1 + vec2(wno, 0.0), 1.34, 0.74);
        float h3 = fractalNoise(worldPos.xz * 0.7 + wave1 + vec2(0.0, wno), 1.34,  0.74);

        return vec3(h2-h1, h3-h1, 1.0) * 0.5 + 0.5;
    }
#endif

/* RENDERTARGETS: 0,1,2,3,4,5 */
layout(location = 1) out vec4 lightmapData;
layout(location = 2) out vec4 encodedNormal;
layout(location = 3) out vec4 encodedNormalMap;
layout(location = 4) out vec4 extraInfo;
layout(location = 5) out vec4 specularMap;

void main() {
    #ifdef DISTANT_HORIZONS
        #if defined DH
            if(viewPosLength < far * 0.80) discard;
            vec2 fragCoord = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
            if(texture(depthtex0, fragCoord).r < 1.0) discard;
        #else
            if(max((viewPosLength - far * 0.95) * 0.2, 0.0) > getNoise(gl_FragCoord.xy)) discard;
        #endif
    #endif

    #ifdef SHADER_WATER
        #if defined DH
            bool isWater = dhID == DH_BLOCK_WATER;
        #elif defined WATER
            bool isWater = blockEntity.x == 2.0;
        #endif
    #endif

    vec4 precolor;
    #if defined SHADER_WATER && defined WATER
        if(!isWater){
    #endif
        precolor = texture(texture, texcoord);
        
        if(precolor.a < 0.1) discard;
        #if defined DH
            precolor.a = 0.9;
        #endif
        precolor.rgb = pow(pow(precolor.rgb, vec3(2.2)) * pow(glcolor.rgb, vec3(2.2)), vec3(1.0/2.2));
    #if defined SHADER_WATER && defined WATER
        }
        else {
            precolor = WATER_COLOR;
            precolor.rgb = mix(pow(precolor.rgb, vec3(2.2)), pow(glcolor.rgb, vec3(2.2)), 0.2);
            precolor.rgb = pow(precolor.rgb, vec3(1.0/2.2));
        }
    #endif

    #if defined NORMAL_MAPPING
        vec3 normalMaps = normal;
        #if !defined(DH) || defined SHADER_WATER
            vec3 playerPos = (gl_ModelViewMatrixInverse * vec4(viewPos, 1.0)).xyz;
            vec3 worldPos = playerPos + cameraPosition;
            mat3 tbn = mat3(tangent, bitangent, normal);
            #if defined SHADER_WATER && defined WATER
                #if !defined DH
                    normalMaps = isWater ? getWaveNormal(worldPos) : texture(normals, texcoord).rgb;
                #else
                    bool facesUp = dot((gl_ModelViewMatrixInverse * vec4(normal, 1.0)).xyz, vec3(0.0, 1.0, 0.0)) >= 0.99;
                    //precolor.xyz = vec3(facesUp);
                    normalMaps = (isWater && facesUp) ? getWaveNormal(worldPos) : vec3(0.5, 0.5, 1.0);
                #endif
            #else
                normalMaps = texture(normals, texcoord).rgb;
            #endif
            normalMaps.z = sqrt(1.0 - dot(normalMaps.xy, normalMaps.xy));
            normalMaps = mix(vec3(0.5, 0.5, 1.0), normalMaps, NORMAL_MAP_STRENGTH);
            normalMaps = normalMaps * 2.0 - 1.0;   
            normalMaps = normalize(tbn * normalMaps);
        #endif
    #endif
    
    gl_FragData[0] = precolor;

    lightmapData = vec4(lmcoord, vertexLightDot, 1.0);
    encodedNormal = vec4(normal * 0.5 + 0.5, 1.0);
    
    #ifdef NORMAL_MAPPING
            encodedNormalMap = vec4(normalMaps * 0.5 + 0.5, 1.0);
    #endif
    #if !defined DH
        #if defined SHADER_WATER && defined WATER
            #if SPECULAR_MAPPING == 2
                specularMap = isWater ? WATER_PBR : texture(specular, texcoord);
            #elif SPECULAR_MAPPING == 1
                specularMap = isWater ? WATER_PBR : vec4(0.75, 0.0, 1.0, 1.0);
            #endif
        #else
            #if SPECULAR_MAPPING == 2
                specularMap = texture(specular, texcoord);
            #elif SPECULAR_MAPPING == 1
                specularMap = vec4(0.75, 0.0, 1.0, 1.0);
            #endif
        #endif
        
    #elif SPECULAR_MAPPING != 0
        #if defined SHADER_WATER && defined WATER
            specularMap = isWater ? WATER_PBR : vec4(0.75, 0.0, 1.0, 1.0);
        #else
            specularMap = vec4(0.75, 0.0, 1.0, 1.0);
        #endif
    #endif
    extraInfo = vec4(MASK, vanillaAO, 0.0, 1.0);
}