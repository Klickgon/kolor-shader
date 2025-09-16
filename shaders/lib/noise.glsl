float random(vec2 p){
    return fract(sin(p.x*547.0 + p.y*72.0)* 100.0);
}

vec2 smoothVec2(vec2 v){
    return v*v*(3.0-2.0*v);
}

float smoothNoise(vec2 p){
    vec2 f = smoothVec2(fract(p));
    float a = random(floor(p));
    float b = random(vec2(ceil(p.x), floor(p.y)));
    float c = random(vec2(floor(p.x), ceil(p.y)));
    float d = random(ceil(p));
    return mix(mix(a,b,f.x), mix(c, d, f.x), f.y);
}

float fractalNoise(vec2 p){
    float total = 0.5;
    float amplitude = 1.1;
    float frequency = 1.3;
    const int iterations = 4;
    for(int i = 0; i < iterations; i++){
        total += (smoothNoise(p*frequency) - 0.5) * amplitude;
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    return total;
}