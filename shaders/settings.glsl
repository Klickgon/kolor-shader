#define SHADOW_DISTORT_ENABLED //Toggles shadow map distortion
#define SHADOW_DISTORT_FACTOR 0.20 //Distortion factor for the shadow map. Has no effect when shadow distortion is disabled. [0.00 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.20 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.30 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.40 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.50 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.60 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.70 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.80 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.90 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.00]
#define SHADOW_BIAS 0.10 //Increase this if you get shadow acne. Decrease this if you get peter panning. [0.00 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.60 0.70 0.80 0.90 1.00 1.50 2.00 2.50 3.00 3.50 4.00 4.50 5.00 6.00 7.00 8.00 9.00 10.00]
#define SHADOW_NORMAL_OFFSET 0.05 //[0.00 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.60 0.70 0.80 0.90 1.00 1.50 2.00 2.50 3.00 3.50 4.00 4.50 5.00 6.00 7.00 8.00 9.00 10.00]
//#define EXCLUDE_FOLIAGE //If true, foliage will not cast shadows.
#define SHADOW_BRIGHTNESS 0.65 //Light levels are multiplied by this number when the surface is in shadows [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define COLORED_SHADOWS 1 //0: Stained glass will cast ordinary shadows. 1: Stained glass will cast colored shadows. 2: Stained glass will not cast any shadows. [0 1 2]
#define PENUMBRA_SHADOWS
#define SHADOW_FADE_LENGTH 0.1 //[0 0.05 0.1 0.15 0.2 0.25]
#define HAND_HELD_LIGHTING
#define SHADOW_FILTER_QUALITY 3 //[0 1 2 3 4]
#define SHADOW_FILTER_BLUR 2.0 //[1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0]
#define SHADOW_RENDER_DISTANCE 1.0 //[0.0 0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0 2.2 2.4 2.6 2.8 3.0 3.2]
#define SCREEN_SPACE_REFLECTIONS
#define DRAW_SHADOW_MAP 0 //Configures which buffer to draw to the screen [0 1 2 3 4]
#define SCREEN_SPACE_SHADOWS
#define FOG_START_MULTIPLIER 0.6 //[0.2 0.4 0.6 0.8 1.0]
#define NORMAL_MAPPING
#define NORMAL_MAP_STRENGTH 0.5 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define SPECULAR_MAPPING 2 //[0 1 2]
#define SPECULAR_LIGHT_QUALITY 2 //[1 2]
#define SHADER_WATER
#define WATER_GEOMETRY_WAVES
#define EXPOSURE
#define REFLECTIVITY_CURVE 2.0 //[1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0]

/*
const int colortex0Format = RGBA16F;
const int colortex7Format = RGBA16F;
const int colortex2Format = RGB16;
const int colortex3Format = RGB16;
const bool colortex0MipmapEnabled = true;
const bool colortex7MipmapEnabled = true;
*/

const float ambientOcclusionLevel = 1.0;
const float eyeBrightnessHalflife = 10.0;

const bool shadowcolor0Nearest = true;
const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;

const float shadowDistance = 160.0;
const int shadowMapResolution = 3072; //Resolution of the shadow map. Higher numbers mean more accurate shadows. [128 256 512 1024 2048 3072 4096 8192]
const float sunPathRotation = -30.0; // [-40.0 -30.0 -20.0 -10.0 0.0 10.0 20.0 30.0 40.0]
const int noiseTextureResolution = 512;
const float shadowDistanceRenderMul = SHADOW_RENDER_DISTANCE;