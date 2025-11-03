
vec3 applyWindEffect(vec3 worldPos){
	worldPos.x += sin((frameTimeCounter * 1.5) + worldPos.x) * 0.02 + sin((frameTimeCounter * 1.3) + worldPos.x) * 0.01;
	worldPos.y += sin((frameTimeCounter* 1.6) + 54 + worldPos.y) * 0.01 + sin((frameTimeCounter * 1.8) + 32 + worldPos.y) * 0.008;
	worldPos.z += sin((frameTimeCounter * 1.8) + 54 + worldPos.z) * 0.02 + sin((frameTimeCounter * 1.2) + 54 + worldPos.z) * 0.01;
	return worldPos;
}

vec3 applyWaveEffect(vec3 worldPos){
	worldPos.y += (sin((frameTimeCounter * 2.7) + 4 + worldPos.x) * 0.02 + sin((frameTimeCounter * 3.1) + 12 + worldPos.z) * 0.01 - 0.007) * lmcoord.y;
	return worldPos;
}
