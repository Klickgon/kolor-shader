uniform sampler2D texture;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying vec3 normal;
varying float lightDot;

/* RENDERTARGETS: 0,1,2,3 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 lightmapData;
layout(location = 2) out vec4 encodedNormal;
layout(location = 3) out vec4 mask;


void main() {
    vec4 precolor = texture(texture, texcoord) * glcolor;
    if (precolor.a < 0.1) discard;
    color = precolor;
    lightmapData = vec4(lmcoord, lightDot, 1.0);
    encodedNormal = vec4(normal * 0.5 + 0.5, 1.0);
    mask = vec4(1.0);
}