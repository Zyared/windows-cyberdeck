# Arasaka audio-reactive wallpaper

The existing corporate terminal now has a red 64-bar mirrored spectrum below
the emblem. Low frequencies gently scale the emblem (up to 4.5%) and its halo
(up to 8%) and brighten the red glow. The logo and typography remain recognisable.

`live/index.html` registers Wallpaper Engine's system-playback audio listener.
The installer writes `general.supportsaudioprocessing=true` in `project.json`.
It combines the two 64-bin channels, places bass in the centre, clamps invalid or
oversized samples, and smooths attack/release. Rendering is capped at 30 FPS and
stops on `setPaused(true)`. Silence or a missing feed settles to a quiet baseline;
there is no random/demo audio fallback. Reduced-motion preference disables scaling.
No microphone capture, network service or additional resident application is used.

API: [Wallpaper Engine audio visualization](https://docs.wallpaperengine.io/en/web/audio/visualizer.html).

Applied on 2026-11-14 to `%USERPROFILE%\CyberDeck\live\index.html` and the selected
`D:\SteamLibrary\steamapps\common\wallpaper_engine\projects\myprojects\cyberdeck`.
Only the web wallpaper was reloaded; global playback/lockscreen settings stayed
unchanged. Existing pause-on-maximized/fullscreen rules still apply.

Before-change files: `%USERPROFILE%\CyberDeck\backup\audio-wallpaper-20261114`:
`installed-index.html`, `engine-index.html`, `project.json`. Restore these to the
respective installed HTML files and project manifest, then reload the wallpaper
to undo just this visual change. The repository preserves the new version.

Validation: JavaScript syntax, installer PowerShell syntax, synthetic bass/silence,
invalid samples, missing-feed timeout and pause/resume passed. A 1920x1080 headless
render verified layout. These checks do not establish actual system-audio delivery;
The user then confirmed that the bars move with currently playing music, and
requested lower sensitivity. Spectrum gain was reduced from 1.55 to 1.15 and
bass gain from 1.8 to 1.35 (about 25% less before saturation), then reloaded.
