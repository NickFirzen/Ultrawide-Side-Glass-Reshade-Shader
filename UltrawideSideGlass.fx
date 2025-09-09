/*
 * UltrawideSideGlass ReShade Shader-Anti Pillarbox Measurement, small readme:
 
 * Installation:
 * Install ReShade if you haven'T yet from reshade.me for your game or media player.
 * Copy SideGlass_UltraWide.fx to your ReShade shaders folder per game/app you'd like to use with (..\reshade shaders\Shaders).
 * Open ReShade’s UI in-game (default: Home key).
 * Select SideGlass_UltraWide from the shader list.
 * Choose your aspect ratio (e.g., Enable_21_9 or Enable_32_9) and tweak settings as needed, try combos.
 * Optional: Extract the .rar for pre-configured settings or backup.
 
 * Fills black pillars on ultrawide monitors with zoomed, mirrored, or crystal-like content.
 * Center: Untouched, passes HDR metadata.
 * Sides: LegacyMirror -> Zoom -> ZoomFlip -> Fisheye -> MirrorPlane -> CrystalView -> FrostedBlur -> BrightnessBoost
 * Supported Aspect Ratios: 16:9, 21:9, 2.35:1, 2.37:1, 2.39:1, 2.40:1, 4:3, 2:1
 * Note: This is a comprehensive shader with all features. For optimal performance, create standalone versions per aspect ratio after finalizing settings.
 *
 * Tested with Media Player Classic x64 and Black Edition, using ReShade 6.5.1. Should work with games and other apps, but not guaranteed.
 * Created by NickFirzen, with significant help from Grok (xAI). Other AI tools (ChatGPT, Copilot, etc.) may have contributed—honestly, it was chaos, I’m not a coder! :)
 * No shaders by others were used; any similarities are coincidental due to AI assistance. Sorry if that happened!
 * I’ve wanted something like this for ages. Hope you love it as much as I do!
 *
 * License: Free to use, modify, or build upon (MIT License). Feel free to:
 * - Create versions for 16:9/16:10 to fill letterboxes instead of pillarboxes.
 * - Combine with other shaders/presets (e.g., add image backgrounds, alpha-transparent PNGs like window/TV frames or landscapes).
 *
 * Find me as NickFirzen on Ko-fi, YouTube, or elsewhere if you want to support me in anyway!
 * Ultrawide FTW!
 */

#include "ReShade.fxh"

// --- Helpers ---
float hash12(float2 p) {
    float h = dot(p, float2(127.1, 311.7));
    return frac(sin(h) * 43758.5453);
}

float perlin_noise(float2 p) {
    float2 i = floor(p);
    float2 f = frac(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return lerp(
        lerp(hash12(i + float2(0.0, 0.0)), hash12(i + float2(1.0, 0.0)), u.x),
        lerp(hash12(i + float2(0.0, 1.0)), hash12(i + float2(1.0, 1.0)), u.x),
        u.y
    );
}

float2 ApplyLegacyMirror(float2 uv, float left, float right, bool isLeftSide, float mirrorStrength, float mirrorAxisOffset) {
    float2 uvOut = uv;
    if (mirrorStrength > 0.0) {
        float axis = isLeftSide ? left + mirrorAxisOffset : right - mirrorAxisOffset;
        uvOut.x = isLeftSide ? (axis + (axis - uv.x)) : (axis - (uv.x - axis));
        uvOut.x = clamp(uvOut.x, left, right);
    }
    return lerp(uv, uvOut, mirrorStrength);
}

float2 ApplyZoom(float2 uv, float amount, float zoomAxisOffset) {
    float2 center = float2(0.5 + zoomAxisOffset, 0.5);
    return center + (uv - center) * (1.0 - amount);
}

float2 ApplyFisheye(float2 uv, float strength) {
    float2 c = float2(0.5, 0.5);
    float2 d = uv - c;
    float r = length(d);
    float f = 1.0 + strength * (r * r);
    return c + d / max(f, 1e-4);
}

float2 ApplyMirrorPlane(float2 uv, float left, float right, bool isLeftSide, float planeAngle, float depthScale, float stretch) {
    float2 uvOut = uv;
    float angleRad = radians(planeAngle);
    float depth = depthScale * (isLeftSide ? (left - uv.x) : (uv.x - right));
    uvOut.x += depth * tan(angleRad);
    uvOut.y = (uv.y - 0.5) * (1.0 + depth * stretch) + 0.5;
    uvOut.x = clamp(uvOut.x, left, right);
    return uvOut;
}

float2 ApplyCrystalView(float2 uv, float strength) {
    float2 p = uv * float2(BUFFER_WIDTH, BUFFER_HEIGHT) * 0.05; // Higher frequency for denser effect
    float noise = perlin_noise(p) * 2.0 - 1.0;
    float2 offset = float2(noise, noise) * strength * 0.02;
    return uv + offset;
}

float4 FrostedBlurTint(float2 uv, float strength, float tint, float3 tintRGB) {
    float2 off = float2(1.0 / BUFFER_WIDTH, 1.0 / BUFFER_HEIGHT) * max(strength, 1e-4);
    float4 sum = 0;
    [unroll]
    for (int x = -1; x <= 1; ++x) // Reduced kernel for MPC-BE compatibility
        [unroll]
        for (int y = -1; y <= 1; ++y)
            sum += tex2D(ReShade::BackBuffer, uv + float2(x, y) * off);
    float4 blurred = sum / 9.0;
    return lerp(blurred, float4(tintRGB, 1.0), saturate(tint));
}

float4 FrostedBlurBlack(float2 uv, float strength, float tintBlack) {
    return FrostedBlurTint(uv, strength, tintBlack, float3(0.0, 0.0, 0.0));
}

float4 FrostedBlurWhite(float2 uv, float strength, float tintWhite) {
    return FrostedBlurTint(uv, strength, tintWhite, float3(1.0, 1.0, 1.0));
}

float3 ApplyBrightnessBoost(float3 color, float boost) {
    return color * (1.0 + boost);
}

// --- 4:3 ---
uniform bool Enable_4_3 < ui_label = "Enable 4:3"; ui_category = "[4:3]"; ui_category_closed = true; > = false;
uniform float Blur_4_3 < ui_type="drag"; ui_label="Blur Strength"; ui_min=0.0; ui_max=16.0; ui_category="[4:3]"; > = 4.385000;
uniform float Zoom_4_3 < ui_type="drag"; ui_label="Zoom Amount"; ui_min=-2.0; ui_max=2.0; ui_category="[4:3]"; > = 0.000000;
uniform float ZoomAxisOffset_4_3 < ui_type="drag"; ui_label="Zoom Axis Offset"; ui_min=-0.5; ui_max=0.5; ui_category="[4:3]"; > = 0.000000;
uniform bool Enable_ZoomFlip_4_3 < ui_label="Enable Zoom-Flip Mode"; ui_category="[4:3]"; > = true;
uniform float Fisheye_4_3 < ui_type="drag"; ui_label="Fisheye Strength"; ui_min=-2.0; ui_max=2.0; ui_category="[4:3]"; > = 0.000000;
uniform float HorizontalFOV_4_3 < ui_type="drag"; ui_label="Horizontal FOV"; ui_min=0.2; ui_max=3.0; ui_category="[4:3]"; > = 1.000000;
uniform float FrostTintBlack_4_3 < ui_type="drag"; ui_label="Frost Tint (Black)"; ui_min=0.0; ui_max=2.0; ui_category="[4:3]"; > = 0.000000;
uniform float FrostTintWhite_4_3 < ui_type="drag"; ui_label="Frost Tint (White)"; ui_min=0.0; ui_max=2.0; ui_category="[4:3]"; > = 0.000000;
uniform bool Enable_AvgHorizontalStretch_4_3 < ui_label="Average Horizontal Stretch"; ui_category="[4:3]"; > = false;
uniform bool Enable_LegacyMirror_4_3 < ui_label="Enable Legacy Mirror"; ui_category="[4:3]"; > = false;
uniform float MirrorStrength_4_3 < ui_type="drag"; ui_label="Mirror Strength"; ui_min=0.0; ui_max=1.0; ui_category="[4:3]"; > = 0.500000;
uniform float MirrorAxisOffset_4_3 < ui_type="drag"; ui_label="Mirror Axis Offset"; ui_min=-0.5; ui_max=0.5; ui_category="[4:3]"; > = 0.000000;
uniform bool Enable_MirrorPlane_4_3 < ui_label="Enable Mirror Plane"; ui_category="[4:3]"; > = true;
uniform float PlaneAngle_4_3 < ui_type="drag"; ui_label="Plane Rotation Angle (degrees)"; ui_min=-45.0; ui_max=45.0; ui_category="[4:3]"; > = 0.000000;
uniform float DepthScale_4_3 < ui_type="drag"; ui_label="Depth Scale"; ui_min=0.0; ui_max=3.0; ui_category="[4:3]"; > = 0.833000;
uniform float Stretch_4_3 < ui_type="drag"; ui_label="Depth Stretch"; ui_min=0.0; ui_max=3.0; ui_category="[4:3]"; > = 1.052000;
uniform float CrystalStrength_4_3 < ui_type="drag"; ui_label="Crystal Strength"; ui_min=0.0; ui_max=1.0; ui_category="[4:3]"; > = 0.757000;
uniform float3 CrystalTint_4_3 < ui_type="color"; ui_label="Crystal Tint"; ui_category="[4:3]"; > = float3(0.371972, 0.588235, 0.098039);
uniform float CrystalTintStrength_4_3 < ui_type="drag"; ui_label="Crystal Tint Strength"; ui_min=0.0; ui_max=1.0; ui_category="[4:3]"; > = 0.000000;
uniform float BrightnessBoost_4_3 < ui_type="drag"; ui_label="Brightness Boost"; ui_min=0.0; ui_max=2.0; ui_category="[4:3]"; > = 0.000000;
uniform bool UseBackgroundColor_4_3 < ui_label="Use Solid Color"; ui_category="[4:3]"; > = false;
uniform float3 BackgroundColor_4_3 < ui_type="color"; ui_label="Background Color"; ui_category="[4:3]"; > = float3(0.000000, 0.000000, 0.000000);
uniform bool ShowDebugMask_4_3 < ui_label="Show Side Mask (Red)"; ui_category="[4:3]"; > = false;

// --- 16:9 ---
uniform bool Enable_16_9 < ui_label = "Enable 16:9"; ui_category = "[16:9]"; ui_category_closed = true; > = false;
uniform float Blur_16_9 < ui_type="drag"; ui_label="Blur Strength"; ui_min=0.0; ui_max=16.0; ui_category="[16:9]"; > = 4.000000;
uniform float Zoom_16_9 < ui_type="drag"; ui_label="Zoom Amount"; ui_min=-2.0; ui_max=2.0; ui_category="[16:9]"; > = 0.000000;
uniform float ZoomAxisOffset_16_9 < ui_type="drag"; ui_label="Zoom Axis Offset"; ui_min=-0.5; ui_max=0.5; ui_category="[16:9]"; > = 0.000000;
uniform bool Enable_ZoomFlip_16_9 < ui_label="Enable Zoom-Flip Mode"; ui_category="[16:9]"; > = true;
uniform float Fisheye_16_9 < ui_type="drag"; ui_label="Fisheye Strength"; ui_min=-2.0; ui_max=2.0; ui_category="[16:9]"; > = 0.332000;
uniform float HorizontalFOV_16_9 < ui_type="drag"; ui_label="Horizontal FOV"; ui_min=0.2; ui_max=3.0; ui_category="[16:9]"; > = 1.000000;
uniform float FrostTintBlack_16_9 < ui_type="drag"; ui_label="Frost Tint (Black)"; ui_min=0.0; ui_max=2.0; ui_category="[16:9]"; > = 0.000000;
uniform float FrostTintWhite_16_9 < ui_type="drag"; ui_label="Frost Tint (White)"; ui_min=0.0; ui_max=2.0; ui_category="[16:9]"; > = 0.000000;
uniform bool Enable_AvgHorizontalStretch_16_9 < ui_label="Average Horizontal Stretch"; ui_category="[16:9]"; > = false;
uniform bool Enable_LegacyMirror_16_9 < ui_label="Enable Legacy Mirror"; ui_category="[16:9]"; > = false;
uniform float MirrorStrength_16_9 < ui_type="drag"; ui_label="Mirror Strength"; ui_min=0.0; ui_max=1.0; ui_category="[16:9]"; > = 0.500000;
uniform float MirrorAxisOffset_16_9 < ui_type="drag"; ui_label="Mirror Axis Offset"; ui_min=-0.5; ui_max=0.5; ui_category="[16:9]"; > = 0.000000;
uniform bool Enable_MirrorPlane_16_9 < ui_label="Enable Mirror Plane"; ui_category="[16:9]"; > = true;
uniform float PlaneAngle_16_9 < ui_type="drag"; ui_label="Plane Rotation Angle (degrees)"; ui_min=-45.0; ui_max=45.0; ui_category="[16:9]"; > = 0.000000;
uniform float DepthScale_16_9 < ui_type="drag"; ui_label="Depth Scale"; ui_min=0.0; ui_max=3.0; ui_category="[16:9]"; > = 0.900000;
uniform float Stretch_16_9 < ui_type="drag"; ui_label="Depth Stretch"; ui_min=0.0; ui_max=3.0; ui_category="[16:9]"; > = 2.244000;
uniform float CrystalStrength_16_9 < ui_type="drag"; ui_label="Crystal Strength"; ui_min=0.0; ui_max=1.0; ui_category="[16:9]"; > = 0.291000;
uniform float3 CrystalTint_16_9 < ui_type="color"; ui_label="Crystal Tint"; ui_category="[16:9]"; > = float3(0.041450, 0.394754, 0.563725);
uniform float CrystalTintStrength_16_9 < ui_type="drag"; ui_label="Crystal Tint Strength"; ui_min=0.0; ui_max=1.0; ui_category="[16:9]"; > = 0.000000;
uniform float BrightnessBoost_16_9 < ui_type="drag"; ui_label="Brightness Boost"; ui_min=0.0; ui_max=2.0; ui_category="[16:9]"; > = 0.000000;
uniform bool UseBackgroundColor_16_9 < ui_label="Use Solid Color"; ui_category="[16:9]"; > = false;
uniform float3 BackgroundColor_16_9 < ui_type="color"; ui_label="Background Color"; ui_category="[16:9]"; > = float3(0.387255, 0.360679, 0.360679);
uniform bool ShowDebugMask_16_9 < ui_label="Show Side Mask (Red)"; ui_category="[16:9]"; > = false;

// --- 21:9 ---
uniform bool Enable_21_9 < ui_label = "Enable 21:9"; ui_category = "[21:9]"; ui_category_closed = true; > = false;
uniform float Blur_21_9 < ui_type="drag"; ui_label="Blur Strength"; ui_min=0.0; ui_max=16.0; ui_category="[21:9]"; > = 2.000000;
uniform float Zoom_21_9 < ui_type="drag"; ui_label="Zoom Amount"; ui_min=-2.0; ui_max=2.0; ui_category="[21:9]"; > = 0.000000;
uniform float ZoomAxisOffset_21_9 < ui_type="drag"; ui_label="Zoom Axis Offset"; ui_min=-0.5; ui_max=0.5; ui_category="[21:9]"; > = 0.000000;
uniform bool Enable_ZoomFlip_21_9 < ui_label="Enable Zoom-Flip Mode"; ui_category="[21:9]"; > = true;
uniform float Fisheye_21_9 < ui_type="drag"; ui_label="Fisheye Strength"; ui_min=-2.0; ui_max=2.0; ui_category="[21:9]"; > = 0.037000;
uniform float HorizontalFOV_21_9 < ui_type="drag"; ui_label="Horizontal FOV"; ui_min=0.2; ui_max=3.0; ui_category="[21:9]"; > = 1.000000;
uniform float FrostTintBlack_21_9 < ui_type="drag"; ui_label="Frost Tint (Black)"; ui_min=0.0; ui_max=2.0; ui_category="[21:9]"; > = 0.000000;
uniform float FrostTintWhite_21_9 < ui_type="drag"; ui_label="Frost Tint (White)"; ui_min=0.0; ui_max=2.0; ui_category="[21:9]"; > = 0.000000;
uniform bool Enable_AvgHorizontalStretch_21_9 < ui_label="Average Horizontal Stretch"; ui_category="[21:9]"; > = false;
uniform bool Enable_LegacyMirror_21_9 < ui_label="Enable Legacy Mirror"; ui_category="[21:9]"; > = false;
uniform float MirrorStrength_21_9 < ui_type="drag"; ui_label="Mirror Strength"; ui_min=0.0; ui_max=1.0; ui_category="[21:9]"; > = 0.500000;
uniform float MirrorAxisOffset_21_9 < ui_type="drag"; ui_label="Mirror Axis Offset"; ui_min=-0.5; ui_max=0.5; ui_category="[21:9]"; > = 0.000000;
uniform bool Enable_MirrorPlane_21_9 < ui_label="Enable Mirror Plane"; ui_category="[21:9]"; > = true;
uniform float PlaneAngle_21_9 < ui_type="drag"; ui_label="Plane Rotation Angle (degrees)"; ui_min=-45.0; ui_max=45.0; ui_category="[21:9]"; > = 0.000000;
uniform float DepthScale_21_9 < ui_type="drag"; ui_label="Depth Scale"; ui_min=0.0; ui_max=3.0; ui_category="[21:9]"; > = 0.670000;
uniform float Stretch_21_9 < ui_type="drag"; ui_label="Depth Stretch"; ui_min=0.0; ui_max=3.0; ui_category="[21:9]"; > = 0.817000;
uniform float CrystalStrength_21_9 < ui_type="drag"; ui_label="Crystal Strength"; ui_min=0.0; ui_max=1.0; ui_category="[21:9]"; > = 0.200000;
uniform float3 CrystalTint_21_9 < ui_type="color"; ui_label="Crystal Tint"; ui_category="[21:9]"; > = float3(0.000000, 0.000000, 0.000000);
uniform float CrystalTintStrength_21_9 < ui_type="drag"; ui_label="Crystal Tint Strength"; ui_min=0.0; ui_max=1.0; ui_category="[21:9]"; > = 0.000000;
uniform float BrightnessBoost_21_9 < ui_type="drag"; ui_label="Brightness Boost"; ui_min=0.0; ui_max=2.0; ui_category="[21:9]"; > = 0.000000;
uniform bool UseBackgroundColor_21_9 < ui_label="Use Solid Color"; ui_category="[21:9]"; > = false;
uniform float3 BackgroundColor_21_9 < ui_type="color"; ui_label="Background Color"; ui_category="[21:9]"; > = float3(0.000000, 0.000000, 0.000000);
uniform bool ShowDebugMask_21_9 < ui_label="Show Side Mask (Red)"; ui_category="[21:9]"; > = false;

// --- 2:1 ---
uniform bool Enable_2_1 < ui_label = "Enable 2:1"; ui_category = "[2:1]"; ui_category_closed = true; > = false;
uniform float Blur_2_1 < ui_type="drag"; ui_label="Blur Strength"; ui_min=0.0; ui_max=16.0; ui_category="[2:1]"; > = 2.000000;
uniform float Zoom_2_1 < ui_type="drag"; ui_label="Zoom Amount"; ui_min=-2.0; ui_max=2.0; ui_category="[2:1]"; > = 0.000000;
uniform float ZoomAxisOffset_2_1 < ui_type="drag"; ui_label="Zoom Axis Offset"; ui_min=-0.5; ui_max=0.5; ui_category="[2:1]"; > = 0.000000;
uniform bool Enable_ZoomFlip_2_1 < ui_label="Enable Zoom-Flip Mode"; ui_category="[2:1]"; > = true;
uniform float Fisheye_2_1 < ui_type="drag"; ui_label="Fisheye Strength"; ui_min=-2.0; ui_max=2.0; ui_category="[2:1]"; > = 0.250000;
uniform float HorizontalFOV_2_1 < ui_type="drag"; ui_label="Horizontal FOV"; ui_min=0.2; ui_max=3.0; ui_category="[2:1]"; > = 1.000000;
uniform float FrostTintBlack_2_1 < ui_type="drag"; ui_label="Frost Tint (Black)"; ui_min=0.0; ui_max=2.0; ui_category="[2:1]"; > = 0.000000;
uniform float FrostTintWhite_2_1 < ui_type="drag"; ui_label="Frost Tint (White)"; ui_min=0.0; ui_max=2.0; ui_category="[2:1]"; > = 0.000000;
uniform bool Enable_AvgHorizontalStretch_2_1 < ui_label="Average Horizontal Stretch"; ui_category="[2:1]"; > = false;
uniform bool Enable_LegacyMirror_2_1 < ui_label="Enable Legacy Mirror"; ui_category="[2:1]"; > = false;
uniform float MirrorStrength_2_1 < ui_type="drag"; ui_label="Mirror Strength"; ui_min=0.0; ui_max=1.0; ui_category="[2:1]"; > = 0.500000;
uniform float MirrorAxisOffset_2_1 < ui_type="drag"; ui_label="Mirror Axis Offset"; ui_min=-0.5; ui_max=0.5; ui_category="[2:1]"; > = 0.000000;
uniform bool Enable_MirrorPlane_2_1 < ui_label="Enable Mirror Plane"; ui_category="[2:1]"; > = true;
uniform float PlaneAngle_2_1 < ui_type="drag"; ui_label="Plane Rotation Angle (degrees)"; ui_min=-45.0; ui_max=45.0; ui_category="[2:1]"; > = 0.000000;
uniform float DepthScale_2_1 < ui_type="drag"; ui_label="Depth Scale"; ui_min=0.0; ui_max=3.0; ui_category="[2:1]"; > = 0.876000;
uniform float Stretch_2_1 < ui_type="drag"; ui_label="Depth Stretch"; ui_min=0.0; ui_max=3.0; ui_category="[2:1]"; > = 1.109000;
uniform float CrystalStrength_2_1 < ui_type="drag"; ui_label="Crystal Strength"; ui_min=0.0; ui_max=1.0; ui_category="[2:1]"; > = 0.200000;
uniform float3 CrystalTint_2_1 < ui_type="color"; ui_label="Crystal Tint"; ui_category="[2:1]"; > = float3(0.000000, 0.000000, 0.000000);
uniform float CrystalTintStrength_2_1 < ui_type="drag"; ui_label="Crystal Tint Strength"; ui_min=0.0; ui_max=1.0; ui_category="[2:1]"; > = 0.000000;
uniform float BrightnessBoost_2_1 < ui_type="drag"; ui_label="Brightness Boost"; ui_min=0.0; ui_max=2.0; ui_category="[2:1]"; > = 0.000000;
uniform bool UseBackgroundColor_2_1 < ui_label="Use Solid Color"; ui_category="[2:1]"; > = false;
uniform float3 BackgroundColor_2_1 < ui_type="color"; ui_label="Background Color"; ui_category="[2:1]"; > = float3(0.000000, 0.000000, 0.000000);
uniform bool ShowDebugMask_2_1 < ui_label="Show Side Mask (Red)"; ui_category="[2:1]"; > = false;

// --- 2.35:1 ---
uniform bool Enable_2_35_1 < ui_label = "Enable 2.35:1"; ui_category = "[2.35:1]"; ui_category_closed = true; > = false;
uniform float Blur_2_35_1 < ui_type="drag"; ui_label="Blur Strength"; ui_min=0.0; ui_max=16.0; ui_category="[2.35:1]"; > = 3.556000;
uniform float Zoom_2_35_1 < ui_type="drag"; ui_label="Zoom Amount"; ui_min=-2.0; ui_max=2.0; ui_category="[2.35:1]"; > = 0.000000;
uniform float ZoomAxisOffset_2_35_1 < ui_type="drag"; ui_label="Zoom Axis Offset"; ui_min=-0.5; ui_max=0.5; ui_category="[2.35:1]"; > = 0.000000;
uniform bool Enable_ZoomFlip_2_35_1 < ui_label="Enable Zoom-Flip Mode"; ui_category="[2.35:1]"; > = true;
uniform float Fisheye_2_35_1 < ui_type="drag"; ui_label="Fisheye Strength"; ui_min=-2.0; ui_max=2.0; ui_category="[2.35:1]"; > = 0.256000;
uniform float HorizontalFOV_2_35_1 < ui_type="drag"; ui_label="Horizontal FOV"; ui_min=0.2; ui_max=3.0; ui_category="[2.35:1]"; > = 1.000000;
uniform float FrostTintBlack_2_35_1 < ui_type="drag"; ui_label="Frost Tint (Black)"; ui_min=0.0; ui_max=2.0; ui_category="[2.35:1]"; > = 0.000000;
uniform float FrostTintWhite_2_35_1 < ui_type="drag"; ui_label="Frost Tint (White)"; ui_min=0.0; ui_max=2.0; ui_category="[2.35:1]"; > = 0.000000;
uniform bool Enable_AvgHorizontalStretch_2_35_1 < ui_label="Average Horizontal Stretch"; ui_category="[2.35:1]"; > = false;
uniform bool Enable_LegacyMirror_2_35_1 < ui_label="Enable Legacy Mirror"; ui_category="[2.35:1]"; > = false;
uniform float MirrorStrength_2_35_1 < ui_type="drag"; ui_label="Mirror Strength"; ui_min=0.0; ui_max=1.0; ui_category="[2.35:1]"; > = 0.500000;
uniform float MirrorAxisOffset_2_35_1 < ui_type="drag"; ui_label="Mirror Axis Offset"; ui_min=-0.5; ui_max=0.5; ui_category="[2.35:1]"; > = 0.000000;
uniform bool Enable_MirrorPlane_2_35_1 < ui_label="Enable Mirror Plane"; ui_category="[2.35:1]"; > = true;
uniform float PlaneAngle_2_35_1 < ui_type="drag"; ui_label="Plane Rotation Angle (degrees)"; ui_min=-45.0; ui_max=45.0; ui_category="[2.35:1]"; > = 0.000000;
uniform float DepthScale_2_35_1 < ui_type="drag"; ui_label="Depth Scale"; ui_min=0.0; ui_max=3.0; ui_category="[2.35:1]"; > = 1.014000;
uniform float Stretch_2_35_1 < ui_type="drag"; ui_label="Depth Stretch"; ui_min=0.0; ui_max=3.0; ui_category="[2.35:1]"; > = 1.854000;
uniform float CrystalStrength_2_35_1 < ui_type="drag"; ui_label="Crystal Strength"; ui_min=0.0; ui_max=1.0; ui_category="[2.35:1]"; > = 0.778000;
uniform float3 CrystalTint_2_35_1 < ui_type="color"; ui_label="Crystal Tint"; ui_category="[2.35:1]"; > = float3(0.221909, 0.475490, 0.156166);
uniform float CrystalTintStrength_2_35_1 < ui_type="drag"; ui_label="Crystal Tint Strength"; ui_min=0.0; ui_max=1.0; ui_category="[2.35:1]"; > = 0.000000;
uniform float BrightnessBoost_2_35_1 < ui_type="drag"; ui_label="Brightness Boost"; ui_min=0.0; ui_max=2.0; ui_category="[2.35:1]"; > = 0.000000;
uniform bool UseBackgroundColor_2_35_1 < ui_label="Use Solid Color"; ui_category="[2.35:1]"; > = false;
uniform float3 BackgroundColor_2_35_1 < ui_type="color"; ui_label="Background Color"; ui_category="[2.35:1]"; > = float3(0.000000, 0.000000, 0.000000);
uniform bool ShowDebugMask_2_35_1 < ui_label="Show Side Mask (Red)"; ui_category="[2.35:1]"; > = false;

// --- 2.37:1 ---
uniform bool Enable_2_37_1 < ui_label = "Enable 2.37:1"; ui_category = "[2.37:1]"; ui_category_closed = true; > = false;
uniform float Blur_2_37_1 < ui_type="drag"; ui_label="Blur Strength"; ui_min=0.0; ui_max=16.0; ui_category="[2.37:1]"; > = 4.000000;
uniform float Zoom_2_37_1 < ui_type="drag"; ui_label="Zoom Amount"; ui_min=-2.0; ui_max=2.0; ui_category="[2.37:1]"; > = 0.000000;
uniform float ZoomAxisOffset_2_37_1 < ui_type="drag"; ui_label="Zoom Axis Offset"; ui_min=-0.5; ui_max=0.5; ui_category="[2.37:1]"; > = 0.080000;
uniform bool Enable_ZoomFlip_2_37_1 < ui_label="Enable Zoom-Flip Mode"; ui_category="[2.37:1]"; > = true;
uniform float Fisheye_2_37_1 < ui_type="drag"; ui_label="Fisheye Strength"; ui_min=-2.0; ui_max=2.0; ui_category="[2.37:1]"; > = 0.478000;
uniform float HorizontalFOV_2_37_1 < ui_type="drag"; ui_label="Horizontal FOV"; ui_min=0.2; ui_max=3.0; ui_category="[2.37:1]"; > = 1.000000;
uniform float FrostTintBlack_2_37_1 < ui_type="drag"; ui_label="Frost Tint (Black)"; ui_min=0.0; ui_max=2.0; ui_category="[2.37:1]"; > = 0.000000;
uniform float FrostTintWhite_2_37_1 < ui_type="drag"; ui_label="Frost Tint (White)"; ui_min=0.0; ui_max=2.0; ui_category="[2.37:1]"; > = 0.000000;
uniform bool Enable_AvgHorizontalStretch_2_37_1 < ui_label="Average Horizontal Stretch"; ui_category="[2.37:1]"; > = false;
uniform bool Enable_LegacyMirror_2_37_1 < ui_label="Enable Legacy Mirror"; ui_category="[2.37:1]"; > = false;
uniform float MirrorStrength_2_37_1 < ui_type="drag"; ui_label="Mirror Strength"; ui_min=0.0; ui_max=1.0; ui_category="[2.37:1]"; > = 1.500000;
uniform float MirrorAxisOffset_2_37_1 < ui_type="drag"; ui_label="Mirror Axis Offset"; ui_min=-0.5; ui_max=0.5; ui_category="[2.37:1]"; > = 0.000000;
uniform bool Enable_MirrorPlane_2_37_1 < ui_label="Enable Mirror Plane"; ui_category="[2.37:1]"; > = true;
uniform float PlaneAngle_2_37_1 < ui_type="drag"; ui_label="Plane Rotation Angle (degrees)"; ui_min=-45.0; ui_max=45.0; ui_category="[2.37:1]"; > = 0.000000;
uniform float DepthScale_2_37_1 < ui_type="drag"; ui_label="Depth Scale"; ui_min=0.0; ui_max=3.0; ui_category="[2.37:1]"; > = 3.000000;
uniform float Stretch_2_37_1 < ui_type="drag"; ui_label="Depth Stretch"; ui_min=0.0; ui_max=3.0; ui_category="[2.37:1]"; > = 0.767000;
uniform float CrystalStrength_2_37_1 < ui_type="drag"; ui_label="Crystal Strength"; ui_min=0.0; ui_max=1.0; ui_category="[2.37:1]"; > = 1.000000;
uniform float3 CrystalTint_2_37_1 < ui_type="color"; ui_label="Crystal Tint"; ui_category="[2.37:1]"; > = float3(0.171424, 0.426471, 0.171424);
uniform float CrystalTintStrength_2_37_1 < ui_type="drag"; ui_label="Crystal Tint Strength"; ui_min=0.0; ui_max=1.0; ui_category="[2.37:1]"; > = 0.000000;
uniform float BrightnessBoost_2_37_1 < ui_type="drag"; ui_label="Brightness Boost"; ui_min=0.0; ui_max=2.0; ui_category="[2.37:1]"; > = 0.000000;
uniform bool UseBackgroundColor_2_37_1 < ui_label="Use Solid Color"; ui_category="[2.37:1]"; > = false;
uniform float3 BackgroundColor_2_37_1 < ui_type="color"; ui_label="Background Color"; ui_category="[2.37:1]"; > = float3(0.000000, 0.000000, 0.000000);
uniform bool ShowDebugMask_2_37_1 < ui_label="Show Side Mask (Red)"; ui_category="[2.37:1]"; > = false;

// --- 2.39:1 ---
uniform bool Enable_2_39_1 < ui_label = "Enable 2.39:1"; ui_category = "[2.39:1]"; ui_category_closed = true; > = false;
uniform float Blur_2_39_1 < ui_type="drag"; ui_label="Blur Strength"; ui_min=0.0; ui_max=16.0; ui_category="[2.39:1]"; > = 3.126000;
uniform float Zoom_2_39_1 < ui_type="drag"; ui_label="Zoom Amount"; ui_min=-2.0; ui_max=2.0; ui_category="[2.39:1]"; > = 0.000000;
uniform float ZoomAxisOffset_2_39_1 < ui_type="drag"; ui_label="Zoom Axis Offset"; ui_min=-0.5; ui_max=0.5; ui_category="[2.39:1]"; > = 0.000000;
uniform bool Enable_ZoomFlip_2_39_1 < ui_label="Enable Zoom-Flip Mode"; ui_category="[2.39:1]"; > = true;
uniform float Fisheye_2_39_1 < ui_type="drag"; ui_label="Fisheye Strength"; ui_min=-2.0; ui_max=2.0; ui_category="[2.39:1]"; > = 0.233000;
uniform float HorizontalFOV_2_39_1 < ui_type="drag"; ui_label="Horizontal FOV"; ui_min=0.2; ui_max=3.0; ui_category="[2.39:1]"; > = 1.000000;
uniform float FrostTintBlack_2_39_1 < ui_type="drag"; ui_label="Frost Tint (Black)"; ui_min=0.0; ui_max=2.0; ui_category="[2.39:1]"; > = 0.000000;
uniform float FrostTintWhite_2_39_1 < ui_type="drag"; ui_label="Frost Tint (White)"; ui_min=0.0; ui_max=2.0; ui_category="[2.39:1]"; > = 0.000000;
uniform bool Enable_AvgHorizontalStretch_2_39_1 < ui_label="Average Horizontal Stretch"; ui_category="[2.39:1]"; > = false;
uniform bool Enable_LegacyMirror_2_39_1 < ui_label="Enable Legacy Mirror"; ui_category="[2.39:1]"; > = false;
uniform float MirrorStrength_2_39_1 < ui_type="drag"; ui_label="Mirror Strength"; ui_min=0.0; ui_max=1.0; ui_category="[2.39:1]"; > = 0.500000;
uniform float MirrorAxisOffset_2_39_1 < ui_type="drag"; ui_label="Mirror Axis Offset"; ui_min=-0.5; ui_max=0.5; ui_category="[2.39:1]"; > = 0.000000;
uniform bool Enable_MirrorPlane_2_39_1 < ui_label="Enable Mirror Plane"; ui_category="[2.39:1]"; > = true;
uniform float PlaneAngle_2_39_1 < ui_type="drag"; ui_label="Plane Rotation Angle (degrees)"; ui_min=-45.0; ui_max=45.0; ui_category="[2.39:1]"; > = 0.000000;
uniform float DepthScale_2_39_1 < ui_type="drag"; ui_label="Depth Scale"; ui_min=0.0; ui_max=3.0; ui_category="[2.39:1]"; > = 2.891000;
uniform float Stretch_2_39_1 < ui_type="drag"; ui_label="Depth Stretch"; ui_min=0.0; ui_max=3.0; ui_category="[2.39:1]"; > = 1.049000;
uniform float CrystalStrength_2_39_1 < ui_type="drag"; ui_label="Crystal Strength"; ui_min=0.0; ui_max=1.0; ui_category="[2.39:1]"; > = 0.518000;
uniform float3 CrystalTint_2_39_1 < ui_type="color"; ui_label="Crystal Tint"; ui_category="[2.39:1]"; > = float3(0.000000, 0.000000, 0.000000);
uniform float CrystalTintStrength_2_39_1 < ui_type="drag"; ui_label="Crystal Tint Strength"; ui_min=0.0; ui_max=1.0; ui_category="[2.39:1]"; > = 0.000000;
uniform float BrightnessBoost_2_39_1 < ui_type="drag"; ui_label="Brightness Boost"; ui_min=0.0; ui_max=2.0; ui_category="[2.39:1]"; > = 0.000000;
uniform bool UseBackgroundColor_2_39_1 < ui_label="Use Solid Color"; ui_category="[2.39:1]"; > = false;
uniform float3 BackgroundColor_2_39_1 < ui_type="color"; ui_label="Background Color"; ui_category="[2.39:1]"; > = float3(0.639668, 0.740196, 0.170535);
uniform bool ShowDebugMask_2_39_1 < ui_label="Show Side Mask (Red)"; ui_category="[2.39:1]"; > = false;

// --- 2.40:1 ---
uniform bool Enable_2_40_1 < ui_label = "Enable 2.40:1"; ui_category = "[2.40:1]"; ui_category_closed = true; > = false;
uniform float Blur_2_40_1 < ui_type="drag"; ui_label="Blur Strength"; ui_min=0.0; ui_max=16.0; ui_category="[2.40:1]"; > = 2.676000;
uniform float Zoom_2_40_1 < ui_type="drag"; ui_label="Zoom Amount"; ui_min=-2.0; ui_max=2.0; ui_category="[2.40:1]"; > = -0.000000;
uniform float ZoomAxisOffset_2_40_1 < ui_type="drag"; ui_label="Zoom Axis Offset"; ui_min=-0.5; ui_max=0.5; ui_category="[2.40:1]"; > = 0.000000;
uniform bool Enable_ZoomFlip_2_40_1 < ui_label="Enable Zoom-Flip Mode"; ui_category="[2.40:1]"; > = true;
uniform float Fisheye_2_40_1 < ui_type="drag"; ui_label="Fisheye Strength"; ui_min=-2.0; ui_max=2.0; ui_category="[2.40:1]"; > = 0.571000;
uniform float HorizontalFOV_2_40_1 < ui_type="drag"; ui_label="Horizontal FOV"; ui_min=0.2; ui_max=3.0; ui_category="[2.40:1]"; > = 1.000000;
uniform float FrostTintBlack_2_40_1 < ui_type="drag"; ui_label="Frost Tint (Black)"; ui_min=0.0; ui_max=2.0; ui_category="[2.40:1]"; > = 0.000000;
uniform float FrostTintWhite_2_40_1 < ui_type="drag"; ui_label="Frost Tint (White)"; ui_min=0.0; ui_max=2.0; ui_category="[2.40:1]"; > = 0.000000;
uniform bool Enable_AvgHorizontalStretch_2_40_1 < ui_label="Average Horizontal Stretch"; ui_category="[2.40:1]"; > = false;
uniform bool Enable_LegacyMirror_2_40_1 < ui_label="Enable Legacy Mirror"; ui_category="[2.40:1]"; > = false;
uniform float MirrorStrength_2_40_1 < ui_type="drag"; ui_label="Mirror Strength"; ui_min=0.0; ui_max=1.0; ui_category="[2.40:1]"; > = 0.500000;
uniform float MirrorAxisOffset_2_40_1 < ui_type="drag"; ui_label="Mirror Axis Offset"; ui_min=-0.5; ui_max=0.5; ui_category="[2.40:1]"; > = 0.000000;
uniform bool Enable_MirrorPlane_2_40_1 < ui_label="Enable Mirror Plane"; ui_category="[2.40:1]"; > = true;
uniform float PlaneAngle_2_40_1 < ui_type="drag"; ui_label="Plane Rotation Angle (degrees)"; ui_min=-45.0; ui_max=45.0; ui_category="[2.40:1]"; > = 0.000000;
uniform float DepthScale_2_40_1 < ui_type="drag"; ui_label="Depth Scale"; ui_min=0.0; ui_max=3.0; ui_category="[2.40:1]"; > = 0.600000;
uniform float Stretch_2_40_1 < ui_type="drag"; ui_label="Depth Stretch"; ui_min=0.0; ui_max=3.0; ui_category="[2.40:1]"; > = 0.600000;
uniform float CrystalStrength_2_40_1 < ui_type="drag"; ui_label="Crystal Strength"; ui_min=0.0; ui_max=1.0; ui_category="[2.40:1]"; > = 1.000000;
uniform float3 CrystalTint_2_40_1 < ui_type="color"; ui_label="Crystal Tint"; ui_category="[2.40:1]"; > = float3(0.235701, 0.705882, 0.134948);
uniform float CrystalTintStrength_2_40_1 < ui_type="drag"; ui_label="Crystal Tint Strength"; ui_min=0.0; ui_max=1.0; ui_category="[2.40:1]"; > = 0.000000;
uniform float BrightnessBoost_2_40_1 < ui_type="drag"; ui_label="Brightness Boost"; ui_min=0.0; ui_max=2.0; ui_category="[2.40:1]"; > = 0.000000;
uniform bool UseBackgroundColor_2_40_1 < ui_label="Use Solid Color"; ui_category="[2.40:1]"; > = false;
uniform float3 BackgroundColor_2_40_1 < ui_type="color"; ui_label="Background Color"; ui_category="[2.40:1]"; > = float3(0.289216, 0.289216, 0.289216);
uniform bool ShowDebugMask_2_40_1 < ui_label="Show Side Mask (Red)"; ui_category="[2.40:1]"; > = false;

// --- Pixel Shader ---
float4 PS_SideGlass(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    if (Enable_4_3) // 4:3
    {
        float aspect = 4.0 / 3.0;
        float blur = Blur_4_3;
        float zoom = Zoom_4_3;
        float zoomAxisOffset = ZoomAxisOffset_4_3;
        bool enableZoomFlip = Enable_ZoomFlip_4_3;
        float fish = Fisheye_4_3;
        float hFOV = HorizontalFOV_4_3;
        float frostB = FrostTintBlack_4_3;
        float frostW = FrostTintWhite_4_3;
        bool avgStretch = Enable_AvgHorizontalStretch_4_3;
        bool legacyMirror = Enable_LegacyMirror_4_3;
        float mirrorStrength = MirrorStrength_4_3;
        float mirrorAxisOffset = MirrorAxisOffset_4_3;
        bool mirrorPlane = Enable_MirrorPlane_4_3;
        float planeAngle = PlaneAngle_4_3;
        float depthScale = DepthScale_4_3;
        float stretch = Stretch_4_3;
        float crystalStrength = CrystalStrength_4_3;
        float brightnessBoost = BrightnessBoost_4_3;
        bool useCol = UseBackgroundColor_4_3;
        float3 bgCol = BackgroundColor_4_3;
        bool dbg = ShowDebugMask_4_3;

        float innerW = BUFFER_HEIGHT * aspect;
        float left = (BUFFER_WIDTH - innerW) * 0.5 / BUFFER_WIDTH;
        float right = 1.0 - left;
        bool isSide = uv.x < left || uv.x > right;
        if (!isSide) return tex2D(ReShade::BackBuffer, uv);

        bool toLeft = uv.x < left;
        float2 uvWorking = uv;

        if (avgStretch) {
            float4 avgcol = 0;
            [unroll]
            for (int k = 0; k < 4; ++k) {
                float t = (k + 0.5) / 4.0;
                float2 sUV = float2(t, uv.y);
                avgcol += tex2D(ReShade::BackBuffer, sUV);
            }
            float4 outAvg = avgcol / 4.0;
            if (dbg) outAvg.rgb = float3(1, 0, 0);
            return outAvg;
        }

        float4 sideBase;
        if (useCol) {
            sideBase = float4(bgCol, 1.0);
        } else {
            float2 uvTemp = uvWorking;
            if (legacyMirror) {
                uvTemp = ApplyLegacyMirror(uvTemp, left, right, toLeft, mirrorStrength, mirrorAxisOffset);
            }
            float2 zUV = ApplyZoom(uvTemp, zoom, zoomAxisOffset);
            if (enableZoomFlip) {
                if (uv.x < left) {
                    zUV.x = 2.0 * left - zUV.x;
                } else if (uv.x > right) {
                    zUV.x = 2.0 * right - zUV.x;
                }
            }
            float2 feUV = ApplyFisheye(zUV, fish);
            if (mirrorPlane) {
                feUV = ApplyMirrorPlane(feUV, left, right, toLeft, planeAngle, depthScale, stretch);
            }
            feUV = ApplyCrystalView(feUV, crystalStrength);
            feUV.x = 0.5 + (feUV.x - 0.5) * hFOV;
            sideBase = tex2D(ReShade::BackBuffer, feUV);
            sideBase.rgb = lerp(sideBase.rgb, sideBase.rgb * CrystalTint_4_3, CrystalTintStrength_4_3);

            float4 blackBlur = FrostedBlurBlack(feUV, blur, frostB);
            float4 whiteBlur = FrostedBlurWhite(feUV, blur, frostW);

            sideBase = (sideBase * 0.4 + blackBlur * 0.3 + whiteBlur * 0.3);
        }

        sideBase.rgb = ApplyBrightnessBoost(sideBase.rgb, brightnessBoost);

        if (dbg) sideBase.rgb = float3(1, 0, 0);
        return sideBase;
    }
    if (Enable_16_9) // 16:9
    {
        float aspect = 16.0 / 9.0;
        float blur = Blur_16_9;
        float zoom = Zoom_16_9;
        float zoomAxisOffset = ZoomAxisOffset_16_9;
        bool enableZoomFlip = Enable_ZoomFlip_16_9;
        float fish = Fisheye_16_9;
        float hFOV = HorizontalFOV_16_9;
        float frostB = FrostTintBlack_16_9;
        float frostW = FrostTintWhite_16_9;
        bool avgStretch = Enable_AvgHorizontalStretch_16_9;
        bool legacyMirror = Enable_LegacyMirror_16_9;
        float mirrorStrength = MirrorStrength_16_9;
        float mirrorAxisOffset = MirrorAxisOffset_16_9;
        bool mirrorPlane = Enable_MirrorPlane_16_9;
        float planeAngle = PlaneAngle_16_9;
        float depthScale = DepthScale_16_9;
        float stretch = Stretch_16_9;
        float crystalStrength = CrystalStrength_16_9;
        float brightnessBoost = BrightnessBoost_16_9;
        bool useCol = UseBackgroundColor_16_9;
        float3 bgColSolid = BackgroundColor_16_9; // renamed to avoid clash
        bool dbg = ShowDebugMask_16_9;

        float4 color = tex2D(ReShade::BackBuffer, uv); 
        float innerW = BUFFER_HEIGHT * aspect;
        float left = (BUFFER_WIDTH - innerW) * 0.5 / BUFFER_WIDTH;
        float right = 1.0 - left;
        bool isSide = uv.x < left || uv.x > right;
        if (!isSide) return tex2D(ReShade::BackBuffer, uv);

        bool toLeft = uv.x < left;
        float2 uvWorking = uv;

        if (avgStretch) {
            float4 avgcol = 0;
            [unroll]
            for (int k = 0; k < 4; ++k) {
                float t = (k + 0.5) / 4.0;
                float2 sUV = float2(t, uv.y);
                avgcol += tex2D(ReShade::BackBuffer, sUV);
            }
            float4 outAvg = avgcol / 4.0;
            if (dbg) outAvg.rgb = float3(1, 0, 0);
            return outAvg;
        }

        float2 uvTemp = uvWorking;
        if (legacyMirror) {
            uvTemp = ApplyLegacyMirror(uvTemp, left, right, toLeft, mirrorStrength, mirrorAxisOffset);
        }
        float2 zUV = ApplyZoom(uvTemp, zoom, zoomAxisOffset);
        if (enableZoomFlip) {
            if (uv.x < left) zUV.x = 2.0 * left - zUV.x;
            else if (uv.x > right) zUV.x = 2.0 * right - zUV.x;
        }
        float2 feUV = ApplyFisheye(zUV, fish);
        if (mirrorPlane) {
            feUV = ApplyMirrorPlane(feUV, left, right, toLeft, planeAngle, depthScale, stretch);
        }
        feUV = ApplyCrystalView(feUV, crystalStrength);
        feUV.x = 0.5 + (feUV.x - 0.5) * hFOV;
        float4 sideBase = tex2D(ReShade::BackBuffer, feUV);
        sideBase.rgb = lerp(sideBase.rgb, sideBase.rgb * CrystalTint_16_9, CrystalTintStrength_16_9);

        float4 blackBlur = FrostedBlurBlack(feUV, blur, frostB);
        float4 whiteBlur = FrostedBlurWhite(feUV, blur, frostW);
        sideBase = (sideBase * 0.4 + blackBlur * 0.3 + whiteBlur * 0.3);

        if (useCol)
        {
            sideBase = float4(bgColSolid, 1.0);
        }

        sideBase.rgb = ApplyBrightnessBoost(sideBase.rgb, brightnessBoost);
        if (dbg) sideBase.rgb = float3(1, 0, 0);
        return sideBase;
    }

    if (Enable_21_9) // 21:9
    {
        float aspect = 21.0 / 9.0;
        float blur = Blur_21_9;
        float zoom = Zoom_21_9;
        float zoomAxisOffset = ZoomAxisOffset_21_9;
        bool enableZoomFlip = Enable_ZoomFlip_21_9;
        float fish = Fisheye_21_9;
        float hFOV = HorizontalFOV_21_9;
        float frostB = FrostTintBlack_21_9;
        float frostW = FrostTintWhite_21_9;
        bool avgStretch = Enable_AvgHorizontalStretch_21_9;
        bool legacyMirror = Enable_LegacyMirror_21_9;
        float mirrorStrength = MirrorStrength_21_9;
        float mirrorAxisOffset = MirrorAxisOffset_21_9;
        bool mirrorPlane = Enable_MirrorPlane_21_9;
        float planeAngle = PlaneAngle_21_9;
        float depthScale = DepthScale_21_9;
        float stretch = Stretch_21_9;
        float crystalStrength = CrystalStrength_21_9;
        float brightnessBoost = BrightnessBoost_21_9;
        bool useCol = UseBackgroundColor_21_9;
        float3 bgCol = BackgroundColor_21_9;
        bool dbg = ShowDebugMask_21_9;

        float innerW = BUFFER_HEIGHT * aspect;
        float left = (BUFFER_WIDTH - innerW) * 0.5 / BUFFER_WIDTH;
        float right = 1.0 - left;
        bool isSide = uv.x < left || uv.x > right;
        if (!isSide) return tex2D(ReShade::BackBuffer, uv);

        bool toLeft = uv.x < left;
        float2 uvWorking = uv;

        if (avgStretch) {
            float4 avgcol = 0;
            [unroll]
            for (int k = 0; k < 4; ++k) {
                float t = (k + 0.5) / 4.0;
                float2 sUV = float2(t, uv.y);
                avgcol += tex2D(ReShade::BackBuffer, sUV);
            }
            float4 outAvg = avgcol / 4.0;
            if (dbg) outAvg.rgb = float3(1, 0, 0);
            return outAvg;
        }

        float4 sideBase;
        if (useCol) {
            sideBase = float4(bgCol, 1.0);
        } else {
            float2 uvTemp = uvWorking;
            if (legacyMirror) {
                uvTemp = ApplyLegacyMirror(uvTemp, left, right, toLeft, mirrorStrength, mirrorAxisOffset);
            }
            float2 zUV = ApplyZoom(uvTemp, zoom, zoomAxisOffset);
            if (enableZoomFlip) {
                if (uv.x < left) {
                    zUV.x = 2.0 * left - zUV.x;
                } else if (uv.x > right) {
                    zUV.x = 2.0 * right - zUV.x;
                }
            }
            float2 feUV = ApplyFisheye(zUV, fish);
            if (mirrorPlane) {
                feUV = ApplyMirrorPlane(feUV, left, right, toLeft, planeAngle, depthScale, stretch);
            }
            feUV = ApplyCrystalView(feUV, crystalStrength);
            feUV.x = 0.5 + (feUV.x - 0.5) * hFOV;
            sideBase = tex2D(ReShade::BackBuffer, feUV);
            sideBase.rgb = lerp(sideBase.rgb, sideBase.rgb * CrystalTint_21_9, CrystalTintStrength_21_9);

            float4 blackBlur = FrostedBlurBlack(feUV, blur, frostB);
            float4 whiteBlur = FrostedBlurWhite(feUV, blur, frostW);

            sideBase = (sideBase * 0.4 + blackBlur * 0.3 + whiteBlur * 0.3);
        }

        sideBase.rgb = ApplyBrightnessBoost(sideBase.rgb, brightnessBoost);

        if (dbg) sideBase.rgb = float3(1, 0, 0);
        return sideBase;
    }

    if (Enable_2_1) // 2:1
    {
        float aspect = 2.0 / 1.0;
        float blur = Blur_2_1;
        float zoom = Zoom_2_1;
        float zoomAxisOffset = ZoomAxisOffset_2_1;
        bool enableZoomFlip = Enable_ZoomFlip_2_1;
        float fish = Fisheye_2_1;
        float hFOV = HorizontalFOV_2_1;
        float frostB = FrostTintBlack_2_1;
        float frostW = FrostTintWhite_2_1;
        bool avgStretch = Enable_AvgHorizontalStretch_2_1;
        bool legacyMirror = Enable_LegacyMirror_2_1;
        float mirrorStrength = MirrorStrength_2_1;
        float mirrorAxisOffset = MirrorAxisOffset_2_1;
        bool mirrorPlane = Enable_MirrorPlane_2_1;
        float planeAngle = PlaneAngle_2_1;
        float depthScale = DepthScale_2_1;
        float stretch = Stretch_2_1;
        float crystalStrength = CrystalStrength_2_1;
        float brightnessBoost = BrightnessBoost_2_1;
        bool useCol = UseBackgroundColor_2_1;
        float3 bgCol = BackgroundColor_2_1;
        bool dbg = ShowDebugMask_2_1;

        float innerW = BUFFER_HEIGHT * aspect;
        float left = (BUFFER_WIDTH - innerW) * 0.5 / BUFFER_WIDTH;
        float right = 1.0 - left;
        bool isSide = uv.x < left || uv.x > right;
        if (!isSide) return tex2D(ReShade::BackBuffer, uv);

        bool toLeft = uv.x < left;
        float2 uvWorking = uv;

        if (avgStretch) {
            float4 avgcol = 0;
            [unroll]
            for (int k = 0; k < 4; ++k) {
                float t = (k + 0.5) / 4.0;
                float2 sUV = float2(t, uv.y);
                avgcol += tex2D(ReShade::BackBuffer, sUV);
            }
            float4 outAvg = avgcol / 4.0;
            if (dbg) outAvg.rgb = float3(1, 0, 0);
            return outAvg;
        }

        float4 sideBase;
        if (useCol) {
            sideBase = float4(bgCol, 1.0);
        } else {
            float2 uvTemp = uvWorking;
            if (legacyMirror) {
                uvTemp = ApplyLegacyMirror(uvTemp, left, right, toLeft, mirrorStrength, mirrorAxisOffset);
            }
            float2 zUV = ApplyZoom(uvTemp, zoom, zoomAxisOffset);
            if (enableZoomFlip) {
                if (uv.x < left) {
                    zUV.x = 2.0 * left - zUV.x;
                } else if (uv.x > right) {
                    zUV.x = 2.0 * right - zUV.x;
                }
            }
            float2 feUV = ApplyFisheye(zUV, fish);
            if (mirrorPlane) {
                feUV = ApplyMirrorPlane(feUV, left, right, toLeft, planeAngle, depthScale, stretch);
            }
            feUV = ApplyCrystalView(feUV, crystalStrength);
            feUV.x = 0.5 + (feUV.x - 0.5) * hFOV;
            sideBase = tex2D(ReShade::BackBuffer, feUV);
            sideBase.rgb = lerp(sideBase.rgb, sideBase.rgb * CrystalTint_2_1, CrystalTintStrength_2_1);

            float4 blackBlur = FrostedBlurBlack(feUV, blur, frostB);
            float4 whiteBlur = FrostedBlurWhite(feUV, blur, frostW);

            sideBase = (sideBase * 0.4 + blackBlur * 0.3 + whiteBlur * 0.3);
        }

        sideBase.rgb = ApplyBrightnessBoost(sideBase.rgb, brightnessBoost);

        if (dbg) sideBase.rgb = float3(1, 0, 0);
        return sideBase;
    }

    if (Enable_2_35_1) // 2.35:1
    {
        float aspect = 2.35 / 1.0;
        float blur = Blur_2_35_1;
        float zoom = Zoom_2_35_1;
        float zoomAxisOffset = ZoomAxisOffset_2_35_1;
        bool enableZoomFlip = Enable_ZoomFlip_2_35_1;
        float fish = Fisheye_2_35_1;
        float hFOV = HorizontalFOV_2_35_1;
        float frostB = FrostTintBlack_2_35_1;
        float frostW = FrostTintWhite_2_35_1;
        bool avgStretch = Enable_AvgHorizontalStretch_2_35_1;
        bool legacyMirror = Enable_LegacyMirror_2_35_1;
        float mirrorStrength = MirrorStrength_2_35_1;
        float mirrorAxisOffset = MirrorAxisOffset_2_35_1;
        bool mirrorPlane = Enable_MirrorPlane_2_35_1;
        float planeAngle = PlaneAngle_2_35_1;
        float depthScale = DepthScale_2_35_1;
        float stretch = Stretch_2_35_1;
        float crystalStrength = CrystalStrength_2_35_1;
        float brightnessBoost = BrightnessBoost_2_35_1;
        bool useCol = UseBackgroundColor_2_35_1;
        float3 bgCol = BackgroundColor_2_35_1;
        bool dbg = ShowDebugMask_2_35_1;

        float innerW = BUFFER_HEIGHT * aspect;
        float left = (BUFFER_WIDTH - innerW) * 0.5 / BUFFER_WIDTH;
        float right = 1.0 - left;
        bool isSide = uv.x < left || uv.x > right;
        if (!isSide) return tex2D(ReShade::BackBuffer, uv);

        bool toLeft = uv.x < left;
        float2 uvWorking = uv;

        if (avgStretch) {
            float4 avgcol = 0;
            [unroll]
            for (int k = 0; k < 4; ++k) {
                float t = (k + 0.5) / 4.0;
                float2 sUV = float2(t, uv.y);
                avgcol += tex2D(ReShade::BackBuffer, sUV);
            }
            float4 outAvg = avgcol / 4.0;
            if (dbg) outAvg.rgb = float3(1, 0, 0);
            return outAvg;
        }

        float4 sideBase;
        if (useCol) {
            sideBase = float4(bgCol, 1.0);
        } else {
            float2 uvTemp = uvWorking;
            if (legacyMirror) {
                uvTemp = ApplyLegacyMirror(uvTemp, left, right, toLeft, mirrorStrength, mirrorAxisOffset);
            }
            float2 zUV = ApplyZoom(uvTemp, zoom, zoomAxisOffset);
            if (enableZoomFlip) {
                if (uv.x < left) {
                    zUV.x = 2.0 * left - zUV.x;
                } else if (uv.x > right) {
                    zUV.x = 2.0 * right - zUV.x;
                }
            }
            float2 feUV = ApplyFisheye(zUV, fish);
            if (mirrorPlane) {
                feUV = ApplyMirrorPlane(feUV, left, right, toLeft, planeAngle, depthScale, stretch);
            }
            feUV = ApplyCrystalView(feUV, crystalStrength);
            feUV.x = 0.5 + (feUV.x - 0.5) * hFOV;
            sideBase = tex2D(ReShade::BackBuffer, feUV);
            sideBase.rgb = lerp(sideBase.rgb, sideBase.rgb * CrystalTint_2_35_1, CrystalTintStrength_2_35_1);

            float4 blackBlur = FrostedBlurBlack(feUV, blur, frostB);
            float4 whiteBlur = FrostedBlurWhite(feUV, blur, frostW);

            sideBase = (sideBase * 0.4 + blackBlur * 0.3 + whiteBlur * 0.3);
        }

        sideBase.rgb = ApplyBrightnessBoost(sideBase.rgb, brightnessBoost);

        if (dbg) sideBase.rgb = float3(1, 0, 0);
        return sideBase;
    }

    if (Enable_2_37_1) // 2.37:1
    {
        float aspect = 2.37 / 1.0;
        float blur = Blur_2_37_1;
        float zoom = Zoom_2_37_1;
        float zoomAxisOffset = ZoomAxisOffset_2_37_1;
        bool enableZoomFlip = Enable_ZoomFlip_2_37_1;
        float fish = Fisheye_2_37_1;
        float hFOV = HorizontalFOV_2_37_1;
        float frostB = FrostTintBlack_2_37_1;
        float frostW = FrostTintWhite_2_37_1;
        bool avgStretch = Enable_AvgHorizontalStretch_2_37_1;
        bool legacyMirror = Enable_LegacyMirror_2_37_1;
        float mirrorStrength = MirrorStrength_2_37_1;
        float mirrorAxisOffset = MirrorAxisOffset_2_37_1;
        bool mirrorPlane = Enable_MirrorPlane_2_37_1;
        float planeAngle = PlaneAngle_2_37_1;
        float depthScale = DepthScale_2_37_1;
        float stretch = Stretch_2_37_1;
        float crystalStrength = CrystalStrength_2_37_1;
        float brightnessBoost = BrightnessBoost_2_37_1;
        bool useCol = UseBackgroundColor_2_37_1;
        float3 bgCol = BackgroundColor_2_37_1;
        bool dbg = ShowDebugMask_2_37_1;

        float innerW = BUFFER_HEIGHT * aspect;
        float left = (BUFFER_WIDTH - innerW) * 0.5 / BUFFER_WIDTH;
        float right = 1.0 - left;
        bool isSide = uv.x < left || uv.x > right;
        if (!isSide) return tex2D(ReShade::BackBuffer, uv);

        bool toLeft = uv.x < left;
        float2 uvWorking = uv;

        if (avgStretch) {
            float4 avgcol = 0;
            [unroll]
            for (int k = 0; k < 4; ++k) {
                float t = (k + 0.5) / 4.0;
                float2 sUV = float2(t, uv.y);
                avgcol += tex2D(ReShade::BackBuffer, sUV);
            }
            float4 outAvg = avgcol / 4.0;
            if (dbg) outAvg.rgb = float3(1, 0, 0);
            return outAvg;
        }

        float4 sideBase;
        if (useCol) {
            sideBase = float4(bgCol, 1.0);
        } else {
            float2 uvTemp = uvWorking;
            if (legacyMirror) {
                uvTemp = ApplyLegacyMirror(uvTemp, left, right, toLeft, mirrorStrength, mirrorAxisOffset);
            }
            float2 zUV = ApplyZoom(uvTemp, zoom, zoomAxisOffset);
            if (enableZoomFlip) {
                if (uv.x < left) {
                    zUV.x = 2.0 * left - zUV.x;
                } else if (uv.x > right) {
                    zUV.x = 2.0 * right - zUV.x;
                }
            }
            float2 feUV = ApplyFisheye(zUV, fish);
            if (mirrorPlane) {
                feUV = ApplyMirrorPlane(feUV, left, right, toLeft, planeAngle, depthScale, stretch);
            }
            feUV = ApplyCrystalView(feUV, crystalStrength);
            feUV.x = 0.5 + (feUV.x - 0.5) * hFOV;
            sideBase = tex2D(ReShade::BackBuffer, feUV);
            sideBase.rgb = lerp(sideBase.rgb, sideBase.rgb * CrystalTint_2_37_1, CrystalTintStrength_2_37_1);

            float4 blackBlur = FrostedBlurBlack(feUV, blur, frostB);
            float4 whiteBlur = FrostedBlurWhite(feUV, blur, frostW);

            sideBase = (sideBase * 0.4 + blackBlur * 0.3 + whiteBlur * 0.3);
        }

        sideBase.rgb = ApplyBrightnessBoost(sideBase.rgb, brightnessBoost);

        if (dbg) sideBase.rgb = float3(1, 0, 0);
        return sideBase;
    }

    if (Enable_2_39_1) // 2.39:1
    {
        float aspect = 2.39 / 1.0;
        float blur = Blur_2_39_1;
        float zoom = Zoom_2_39_1;
        float zoomAxisOffset = ZoomAxisOffset_2_39_1;
        bool enableZoomFlip = Enable_ZoomFlip_2_39_1;
        float fish = Fisheye_2_39_1;
        float hFOV = HorizontalFOV_2_39_1;
        float frostB = FrostTintBlack_2_39_1;
        float frostW = FrostTintWhite_2_39_1;
        bool avgStretch = Enable_AvgHorizontalStretch_2_39_1;
        bool legacyMirror = Enable_LegacyMirror_2_39_1;
        float mirrorStrength = MirrorStrength_2_39_1;
        float mirrorAxisOffset = MirrorAxisOffset_2_39_1;
        bool mirrorPlane = Enable_MirrorPlane_2_39_1;
        float planeAngle = PlaneAngle_2_39_1;
        float depthScale = DepthScale_2_39_1;
        float stretch = Stretch_2_39_1;
        float crystalStrength = CrystalStrength_2_39_1;
        float brightnessBoost = BrightnessBoost_2_39_1;
        bool useCol = UseBackgroundColor_2_39_1;
        float3 bgCol = BackgroundColor_2_39_1;
        bool dbg = ShowDebugMask_2_39_1;

        float innerW = BUFFER_HEIGHT * aspect;
        float left = (BUFFER_WIDTH - innerW) * 0.5 / BUFFER_WIDTH;
        float right = 1.0 - left;
        bool isSide = uv.x < left || uv.x > right;
        if (!isSide) return tex2D(ReShade::BackBuffer, uv);

        bool toLeft = uv.x < left;
        float2 uvWorking = uv;

        if (avgStretch) {
            float4 avgcol = 0;
            [unroll]
            for (int k = 0; k < 4; ++k) {
                float t = (k + 0.5) / 4.0;
                float2 sUV = float2(t, uv.y);
                avgcol += tex2D(ReShade::BackBuffer, sUV);
            }
            float4 outAvg = avgcol / 4.0;
            if (dbg) outAvg.rgb = float3(1, 0, 0);
            return outAvg;
        }

        float4 sideBase;
        if (useCol) {
            sideBase = float4(bgCol, 1.0);
        } else {
            float2 uvTemp = uvWorking;
            if (legacyMirror) {
                uvTemp = ApplyLegacyMirror(uvTemp, left, right, toLeft, mirrorStrength, mirrorAxisOffset);
            }
            float2 zUV = ApplyZoom(uvTemp, zoom, zoomAxisOffset);
            if (enableZoomFlip) {
                if (uv.x < left) {
                    zUV.x = 2.0 * left - zUV.x;
                } else if (uv.x > right) {
                    zUV.x = 2.0 * right - zUV.x;
                }
            }
            float2 feUV = ApplyFisheye(zUV, fish);
            if (mirrorPlane) {
                feUV = ApplyMirrorPlane(feUV, left, right, toLeft, planeAngle, depthScale, stretch);
            }
            feUV = ApplyCrystalView(feUV, crystalStrength);
            feUV.x = 0.5 + (feUV.x - 0.5) * hFOV;
            sideBase = tex2D(ReShade::BackBuffer, feUV);
            sideBase.rgb = lerp(sideBase.rgb, sideBase.rgb * CrystalTint_2_39_1, CrystalTintStrength_2_39_1);

            float4 blackBlur = FrostedBlurBlack(feUV, blur, frostB);
            float4 whiteBlur = FrostedBlurWhite(feUV, blur, frostW);

            sideBase = (sideBase * 0.4 + blackBlur * 0.3 + whiteBlur * 0.3);
        }

        sideBase.rgb = ApplyBrightnessBoost(sideBase.rgb, brightnessBoost);

        if (dbg) sideBase.rgb = float3(1, 0, 0);
        return sideBase;
    }

    if (Enable_2_40_1) // 2.40:1
    {
        float aspect = 2.40 / 1.0;
        float blur = Blur_2_40_1;
        float zoom = Zoom_2_40_1;
        float zoomAxisOffset = ZoomAxisOffset_2_40_1;
        bool enableZoomFlip = Enable_ZoomFlip_2_40_1;
        float fish = Fisheye_2_40_1;
        float hFOV = HorizontalFOV_2_40_1;
        float frostB = FrostTintBlack_2_40_1;
        float frostW = FrostTintWhite_2_40_1;
        bool avgStretch = Enable_AvgHorizontalStretch_2_40_1;
        bool legacyMirror = Enable_LegacyMirror_2_40_1;
        float mirrorStrength = MirrorStrength_2_40_1;
        float mirrorAxisOffset = MirrorAxisOffset_2_40_1;
        bool mirrorPlane = Enable_MirrorPlane_2_40_1;
        float planeAngle = PlaneAngle_2_40_1;
        float depthScale = DepthScale_2_40_1;
        float stretch = Stretch_2_40_1;
        float crystalStrength = CrystalStrength_2_40_1;
        float brightnessBoost = BrightnessBoost_2_40_1;
        bool useCol = UseBackgroundColor_2_40_1;
        float3 bgCol = BackgroundColor_2_40_1;
        bool dbg = ShowDebugMask_2_40_1;

        float innerW = BUFFER_HEIGHT * aspect;
        float left = (BUFFER_WIDTH - innerW) * 0.5 / BUFFER_WIDTH;
        float right = 1.0 - left;
        bool isSide = uv.x < left || uv.x > right;
        if (!isSide) return tex2D(ReShade::BackBuffer, uv);

        bool toLeft = uv.x < left;
        float2 uvWorking = uv;

        if (avgStretch) {
            float4 avgcol = 0;
            [unroll]
            for (int k = 0; k < 4; ++k) {
                float t = (k + 0.5) / 4.0;
                float2 sUV = float2(t, uv.y);
                avgcol += tex2D(ReShade::BackBuffer, sUV);
            }
            float4 outAvg = avgcol / 4.0;
            if (dbg) outAvg.rgb = float3(1, 0, 0);
            return outAvg;
        }

        float4 sideBase;
        if (useCol) {
            sideBase = float4(bgCol, 1.0);
        } else {
            float2 uvTemp = uvWorking;
            if (legacyMirror) {
                uvTemp = ApplyLegacyMirror(uvTemp, left, right, toLeft, mirrorStrength, mirrorAxisOffset);
            }
            float2 zUV = ApplyZoom(uvTemp, zoom, zoomAxisOffset);
            if (enableZoomFlip) {
                if (uv.x < left) {
                    zUV.x = 2.0 * left - zUV.x;
                } else if (uv.x > right) {
                    zUV.x = 2.0 * right - zUV.x;
                }
            }
            float2 feUV = ApplyFisheye(zUV, fish);
            if (mirrorPlane) {
                feUV = ApplyMirrorPlane(feUV, left, right, toLeft, planeAngle, depthScale, stretch);
            }
            feUV = ApplyCrystalView(feUV, crystalStrength);
            feUV.x = 0.5 + (feUV.x - 0.5) * hFOV;
            sideBase = tex2D(ReShade::BackBuffer, feUV);
            sideBase.rgb = lerp(sideBase.rgb, sideBase.rgb * CrystalTint_2_40_1, CrystalTintStrength_2_40_1);

            float4 blackBlur = FrostedBlurBlack(feUV, blur, frostB);
            float4 whiteBlur = FrostedBlurWhite(feUV, blur, frostW);

            sideBase = (sideBase * 0.4 + blackBlur * 0.3 + whiteBlur * 0.3);
        }

        sideBase.rgb = ApplyBrightnessBoost(sideBase.rgb, brightnessBoost);

        if (dbg) sideBase.rgb = float3(1, 0, 0);
        return sideBase;
    }

// Default case: pass through the back buffer if no aspect ratio is enabled
return tex2D(ReShade::BackBuffer, uv);
}

technique SideGlass
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_SideGlass;
    }
}