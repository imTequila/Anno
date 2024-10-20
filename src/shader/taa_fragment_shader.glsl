#version 330 core
in vec2 vTextureCoord;
in mat4 vWorldToScreen;

uniform sampler2D uPreFrame;
uniform sampler2D uCurFrame;
uniform sampler2D uDepth;
uniform sampler2D uVelocity;

uniform float uBlend;

out vec4 FragColor;


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

void main() {

  vec3 color = texture2D(uCurFrame, vTextureCoord).rgb;

  vec2 velocity = texture2D(uVelocity, GetClosestOffset()).rg;
  vec2 preUV = vTextureCoord + velocity;
  vec2 offsetUV = clamp(preUV, 0, 1);
  vec3 preColor = texture2D(uPreFrame, offsetUV).rgb;

  float c = uBlend;
  if (preUV.x < 0 || preUV.y < 0 || preUV.x > 1 || preUV.y > 1) {
    c = 1.0;
  }
  color = c * color + (1.0 - c) * preColor;

  FragColor = vec4(color, 1.0);
}