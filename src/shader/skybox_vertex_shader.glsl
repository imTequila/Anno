#version 330 core
layout (location = 0) in vec3 aPos;
uniform mat4 uProjectionMatrix;
uniform mat4 uViewMatrix;
out vec3 vTextureCoord;

void main()
{
    vTextureCoord = aPos;
    gl_Position = uProjectionMatrix * uViewMatrix * vec4(aPos, 1.0);
}