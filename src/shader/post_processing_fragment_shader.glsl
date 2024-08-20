#version 330 core
in vec2 vTextureCoord;
in mat4 vWorldToScreen;

uniform sampler2D uShadingColor;

out vec4 FragColor;

void main() {
    FragColor = texture(uShadingColor, vTextureCoord).rgba;
}