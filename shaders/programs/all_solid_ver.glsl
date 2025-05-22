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
varying vec4 shadowPos;
varying vec4 normal;
varying vec3 viewPos3;
varying float distortFactor;

#include "/settings.glsl"
#include "/lib/distort.glsl"
#include "/lib/vertex_manipulation.glsl"

void main() {
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;

	float lightDot = dot(normalize(shadowLightPosition), normalize(gl_NormalMatrix * gl_Normal));
	#ifdef EXCLUDE_FOLIAGE
		//when EXCLUDE_FOLIAGE is enabled, act as if foliage is always facing towards the sun.
		//in other words, don't darken the back side of it unless something else is casting a shadow on it.
		if (mc_Entity.x == 10601.0 || mc_Entity.x == 12412.0) lightDot = 1.0;
	#endif
		vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
		vec3 vPos = gl_Vertex.xyz;
		vec3 worldPos = (gbufferModelViewInverse * viewPos).xyz + cameraPosition;
	if(mc_Entity.x == 10601.0 || mc_Entity.x == 2003){
		viewPos = gbufferModelView * vec4(applyWindEffect(worldPos, vPos) - cameraPosition, 1.0);
	}
	if((mc_Entity.x == 12412.0) && mc_midTexCoord.y > texcoord.y){
		viewPos = gbufferModelView * vec4(applyWindEffect(worldPos, vPos) - cameraPosition, 1.0);
	}
	viewPos3 = viewPos.xyz;
	if (lightDot > 0.0) { //vertex is facing towards the sun
		vec4 playerPos = gbufferModelViewInverse * viewPos;
		shadowPos = shadowProjection * (shadowModelView * playerPos); //convert to shadow ndc space.
		float bias = computeBias(shadowPos.xyz);
		shadowPos.xyz = distort(shadowPos.xyz); //apply shadow distortion
		shadowPos.xyz = shadowPos.xyz * 0.5 + 0.5; //convert from -1 ~ +1 to 0 ~ 1
		normal = shadowProjection * vec4(mat3(shadowModelView) * (mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal)), 1.0);
    	//apply shadow bias.
        #ifdef NORMAL_BIAS
            shadowPos.xyz += normal.xyz * bias / max(abs(lightDot), 0.1);
        #else
            shadowPos.z -= max(bias * (1.0 - lightDot), bias);
        #endif
	}
	else { //vertex is facing away from the sun
		lmcoord.y *= SHADOW_BRIGHTNESS; //guaranteed to be in shadows. reduce light level immediately.
		shadowPos = vec4(0.0); //mark that this vertex does not need to check the shadow map.
	}
	shadowPos.w = lightDot;
	gl_Position = gl_ProjectionMatrix * viewPos;
}