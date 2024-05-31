#version 330 core
in vec2 vTextureCoord;

uniform vec3 uLightPos;
uniform vec3 uCameraPos;

uniform sampler2D uPosition;
uniform sampler2D uNormal;
uniform sampler2D uBasecolor;
uniform sampler2D uRMO;
uniform sampler2D uEmission;

uniform samplerCube uPrefilterMap;
uniform sampler2D uBRDFLut_ibl;

uniform sampler2D uBRDFLut;
uniform sampler2D uEavgLut;

out vec4 FragColor;

const float PI = 3.14159265359;

float DistributionGGX(vec3 N, vec3 H, float roughness) {
  float alpha2 = roughness * roughness * roughness * roughness;
  float NdotH = dot(N, H);
  float NdotH2 = NdotH * NdotH;
  float denom = (NdotH2 * (alpha2 - 1.0) + 1.0);
  float GGX = alpha2 / (PI * denom * denom);
  if (GGX > 0.0)
    return GGX;
  return 0.0001;
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

vec3 AverageFresnel(vec3 r, vec3 g) {
  return vec3(0.087237) + 0.0230685 * g - 0.0864902 * g * g +
         0.0774594 * g * g * g + 0.782654 * r - 0.136432 * r * r +
         0.278708 * r * r * r + 0.19744 * g * r + 0.0360605 * g * g * r -
         0.2586 * g * r * r;
}

vec3 MultiScatterBRDF(float NdotL, float NdotV, float roughness) {
  vec3 albedo = texture(uBasecolor, vTextureCoord).rgb;

  vec3 E_o = texture(uBRDFLut, vec2(NdotL, roughness)).xyz;
  vec3 E_i = texture(uBRDFLut, vec2(NdotV, roughness)).xyz;

  vec3 E_avg = texture2D(uEavgLut, vec2(0, roughness)).xyz;

  vec3 edgetint = vec3(0.827, 0.792, 0.678);
  vec3 F_avg = AverageFresnel(albedo, edgetint);

  vec3 F_ms =
      (vec3(1.0) - E_o) * (vec3(1.0) - E_i) / (PI * (vec3(1.0) - E_avg));
  vec3 F_add = F_avg * E_avg / (vec3(1.0) - F_avg * (vec3(1.0) - E_avg));
  return F_add * F_ms;
}

void main() {
  vec3 albedo = texture(uBasecolor, vTextureCoord).rgb;
  float alpha = texture(uBasecolor, vTextureCoord).a;
  if (alpha < 0.1) {
    discard;
  }
  vec3 position = texture(uPosition, vTextureCoord).rgb;
  vec3 N = texture(uNormal, vTextureCoord).rgb;

  vec3 V = normalize(uCameraPos - position);
  float NdotV = max(dot(N, V), 0.0);

  float metallic = texture(uRMO, vTextureCoord).g;

  vec3 F0 = vec3(0.04);
  F0 = mix(F0, albedo, metallic);

  vec3 Lo = vec3(0.0);

  vec3 lightDir = uLightPos - position;
  vec3 L = normalize(lightDir);
  vec3 H = normalize(V + L);
  float NdotL = max(dot(N, L), 0.0);

  vec3 radiance = vec3(1.0f, 1.0f, 1.0f);

  float roughness = texture(uRMO, vTextureCoord).r;

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
  // vec3 BRDF = Fmicro + Fms + (kD * albedo / PI);
  vec3 BRDF = Fms + Fmicro;

  vec3 R = reflect(-V, N);
  const float MAX_LOD = 4.0;
  vec3 prefilter_color = textureLod(uPrefilterMap, R, roughness * MAX_LOD).rgb;
  vec2 env_brdf =
      texture(uBRDFLut_ibl, vec2(max(dot(N, V), 0.0)), roughness).rg;
  float occlusion = texture(uRMO, vTextureCoord).b;
  vec3 ibl = prefilter_color * (F * env_brdf.x + env_brdf.y) * occlusion;



//   vec3 light_space = vShadowPos.xyz / vShadowPos.w;
//   light_space = light_space * 0.5 + 0.5;
//   float depth = texture(uShadowMap, light_space.xy).r;
//   float shadow = depth < light_space.z - 0.009? 0.0 : 1.0;

  Lo += radiance * BRDF * NdotL;
  Lo += ibl;
  vec3 color = Lo;
  color += texture(uEmission, vTextureCoord).rgb;

  color = color / (color + vec3(1.0));
  color = pow(color, vec3(1.0 / 2.2));

  FragColor = vec4(color, 1.0);
}