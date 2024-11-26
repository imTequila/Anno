/* 
  forward pipeline, abandoned
*/

#version 330 core
in vec2 vTextureCoord;
in vec3 vNormal;
in vec3 vFragPos;
in vec4 vShadowPos;
in vec3 vTangent;
in vec3 vBitangent;

uniform int uEnableBump;
uniform int uEnableOcclusion;
uniform int uEnableEmission;

uniform vec3 uLightPos;
uniform vec3 uCameraPos;

uniform vec4 uBasecolor;
uniform float uMetalness;
uniform float uRoughness;

uniform sampler2D uBasecolorMap;
uniform sampler2D uMetalnessMap;
uniform sampler2D uRoughnessMap;
uniform sampler2D uNormalMap;
uniform sampler2D uOcclusionMap;
uniform sampler2D uEmissionMap;

uniform samplerCube uPrefilterMap;
uniform sampler2D uBRDFLut_ibl;

uniform sampler2D uBRDFLut;
uniform sampler2D uEavgLut;

uniform sampler2D uShadowMap;
 
out vec4 FragColor;

const float PI = 3.14159265359;

float DistributionGGX(vec3 N, vec3 H, float roughness) {
  float alpha2 = roughness * roughness * roughness * roughness;
  float NdotH = dot(N, H);
  float NdotH2 = NdotH * NdotH;
  float denom = (NdotH2 * (alpha2 - 1.0) + 1.0);
  float GGX = alpha2 / (PI * denom * denom);
  return GGX;
}

float GeometrySchlickGGX(float NdotV, float roughness) {
  float k = (roughness + 1.0) * (roughness + 1.0) / 8.0;
  return NdotV / (NdotV * (1.0 - k) + k);
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
  float NdotV = max(dot(N, V), 0.0);
  float NdotL = max(dot(N, L), 0.0);
  float ggx2 = GeometrySchlickGGX(NdotV, roughness);
  float ggx1 = GeometrySchlickGGX(NdotL, roughness);

  return ggx1 * ggx2;
}

vec3 FresnelSchlick(vec3 F0, vec3 V, vec3 H) {
  return F0 + (1.0 - F0) * pow(clamp(1.0 - max(dot(H, V), 0.0), 0.0, 1.0), 5.0);
}

vec3 FresnelSchlickRoughness(float cosTheta, vec3 F0, float roughness)
{
    return F0 + (max(vec3(1.0 - roughness), F0) - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
} 

vec3 AverageFresnel(vec3 r, vec3 g) {
  return vec3(0.087237) + 0.0230685 * g - 0.0864902 * g * g +
         0.0774594 * g * g * g + 0.782654 * r - 0.136432 * r * r +
         0.278708 * r * r * r + 0.19744 * g * r + 0.0360605 * g * g * r -
         0.2586 * g * r * r;
}

vec3 MultiScatterBRDF(float NdotL, float NdotV, float roughness) {
  vec3 albedo;
  if (uBasecolor.r < 0) {
    albedo = pow(texture(uBasecolorMap, vTextureCoord).rgb, vec3(2.2));
  } else {
    albedo = pow(uBasecolor.rgb, vec3(2.2));
  }

  vec3 Eo = texture(uBRDFLut, vec2(NdotL, roughness)).xyz;
  vec3 Ei = texture(uBRDFLut, vec2(NdotV, roughness)).xyz;

  vec3 Eavg = texture2D(uEavgLut, vec2(0, roughness)).xyz;

  vec3 edgetint = vec3(0.827, 0.792, 0.678);
  vec3 Favg = AverageFresnel(albedo, edgetint);

  vec3 Fms =
      (vec3(1.0) - Eo) * (vec3(1.0) - Ei) / (PI * (vec3(1.0) - Eavg));
  vec3 Fadd = Favg * Eavg / (vec3(1.0) - Favg * (vec3(1.0) - Eavg));
  return Fadd * Fms;
}

void main() {
  vec3 albedo;
  if (uBasecolor.r < 0) {
    albedo = pow(texture(uBasecolorMap, vTextureCoord).rgb, vec3(2.2));
  } else {
    albedo = pow(uBasecolor.rgb, vec3(2.2));
  }

  vec3 N = normalize(vNormal);
  
  if (uEnableBump == 1) {
    vec3 T = normalize(vTangent);
    vec3 B = normalize(vBitangent);
    mat3 TBN = mat3(T, B, N);
    vec3 normal_from_map = normalize(texture(uNormalMap, vTextureCoord).rgb * 2.0 - 1.0);
    N = TBN * normal_from_map;
  }
  vec3 V = normalize(uCameraPos - vFragPos);
  float NdotV = max(dot(N, V), 0.0);

  float metallic;
  if (uMetalness < 0) {
    metallic = texture(uMetalnessMap, vTextureCoord).r;
  } else {
    metallic = uMetalness;
  }

  vec3 F0 = vec3(0.04);
  F0 = mix(F0, albedo, metallic);

  vec3 Lo = vec3(0.0);

  vec3 lightDir = uLightPos - vFragPos;
  vec3 L = normalize(lightDir);
  vec3 H = normalize(V + L);
  float NdotL = max(dot(N, L), 0.0);

  vec3 radiance = vec3(1.0f, 1.0f, 1.0f);

  float roughness;
  if (uRoughness < 0) {
    roughness = clamp(texture(uRoughnessMap, vTextureCoord).r, 0.001, 0.999);
  } else {
    roughness = clamp(uRoughness, 0.001, 0.999);
  }

  float NDF = DistributionGGX(N, H, roughness);
  float G = GeometrySmith(N, V, L, roughness);
  vec3 F = FresnelSchlick(F0, V, H);

  vec3 kS = F;
  vec3 kD = vec3(1.0) - kS;
  kD *= (1.0 - metallic);

  vec3 numerator = NDF * F * G;
  float denominator = max((4.0 * NdotL * NdotV), 0.001);
  vec3 Fmicro = numerator / denominator;
  vec3 Fms = MultiScatterBRDF(NdotL, NdotV, roughness);
  vec3 BRDF = Fms + Fmicro + (kD * albedo / PI);

  vec3 R = reflect(-V, N);
  const float MAX_LOD = 4.0;
  vec3 prefilterColor = textureLod(uPrefilterMap, R, roughness * MAX_LOD).rgb;
  vec2 envBRDF =
      texture(uBRDFLut_ibl, vec2(max(dot(N, V), 0.0)), roughness).rg;
  float occlusion = 1.0f;
  if (uEnableOcclusion == 1) {
    occlusion = texture(uOcclusionMap, vTextureCoord).r;
  }
  vec3 Fibl = FresnelSchlickRoughness(max(dot(N, V), 0.0), F0, roughness);
  vec3 ibl = prefilterColor * (Fibl * envBRDF.x + envBRDF.y) * occlusion;

  Lo += radiance * BRDF * NdotL;
  Lo += ibl;
  vec3 color = Lo;
  if (uEnableEmission == 1) {
    color += pow(texture(uEmissionMap, vTextureCoord).rgb,vec3(2.2));
  }

  color = color / (color + vec3(1.0));
  color = pow(color, vec3(1.0 / 2.2));
  FragColor = vec4(color, 1.0);
}