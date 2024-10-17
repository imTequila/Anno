#version 330 core
in vec3 vWorldPos;

uniform samplerCube uEnvironmentMap;
uniform float uRoughness;

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

void main() {
  vec3 N = normalize(vWorldPos);
  vec3 R = N;
  vec3 V = R;

  const uint SAMPLE_COUNT = 1024u;
  float totalWeight = 0.0;
  vec3 prefilteredColor = vec3(0.0);
  for (uint i = 0u; i < SAMPLE_COUNT; ++i) {
    vec2 Xi = Hammersley(i, SAMPLE_COUNT);
    vec3 H = ImportanceSampleGGX(Xi, N, uRoughness);
    vec3 L = normalize(2.0 * dot(V, H) * H - V);

    float NdotL = max(dot(N, L), 0.0);
    if (NdotL > 0.0) {
      vec3 sampleColor = texture(uEnvironmentMap, L).rgb;
      prefilteredColor += sampleColor * NdotL;
      totalWeight += NdotL;
    }
  }
  prefilteredColor = prefilteredColor / totalWeight;
  FragColor = vec4(prefilteredColor, 1.0);
}
