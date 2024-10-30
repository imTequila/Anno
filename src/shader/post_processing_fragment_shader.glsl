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
uniform samplerCube uPrefilterMap;

uniform vec3 uCameraPos;
uniform float uBlend;
uniform int uFrameCount;

out vec4 FragColor;

const float PI = 3.14159265359;
const float MAX_DIFF = 100;

vec3 FresnelSchlickRoughness(float cosTheta, vec3 F0, float roughness) {
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

uvec3 Rand3DPCG16(ivec3 p) {
	// taking a signed int then reinterpreting as unsigned gives good behavior for negatives
	uvec3 v = uvec3(p);

	// Linear congruential step. These LCG constants are from Numerical Recipies
	// For additional #'s, PCG would do multiple LCG steps and scramble each on output
	// So v here is the RNG state
	v = v * 1664525u + 1013904223u;

	// PCG uses xorshift for the final shuffle, but it is expensive (and cheap
	// versions of xorshift have visible artifacts). Instead, use simple MAD Feistel steps
	//
	// Feistel ciphers divide the state into separate parts (usually by bits)
	// then apply a series of permutation steps one part at a time. The permutations
	// use a reversible operation (usually ^) to part being updated with the result of
	// a permutation function on the other parts and the key.
	//
	// In this case, I'm using v.x, v.y and v.z as the parts, using + instead of ^ for
	// the combination function, and just multiplying the other two parts (no key) for 
	// the permutation function.
	//
	// That gives a simple mad per round.
	v.x += v.y*v.z;
	v.y += v.z*v.x;
	v.z += v.x*v.y;
	v.x += v.y*v.z;
	v.y += v.z*v.x;
	v.z += v.x*v.y;

	// only top 16 bits are well shuffled
	return v >> 16u;
}

uint ReverseBits32( uint bits ) {
	bits = uint (( bits << 16) | ( bits >> 16));
	bits = ( (bits & 0x00ff00ffu ) << 8u ) | ( (bits & 0xff00ff00u ) >> 8 );
	bits = ( (bits & 0x0f0f0f0fu ) << 4u ) | ( (bits & 0xf0f0f0f0u ) >> 4 );
	bits = ( (bits & 0x33333333u ) << 2u ) | ( (bits & 0xccccccccu ) >> 2 );
	bits = ( (bits & 0x55555555u ) << 1u ) | ( (bits & 0xaaaaaaaau ) >> 1 );
	return bits;
}

float Frac(float x) {
  if (x > 0) return x;
  else return x - int(x);
}

vec2 Hammersley16( uint Index, uint NumSamples, uvec2 random ) {
	float E1 = Frac( float( Index ) / NumSamples + float( random.x ) * (1.0 / 65536.0) );
	float E2 = float( ( ReverseBits32(Index) >> 16 ) ^ random.y ) * (1.0 / 65536.0);
	return vec2( E1, E2 );
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

vec3 ImportanceSampleGGX(vec2 xi, vec3 N, float roughness) {
  float a = roughness * roughness;

  float phi = 2.0 * PI * xi.x;
  float cosTheta = sqrt((1.0 - xi.y) / (1.0 + (a * a - 1.0) * xi.y));
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

float GetStepScreenFactorToClipAtScreenEdge(vec2 RayStartScreen, vec2 RayStepScreen) {
	// Computes the scale down factor for RayStepScreen required to fit on the X and Y axis in order to clip it in the viewport
  float Length = sqrt(RayStepScreen.x * RayStepScreen.x + RayStepScreen.y * RayStepScreen.y);
	float RayStepScreenInvFactor = 0.5 * Length;
	vec2 S = 1 - max(abs(RayStepScreen + RayStartScreen * RayStepScreenInvFactor) - RayStepScreenInvFactor, 0.0f) / abs(RayStepScreen);

	// Rescales RayStepScreen accordingly
	float RayStepFactor = min(S.x, S.y) / RayStepScreenInvFactor;

	return RayStepFactor;
}

float MaxOutDistance(vec3 ori, vec3 dir) {
  float maxOutDistance = 0;
  maxOutDistance = dir.x > 0 ? (1 - ori.x) / dir.x : -ori.x / dir.x;
  maxOutDistance = min(maxOutDistance, dir.y > 0 ? (1 - ori.y) / dir.y : -ori.y / dir.y);
  maxOutDistance = min(maxOutDistance, dir.z > 0 ? (1 - ori.z) / dir.z : -ori.z / dir.z);
  return maxOutDistance;
}

bool RayMarch(vec3 ori, vec3 dir, out vec2 hit) {
  const int total_step_times = 32 * 4 + 1;
  int cur_times = 1;

  ori += (0.01 * dir);

  vec4 start_clip = vWorldToScreen * vec4(ori, 1.0);
  vec4 end_clip = vWorldToScreen * vec4(ori + dir, 1.0);

  vec3 start_texture = (start_clip.xyz / start_clip.w) * 0.5 + 0.5;
  vec3 end_texture = (end_clip.xyz / end_clip.w) * 0.5 + 0.5;
  vec3 dir_texture = end_texture - start_texture;

  float maxOutDistance = MaxOutDistance(start_texture, dir_texture);
  // dir_texture *= maxOutDistance;
  // end_texture = start_texture + dir_texture;

  vec2 start_uv = start_texture.xy;   // texture space xy of start
  vec2 end_uv = end_texture.xy;       // texture space xy of end
  vec2 step_uv = end_uv - start_uv;

  float start_depth = start_clip.w;
  float end_depth = end_clip.w;
  float step_depth = end_depth - start_depth;

  float len = sqrt(step_uv.x * step_uv.x + step_uv.y * step_uv.y);
  float step = 0.004 / len;

  float LastDiff = 0;

  while (cur_times < total_step_times) {  
		vec2 SamplesUV[4];
		float SamplesZ[4];
		float SamplesDepth[4];
    float DiffDepth[4];
    bool FoundAny = false;
    bool OutBoundary = false;

    for (int i = 0; i < 4; i++) {
      SamplesUV[i] = start_uv + (cur_times + i) * (step * step_uv);
      SamplesZ[i] = start_depth + (cur_times + i) * (step * step_depth);
      SamplesDepth[i] = texture(uDepth, SamplesUV[i]).r;
      DiffDepth[i] = SamplesZ[i] - SamplesDepth[i];
      
      if (SamplesUV[i].x < 0 || SamplesUV[i].y < 0 || SamplesUV[i].x > 1 || SamplesUV[i].y > 1) {
        OutBoundary = true;
        DiffDepth[i] = -1;
      }

      if (SamplesDepth[i] < 0.01) {
        DiffDepth[i] = -1;
      }

      if (DiffDepth[i] > 0.01 && DiffDepth[i] < 1) FoundAny = true;
    }

    if (FoundAny) {
      float DepthDiff0 = DiffDepth[2];
      float DepthDiff1 = DiffDepth[3];
      float Time0 = 3;

      if ( DiffDepth[2] > 0.01 && DiffDepth[2] < 1)
      {
          DepthDiff0 = DiffDepth[1];
          DepthDiff1 = DiffDepth[2];
          Time0 = 2;
      }

      if ( DiffDepth[1] > 0.01 && DiffDepth[1] < 1)
      {
          DepthDiff0 = DiffDepth[0];
          DepthDiff1 = DiffDepth[1];
          Time0 = 1;
      }

      if ( DiffDepth[0] > 0.01 && DiffDepth[0] < 1)
      {
          DepthDiff0 = LastDiff;
          DepthDiff1 = DiffDepth[0];
          Time0 = 0;
      }
      Time0 += float(cur_times);
      float Time1 = Time0 + 1;
      float TimeLerp = clamp(abs(DepthDiff0) / (abs(DepthDiff0) + abs(DepthDiff1)), 0.0, 1.0);
      float IntersectTime = Time0 + TimeLerp;
      hit =  start_uv + IntersectTime * step_uv * step;
      if (texture2D(uDepth, hit).r >= 0.001) {
        return true;
      }
    }
    if (OutBoundary) return false;
    cur_times += 4;
  }

  // while (cur_times < total_step_times) {
  //   vec2 uv = start_uv + cur_times * (step_uv * step);
  //   float depth = start_depth + cur_times * (step_depth * step);
  //   float scene_depth = texture(uDepth, uv).r;
  //   if (depth - scene_depth > 0.001){
  //     hit = ori + cur_times * dir_step;
  //     return true;
  //   }
  //   cur_times ++;
  // }

  return false;
}

void main() {
  vec3 position = texture2D(uPosition, vTextureCoord).rgb;
  vec3 N = texture2D(uNormal, vTextureCoord).rgb;
  vec3 V = normalize(uCameraPos - position);

  vec3 albedo = texture(uBaseColor, vTextureCoord).rgb;
  float roughness = texture2D(uRMO, vTextureCoord).r;
  float metallic = texture(uRMO, vTextureCoord).g;

  vec3 F0 = vec3(0.04);
  F0 = mix(F0, albedo, metallic);

  vec2 envBRDF = texture(uBRDFLut_ibl, vec2(max(dot(N, V), 0.0)), roughness).rg;


  vec3 R = normalize(reflect(-V, N));
  const uint SAMPLE_NUM = 4u;
  vec3 indirLo = vec3(0.0);
  uint total = 0u;
  
  uvec2 random = Rand3DPCG16( ivec3( vTextureCoord * 1080, uFrameCount % 32 ) ).xy;

  for(uint i = 0u; i < SAMPLE_NUM; i++) {
    vec2 xi = Hammersley16(i, SAMPLE_NUM, random);
    vec3 sampleVector = normalize(ImportanceSampleGGX(xi, R, roughness));

    float NdotSample = dot(N, sampleVector);
    vec2 hit;
    if (RayMarch(position, sampleVector, hit)) {
      vec2 uv = hit;
      vec3 hitColor = texture2D(uShadingColor, uv).rgb;

      indirLo += (hitColor);
      total ++;
    }
  }
  if (total > 0u)
    indirLo /= total;
  vec3 Fibl = FresnelSchlickRoughness(max(dot(N, V), 0.0), F0, roughness);
  vec3 ssr = indirLo * (Fibl * envBRDF.x + envBRDF.y);

  const float MAX_LOD = 4.0;
  vec3 prefilterColor = textureLod(uPrefilterMap, R, roughness * MAX_LOD).rgb;
  float occlusion = texture(uRMO, vTextureCoord).b;
  vec3 ibl = prefilterColor * (Fibl * envBRDF.x + envBRDF.y) * occlusion;

  vec3 indirColor = float(total) / float(SAMPLE_NUM) * ssr + float(SAMPLE_NUM - total) / float(SAMPLE_NUM) * ibl;

  vec3 color = texture(uShadingColor, vTextureCoord).rgb + indirColor;
  color = color / (color + vec3(1.0)); // to LDR here?

  FragColor = vec4(color, 1.0);
}