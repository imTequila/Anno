#version 330 core
in vec2 vTextureCoord;
in mat4 vWorldToScreen;

uniform vec3 uLightPos;
uniform vec3 uCameraPos;

uniform sampler2D uPosition;
uniform sampler2D uNormal;
uniform sampler2D uBasecolor;
uniform sampler2D uRMO;
uniform sampler2D uEmission;
uniform sampler2D uDepth;

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

vec2 GetScreenCoordinate(vec3 pos) {
  vec4 screen_coor = vWorldToScreen * vec4(pos, 1.0);
  vec2 uv = (screen_coor.xy / screen_coor.w) * 0.5 + 0.5;
  return uv;
}

float GetDepth(vec3 pos) {
  vec4 screen_coor = vWorldToScreen * vec4(pos, 1.0);
  return screen_coor.z / screen_coor.w;
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

bool RayMarch(vec3 ori, vec3 dir, out vec3 hit) {
  float step = 0.005;
  const int total_step_times = 300;
  int cur_times = 0;

  vec3 dir_step = normalize(dir) * step;
  vec3 cur_position = ori;

  while (cur_times < total_step_times) {
    vec2 uv = GetScreenCoordinate(cur_position);
    if (uv.x > 1.0 || uv.x < 0.0 || uv.y > 1.0 || uv.y < 0.0){
      return false;
    }
    float ray_depth = GetDepth(cur_position);
    float depth = texture(uDepth, uv).r;
    if(depth < 0.000001) depth = 10000;
    if (ray_depth > depth + 0.0001) {
      hit = cur_position;
      return true;
    }
    cur_position += dir_step;
    cur_times ++;
  }

  return false;
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

  float roughness =clamp(texture(uRMO, vTextureCoord).r, 0.05, 0.995);

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
  vec3 prefilter_color = textureLod(uPrefilterMap, R, roughness * MAX_LOD).rgb;
  vec2 env_brdf =
      texture(uBRDFLut_ibl, vec2(max(dot(N, V), 0.0)), roughness).rg;
  float occlusion = texture(uRMO, vTextureCoord).b;
  vec3 ibl = prefilter_color * (F * env_brdf.x + env_brdf.y) * occlusion;


/*
 *  vec3 light_space = vShadowPos.xyz / vShadowPos.w;
 *  light_space = light_space * 0.5 + 0.5;
 *  float depth = texture(uShadowMap, light_space.xy).r;
 *  float shadow = depth < light_space.z - 0.009? 0.0 : 1.0;
 */

  const uint SAMPLE_NUM = 4u;
  vec3 Lo_dir = vec3(0.0);
  uint total = 0u;
  for(uint i = 0u; i < SAMPLE_NUM; i++) {
    vec2 Xi = Hammersley(i, SAMPLE_NUM);
    vec3 sample_vector = normalize(ImportanceSampleGGX(Xi, R, roughness));
    float NdotSample = dot(N, sample_vector);
    vec3 hit;
    if (RayMarch(position, sample_vector, hit)) {
      vec2 uv = GetScreenCoordinate(hit);
      if (uv.x > 1.0 || uv.x < 0.0 || uv.y > 1.0 || uv.y < 0.0){
        continue;
      }
      vec3 hit_albedo = texture(uBasecolor, uv).rgb;
      vec3 hit_normal = texture(uNormal, uv).rgb;
      float hit_roughness = texture(uRMO, uv).r;
      float hit_metallic = texture(uRMO, uv).g;
      vec3 hit_emission = texture(uEmission, uv).rgb;
      vec3 hit_light = normalize(uLightPos - hit);
      vec3 hit_view = normalize(position - hit);
      vec3 hit_half = normalize(hit_light + hit_view);

      float hit_NdotL = dot(hit_normal, hit_light);
      float hit_NdotV = dot(hit_normal, hit_view);

      vec3 hit_F0 = vec3(0.04);
      hit_F0 = mix(hit_F0, hit_albedo, hit_metallic);
      float hit_NDF = DistributionGGX(hit_normal, hit_half, hit_roughness);
      float hit_G = GeometrySmith(hit_normal, hit_view, hit_light, hit_roughness);
      vec3 hit_F = FresnelSchlick(hit_F0, hit_view, hit_half);

      vec3 hit_kS = hit_F;
      vec3 hit_kD = vec3(1.0) - hit_kS;
      hit_kD *= (1.0 - hit_metallic);

      vec3 hit_numerator = hit_NDF * hit_F * hit_G;
      float hit_denominator = max((4.0 * hit_NdotL * hit_NdotV), 0.001);
      vec3 hit_Fmicro = hit_numerator / hit_denominator;
      vec3 hit_BRDF = hit_Fmicro + (hit_kD * hit_albedo / PI);

      Lo_dir += radiance;
      total ++;
    }
  }
  Lo_dir /= SAMPLE_NUM;

  vec3 ssr = Lo_dir * (F * env_brdf.x + env_brdf.y);

  Lo += radiance * BRDF * NdotL;
  Lo += ssr;
  Lo += (ibl * (SAMPLE_NUM - total) / SAMPLE_NUM);
  vec3 color = Lo;
  color += texture(uEmission, vTextureCoord).rgb;
  color = color / (color + vec3(1.0));
  color = pow(color, vec3(1.0 / 2.2));
  FragColor = vec4(color, 1.0);
}