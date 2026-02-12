#version 330 compatibility

out vec2 texcoord;

void main() {
    // Standard transform
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    // --- FIX: Backface Shifting ---
    // We slightly push the shadow geometry away from the sun 
    // to ensure the front faces are "clear" of their own shadow.
    gl_Position.z -= 0.0001; 
}