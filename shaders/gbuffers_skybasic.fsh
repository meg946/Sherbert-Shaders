#version 330 compatibility

uniform sampler2D lightmap;
uniform sampler2D gtexture;

uniform vec3 shadowLightPosition;

uniform int worldTime;
uniform int isEyeInWater;

uniform float sunAngle;
uniform float shadowAngle;
uniform float alphaTestRef = 0.1;

in vec2 lmcoord;
in vec2 texcoord;

in vec3 normal;
uniform vec3 fogColor;

in vec4 glcolor;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

const vec3 MOON_BLUE  = vec3(0.2, 0.25, 0.45) * 0.65; 
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
	color = texture(gtexture, texcoord) * glcolor;	
    
    if (color.a < alphaTestRef) {
		discard;
	}

    vec3 currentLightTemp = calcLightColor();
    vec4 lightMapColor = texture(lightmap, lmcoord);

    color.rgb *= lightMapColor.rgb * currentLightTemp;
}

