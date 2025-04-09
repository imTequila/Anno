#version 330 core

in float vDepth;
in vec4 vViewSpacePosition;

out vec4 FragColor;

const float g_DistributeFPFactor = 256;
vec4 DistributeFP(vec2 Value)
{
  float FactorInv = 1 / g_DistributeFPFactor;
  
  // Split precision
  vec2 IntPart;
  vec2 FracPart = modf(Value * g_DistributeFPFactor, IntPart);
  
  // Compose outputs to make it cheap to recombine
  return vec4(IntPart * FactorInv, FracPart);
}

void main() {
  float len = length(vViewSpacePosition.xyz);
  // float dx = dFdx(len);
  // float dy = dFdy(len);
  // vec2 moment = vec2(len + 0.5, len * len + 0.25 * (dx * dx + dy * dy));
  vec2 moment = vec2(len + 0.5, len * len);
  FragColor = DistributeFP(moment);
}