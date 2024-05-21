#version 330 core
layout(location = 0) in vec3 aPos;
layout(location = 1) in vec2 aTex;
layout(location = 2) in vec3 aNor;
uniform mat4 uModelMatrix;
uniform mat4 uViewMatrix;
uniform mat4 uProjectionMatrix;
uniform mat4 uLightViewMatrix;
uniform mat4 uLightProjectionMatrix;

out vec2 vTextureCoord;
out vec3 vNormal;
out vec3 vFragPos;
out vec4 vShadowPos;

void main() {
  vFragPos = (uModelMatrix * vec4(aPos, 1.0)).xyz;
  vNormal = (uModelMatrix * vec4(aNor, 0.0)).xyz;
  vTextureCoord = aTex;
  vShadowPos = uProjectionMatrix * uViewMatrix * uModelMatrix * vec4(aPos, 1.0);
  gl_Position =
      uProjectionMatrix * uViewMatrix * uModelMatrix * vec4(aPos, 1.0);
}