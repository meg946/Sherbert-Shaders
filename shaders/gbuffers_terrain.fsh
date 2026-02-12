#version 330 compatibility

/* RENDERTARGETS: 0,1,2 */

uniform sampler2D lightmap;
uniform sampler2D gtexture;
uniform sampler2D normals;
uniform sampler2D specular;

uniform vec3 shadowLightPosition;
uniform vec3 fogColor;
uniform int worldTime;
uniform float alphaTestRef = 0.1;
uniform mat4 gbufferModelViewInverse;

in vec2 lmcoord;
in vec2 texcoord;
in vec3 normal;
in vec3 binormal;
in vec3 tangent;
in vec4 glcolor;
in vec3 viewVector; // Needed for reflections

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

    // 2. Unpack PBR Data
    vec4 normalData = texture(normals, texcoord);
    vec4 specData   = texture(specular, texcoord);

    float smoothness = specData.r;
    float metalness  = specData.g;
    float emissive   = specData.a;

    // 3. Calculate PBR Normal (The "Bump" Effect)
    vec3 viewNormal = normalData.rgb * 2.0 - 1.0;
    mat3 tbnMatrix = mat3(tangent, binormal, normal);
    
    // This is the vector that makes things look 3D
    vec3 finalNormal = normalize(tbnMatrix * viewNormal);

    // 4. Lighting Setup
    vec3 lightDir = normalize(shadowLightPosition); // Vector towards the sun
    vec3 viewDir = normalize(-viewVector);          // Vector towards the camera

    // --- EFFECT 1: BUMP MAPPING (Shadows on the texture) ---
    // Use finalNormal instead of normal
    float NdotL = max(dot(finalNormal, lightDir), 0.0);
    
    // --- EFFECT 2: SPECULAR HIGHLIGHTS (Shininess) ---
    // Calculate reflection vector
    vec3 reflectDir = reflect(-lightDir, finalNormal);
    
    // Calculate highlight size based on smoothness
    float specStrength = pow(max(dot(viewDir, reflectDir), 0.0), 10.0 + (smoothness * 200.0));
    
    // Adjust brightness based on smoothness/metalness
    vec3 specularHighlight = vec3(specStrength) * smoothness * (1.0 + metalness);

    // 5. Combine Everything
    vec4 lightMapColor = texture(lightmap, lmcoord);
    vec3 sunColor = calcLightColor();
    
    // Base Lighting (Sunlight + Blocklight)
    vec3 diffuse = albedo.rgb * (lightMapColor.rgb * sunColor + (vec3(NdotL) * 0.5));
    
    // Add Shininess (Specular) and Glow (Emissive)
    vec3 finalColor = diffuse + specularHighlight + (albedo.rgb * emissive);

    // 6. Output to Screen
    gl_FragData[0] = vec4(finalColor, albedo.a);          // Visual Color
    gl_FragData[1] = vec4(finalNormal, 1.0);              // Backup Normal
    gl_FragData[2] = vec4(smoothness, metalness, emissive, 1.0); // Backup PBR
}