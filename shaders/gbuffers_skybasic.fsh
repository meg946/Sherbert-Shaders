#version 330 compatibility

// Uniforms provided by the shader loader
uniform sampler2D lightmap;  // Contains block and sky light values
uniform sampler2D gtexture;  // The base texture (sun/moon/sky)
uniform int worldTime;       // Current Minecraft time (0-24000)
uniform float alphaTestRef = 0.1; // Threshold for discarding transparent pixels

// Varying inputs from the vertex shader
in vec2 lmcoord;  // Lightmap coordinates (x: block light, y: sky light)
in vec2 texcoord; // Standard texture coordinates
in vec4 glcolor;  // Vertex color (includes biome tinting)

layout(location = 0) out vec4 color;

// Defined color constants for different times of day
const vec3 MOON_BLUE  = vec3(0.2, 0.25, 0.45) * 0.65;
const vec3 SUNRISE    = vec3(1.0, 0.5, 0.3) * 0.5;
const vec3 NOON       = vec3(0.95, 0.98, 1.0) * 1.0;
const vec3 SUNSET     = vec3(0.5, 0.3, 0.1) * 0.75;

// Function to calculate the sunlight/moonlight color based on the current world time
vec3 calcLightColor() {
    vec3 lightColor = MOON_BLUE;
    float blendFactor = 0.0;
    float timeFloat = float(worldTime);

    // Transition from Moon to Sunrise (late night/early morning)
    if (worldTime >= 22000) {
        blendFactor = smoothstep(22000.0, 24000.0, timeFloat);
        lightColor = mix(MOON_BLUE, SUNRISE, blendFactor);
    }
    // Transition from Sunrise to Noon
    else if (worldTime < 1000) {
         blendFactor = smoothstep(0.0, 1000.0, timeFloat);
         lightColor = mix(SUNRISE, NOON, blendFactor);
    }
    // Morning transition
    else if (worldTime >= 1000 && worldTime < 6000) {
        blendFactor = smoothstep(1000.0, 6000.0, timeFloat);
        lightColor = mix(mix(SUNRISE, NOON, 0.5), NOON, blendFactor);
    }
    // Static Noon light
    else if (worldTime >= 6000 && worldTime < 9000) {
        lightColor = NOON;
    }
    // Transition from Noon to Sunset
    else if (worldTime >= 9000 && worldTime < 12000) {
        blendFactor = smoothstep(9000.0, 12000.0, timeFloat);
        lightColor = mix(NOON, SUNSET, blendFactor);
    }
    // Transition from Sunset back to Moon
    else if (worldTime >= 12000 && worldTime < 14000) {
        blendFactor = smoothstep(12000.0, 14000.0, timeFloat);
        lightColor = mix(SUNSET, MOON_BLUE, blendFactor);
    }
    // Full night
    else {
        lightColor = MOON_BLUE;
    }

    return lightColor;
}

void main() {
    // Combine base texture color with vertex color
    color = texture(gtexture, texcoord) * glcolor;	
    
    // Alpha test: discard pixels that are too transparent (e.g., edges of sun/moon)
    if (color.a < alphaTestRef) {
		discard;
    }

    // Determine current environmental light color
    vec3 currentLightTemp = calcLightColor();
    // Sample the lightmap for brightness
    vec4 lightMapColor = texture(lightmap, lmcoord);

    // Apply lighting: combine texture, lightmap brightness, and time-of-day color
    color.rgb *= lightMapColor.rgb * currentLightTemp;
}