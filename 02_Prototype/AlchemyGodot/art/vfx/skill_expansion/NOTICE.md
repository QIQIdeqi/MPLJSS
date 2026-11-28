# 新增基础技能特效

下表除雷盐外的图集使用 [winkidney/pixelfx-godot](https://github.com/winkidney/pixelfx-godot/tree/620f7556f13be39724998ef5cb2157074d5940c1) 提交 `620f7556f13be39724998ef5cb2157074d5940c1`。Godot 移植作者为 winkidney，原版 PixelFX 由 Patch 制作。上游素材归属见 [Godot 移植版 NOTICE](https://github.com/winkidney/pixelfx-godot/blob/620f7556f13be39724998ef5cb2157074d5940c1/NOTICE.md)，本目录保留上游 MIT `LICENSE`。

雷盐落雷取自原版 Patch PixelFX 提交 `5294518ce7c72e48b6100a744596e0acf57f2826` 的 [Lightning Strike](https://github.com/patch-gg/pixelfx/blob/5294518ce7c72e48b6100a744596e0acf57f2826/src/fx/lightning/lightning-strike.js)。以原库渲染器导出第一次落雷及余烬，去掉演示蓄力圈、场景压暗和广域光晕。每帧 240 × 264，落点为 (120, 228)。原版 [NOTICE](https://github.com/patch-gg/pixelfx/blob/5294518ce7c72e48b6100a744596e0acf57f2826/NOTICE.md) 标明闪电部分源自 Hugo Duprez 的 MIT Lightning 效果。

每个图集使用 8 列 × 3 行，共 24 个透明帧。导出使用上游像素画布的效果层，按本项目的技能时序、脚点与配色裁切。运行时根据技能的真实位置、范围和持续时间播放特效图集并驱动微光。分裂分支的颜色体现在图集和粒子中。

| 图集 | 上游效果 | 游戏内改动 |
|---|---|---|
| `thunder_salt` | `lightning/lightning-strike` | 青白主雷、分叉和电火星在实际命中点播放。 |
| `fire_oil` | `fire/fire-ring` | 缩小火焰前缘，做成沿实际油迹分布的橙红火头。 |
| `mercury_ring` | `water/whirlpool` | 银白水纹作为扩张环的反光，环的前沿读取实际命中半径。 |
| `frost_powder` | `ice/ice-shatter` | 取散碎冰屑的阶段和浅青配色，落点补贴地的霜白边界。 |
| `wind_flask` | `melee/sword-slash` | 浅灰风弧与被推动的方向一致，扇形范围由技能角度驱动。 |
| `feather_draught` | `pickups/xp-orb` | 浅绿短尾光伴随角色。 |
| `wind_boots` | `projectiles/laser-bolt` | 低矮的青白跟步光贴合闪避路径。 |
| `return_wind` | `impacts/ricochet` | 淡紫折线与小火星提示可用的第二闪。 |
| `renewal_flask` | `arcane/rune-circle` | 绿色回春光纹定在池心，外围另画真实半径。 |
| `dew_tonic` | `holy/sunburst` | 小范围蜂蜜金回复闪光随实际回复脉冲升起。 |

雷盐与霜粉投掷物的独立像素外形在 `scripts/skill_expansion_fx.gd` 中绘制。上游使用或改编的 Sprite Fusion 效果为 Copyright (c) 2026 Hugo Duprez，MIT License。原始子效果的归属、许可证与链接见上游 NOTICE。
