# 当前运行技能特效包（首批）

创建日期：2026-11-17。范围为当前 `SkillManager` 实际加载的十个技能行为；不替代尚未接入运行时的 25 项正式技能表。

## 接入目标

| 运行技能 | 行为 | 视觉族 | 可复用运行资源 | 首批方向稿 |
| --- | --- | --- | --- | --- |
| 魔法弹 | projectile | 原有紫色弹丸与拖尾 | `PixelFX Hit` 作为命中尾帧 | 不使用新增图集 |
| 火球 | blast | 火系投射与爆裂 | `PixelFX Hit` 作为命中尾帧 | `fire_projectile_24f_concept.png` |
| 冰锥 | line | 冰晶直线 | `frost_ring.png` 的冰色与命中层 | `ice_ring_24f_concept.png` |
| 雷击 | instant | 雷击与链式分叉 | `PixelFX Hit` 作为中心命中 | `thunder_strike_24f.png` |
| 风刃 | boomerang | 风刃往返 | 现有 `FX.trail` 作为行为回退 | `wind_blade_24f.png` |
| 旋风 | orbit | 角色周身旋流 | 现有 `orbit_blade.gd` 作为行为回退 | `cyclone_24f.png` |
| 毒雾 | zone | 持续毒雾 | `PixelFX Poison` 四层循环 | 无需新增图集 |
| 落石 | aoe | 落点冲击与尘雾 | `PixelFX Hit` 作为落点命中 | `earth_strike_24f_concept.png` |
| 光束 | beam | 瞬时直线光束 | 现有 `beam` 行为回退 | `arcane_beam_24f.png` |
| 地刺 | spike | 地面突刺 | 现有 `spike` 行为回退 | `earth_spike_24f.png` |

## 图集规范

- 游戏运行图集使用透明 PNG、最近邻采样、无底图。
- 每套采用 6×4、24 帧、每帧 128×128 px、24 或 30 FPS；实际尺寸须在 Godot 同屏检查后冻结。
- 有实体前后关系的效果拆为 `BackColor`、`BackLight`、`FrontColor`、`FrontLight`；只作投射物或地面环的效果可按需减少层数。
- 命中继续优先复用 `art/pixelfx/Hit_*`；毒雾继续复用 `art/pixelfx/Poison_*`；传送门仅保留给 Boss 和传送交互。
- 运行图集均为 1536×1024 的 6×4 图集（每帧 256px）。已清除与图集边缘连通的低 Alpha 渐变底；特效本体的内部半透明高光被保留。文件名中的 `_concept` 表示后续仍可由正式美术替换，而非未接入。

## 接入边界

当前运行接入以 `skill_id` 选择十个视觉族、以 `behavior` 作为回退。除魔法弹保留原有效果外，每项技能拥有独立图集或既有独立 Poison 图集；不再跨技能复用新增图集。`scripts/battle_fx.gd` 以 `AnimatedSprite2D` 播放新增图集；`scripts/hd_battle_world.gd` 对相同图集建立 `AnimatedSprite3D`，使当前 HD 战斗画面也能直接看到动画。HD 模式只播放 3D 专属特效，避免与 2D 图集、通用命中爆点双播。新技能系统已替代旧自动普攻，以确保施法事件实际发生。现阶段不要把 25 项正式技能名称直接写进当前 10 技能的运行逻辑。

## 许可

`art/pixelfx/` 的来源、MIT LICENSE 与 NOTICE 必须随项目保留。上游 gallery 字体不随该 MIT 许可覆盖。
