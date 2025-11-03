#version 120

uniform sampler2D texture;

varying vec2 texcoord;

float grayScale(vec3 color){
    return (color.r + color.g + color.b) / 3.0;
}

void main() {
	vec4 color = texture2D(texture, texcoord);
	/*vec3 bluredColor = textureLod(texture, texcoord, 3.5).rgb;
	float bloomStrength = grayScale(max(bluredColor - 1.0, 0.0));
	color.rgb = color.rgb + (bluredColor * (exp(bloomStrength) - 1.0));
	color.rgb += (bluredColor * (exp(bloomStrength) - 1.0));*/
	color.rgb = pow(color.rgb, vec3(1.0/2.2));
/* RENDERTARGETS:0 */
	gl_FragData[0] = color;
}