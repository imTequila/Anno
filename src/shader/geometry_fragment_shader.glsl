#version 330 core
in vec2 vTextureCoord;
in vec3 vNormal;
in vec3 vFragPos;
in vec3 vTangent;
in vec3 vBitangent;

uniform int uEnableBump;
uniform int uEnableOcclusion;
uniform int uEnableEmission;

uniform vec4 uBasecolor;
uniform float uMetalness;
uniform float uRoughness;

uniform sampler2D uBasecolorMap;
uniform sampler2D uMetalnessMap;
uniform sampler2D uRoughnessMap;
uniform sampler2D uNormalMap;
uniform sampler2D uOcclusionMap;
uniform sampler2D uEmissionMap;


layout (location = 0) out vec3 g_position;
layout (location = 1) out vec3 g_normal;
layout (location = 2) out vec3 g_basecolor;
layout (location = 3) out vec3 g_rmo;
layout (location = 4) out vec3 g_emission;

void main() {
    
  g_position = vFragPos;

  vec3 N = normalize(vNormal);
  if (uEnableBump == 1) {
    vec3 T = normalize(vTangent);
    vec3 B = normalize(vBitangent);
    mat3 TBN = mat3(T, B, N);
    vec3 normal_from_map = normalize(texture(uNormalMap, vTextureCoord).rgb * 2.0 - 1.0);
    N = TBN * normal_from_map;
  }
  g_normal = N;

  vec3 albedo;
  if (uBasecolor.r < 0) {
    albedo = pow(texture(uBasecolorMap, vTextureCoord).rgb, vec3(2.2));
  } else {
    albedo = pow(uBasecolor.rgb, vec3(2.2));
  }
  g_basecolor = albedo;

  float roughness;
  if (uRoughness < 0) {
    roughness = clamp(texture(uRoughnessMap, vTextureCoord).r, 0.001, 0.999);
  } else {
    roughness = clamp(uRoughness, 0.001, 0.999);
  }
  g_rmo.r = roughness;

  float metallic;
  if (uMetalness < 0) {
    metallic = texture(uMetalnessMap, vTextureCoord).r;
  } else {
    metallic = uMetalness;
  }
  g_rmo.g = metallic;

  float occlusion = 1.0f;
  if (uEnableOcclusion == 1) {
    occlusion = texture(uOcclusionMap, vTextureCoord).r;
  }
  g_rmo.b = occlusion;

  if (uEnableEmission == 1) {
    g_emission = texture(uEmissionMap, vTextureCoord).rgb;
  }else {
    g_emission = vec3(0.0);
  }

}