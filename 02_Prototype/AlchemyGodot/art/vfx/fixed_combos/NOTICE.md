# 九项同属性独立技能特效

透明图集改自 [winkidney/pixelfx-godot](https://github.com/winkidney/pixelfx-godot/tree/620f7556f13be39724998ef5cb2157074d5940c1) 提交 `620f7556f13be39724998ef5cb2157074d5940c1`。原版 PixelFX 作者为 Patch，Godot 移植由 winkidney 制作。上游素材和第三方效果的完整归属见 [PixelFX Godot NOTICE](https://github.com/winkidney/pixelfx-godot/blob/620f7556f13be39724998ef5cb2157074d5940c1/NOTICE.md)。本目录随附上游 MIT LICENSE。使用或改编的 Sprite Fusion 效果为 Copyright (c) 2026 Hugo Duprez，MIT License。

这批素材由项目留存的上游纯效果层再次裁切、按固定格心以最近邻调整比例，并重新分配高光、中间色和暗色。每张透明图集为 768 × 288 像素，以八列三行存放 24 帧。运行时用程序绘制实际命中路径、墙脚、危险区切口和出入口，粒子图集播放在对应的真实触发位置。

| 组合 | 图集 | PixelFX 原始效果 | 改动与用途 |
| --- | --- | --- | --- |
| 熔火炉 | furnace | fire/fire-ring | 蓄热时火星散布在炉区，橙红火浪贴着三档火面前沿推进。 |
| 雷衣 | thunder_coat | lightning/zap-hit | 金白环甲围绕角色，吸收时炸开环沿和电火花，回击以白金分岔闪电联到攻击者。 |
| 回浪镜 | tide_mirror | impacts/ricochet | 青白闪光配合直立的水镜和带双鳍的浪脊返弹，实际拦截及命中处呈现扇状飞沫。 |
| 回流锚 | rewind_anchor | water/whirlpool | 靛蓝刻度钟标明原站位，反向箭头沿回移路线连接，银蓝水纹定在真实落点。 |
| 净路剂 | cleanser | nature/acid-splash | 浅青薄尘沿真实切口消散，孢子退开后显露安全带地面。 |
| 晶门 | crystal_gate | ice/ice-shatter | 紫白窄晶屑，分别在出发点和落脚点闪动。 |
| 寒晶墙 | crystal_wall | ice/ice-spikes | 蓝白晶块和碎光，竖起来的实际墙面为半透明程序几何。 |
| 照影 | opening_counter | arcane/rune-circle | 金色火星在角色脚下聚拢，踩地时尘光向实际范围内散开，像素符文集中在踩踏落点。 |
| 收露瓶 | dew_pickup | pickups/xp-orb | 浅金露滴随时间浮动，固定地印由程序显示。 |
