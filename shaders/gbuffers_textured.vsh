#version 330 compatibility

in vec4 mc_Entity;
in vec4 at_tangent;

uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;

out vec3 normal;
out vec3 tangent;
out vec3 binormal;
out vec3 worldPos;
out vec3 viewVector;

flat out int blockId;

void main() {
    texcoord = gl_MultiTexCoord0.xy;
    lmcoord  = gl_MultiTexCoord1.xy;
    glcolor  = gl_Color;

    normal   = normalize(gl_NormalMatrix * gl_Normal);
    tangent  = normalize(gl_NormalMatrix * at_tangent.xyz);
    binormal = cross(tangent, normal) * at_tangent.w;

    gl_Position = ftransform();

    worldPos   = (gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex).xyz + cameraPosition;
    viewVector = -(gl_ModelViewMatrix * gl_Vertex).xyz;

    blockId = (mc_Entity.x > -0.5) ? int(mc_Entity.x + 0.1) : 0;
}
