/* 
  forward pipeline, abandoned
*/

#version 330 core
layout(location = 0) in vec3 aPos;
layout(location = 1) in vec2 aTex;
layout(location = 2) in vec3 aNor;
layout(location = 3) in vec4 aTan;

uniform mat4 uModelMatrix;
uniform mat4 uViewMatrix;
uniform mat4 uProjectionMatrix;
uniform mat4 uLightViewMatrix;
uniform mat4 uLightProjectionMatrix;

out vec2 vTextureCoord;
out vec3 vNormal;
out vec3 vFragPos;
out vec4 vShadowPos;
out vec3 vTangent;
out vec3 vBitangent;


void main() {
  vFragPos = (uModelMatrix * vec4(aPos, 1.0)).xyz;
  vNormal = (uModelMatrix * vec4(aNor, 0.0)).xyz;
  vTextureCoord = aTex;
  vShadowPos = uLightProjectionMatrix * uLightViewMatrix * uModelMatrix * vec4(aPos, 1.0);
  vTangent = (uModelMatrix * vec4(aTan.xyz, 0.0)).xyz;
  vBitangent = cross(vNormal, vTangent) * aTan.w;

  gl_Position =
      uProjectionMatrix * uViewMatrix * uModelMatrix * vec4(aPos, 1.0);

}