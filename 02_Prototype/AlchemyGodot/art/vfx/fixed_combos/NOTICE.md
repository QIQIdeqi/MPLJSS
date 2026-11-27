# 九项同属性独立技能特效

透明图集改自 [winkidney/pixelfx-godot](https://github.com/winkidney/pixelfx-godot/tree/620f7556f13be39724998ef5cb2157074d5940c1) 提交 `620f7556f13be39724998ef5cb2157074d5940c1`。原版 PixelFX 作者为 Patch，Godot 移植由 winkidney 制作。上游素材和第三方效果的完整归属见 [PixelFX Godot NOTICE](https://github.com/winkidney/pixelfx-godot/blob/620f7556f13be39724998ef5cb2157074d5940c1/NOTICE.md)。本目录随附上游 MIT LICENSE。使用或改编的 Sprite Fusion 效果为 Copyright (c) 2026 Hugo Duprez，MIT License。

这批素材由项目留存的上游纯效果层再次裁切、按固定格心以最近邻调整比例，并重新分配高光、中间色和暗色。每张透明图集为 768 × 288 像素，以八列三行存放 24 帧。运行时用程序绘制实际命中路径、墙脚、危险区切口和出入口，粒子图集播放在对应的真实触发位置。

| 组合 | 图集 | PixelFX 原始效果 | 改动与用途 |
| --- | --- | --- | --- |
| 熔火炉 | furnace | fire/fire-ring | 压低橙红火浪，亮芯贴着三档火面前沿推进。 |
| 雷衣 | thunder_coat | lightning/zap-hit | 琥珀保护电火花和白金回击点，待机只显示肩侧电粒。 |
| 回浪镜 | tide_mirror | impacts/ricochet | 压扁的青白拦截闪光，镜面与返弹轨迹由程序驱动。 |
| 回流锚 | rewind_anchor | water/whirlpool | 内圈银蓝水纹缩作旧脚点，受影响目标拉出贴地回移残影。 |
| 净路剂 | cleanser | nature/acid-splash | 浅青薄尘沿实际切口消散，安全带由边沿标出。 |
| 晶门 | crystal_gate | ice/ice-shatter | 紫白窄晶屑，分别在出发点和落脚点闪动。 |
| 寒晶墙 | crystal_wall | ice/ice-spikes | 蓝白晶块和碎光，竖起来的实际墙面为半透明程序几何。 |
| 照影 | opening_counter | arcane/rune-circle | 细金符文改制为反击时的短闪，并与实际侧点相连。 |
| 收露瓶 | dew_pickup | pickups/xp-orb | 浅金露滴随时间浮动，固定地印由程序显示。 |
