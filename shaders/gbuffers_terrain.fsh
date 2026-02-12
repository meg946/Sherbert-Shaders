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
in vec4 at_midBlock;


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
	color = texture(gtexture, texcoord) * glcolor;
    

    //PBR STUFF


    vec4 albedoData = texture2D(gtexture, texcoord) * color;
    vec4 normalData = texture2D(normals, texcoord);
    vec4 specData   = texture2D(specular, texcoord);

    vec3 viewNormal = normalData.rgb * 2.0 - 1.0;

    mat3 tbnMatrix = mat3(tangent, binormal, normal);
    vec3 finalNormal = normalize(tbnMatrix * viewNormal);

    float smoothness = specData.r;
    float metalness = specData.g;
    float porosity = specData.b;
    float emissive = specData.a;
    float height = normalData.a;

    
    
    //END OF PBR


    vec3 ambientLight = vec3(-.2);

    vec3 lightVector = normalize(shadowLightPosition);
    vec3 worldLightVector = mat3(gbufferModelViewInverse) * lightVector;


    if (color.a < alphaTestRef) {
		discard;
	}
    
    if (at_midBlock.w >= 1){
        color.rgb *= vec3(1.40);
    }

    vec3 currentLightTemp = calcLightColor();
    vec3 sunlight = clamp(dot(worldLightVector, normal), 0.0, 0.10) * vec3(texture(lightmap,texcoord));

    vec4 lightMapColor = texture(lightmap, lmcoord);

    color.rgb *= lightMapColor.rgb * currentLightTemp + sunlight;
    
    gl_FragData[0] = albedoData;
    gl_FragData[1] = vec4(finalNormal, 1.0);
    gl_FragData[2] = vec4(smoothness, metalness, emissive, 1.0);

}

