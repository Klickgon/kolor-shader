#version 120

attribute vec4 mc_Entity;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform float frameTimeCounter;
uniform vec3 cameraPosition;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

in vec2 mc_midTexCoord;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying float distortFactor;

#include "/settings.glsl"
#include "/lib/distort.glsl"
#include "/lib/vertex_manipulation.glsl"

void main() {
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;

	#ifdef EXCLUDE_FOLIAGE
		if (mc_Entity.x == 10000.0) {
			gl_Position = vec4(10.0);
		}
		else {
	#endif
			gl_Position = ftransform();
			vec3 worldPos = (shadowModelViewInverse * (gl_ModelViewMatrix * gl_Vertex)).xyz + cameraPosition;
			vec3 vPos = gl_Vertex.xyz;
			if(mc_Entity.x == 10601.0 || mc_Entity.x == 2003){
				gl_Position = shadowModelView * vec4(applyWindEffect(worldPos, vPos) - cameraPosition, 1.0);
				gl_Position = gl_ProjectionMatrix * gl_Position;
			} else if((mc_Entity.x == 12412.0) && mc_midTexCoord.y > texcoord.y){
				gl_Position = shadowModelView * vec4(applyWindEffect(worldPos, vPos) - cameraPosition, 1.0);
				gl_Position = gl_ProjectionMatrix * gl_Position;
			}
			gl_Position.xyz = distort(gl_Position.xyz);
	#ifdef EXCLUDE_FOLIAGE
		}
	#endif
	
}