#version 330 compatibility

/* RENDERTARGETS: 0,1,2 */

uniform sampler2D lightmap;
uniform sampler2D gtexture;
uniform sampler2D normals;
uniform sampler2D specular;

uniform vec3 shadowLightPosition;
uniform float alphaTestRef = 0.1;

uniform int worldTime;

in vec2 lmcoord;
in vec2 texcoord;
in vec3 normal;
in vec3 binormal;
in vec3 tangent;
in vec4 glcolor;
in vec3 viewVector;

// --- COLOR CONSTANTS ---
const vec3 MOON_BLUE  = vec3(0.3, 0.35, 0.45) * 0.85;
const vec3 SUNRISE    = vec3(1.0, 0.5, 0.3) * 0.5;
const vec3 NOON       = vec3(0.95, 0.98, 1.0) * 1.0;
const vec3 SUNSET     = vec3(0.5, 0.3, 0.1) * 0.75;

vec3 calcLightColor() {
    float timeFloat = float(worldTime);
    float blendFactor = 0.0;
    vec3 lightColor = MOON_BLUE;

    if (worldTime >= 22000) {
        blendFactor = smoothstep(22000.0, 24000.0, timeFloat);
        lightColor = mix(MOON_BLUE, SUNRISE, blendFactor);
    } else if (worldTime < 1000) {
         blendFactor = smoothstep(0.0, 1000.0, timeFloat);
        lightColor = mix(SUNRISE, NOON, blendFactor);
    } else if (worldTime >= 1000 && worldTime < 6000) {
        blendFactor = smoothstep(1000.0, 6000.0, timeFloat);
        lightColor = mix(mix(SUNRISE, NOON, 0.5), NOON, blendFactor);
    } else if (worldTime >= 6000 && worldTime < 9000) {
        lightColor = NOON;
    } else if (worldTime >= 9000 && worldTime < 12000) {
        blendFactor = smoothstep(9000.0, 12000.0, timeFloat);
        lightColor = mix(NOON, SUNSET, blendFactor);
    } else if (worldTime >= 12000 && worldTime < 14000) {
        blendFactor = smoothstep(12000.0, 14000.0, timeFloat);
        lightColor = mix(SUNSET, MOON_BLUE, blendFactor);
    }
    
    return lightColor;
}

void main() {
    // 1. Base Color
    vec4 albedo = texture(gtexture, texcoord) * glcolor;
    if (albedo.a < alphaTestRef) discard;

    // 2. HARDCODED PBR DEFAULTS (Fixes the "Bright Ground" & "Dark Logs" issue)
    // Since we don't have a PBR resource pack, we must set these to 0 manually.
    float smoothness = 0.0;
    float metalness  = 0.0;
    float emissive   = 0.0; 

    // 3. GEOMETRY NORMALS ONLY
    // We ignore the 'normals' texture because it contains garbage data for vanilla blocks.
    vec3 finalNormal = normalize(normal); 

    // 4. Lighting Calculation
    vec3 lightDir = normalize(shadowLightPosition);
    vec3 viewDir = normalize(-viewVector);

    // Bump Shadow (Sun/Moon Shadow)
    // Using 0.3 as a minimum brightness so shadows aren't pitch black
    float NdotL = max(dot(finalNormal, lightDir), 0.0);
    float bumpShadow = NdotL * 0.7 + 0.3; 

    // Specular Highlight (Standard Blinn-Phong)
    // We keep this simple since we disabled the PBR maps
    vec3 reflectDir = reflect(-lightDir, finalNormal);
    // Low specular for everything by default
    float specStrength = pow(max(dot(viewDir, reflectDir), 0.0), 16.0);
    vec3 highlight = vec3(specStrength) * 0.1; 

    // 5. Combine Colors (Corrected Lightmap)
    vec3 sunColor = calcLightColor();
    
    // Separate Block Light (Torches) from Sky Light (Sun)
    // lmcoord.x = Torch Light | lmcoord.y = Sky Light
    // Torch light should NOT be affected by the sun shadow (bumpShadow)
    vec3 blockLightColor = texture(lightmap, vec2(lmcoord.x, 0.03)).rgb; 
    
    // Sky light IS affected by the sun shadow and our custom sun color
    vec3 skyLightColor   = texture(lightmap, vec2(0.03, lmcoord.y)).rgb * sunColor * bumpShadow;

    // Final Mix: Albedo * (Block + Sky) + Highlight
    vec3 finalColor = albedo.rgb * (blockLightColor + skyLightColor) + highlight;

    // 6. Output
    gl_FragData[0] = vec4(finalColor, albedo.a);
    gl_FragData[1] = vec4(finalNormal, 1.0);
    gl_FragData[2] = vec4(smoothness, metalness, emissive, 1.0);
}