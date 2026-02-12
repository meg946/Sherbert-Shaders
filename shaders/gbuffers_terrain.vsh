#version 330 compatibility

// Inverse matrix to transform view-space coordinates back to world-space
uniform mat4 gbufferModelViewInverse;

// Tangent attribute used for normal mapping (provided by Optifine/Iris)
attribute vec4 at_tangent; 

// Varying outputs to the fragment shader
out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec3 normal;
out vec3 tangent;
out vec3 binormal;
out vec3 viewVector;
out vec3 worldPos; // Raw position in the world

void main() {
    // Transform vertex to clip space
    gl_Position = ftransform();
    
    // Pass texture and lightmap coordinates
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    
    // Pass vertex color (biome tints, etc.)
    glcolor = gl_Color;

    // Calculate Normal, Tangent, and Binormal for TBN matrix (Normal Mapping)
    normal = normalize(gl_NormalMatrix * gl_Normal);
    tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
    // Binormal is derived from the cross product of tangent and normal
    binormal = cross(tangent, normal) * at_tangent.w;

    // Calculate the vector from the camera to the vertex in view space
    vec4 position = gl_ModelViewMatrix * gl_Vertex;
    viewVector = normalize(position.xyz);

    // Calculate world position by multiplying the view-space position by the inverse model-view matrix
    worldPos = (gbufferModelViewInverse * position).xyz;
}