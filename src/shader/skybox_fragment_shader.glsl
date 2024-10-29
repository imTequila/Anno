#version 330 core
in vec3 vTextureCoord;
uniform samplerCube uSkyboxMap; 
out vec4 FragColor;

void main()
{             
    vec3 color = textureLod(uSkyboxMap, vTextureCoord, 0.0).rgb;
    color = color / (color + vec3(1.0));
    FragColor = vec4(color, 1.0);
}