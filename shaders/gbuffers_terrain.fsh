#version 330 compatibility
/* RENDERTARGETS: 0,1,2 */
layout (location = 0) out vec4 outColor;
layout (location = 1) out vec4 outNormal;
layout (location = 2) out vec4 outMaterial;

// --- UNIFORMS ---
uniform sampler2D lightmap;
uniform sampler2D gtexture;      
uniform sampler2D specular;      
uniform sampler2D shadowtex0;    
uniform sampler2D shadowtex1;    
uniform sampler2D shadowcolor0;  
uniform sampler2D noisetex;      

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;
uniform float alphaTestRef = 0.1;
uniform int worldTime;
uniform vec3 sunPosition;
uniform float viewWidth;
uniform float viewHeight;


// --- INPUTS ---
flat in int blockId;    
in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec3 normal;
in vec3 tangent;
in vec3 binormal;
in vec3 viewVector;
in vec3 worldPos;

// --- CONSTANTS ---
const float PI = 3.14159265359;

// FIX: Reduced from 2 to 1 to stop the GPU crash.
// Range 1 = 4 samples. Range 2 = 16 samples (Too heavy!)
const int SHADOW_RANGE = 1; 
const float SHADOW_RADIUS = 1.0;

const vec3 MOON_BLUE = vec3(0.3, 0.35, 0.45) * 0.85;
const vec3 SUNRISE   = vec3(1.0, 0.5, 0.3) * 0.5;
const vec3 NOON      = vec3(0.95, 0.98, 1.0) * 1.0;
const vec3 SUNSET    = vec3(0.5, 0.3, 0.1) * 0.75;

#include "/lib/distort.glsl"

// --- STRUCTS ---
struct Material {
    float roughness;
    float metalness;
    float emission;
    float f0;
    float sss;
};

// --- HELPER FUNCTIONS ---
float getLuma(vec3 color) {
    return dot(color, vec3(0.299, 0.587, 0.114));
}

// Integrated PBR Resolver
Material GetMaterialProperties(int id, vec3 albedoColor) {
    Material m;
    m.roughness = 0.9;
    m.metalness = 0.0;
    m.emission  = 0.0;
    m.f0        = 0.04;
    m.sss       = 0.0;

    // Foliage
    if (id >= 10 && id < 100) {
        m.roughness = 0.8;
        m.sss = 0.5;
    }
    // Rough Terrain
    else if (id >= 100 && id < 200) {
        m.roughness = 0.95; 
        if (id == 117){
            m.roughness = 0.99;
            m.f0 = 0.5;
        }
    }
    // Polished
    else if (id >= 300 && id < 400) {
        m.roughness = 0.4;
    }
    // Metals
    else if (id >= 1000 && id < 2000) {
        m.metalness = 0.85;
        m.roughness = 0.3;
        
        if (id == 1000) m.roughness = 0.25; // Iron
        if (id == 1010) m.roughness = 0.15; // Gold
        if (id == 1022) { m.roughness = 0.5; m.metalness = 0.6; } // Weathered Copper
        if (id == 1023) { m.roughness = 0.45; m.metalness = 0.7; } // Oxidized Copper
    }
    // Gemstones
    else if (id >= 2000 && id < 3000) {
        m.roughness = 0.05;
        if (id == 2000) m.f0 = 0.17; // Diamond
        if (id == 2001) m.f0 = 0.07; // Emerald
    }
    // Emissives (Torches, Glowstone, etc.)
    else if (id >= 3000 && id < 4000) {
        m.emission = getLuma(albedoColor);
        
        // Lava & Fire need to be VERY bright to look hot
        if (id == 3005 || id == 3006) { 
            m.roughness = 0.1; // Lower roughness makes it look "wet" or hot
            // Use Luma to make the bright parts of the texture glow intensely (3.0x)
            // and the dark parts (crust) glow less
            m.emission = getLuma(albedoColor) * 3.0; 
        }

        if (id == 3014){
        m.emission = getLuma(albedoColor) * 1.1;
        m.roughness = 0.4;
        }
    }

    
    // Water/Ice
    else if (id >= 4000) {
        m.roughness = 0.5;
        m.f0 = 0.8;
    }

    if (m.roughness > 0.2 && m.emission == 0.0) {
        float variation = (0.5 - getLuma(albedoColor)) * 0.2;
        m.roughness = clamp(m.roughness + variation, 0.05, 1.0);
    }
    return m;
}

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position){
    vec4 homPos = projectionMatrix * vec4(position, 1.0);
    return homPos.xyz / homPos.w;
}

vec3 calcLightColor() {
    if (worldTime > 23000 || worldTime < 1000) return SUNRISE;
    if (worldTime >= 1000 && worldTime < 12000) return NOON;
    if (worldTime >= 12000 && worldTime < 14000) return SUNSET;
    return MOON_BLUE;
}

// --- PBR MATH ---
vec3 fresnelSchlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

float DistributionGGX(vec3 N, vec3 H, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;
    
    float num = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    return num / (PI * denom * denom);
}

float GeometrySchlickGGX(float NdotV, float roughness) {
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;
    return NdotV / (NdotV * (1.0 - k) + k);
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    return GeometrySchlickGGX(NdotV, roughness) * GeometrySchlickGGX(NdotL, roughness);
}


// --- FOG PARAMETERS ---
uniform vec3 fogColor = vec3(0.7, 0.8, 0.9); // Light sky/fog color
uniform float fogDensity = 0.002;            // How thick the fog is
uniform float fogStart = 64.0;              // For linear fog start
uniform float fogEnd   = 256.0;             // Linear fog end

// Exponential fog
float computeFogFactorExp(float distance) {
    return 1.0 - exp(-distance * fogDensity);
}

// Linear fog
float computeFogFactorLinear(float distance) {
    return clamp((distance - fogStart) / (fogEnd - fogStart), 0.0, 1.0);
}


// --- MAIN ---
void main() {
    vec4 texSample = texture(gtexture, texcoord);
    vec3 albedo = texSample.rgb * glcolor.rgb;
    float alpha = texSample.a; 
    if (alpha < alphaTestRef){ discard; }

    // --- Material ---
    vec4 specData = texture(specular, texcoord);
    bool hasResourcePack = dot(specData.rgb, vec3(1.0)) > 0.0;
    
    Material mat;
    if (hasResourcePack) {
        mat.roughness = pow(1.0 - specData.r, 2.0);
        mat.metalness = specData.g > 0.9 ? 1.0 : 0.0;
        mat.emission  = specData.b;
        mat.f0        = specData.g;
    } else {
        mat = GetMaterialProperties(blockId, albedo);
    }

    vec3 N = normalize(normal);
    vec3 L = normalize(shadowLightPosition); 
    vec3 V = normalize(viewVector);
    vec3 H = normalize(L + V);

    float NdotL = max(dot(N, L), 0.0);
    float NdotV = max(dot(N, V), 0.0);
    float VdotH = max(dot(V, H), 0.0);

    vec3 F0 = mix(vec3(mat.f0), albedo, mat.metalness);
    
    float D = DistributionGGX(N, H, mat.roughness);
    float G = GeometrySmith(N, V, L, mat.roughness);
    vec3 F  = fresnelSchlick(VdotH, F0);
    
    vec3 numerator = D * G * F;
    float denominator = 4.0 * NdotV * NdotL + 0.0001;
    vec3 specularLight = numerator / denominator;
    
    vec3 kS = F;
    vec3 kD = vec3(1.0) - kS;
    kD *= 1.0 - mat.metalness; 

    // --- Shadows ---
    vec2 dims = vec2(max(viewWidth, 1.0), max(viewHeight, 1.0));
    vec2 screenUV = gl_FragCoord.xy / dims;
    
    vec3 NDCPos = vec3(screenUV, gl_FragCoord.z) * 2.0 - 1.0;
    vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);
    vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
    vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);
    
    vec3 shadowVal = clamp(getSoftShadow(shadowClipPos), 0.0, 1.0);

    vec3 lightColor = calcLightColor();
    vec3 ambientColor = (1 * vec3(1.0, 0.8, 0.6) * lightColor * 0.1 + 0.03);
    vec3 ambient = albedo * ambientColor;

    if (mat.metalness > 0.0) {
        vec3 fakeEnvReflection = lightColor * 0.5 + vec3(0.1); 
        ambient += fakeEnvReflection * albedo * mat.metalness * 0.5; 
    }

    vec3 direct = (kD * albedo / PI + specularLight) * lightColor * NdotL * shadowVal;
    vec3 finalColor = direct + ambient + (albedo * mat.emission);

    // --- Tonemapping ---
    vec3 mapped = (finalColor * (2.51 * finalColor + 0.03)) / (finalColor * (2.43 * finalColor + 0.59) + 0.14);
    finalColor = pow(clamp(mapped, 0.0, 1.0), vec3(1.8 / 2.2)); 

    float distanceToCamera = length(worldPos - cameraPosition);
    float fogFactor = computeFogFactorExp(distanceToCamera); // exponential fog

    // --- Glass / Transparent Handling ---
    bool isGlass = (blockId >= 2005 && blockId <= 2900 || blockId >= 4000); // adjust IDs
    if (isGlass) {
        float glassAlpha = texSample.a;
        vec3 glassTint = albedo;

        // Blend fog with glass while keeping transparency
        vec3 colorWithFog = mix(glassTint, fogColor, fogFactor);
        outColor = vec4(colorWithFog, glassAlpha);
    } else {
        // Opaque blocks
        finalColor = mix(finalColor, fogColor, fogFactor);
        outColor = vec4(finalColor, 1.0);
    }

    // --- G-Buffer Outputs ---
    outNormal   = vec4(N * 0.5 + 0.5, 1.0);
    outMaterial = vec4(mat.roughness, mat.metalness, mat.emission, 1.0);
}