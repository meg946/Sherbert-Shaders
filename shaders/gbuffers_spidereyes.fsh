#version 330 compatibility

// The main color buffer (the rendered scene) from previous passes
uniform sampler2D colortex0;

// Texture coordinates received from the vertex shader
in vec2 texcoord;

/* RENDERTARGETS: 0 */
// Outputting to the first color attachment
layout(location = 0) out vec4 color;

void main() {
    // Sample the color from the main scene texture at the current coordinate
    color = texture(colortex0, texcoord);
    color.rgb *= 1.2;
}