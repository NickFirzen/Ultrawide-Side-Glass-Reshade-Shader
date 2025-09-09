UltrawideSideGlass ReShade Shader 🚀-an Anti Pillarbox Measurement🤓

Eliminate black pillars on ultrawide monitors with style! UltrawideSideGlass is a custom ReShade shader that fills the black bars (pillarboxes) on ultrawide displays (21:9, 32:9, and more) with zoomed, mirrored, or crystal-like effects, preserving the center image and HDR metadata.
As a 32:9 user, this was a dream project for me—finally, no more black bars ruining the vibe! Perfect for gaming 🎮 and media playback (e.g., MPC-BE/MPC-HC).

Full visible code: https://github.com/NickFirzen/Ultrawide-Side-Glass-Reshade-Shader/blob/main/UltrawideSideGlass.fx
Rar: https://github.com/NickFirzen/Ultrawide-Side-Glass-Reshade-Shader/blob/main/UltrawideSideGlass-AntiPillarboxMeasurementReshadeShader.rar

Features ✨

-Supported Aspect Ratios: 4:3, 16:9, 16:10, 21:9, 32:9, 2.35:1, 2.37:1, 2.39:1, 2.40:1, 2:1

-Effects Pipeline: Legacy Mirror → Zoom → ZoomFlip → Fisheye → Mirror Plane → CrystalView → Frosted Blur → Brightness Boost

-Customizable: Adjust blur, zoom, fisheye, crystal effects, and more via ReShade’s UI

-Compatibility: Tested with Media Player Classic (MPC-HC, MPC-BE x64, Black Edition) on ReShade 6.5.1. Should work with games and other apps, but not guaranteed

-Free to Modify: MIT License. Create versions for 16:9/16:10 to fill letterboxes, or combine with other shaders/presets in usage or in code (e.g., add image backgrounds or alpha-transparent PNGs like window/TV frames or landscapes)


Installation 🛠️

1️⃣Install ReShade: Download and install ReShade from reshade.me for your game or media player.

2️⃣Add Shader:

-Download/copy SideGlass_UltraWide.fx or the rar (ultrawidesideglass-antipillarboxmeasurementreshadeshader.rar) from the Releases section: https://github.com/NickFirzen/Ultrawide-Side-Glass-Reshade-Shader/releases

-Copy SideGlass_UltraWide.fx to your ReShade shaders folder per game/app you'd like to use with (e.g., ...\reshade-shaders\Shaders).

3️⃣Enable in ReShade:

-Open ReShade’s UI in-game (default: Home key).

-Select SideGlass_UltraWide from the shader list.

-Choose your aspect ratio (e.g., Enable_21_9 or Enable_32_9) and tweak settings as needed, try combos.


Optional: Extract the .rar for pre-configured settings or backup.


Notes 📝

-Performance Tip: This shader supports multiple aspect ratios for flexibility. For optimal performance, isolate your preferred aspect ratio into a standalone version.

-Debug Mode: Enable ShowDebugMask (per aspect ratio) to highlight affected areas in red for setup.


Credits 🙌


Created by NickFirzen with major help from Grok (xAI). Other AI tools (ChatGPT, Copilot, etc.) may have contributed—it was a chaotic coding adventure, and I’m not even a coder! XD No other shaders were used; any similarities are coincidental due to AI. Sorry if so!


Support ☕

This shader is free and open-source (MIT License). If you enjoy it and want to support, consider a one-time donation on Ko-fi:
https://ko-fi.com/nickfirzen
Or a follow/sub as NickFirzen on YouTube or elsewhere!
https://youtube.com/@nickfirzen

!Let’s make ultrawide displays even better—Ultrawide FTW!


Created by NickFirzen. Licensed under MIT.
