#version 330 core
in vec2 vTextureCoord;

uniform vec3 uLightPos;
uniform vec3 uCameraPos;

uniform mat4 uWorldToScreen;
uniform mat4 uLightView;
uniform mat4 uLightWorldToScreen;

uniform sampler2D uPosition;
uniform sampler2D uNormal;
uniform sampler2D uBasecolor;
uniform sampler2D uRMO;
uniform sampler2D uEmission;
uniform sampler2D uDepth;
uniform sampler2D uShadowMap;

uniform sampler2D uBRDFLut_ibl;

uniform sampler2D uBRDFLut;
uniform sampler2D uEavgLut;

out vec4 FragColor;

const float PI = 3.14159265359;

const float g_DistributeFPFactor = 256;
vec2 RecombineFP(vec4 Value)
{
    float FactorInv = 1 / g_DistributeFPFactor;
    return (Value.zw * FactorInv + Value.xy);
}

float DistributionGGX(vec3 N, vec3 H, float roughness) {
  float alpha2 = roughness * roughness * roughness * roughness;
  float NdotH = dot(N, H);
  float denom = ( NdotH * alpha2 - NdotH ) * NdotH + 1;
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
  vec3 albedo = texture(uBasecolor, vTextureCoord).rgb;

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

vec2 GetScreenCoordinate(vec3 pos) {
  vec4 screenCoor = uWorldToScreen * vec4(pos, 1.0);
  vec2 uv = (screenCoor.xy / screenCoor.w) * 0.5 + 0.5;
  return uv;
}

float GetDepth(vec3 pos) {
  vec4 screenCoor = uWorldToScreen * vec4(pos, 1.0);
  return screenCoor.w;
}

float VanDerCorput(uint bits) {
  bits = (bits << 16u) | (bits >> 16u);
  bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
  bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
  bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
  bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
  return float(bits) * 2.3283064365386963e-10;
}

vec2 Hammersley(uint i, uint N) {
  return vec2(float(i) / float(N), VanDerCorput(i));
}

vec3 ImportanceSampleGGX(vec2 Xi, vec3 N, float roughness) {
  float a = roughness * roughness;

  float phi = 2.0 * PI * Xi.x;
  float cosTheta = sqrt((1.0 - Xi.y) / (1.0 + (a * a - 1.0) * Xi.y));
  float sinTheta = sqrt(1.0 - cosTheta * cosTheta);

  vec3 H;
  H.x = cos(phi) * sinTheta;
  H.y = sin(phi) * sinTheta;
  H.z = cosTheta;

  vec3 up = abs(N.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
  vec3 tangent = normalize(cross(up, N));
  vec3 bitangent = cross(N, tangent);

  vec3 sampleVec = tangent * H.x + bitangent * H.y + N * H.z;
  return normalize(sampleVec);
}

vec4 sampleSAT(vec4 coords) {
  vec4 nn = texture2D(uShadowMap, coords.xy);
  vec4 np = texture2D(uShadowMap, coords.xw);
  vec4 pn = texture2D(uShadowMap, coords.zy);
  vec4 pp = texture2D(uShadowMap, coords.zw);
  
  return (pp - pn - np + nn);
}

float Luminance(vec3 color)
{
  return 0.25 * color.r + 0.5 * color.g + 0.25 * color.b;
}

vec3 ToneMap(vec3 color)
{
  return color / (1 + Luminance(color));
}

vec3 UnToneMap(vec3 color)
{
  return color / (1 - Luminance(color));
}

float linstep(float min, float max, float v)
{
    return clamp((v - min) / (max - min), 0, 1);
}

void main() {
  vec3 position = texture(uPosition, vTextureCoord).rgb;

  vec3 albedo = texture(uBasecolor, vTextureCoord).rgb;
  float alpha = texture(uBasecolor, vTextureCoord).a;
  if (alpha < 0.1) {
    discard;
  }

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

  float roughness = clamp(texture(uRMO, vTextureCoord).r, 0.01, 0.999);

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

  float shadow = 1.0;
  vec4 lightViewCoord = uLightView * vec4(position, 1.0);
  vec4 lightClipCoord = uLightWorldToScreen * vec4(position, 1.0);
  vec3 lightScreenCoord = (lightClipCoord.xyz / lightClipCoord.w) * 0.5 + 0.5;

  float dist = length(lightViewCoord.xyz);
  const int shadowSize = 512;
  const float width = 16;
  const vec2 shadowOffset = vec2(width / shadowSize);
  const vec2 normalOffset = vec2(1.0 / shadowSize);
  vec4 coords = vec4(lightScreenCoord.xy - shadowOffset- normalOffset, lightScreenCoord.xy + shadowOffset);

  if (coords.x <= 0 || coords.x >= 1 || coords.y <= 0 || coords.y >= 1 || coords.z <= 0 || coords.z >= 1 || coords.w <= 0 || coords.w >= 1) {
    shadow = 1.0;
  }else {
    vec4 moment = sampleSAT(coords) / ((2 * width + 1) * (2 * width + 1));
    vec2 value = RecombineFP(moment) - vec2(0.5, 0.0);
    float variance = value.y - (value.x * value.x);
    variance = max(0.000001, variance);
    float d = dist - value.x;
    float pMax = variance / (variance + d * d);
    float p;
    if (dist <= value.x) p = 1;
    else p = 0;
    shadow = max(p, pMax);
    shadow = linstep(0.18, 1, shadow);
  }

  Lo += radiance * BRDF * NdotL;
  vec3 color = ToneMap(Lo) * shadow;

  color += texture(uEmission, vTextureCoord).rgb;
  FragColor = vec4(UnToneMap(color), 1.0);
}