#version 330 compatibility

out vec2 texcoord;

void main() {
    // Transform the vertex from the light's point of view
    gl_Position = ftransform();
    
    // Pass texture coordinates to handle alpha-testing in the fragment shader
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    // --- FIX: Backface Shifting ---
    // Slightly push the shadow depth away from the light source.
    // This reduces "shadow acne" where a surface shadows itself due to precision errors.
    gl_Position.z -= 0.0001; 
}