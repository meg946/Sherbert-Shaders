#version 330 compatibility


out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec3 normal;

void main() {
    // 1. Standard Position
    gl_Position = ftransform();

    // 2. Pass standard coordinates
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    
    // 3. Pass Color and Normal
    glcolor = gl_Color;
    normal = normalize(gl_NormalMatrix * gl_Normal);
}