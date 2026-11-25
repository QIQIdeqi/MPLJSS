# Notices

## Spirit Gel impact

Both atlases are adapted from [winkidney/pixelfx-godot](https://github.com/winkidney/pixelfx-godot/tree/620f7556f13be39724998ef5cb2157074d5940c1/godot/addons/pixelfx/fx/water), commit `620f7556f13be39724998ef5cb2157074d5940c1`.

- `spirit_gel_flight_24f.png` uses Water Orb with an amber palette. The crop centers the circulating orb and excludes its floor reflection. The 8 × 3 atlas has 84 × 74 pixel cells and samples one full source loop.
- `spirit_gel_impact_24f.png` uses Splash with an amber palette. It starts at the source's impact with the preview stone disabled. The 8 × 3 atlas has 144 × 120 pixel cells centered on the hit point.

## Upstream notices

**Hugo Duprez.** `src/core/sim.js` and the effects that say so at the top of their file adapt Sprite Fusion's
open-source pixel art VFX (https://www.spritefusion.com/pixel-art-vfx), Copyright (c) 2026 Hugo Duprez, MIT License.

**Hollow Crown.** `src/core/act.js` adapts how Hollow Crown plays its skills (poses on 12 fps steps, hit-stops, the springy
straw target), from
https://github.com/rehan-remade/hollow-crown, Copyright (c) 2026 rehan-remade, MIT License.

**Patch Pixel.** The font in `gallery/fonts` is Patch's own and is not covered by this repository's MIT license. See
`gallery/fonts/NOTICE.md`.
