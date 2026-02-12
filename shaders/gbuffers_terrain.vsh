#version 330 compatibility

uniform mat4 gbufferModelViewInverse;

attribute vec4 at_tangent; 

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec3 normal;
out vec3 tangent;
out vec3 binormal;
out vec3 viewVector;

// Send RAW position (we lock it in the pixel shader)
out vec3 worldPos; 

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;

    normal = normalize(gl_NormalMatrix * gl_Normal);
    tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
    binormal = cross(tangent, normal) * at_tangent.w;

    vec4 position = gl_ModelViewMatrix * gl_Vertex;
    viewVector = normalize(position.xyz);

    // Calculate Smooth World Position
    worldPos = (gbufferModelViewInverse * position).xyz;
}