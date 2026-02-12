#version 330 compatibility

uniform sampler2D lightmap;
uniform sampler2D gtexture;
uniform sampler2D normals;
uniform sampler2D specular;

uniform vec3 shadowLightPosition;
uniform vec3 fogColor;


uniform int worldTime;
uniform int isEyeInWater;
uniform int worldDay;

uniform float sunAngle;
uniform float shadowAngle;
uniform float alphaTestRef = 0.1;
uniform float far;
uniform float near;
uniform float fogDensity;
uniform float fogStart;
uniform float fogEnd;



in vec2 lmcoord;
in vec2 texcoord;

in vec3 normal;
in vec3 binormal;
in vec3 tangent;
in vec4 glcolor;


const float sunPathRotation = 10.0;

uniform mat4 gbufferModelViewInverse;

/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 color;

const vec3 MOON_BLUE  = vec3(0.3, 0.35, 0.45) * 0.85; 
const vec3 SUNRISE    = vec3(1.0, 0.5, 0.3) * 0.5;
const vec3 NOON       = vec3(0.95, 0.98, 1.0) * 1.0; 
const vec3 SUNSET     = vec3(0.5, 0.3, 0.1) * 0.75;


vec3 calcLightColor() {
    vec3 lightColor = MOON_BLUE;
    float blendFactor = 0.0;
    float timeFloat = float(worldTime);

    if (worldTime >= 22000) {
        blendFactor = smoothstep(22000.0, 24000.0, timeFloat);
        lightColor = mix(MOON_BLUE, SUNRISE, blendFactor);
    }

    else if (worldTime < 1000) {

         blendFactor = smoothstep(0.0, 1000.0, timeFloat);
         lightColor = mix(SUNRISE, NOON, blendFactor);
    }

    else if (worldTime >= 1000 && worldTime < 6000) {
        blendFactor = smoothstep(1000.0, 6000.0, timeFloat);
        lightColor = mix(mix(SUNRISE, NOON, 0.5), NOON, blendFactor);
    }

    else if (worldTime >= 6000 && worldTime < 9000) {
        lightColor = NOON;
    }

    else if (worldTime >= 9000 && worldTime < 12000) {
        blendFactor = smoothstep(9000.0, 12000.0, timeFloat);
        lightColor = mix(NOON, SUNSET, blendFactor);
    }

    else if (worldTime >= 12000 && worldTime < 14000) {
        blendFactor = smoothstep(12000.0, 14000.0, timeFloat);
        lightColor = mix(SUNSET, MOON_BLUE, blendFactor);
    }

    else {
        lightColor = MOON_BLUE;
    }

    return lightColor;
}


void main() {
    // 1. Base Color
    vec4 albedo = texture(gtexture, texcoord) * glcolor;
    
    if (albedo.a < alphaTestRef) {
        discard;
    }

    // 2. PBR Data Unpacking
    vec4 normalData = texture(normals, texcoord);
    vec4 specData   = texture(specular, texcoord);

    // 3. Normal Map Calculation (TBN)
    vec3 viewNormal = normalData.rgb * 2.0 - 1.0;
    mat3 tbnMatrix = mat3(tangent, binormal, normal);
    vec3 finalNormal = normalize(tbnMatrix * viewNormal);

    // 4. Specular Data
    float smoothness = specData.r;
    float metalness  = specData.g;
    float emissive   = specData.a;

    // 5. Apply Lighting (Basic)
    vec3 lightVector = normalize(shadowLightPosition);
    vec3 worldLightVector = mat3(gbufferModelViewInverse) * lightVector;
    
    vec4 lightMapColor = texture(lightmap, lmcoord);
    vec3 currentLightTemp = calcLightColor();
    
    // Simple sunlight dot product
    float NdotL = max(dot(normal, worldLightVector), 0.0);
    vec3 sunlight = vec3(NdotL * 0.1) * lightMapColor.rgb; // heavily reduced per your old code

    albedo.rgb *= lightMapColor.rgb * currentLightTemp + sunlight;
    
    // 6. Final Output (Write to all buffers)
    gl_FragData[0] = albedo; // Color
    gl_FragData[1] = vec4(finalNormal, 1.0); // Normal Vector
    gl_FragData[2] = vec4(smoothness, metalness, emissive, 1.0); // PBR Data
}