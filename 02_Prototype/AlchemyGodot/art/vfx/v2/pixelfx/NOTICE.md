# V2 skill effect sources

The 24-frame transparent atlases in this directory use [winkidney/pixelfx-godot](https://github.com/winkidney/pixelfx-godot/tree/620f7556f13be39724998ef5cb2157074d5940c1), commit `620f7556f13be39724998ef5cb2157074d5940c1`. The Godot port is by winkidney and the original PixelFX is by Patch. Some effects adapt work by Hugo Duprez and rehan-remade, as documented in the [upstream notices](https://github.com/winkidney/pixelfx-godot/blob/620f7556f13be39724998ef5cb2157074d5940c1/NOTICE.md). The `LICENSE` in this directory is the upstream MIT license. The gallery font is outside that license.

Each sheet uses eight columns and three rows. The preview backgrounds and actors were omitted. The selection, crop, palette and playback time are adapted for the project's real cast, hit and area events.

| Atlas | Upstream effect | Adaptation |
| --- | --- | --- |
| `clay_strike` | `impacts/blunt-hit` | Earthy impact and dust on an actual punch |
| `mithril_flight` | `pickups/xp-orb` | Recentered on the pearl frame by frame, with a silver-blue palette |
| `mithril_impact` | `impacts/ricochet` | Silver-blue contact flash and short sparks |
| `gravity_flight` | `shadow/void-orb` | Centered dark core with orbiting particles |
| `gravity_zone` | `water/whirlpool` | Violet spiral mapped onto the active pull area |
| `acid_impact` | `nature/acid-splash` | Opening splash, timed from bottle contact |
| `acid_zone` | `nature/toxic-puddle` | Green bubbling surface sized to the active pool |
| `mist_zone` | `explosions/smoke-bomb` | Cool fog after the pop, with the demo canister removed |
| `crystal_impact` | `ice/ice-spikes` | One short crystal cluster for each actual hit point |
| `obsidian_impact` | `melee/scythe-reap` | Violet cutting arc without the example actor |
| `needle_flight` | `projectiles/laser-bolt` | Narrow mint streak aligned with actual flight |
| `blast_golem_end` | `fire/fire-ring` | Growing fire ring on the final burst |
| `mithril_orbit` | `holy/sunburst` | Silver rays beneath the actual orbiting fragments |
| `corrosive_mist` | `nature/poison-cloud` | Low green-violet mist bound to its active area |
| `crystal_shatter` | `ice/ice-shatter` | Crystal shards from the break onward |
| `soulbound_flight` | `ice/ice-lance` | Amber needle with a bright core, aligned with actual flight |
| `soulbound_impact` | `lightning/zap-hit` | Mint branching contact effect on the combo mark |
| `brittle_mark_break` | `ice/ice-shatter` | Amber recolor of the transparent shatter for the vulnerability flask landing, with diameter drawn at runtime from the hit radius |
| `blast_mark_contact` | `impacts/ricochet` | Separate orange-gold recolor at each actual shard hit |

The held amber crack and flying shard are original pixel silhouettes assembled in
`scripts/v2_skill_fx.gd` and layered with the corresponding PixelFX contact
animation. The held crack tracks its enemy until expiration or consumption. The
shard follows its gameplay projectile, with an additional short tracer in HD-2D.
