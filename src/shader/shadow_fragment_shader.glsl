#version 330 core

in float vDepth;

void main() {
  gl_FragDepth = gl_FragCoord.z;
}