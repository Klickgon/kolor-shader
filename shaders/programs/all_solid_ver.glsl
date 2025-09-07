#include "/settings.glsl"

attribute vec4 mc_Entity;

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

varying float vertexLightDot;
varying float viewPosLength;
varying float vanillaAO;

#include "/lib/vertex_manipulation.glsl"

void main() {
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmcoord = lmcoord / (30.0 / 32.0) - (1.0 / 32.0);
	
	glcolor = gl_Color;
	vanillaAO = glcolor.a;

	#if defined TEXTURED
		normal = vec3(0.0, 0.0, 1.0);
	#else
		normal = normalize(gl_NormalMatrix * gl_Normal);
	#endif
	bool lightPassthrough = mc_Entity.x == 10601.0 || mc_Entity.x == 12412.0;
	vertexLightDot = lightPassthrough ? 1.0 : dot(normal, normalize(shadowLightPosition)) * (1.0-(1.0/16.0));

	vec3 viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
	viewPosLength = length(viewPos);
	vec3 playerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
	vec3 worldPos = playerPos + cameraPosition;
	if(mc_Entity.x == 10601.0 || mc_Entity.x == 2003.0){
		viewPos = (gbufferModelView * vec4(applyWindEffect(worldPos) - cameraPosition, 1.0)).xyz;
	}
	if((mc_Entity.x == 12412.0) && mc_midTexCoord.y > texcoord.y){
		viewPos = (gbufferModelView * vec4(applyWindEffect(worldPos) - cameraPosition, 1.0)).xyz;
	}
	#ifdef NORMAL_MAPPING
		tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
		bitangent = cross(tangent, normal) * at_tangent.w;
	#endif
	gl_Position = gl_ProjectionMatrix * vec4(viewPos, 1.0);
}