#version 330 core
in vec2 vTextureCoord;
in mat4 vWorldToScreen;

uniform sampler2D uPreFrame;
uniform sampler2D uCurFrame;
uniform sampler2D uDepth;
uniform sampler2D uVelocity;

uniform float uBlend;

out vec4 FragColor;

vec3 RGB2YCoCgR(vec3 rgbColor)
{
    vec3 YCoCgRColor;

    YCoCgRColor.y = rgbColor.r - rgbColor.b;
    float temp = rgbColor.b + YCoCgRColor.y / 2;
    YCoCgRColor.z = rgbColor.g - temp;
    YCoCgRColor.x = temp + YCoCgRColor.z / 2;

    return YCoCgRColor;
}

vec3 YCoCgR2RGB(vec3 YCoCgRColor)
{
    vec3 rgbColor;

    float temp = YCoCgRColor.x - YCoCgRColor.z / 2;
    rgbColor.g = YCoCgRColor.z + temp;
    rgbColor.b = temp - YCoCgRColor.y / 2;
    rgbColor.r = rgbColor.b + YCoCgRColor.y;

    return rgbColor;
}

vec2 GetClosestOffset() {
  vec2 deltaRes = vec2(1.0 / 1080, 1.0 / 1080);
  float closestDepth = 1.0f;
  vec2 closestUV = vTextureCoord;

  for(int i = -1; i <= 1; ++i)
  {
    for(int j =- 1; j <= 1; ++j)
    {
      vec2 newUV = vTextureCoord + deltaRes * vec2(i, j);

      float depth = texture2D(uDepth, newUV).x;

      if(depth < closestDepth)
      {
        closestDepth = depth;
        closestUV = newUV;
      }
    }
  }
  return closestUV;
}

vec3 ClipAABB(vec3 nowColor, vec3 preColor)
{
    vec3 aabbMin = nowColor, aabbMax = nowColor;
    vec2 deltaRes = vec2(1.0 / 1080, 1.0 / 1080);
    vec3 m1 = vec3(0), m2 = vec3(0);

    for(int i=-1;i<=1;++i)
    {
        for(int j=-1;j<=1;++j)
        {
            vec2 newUV = vTextureCoord + deltaRes * vec2(i, j);
            vec3 C = RGB2YCoCgR(texture2D(uCurFrame, newUV).rgb);
            m1 += C;
            m2 += C * C;
        }
    }

    // Variance clip
    const int N = 9;
    const float CLIP_GAMMA = 1.0f;
    vec3 mu = m1 / N;
    vec3 sigma = sqrt(abs(m2 / N - mu * mu));
    aabbMin = mu - CLIP_GAMMA * sigma;
    aabbMax = mu + CLIP_GAMMA * sigma;

    // clip to center
    vec3 pClip = 0.5 * (aabbMax + aabbMin);
    vec3 eClip = 0.5 * (aabbMax - aabbMin);

    vec3 vClip = preColor - pClip;
    vec3 vUnit = vClip.xyz / eClip;
    vec3 aUnit = abs(vUnit);
    float maUnit = max(aUnit.x, max(aUnit.y, aUnit.z));

    if (maUnit > 1.0)
        return pClip + vClip / maUnit;
    else
        return preColor;
}

void main() {

  

  vec2 velocity = texture2D(uVelocity, GetClosestOffset()).rg;
  vec2 preUV = vTextureCoord + velocity;
  vec2 offsetUV = clamp(preUV, 0, 1);

  vec3 preColor = RGB2YCoCgR(texture2D(uPreFrame, offsetUV).rgb);
  vec3 curColor = RGB2YCoCgR(texture2D(uCurFrame, vTextureCoord).rgb);

  preColor = ClipAABB(curColor, preColor);

  preColor = YCoCgR2RGB(preColor);
  curColor = YCoCgR2RGB(curColor);

  float c = 0.05;
  if (preUV.x < 0 || preUV.y < 0 || preUV.x > 1 || preUV.y > 1) {
    c = 1.0;
  }

  curColor = c * curColor + (1.0 - c) * preColor;

  FragColor = vec4(curColor, 1.0);
}