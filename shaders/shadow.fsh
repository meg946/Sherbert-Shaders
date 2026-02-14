#version 120

// Basic Shadow Fragment Shader
uniform sampler2D texture;
varying vec2 texcoord;

void main() {
    // Get the texture color (e.g., leaves, glass)
    vec4 color = texture2D(texture, texcoord);
    
    // If the pixel is transparent, discard the shadow (don't block light)
    if (color.a < 0.1) discard;
    
    gl_FragColor = color;
}