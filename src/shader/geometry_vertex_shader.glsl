#version 330 core
layout(location = 0) in vec3 aPos;
layout(location = 1) in vec2 aTex;
layout(location = 2) in vec3 aNor;
layout(location = 3) in vec4 aTan;
uniform mat4 uModelMatrix;
uniform mat4 uViewMatrix;
uniform mat4 uProjectionMatrix;

uniform mat4 uPreViewMatrix;
uniform mat4 uPreProjectionMatrix;

uniform int uOffsetIdx;

out vec2 vTextureCoord;
out vec3 vNormal;
out vec3 vFragPos;
out vec3 vTangent;
out vec3 vBitangent;
out float vDepth;

out vec4 vPrePos;
out vec4 vCurPos;

const vec2 Halton_2_3[8] = vec2[8]
(
    vec2(0.0f, -1.0f / 3.0f),
    vec2(-1.0f / 2.0f, 1.0f / 3.0f),
    vec2(1.0f / 2.0f, -7.0f / 9.0f),
    vec2(-3.0f / 4.0f, -1.0f / 9.0f),
    vec2(1.0f / 4.0f, 5.0f / 9.0f),
    vec2(-1.0f / 4.0f, -5.0f / 9.0f),
    vec2(3.0f / 4.0f, 1.0f / 9.0f),
    vec2(-7.0f / 8.0f, 7.0f / 9.0f)
);

void main() {
  vFragPos = (uModelMatrix * vec4(aPos, 1.0)).xyz;
  vNormal = (uModelMatrix * vec4(aNor, 0.0)).xyz;
  vTextureCoord = aTex;
  vTangent = (uModelMatrix * vec4(aTan.xyz, 0.0)).xyz;
  vBitangent = cross(vNormal, vTangent) * aTan.w;


  vPrePos = uPreProjectionMatrix * uPreViewMatrix * uModelMatrix * vec4(aPos, 1.0);
  vCurPos = uProjectionMatrix * uViewMatrix * uModelMatrix * vec4(aPos, 1.0);

  float deltaWidth = 1.0 / 1080, deltaHeight = 1.0 / 1080;
  vec2 jitter = vec2(
      Halton_2_3[uOffsetIdx].x * deltaWidth,
      Halton_2_3[uOffsetIdx].y * deltaHeight
  );
  mat4 jitterMat = uProjectionMatrix;
  jitterMat[2][0] += jitter.x;
  jitterMat[2][1] += jitter.y;

  gl_Position = jitterMat * uViewMatrix * uModelMatrix * vec4(aPos, 1.0);
  vDepth = gl_Position.w;

}