#include "/settings.glsl"

#if !defined MASK
    #define MASK 0.0
#endif

uniform sampler2D texture;
uniform sampler2D depthtex0;

uniform float viewWidth;
uniform float viewHeight;
uniform float far;

#if !defined DH
    #ifdef NORMAL_MAPPING
        uniform sampler2D normals;
    #endif
    #ifdef SPECULAR_MAPPING
        uniform sampler2D specular;
    #endif
#endif

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying vec3 normal;

#if defined NORMAL_MAPPING && !defined(DH)
    varying vec3 tangent;
    varying vec3 bitangent;
#endif

varying float vertexLightDot;
varying float viewPosLength;
varying float vanillaAO;

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
            if(texture(depthtex0, gl_FragCoord.xy / vec2(viewWidth, viewHeight)).r != 1.0) discard;
        #endif
        #if !defined DH
            if(viewPosLength >= far) discard;
            if(viewPosLength < far && viewPosLength >= far * 0.98 && !(int(gl_FragCoord.x / 2.0) % 2 != int(gl_FragCoord.y / 2.0) % 2)) discard;
        #endif
   #endif
    

    vec4 precolor = texture(gtexture, texcoord) * glcolor;
    if (precolor.a < 0.1) discard;

    #if defined NORMAL_MAPPING && !defined(DH)
        vec3 normalMaps;
        mat3 tbn = mat3(tangent, bitangent, normal);
        normalMaps = texture(normals, texcoord).rgb;
        normalMaps.z = sqrt(1.0 - dot(normalMaps.xy, normalMaps.xy));
        normalMaps = mix(vec3(0.5, 0.5, 1.0), normalMaps, NORMAL_MAP_STRENGTH * (1-clamp(viewPosLength * 0.01 - float(precolor.a > 0.7), 0.0, 1.0)));
        normalMaps = normalMaps * 2.0 - 1.0;   
        normalMaps = normalize(tbn * normalMaps);
    #endif
    color = precolor;
    lightmapData = vec4(lmcoord, vertexLightDot, 1.0);
    encodedNormal = vec4(normal * 0.5 + 0.5, 1.0);
    #if !defined DH
        #ifdef NORMAL_MAPPING
            encodedNormalMap = vec4(normalMaps * 0.5 + 0.5, 1.0);
        #endif
        #ifdef SPECULAR_MAPPING
            specularMap = texture(specular, texcoord);
        #endif
    #endif
    extraInfo = vec4(MASK, vanillaAO, 0.0, 1.0);
}