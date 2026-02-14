#version 330 compatibility

// Output texture coordinates to the fragment shader
out vec2 texcoord;

void main() {
    // Standard transformation: maps the vertex position to screen space
    gl_Position = ftransform();

    // Transform the first texture coordinate set using the texture matrix
    // This ensures the coordinates match the screen-space quad
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}