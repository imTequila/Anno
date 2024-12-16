#version 330 core
in vec2 vTextureCoord;

uniform sampler2D uShadowMap;
uniform vec2 uOffset;
uniform vec2 uShadowSize;
uniform int uSamples;

out vec4 FragColor;

void main() {
    vec2 passOffset = uOffset / uShadowSize;

    vec4 t = vec4(0);
    for (int i = 0; i < uSamples; ++i) {
        t += texture2D(uShadowMap, vTextureCoord - i * passOffset);
    }

    FragColor = t;
}