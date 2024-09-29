#version 330 core
in vec2 vTextureCoord;
in mat4 vWorldToScreen;

uniform sampler2D uShadingColor;
uniform sampler2D uPosition;
uniform sampler2D uDepth;
uniform sampler2D uBaseColor;
uniform sampler2D uRMO;
uniform sampler2D uNormal;
uniform sampler2D uBRDFLut_ibl;

uniform vec3 uCameraPos;

out vec4 FragColor;

const float PI = 3.14159265359;

vec3 FresnelSchlickRoughness(float cosTheta, vec3 F0, float roughness)
{
    return F0 + (max(vec3(1.0 - roughness), F0) - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
} 

vec2 GetScreenCoordinate(vec3 pos) {
  vec4 screen_coor = vWorldToScreen * vec4(pos, 1.0);
  vec2 uv = (screen_coor.xy / screen_coor.w) * 0.5 + 0.5;
  return uv;
}

float GetDepth(vec3 pos) {
  vec4 screen_coor = vWorldToScreen * vec4(pos, 1.0);
  return screen_coor.w;
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
  float step = 0.05;
  const int total_step_times = 1000;
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

    if (ray_depth - depth > 0.01) {
      hit = cur_position;
      return true;
    }
    cur_position += dir_step;
    cur_times ++;
  }

  return false;
}

/** Unreal Implement */
float GetStepScreenFactorToClipAtScreenEdge(vec2 RayStartScreen, vec2 RayStepScreen)
{
	// Computes the scale down factor for RayStepScreen required to fit on the X and Y axis in order to clip it in the viewport
  float Length = sqrt(RayStepScreen.x * RayStepScreen.x + RayStepScreen.y * RayStepScreen.y);
	float RayStepScreenInvFactor = 0.5 * Length;
	vec2 S = 1 - max(abs(RayStepScreen + RayStartScreen * RayStepScreenInvFactor) - RayStepScreenInvFactor, 0.0f) / abs(RayStepScreen);

	// Rescales RayStepScreen accordingly
	float RayStepFactor = min(S.x, S.y) / RayStepScreenInvFactor;

	return RayStepFactor;
}

bool RayMarchByUV(vec2 ori, vec2 dir, float oriZ, float deltaZ, out vec2 hit) {
  const int total_step_times = 500;
  
  float fractor = abs(GetStepScreenFactorToClipAtScreenEdge(ori, dir));
  vec2 sample_vector = dir * fractor;
  vec2 each_step = sample_vector / total_step_times;
  
  deltaZ *= fractor;
  deltaZ /= total_step_times;

  int cur_times = 1;
  while (cur_times < total_step_times) {
    vec2 uv = ori + (each_step * cur_times);
    if (uv.x > 1.0 || uv.x < 0.0 || uv.y > 1.0 || uv.y < 0.0){
      return false;
    }

    float ray_depth    = oriZ + (deltaZ * cur_times);
    float screen_depth = texture(uDepth, uv).r;
    if(screen_depth < 0.000001) screen_depth = 10000;

    if (ray_depth - screen_depth > 0.01) {
      hit = uv;
      return true;
    }
    cur_times ++;
  }
}

void main() {
  vec3 position = texture2D(uPosition, vTextureCoord).rgb;
  vec4 NDCPosition = vWorldToScreen * vec4(position, 1.0);
  vec3 N = texture2D(uNormal, vTextureCoord).rgb;
  vec3 V = normalize(uCameraPos - position);

  vec3 albedo = texture(uBaseColor, vTextureCoord).rgb;
  float roughness = texture2D(uRMO, vTextureCoord).r;
  float metallic = texture(uRMO, vTextureCoord).g;

  vec3 F0 = vec3(0.04);
  F0 = mix(F0, albedo, metallic);

  vec2 env_brdf = texture(uBRDFLut_ibl, vec2(max(dot(N, V), 0.0)), roughness).rg;


  vec3 R = normalize(reflect(-V, N));
  const uint SAMPLE_NUM = 1u;
  vec3 Lo_indir = vec3(0.0);
  uint total = 0u;
  
  for(uint i = 0u; i < SAMPLE_NUM; i++) {
    vec2 Xi = Hammersley(i, SAMPLE_NUM);
    vec3 sample_vector = normalize(ImportanceSampleGGX(Xi, R, roughness));
    vec3 sample_end_position = position + sample_vector;

    vec2 uv_ori = GetScreenCoordinate(position);
    vec2 uv_dir = GetScreenCoordinate(sample_end_position) - uv_ori;

    float NdotSample = dot(N, sample_vector);
    vec2 hit;
    if (RayMarchByUV(uv_ori, uv_dir, NDCPosition.w, sample_vector.z, hit)) {
      vec2 uv = hit;
      vec3 hitColor = texture2D(uShadingColor, uv).rgb;

      Lo_indir += hitColor;
      total ++;
    }
  }
  Lo_indir /= SAMPLE_NUM;
  vec3 F_ibl = FresnelSchlickRoughness(max(dot(N, V), 0.0), F0, roughness);
  vec3 ssr = Lo_indir * (F_ibl * env_brdf.x + env_brdf.y);

  vec3 color = texture(uShadingColor, vTextureCoord).rgb + ssr;
  color = color / (color + vec3(1.0));
  color = pow(color, vec3(1.0 / 2.2));
  FragColor = vec4(color, 1.0);
}