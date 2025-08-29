#include "/settings.glsl"

#if !defined MASK
    #define MASK 2.0/15.0
#endif

uniform sampler2D texture;
uniform sampler2D depthtex0;
uniform sampler2D noisetex;

uniform float viewWidth;
uniform float viewHeight;
uniform float far;

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

varying float vertexLightDot;
varying vec3 viewPos;
varying float viewPosLength;
varying float vanillaAO;

vec4 getNoise(vec2 coord){
  ivec2 noiseCoord = ivec2(coord) % noiseTextureResolution; 
  return texelFetch(noisetex, noiseCoord, 0);
}

float grayScale(vec3 color){
    return (color.r + color.g + color.b) / 3.0;
}

/* RENDERTARGETS: 0,1,2,3,4,5 */
layout(location = 0) out vec4 color;
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
            if(max((viewPosLength - far * 0.95) * 0.05, 0.0) > grayScale(getNoise(gl_FragCoord.xy).rgb)) discard;
        #endif
    #endif

    vec4 precolor = texture(texture, texcoord);
    if (precolor.a < 0.1) discard;

    #if defined WEATHER && !defined DH
        precolor.a = 1.0;
    #endif

    #if defined NORMAL_MAPPING && !defined(DH)
        vec3 normalMaps = normal;
        mat3 tbn = mat3(tangent, bitangent, normalMaps);
        normalMaps = texture(normals, texcoord).rgb;
        normalMaps.z = sqrt(1.0 - dot(normalMaps.xy, normalMaps.xy));
        normalMaps = mix(vec3(0.5, 0.5, 1.0), normalMaps, NORMAL_MAP_STRENGTH);
        normalMaps = normalMaps * 2.0 - 1.0;   
        normalMaps = normalize(tbn * normalMaps);
    #endif

    color = precolor;
    color.rgb = pow(pow(color.rgb, vec3(2.2)) * pow(glcolor.rgb, vec3(2.2)), vec3(1.0/2.2));
    lightmapData = vec4(lmcoord, vertexLightDot, 1.0);
    encodedNormal = vec4(normal * 0.5 + 0.5, 1.0);
    
    #if !defined DH
        #ifdef NORMAL_MAPPING
            encodedNormalMap = vec4(normalMaps * 0.5 + 0.5, 1.0);
        #endif
        #if SPECULAR_MAPPING == 2
            specularMap = texture(specular, texcoord);
        #elif SPECULAR_MAPPING == 1
            specularMap = vec4(0.75, 0.0, 1.0, 1.0);
        #endif
    #elif SPECULAR_MAPPING != 0
        specularMap = vec4(0.75, 0.0, 1.0, 1.0);
    #endif
    extraInfo = vec4(MASK, vanillaAO, 0.0, 1.0);
}