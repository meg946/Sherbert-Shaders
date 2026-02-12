#version 330 compatibility

in vec2 texcoord;
in vec4 glcolor;
uniform sampler2D gtexture;

void main() {
    // Sample the texture at the current fragment
    vec4 tex = texture(gtexture, texcoord) * glcolor;

    // Alpha Testing: If the texture is transparent (like leaves or glass), 
    // discard the fragment so it doesn't cast a solid rectangular shadow.
    if (tex.a < 0.1) discard; 
}