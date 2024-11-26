#version 330 core
in vec2 vTextureCoord;

uniform sampler2D uCurFrame;

out vec4 FragColor;

void main() {
  vec3 color = texture(uCurFrame, vTextureCoord).rgb;
  color = pow(color, vec3(1.0 / 2.2));
  FragColor = vec4(color, 1.0);
}