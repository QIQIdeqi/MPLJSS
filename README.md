# MPLJSS · 冒牌炼金术士

当前主线为 [Godot 工程](02_Prototype/AlchemyGodot/README.md)。用 Godot 4.7.2 Standard 导入 [project.godot](02_Prototype/AlchemyGodot/project.godot)，按 F5 从开始界面运行。当前流程为封面 → 新游戏 P00 八画序章 → 格雷弗德村庄与工房 → 出战准备 → 外围战斗 → 可选 Boss → 回村。2026-11-25 的序章接入基于 main `9b0d715f`；旧档继续直进村庄，未完序章可继续观看。详见[接入与存档事件记录](04_工具与协作/AgentTeam/2026-11-25_新游戏序章接入与存档事件.md)。

局外村庄使用 HD-2D 透视、实时光照与景深，支持昼夜、随机天气、积雪与融化。普通战斗和 Boss 场地使用两层随机生成，可在 Godot 的「Alchemy 关卡」面板调整配置。

## 获取工程

```sh
git lfs install
git clone https://github.com/QIQIdeqi/MPLJSS.git
cd MPLJSS
git lfs pull
```

Git LFS 用于仓库中的部分共享素材和试玩包。

## Windows 试玩

[下载 2026-11-11 Windows 64 位试玩 ZIP](03_Build/AlchemyGodot_Win64_20261111.zip) · [SHA-256](03_Build/AlchemyGodot_Win64_20261111.zip.sha256)

本次序章仅更新 Godot 源工程，Windows 试玩 ZIP 尚未重新打包。

解压整个 ZIP，双击 `AlchemyGodot.exe`。`AlchemyGodot.pck` 需放在同目录，源工程提交号见包内的 `VERSION.txt`。

## 策划与协作

- [1.2 场景](00_Doc/协作策划/1.2场景.md) · [1.4 关卡](00_Doc/协作策划/1.4关卡.md) · [1.5 系统](00_Doc/协作策划/1.5系统.md) · [1.6 数值](00_Doc/协作策划/1.6数值.md)
- [制作人工作台](04_工具与协作/AgentTeam/工作台.md) · [团队执行说明](04_工具与协作/AgentTeam/执行说明.md) · [官网源码说明](04_Web/README.md)
- [Unreal 工程与 11 月 9 日试玩包历史快照](https://github.com/QIQIdeqi/MPLJSS/tree/fa5c91c74fc1336bb89296af87611b0b8f41ea17)保留在切换前的提交。

## 五关无限地图与美术需求

普通战斗按种子无限区块展开，五个目的地各有关联的独立Boss场，300秒后可自由挑战。关卡总表、数量/密度和怪物波次仍可在Godot编辑器调整。

- [五关场景美术需求Excel](outputs/five_regions_art_20261124/五关_场景美术需求案.xlsx)：每关一页，5页、40条需求、40张参考图，全部尺寸使用px。
- [素材联系表](outputs/five_regions_art_20261124/素材联系表.png) · [关卡制作与工具说明](02_Prototype/AlchemyGodot/Docs/关卡总表与出战准备.md)。
- [关卡方案](00_Doc/协作策划/1.4关卡.md) · [离线玩法预览HTML](outputs/infinite_level_preview_20261124/五关玩法预览.html)。

以上对应源工程；Windows试玩包请按包内版本说明区分。
