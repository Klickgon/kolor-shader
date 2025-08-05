#include "/settings.glsl"

uniform sampler2D texture;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

#ifdef NORMAL_MAPPING
	uniform sampler2D normals;
#endif

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying vec3 normal;

#ifdef NORMAL_MAPPING
    varying vec3 tangent;
    varying vec3 bitangent;
#endif

varying float vertexLightDot;
varying float viewPosLength;
varying float vanillaAO;

/* RENDERTARGETS: 0,1,2,3,4 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 lightmapData;
layout(location = 2) out vec4 encodedNormal;
layout(location = 3) out vec4 extraInfo;
layout(location = 4) out vec4 encodedNormalMap;

void main() {
    vec4 precolor = texture(texture, texcoord) * glcolor;
    if (precolor.a < 0.1) discard;

    #if defined WEATHER
        precolor.a = 1.0;
    #endif

    #ifdef NORMAL_MAPPING
        vec3 normalMaps = normal;
        mat3 tbn = mat3(tangent, bitangent, normalMaps);
        normalMaps = texture(normals, texcoord).rgb;
        normalMaps.z = sqrt(1.0 - dot(normalMaps.xy, normalMaps.xy));
        normalMaps = mix(vec3(0.5, 0.5, 1.0), normalMaps, NORMAL_MAP_STRENGTH * (1-clamp(viewPosLength * 0.2, 0.0, 1.0)));
        normalMaps = normalMaps * 2.0 - 1.0;   
        normalMaps = normalize(tbn * normalMaps);
    #endif
    color = precolor;
    lightmapData = vec4(lmcoord, vertexLightDot, 1.0);
    encodedNormal = vec4(normal * 0.5 + 0.5, 1.0);
    #ifdef NORMAL_MAPPING
        encodedNormalMap = vec4(normalMaps * 0.5 + 0.5, 1.0);
    #endif
    extraInfo = vec4(1.0, vanillaAO, 0.0, 1.0);
}