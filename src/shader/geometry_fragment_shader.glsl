#version 330 core
in vec2 vTextureCoord;
in vec3 vNormal;
in vec3 vFragPos;
in vec3 vTangent;
in vec3 vBitangent;
in float vDepth;

in vec4 vPrePos;
in vec4 vCurPos;

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


layout (location = 0) out vec3 gPosition;
layout (location = 1) out vec3 gNormal;
layout (location = 2) out vec4 gBasecolor;
layout (location = 3) out vec3 gRMO;
layout (location = 4) out vec3 gEmission;
layout (location = 5) out float gDepth;
layout (location = 6) out vec2 gVelocity;

void main() {
    
  gPosition = vFragPos;
  gDepth = gl_FragCoord.z;

  vec3 N = normalize(vNormal);
  if (uEnableBump == 1) {
    vec3 T = normalize(vTangent);
    vec3 B = normalize(vBitangent);
    mat3 TBN = mat3(T, B, N);
    vec3 mapNormal = normalize(texture(uNormalMap, vTextureCoord).rgb * 2.0 - 1.0);
    N = TBN * mapNormal;
  }
  gNormal = N;

  vec3 albedo;
  if (uBasecolor.r < 0) {
    albedo = pow(texture(uBasecolorMap, vTextureCoord).rgb, vec3(2.2));
  } else {
    albedo = pow(uBasecolor.rgb, vec3(2.2));
  }
  gBasecolor = vec4(albedo, 1.0);

  float roughness;
  if (uRoughness < 0) {
    roughness = clamp(texture(uRoughnessMap, vTextureCoord).r, 0.001, 0.999);
  } else {
    roughness = clamp(uRoughness, 0.001, 0.999);
  }
  gRMO.r = roughness;

  float metallic;
  if (uMetalness < 0) {
    metallic = texture(uMetalnessMap, vTextureCoord).r;
  } else {
    metallic = uMetalness;
  }
  gRMO.g = metallic;

  float occlusion = 1.0f;
  if (uEnableOcclusion == 1) {
    occlusion = texture(uOcclusionMap, vTextureCoord).r;
  }
  gRMO.b = occlusion;

  if (uEnableEmission == 1) {
    gEmission = pow(texture(uEmissionMap, vTextureCoord).rgb, vec3(2.2));
  }else {
    gEmission = vec3(0.0);
  }

  vec2 preScreen = ((vPrePos.xy / vPrePos.w) * vec2(0.5) + vec2(0.5));
  vec2 curScreen = ((vCurPos.xy / vCurPos.w) * vec2(0.5) + vec2(0.5));
  gVelocity = preScreen - curScreen;
}