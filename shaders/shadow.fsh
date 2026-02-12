#version 330 compatibility

in vec2 texcoord;
in vec4 glcolor;
uniform sampler2D gtexture;

void main() {
    vec4 tex = texture(gtexture, texcoord) * glcolor;
    
    // Handle transparent textures (leaves, stained glass)
    if (tex.a < 0.1) discard; 
}