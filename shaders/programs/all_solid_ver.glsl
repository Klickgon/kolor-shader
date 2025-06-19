attribute vec4 mc_Entity;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;
uniform int blockEntityId;
uniform float frameTimeCounter;

varying vec2 mc_midTexCoord;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying vec3 normal;
varying float foliage;


#include "/settings.glsl"
#include "/lib/vertex_manipulation.glsl"

void main() {
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;

	#if TEXTURED != 1
		normal = gl_NormalMatrix * gl_Normal;
	#else
		normal = vec3(1.0);
	#endif

	foliage = float(mc_Entity.x == 10601.0 || mc_Entity.x == 12412.0);

	vec3 viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
	vec3 playerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
	vec3 worldPos = playerPos + cameraPosition;
	if(mc_Entity.x == 10601.0 || mc_Entity.x == 2003.0){
		viewPos = (gbufferModelView * vec4(applyWindEffect(worldPos) - cameraPosition, 1.0)).xyz;
	}
	if((mc_Entity.x == 12412.0) && mc_midTexCoord.y > texcoord.y){
		viewPos = (gbufferModelView * vec4(applyWindEffect(worldPos) - cameraPosition, 1.0)).xyz;
	}
	
	gl_Position = gl_ProjectionMatrix * vec4(viewPos, 1.0);
}