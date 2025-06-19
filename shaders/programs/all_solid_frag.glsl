uniform sampler2D lightmap;
uniform sampler2D texture;


#if COLORED_SHADOWS == 0
	//for normal shadows, only consider the closest thing to the sun,
	//regardless of whether or not it's opaque.
	#define TEX shadowtex0
#else
	//else consider the closest opaque thing
	#define TEX shadowtex1
#endif

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying vec3 normal;
varying float foliage;

/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 lightmapData;
layout(location = 2) out vec4 encodedNormal;

void main() {
    vec4 precolor = texture(gtexture, texcoord) * glcolor;
    if (precolor.a < 0.1) discard;
    color = precolor;
    lightmapData = vec4(lmcoord, foliage, 1.0);
    encodedNormal = vec4(normal * 0.5 + 0.5, 1.0);
}