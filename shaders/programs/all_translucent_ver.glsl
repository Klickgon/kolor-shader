#include "/settings.glsl"

#if !defined DH
	attribute vec4 mc_Entity;
#endif

#ifdef NORMAL_MAPPING
	attribute vec4 at_tangent;	
#endif


uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;

varying vec2 mc_midTexCoord;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying vec3 normal;

#ifdef NORMAL_MAPPING
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

#include "/lib/vertex_manipulation.glsl"

void main() {
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;
	vanillaAO = glcolor.a;
	lmcoord = lmcoord / (30.0 / 32.0) - (1.0 / 32.0);
	#if defined TEXTURED
		normal = vec3(0.0, 0.0, 1.0);
	#else
		normal = gl_NormalMatrix * gl_Normal;
	#endif

	#if !defined DH
		blockEntity = mc_Entity;
	#else 
		dhID = dhMaterialId;
	#endif
	
	#if defined WEATHER || defined DH
		const bool lightPassthrough = true;
	#else
		bool lightPassthrough = mc_Entity.x == 10601.0 || mc_Entity.x == 12412.0;
	#endif

	vertexLightDot = lightPassthrough ? 1.0 : dot(normal, normalize(shadowLightPosition)) * (1.0-(1.0/16.0));
	#ifdef NORMAL_MAPPING
		#if !defined DH
			tangent = gl_NormalMatrix * at_tangent.xyz;
			bitangent = cross(tangent, normal) * at_tangent.w;
		#else
			tangent = vec3(0.0, 0.0, 1.0);
			bitangent = vec3(1.0, 0.0, 0.0);
		#endif
	#endif
	
	viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
	#if defined WATER && !defined DH
		if(mc_Entity.x == 2.0){
			vec3 playerPos = (gl_ModelViewMatrixInverse * vec4(viewPos, 1.0)).xyz;
			vec3 worldPos = playerPos + cameraPosition;
			viewPos = (gl_ModelViewMatrix * vec4(applyWaveEffect(worldPos) - cameraPosition, 1.0)).xyz;
		}
	#endif
	viewPosLength = length(viewPos);
	
	gl_Position = gl_ProjectionMatrix * vec4(viewPos, 1.0);
}