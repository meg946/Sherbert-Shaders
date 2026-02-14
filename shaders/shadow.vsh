#version 120

// Basic Shadow Vertex Shader
varying vec2 texcoord;
varying vec4 color;

void main() {
    texcoord = gl_MultiTexCoord0.xy;
    color = gl_Color;
    
    // Position the vertex in the world
    gl_Position = ftransform();
}