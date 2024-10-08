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

float frac(float x) {
  if (x > 0) return x;
  else return x - int(x);
}

vec2 Hammersley16( uint Index, uint NumSamples, uvec2 Random ) {
	float E1 = frac( float( Index ) / NumSamples + float( Random.x ) * (1.0 / 65536.0) );
	float E2 = float( ( ReverseBits32(Index) >> 16 ) ^ Random.y ) * (1.0 / 65536.0);
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
  const int total_step_times = 500;
  int cur_times = 0;
  vec2 start_uv = GetScreenCoordinate(ori);
  vec2 end_uv = GetScreenCoordinate(ori + dir);
  vec2 step_uv = end_uv - start_uv;
  float len = sqrt(step_uv.x * step_uv.x + step_uv.y * step_uv.y);

  float step = 0.002 / len;

  vec3 dir_step = dir * step;
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

void main() {
  vec3 position = texture2D(uPosition, vTextureCoord).rgb;
  vec3 N = texture2D(uNormal, vTextureCoord).rgb;
  vec3 V = normalize(uCameraPos - position);

  vec3 albedo = texture(uBaseColor, vTextureCoord).rgb;
  float roughness = texture2D(uRMO, vTextureCoord).r;
  float metallic = texture(uRMO, vTextureCoord).g;

  vec3 F0 = vec3(0.04);
  F0 = mix(F0, albedo, metallic);

  vec2 env_brdf = texture(uBRDFLut_ibl, vec2(max(dot(N, V), 0.0)), roughness).rg;


  vec3 R = normalize(reflect(-V, N));
  const uint SAMPLE_NUM = 4u;
  vec3 Lo_indir = vec3(0.0);
  uint total = 0u;
  
  uvec2 Random = Rand3DPCG16( ivec3( vTextureCoord * 1080, 0 ) ).xy;

  for(uint i = 0u; i < SAMPLE_NUM; i++) {
    vec2 Xi = Hammersley16(i, SAMPLE_NUM, Random);
    vec3 sample_vector = normalize(ImportanceSampleGGX(Xi, R, roughness));
    float NdotSample = dot(N, sample_vector);
    vec3 hit;
    if (RayMarch(position, sample_vector, hit)) {
      vec2 uv = GetScreenCoordinate(hit);
      vec3 hitColor = texture2D(uShadingColor, uv).rgb;

      Lo_indir += hitColor;
      total ++;
    }
  }
  Lo_indir /= SAMPLE_NUM;
  vec3 F_ibl = FresnelSchlickRoughness(max(dot(N, V), 0.0), F0, roughness);
  vec3 ssr = Lo_indir * (F_ibl * env_brdf.x + env_brdf.y);
  ssr = Lo_indir;

  vec3 color = texture(uShadingColor, vTextureCoord).rgb + ssr;
  color = color / (color + vec3(1.0));
  color = pow(color, vec3(1.0 / 2.2));
  FragColor = vec4(color, 1.0);
}