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
#if TEXTURED != 1
	varying vec4 normal;
#endif
varying vec3 viewPos;
varying float distortFactor;
varying vec3 playerPos;
varying vec3 worldPos;

#include "/settings.glsl"
#include "/lib/distort.glsl"
#include "/lib/vertex_manipulation.glsl"

void main() {
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;

	#if TEXTURED != 1
		float lightDot;
		if (mc_Entity.x == 10601.0 || mc_Entity.x == 12412.0) lightDot = 1.0;
		else lightDot = dot(normalize(shadowLightPosition), normalize(gl_NormalMatrix * gl_Normal));
	#else 
		float lightDot = 1.0;
	#endif
		viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
		playerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
		worldPos = playerPos + cameraPosition;
	if(mc_Entity.x == 10601.0 || mc_Entity.x == 2003.0){
		viewPos = (gbufferModelView * vec4(applyWindEffect(worldPos) - cameraPosition, 1.0)).xyz;
	}
	if((mc_Entity.x == 12412.0) && mc_midTexCoord.y > texcoord.y){
		viewPos = (gbufferModelView * vec4(applyWindEffect(worldPos) - cameraPosition, 1.0)).xyz;
	}
	if (lightDot > 0.0) { //vertex is facing towards the sun
		shadowPos = shadowProjection * (shadowModelView * vec4(playerPos, 1.0)); //convert to shadow clip pos.
		float bias = computeBias(shadowPos.xyz);
		shadowPos.xyz = distort(shadowPos.xyz); //apply shadow distortion
		shadowPos.xyz = shadowPos.xyz * 0.5 + 0.5; //convert from -1 ~ +1 to 0 ~ 1
		#if TEXTURED != 1
			normal = shadowProjection * vec4(mat3(shadowModelView) * (mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal)), 1.0);
			//apply shadow bias.
			#ifdef NORMAL_BIAS
				shadowPos.xyz += normal.xyz * bias / max(abs(lightDot), 0.1);
			#else
				shadowPos.z -= max(bias * (1.0 - lightDot), bias);
			#endif
		#endif
	}
	else { //vertex is facing away from the sun
		lmcoord.y *= SHADOW_BRIGHTNESS; //guaranteed to be in shadows. reduce light level immediately.
		shadowPos = vec4(0.0); //mark that this vertex does not need to check the shadow map.
	}
	shadowPos.w = lightDot;
	gl_Position = gl_ProjectionMatrix * vec4(viewPos, 1.0);
}