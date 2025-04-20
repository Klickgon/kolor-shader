
vec3 applyWindEffect(vec3 worldPos, vec3 vPos){
	worldPos.x += sin((frameTimeCounter * 1.5) + vPos.x) * 0.02 + sin((frameTimeCounter * 1.3) + vPos.x) * 0.01;
	worldPos.y += sin((frameTimeCounter* 1.6) + 54 + vPos.y) * 0.01 + sin((frameTimeCounter * 1.8) + 32 + vPos.y) * 0.008;
	worldPos.z += sin((frameTimeCounter * 1.8) + 54 + vPos.z) * 0.02 + sin((frameTimeCounter * 1.2) + 54 + vPos.z) * 0.01;
	return worldPos;
}

