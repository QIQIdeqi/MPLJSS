# MPLJSS · 冒牌炼金术士

UE5.8 全2D片 HD2.5D 可玩原型与项目策划工作区。

| 目录 | 内容 |
|---|---|
| `00_Doc` | 关卡、战斗、系统、数值策划案，修改意见与商业分析 |
| `01_Skill` | 本项目使用的策划 Skill 与原始包 |
| `02_Prototype/AlchemyHD2D` | UE5.8.4 工程、源码、原生资源、原创占位图、工具与验证证据 |
| `03_Build/HD2D_PC_UI` | 当前PC字体/HUD及ALCH-002 Windows可运行包；下载完整目录后双击 `启动Demo.cmd` |
| `memory` | 项目决策、操作、验证与未完成事项记录 |
| `logs` / `scripts` | 工作区日志与辅助脚本 |

详细玩法、操作、编译方式及未完成范围见 [工程说明](02_Prototype/AlchemyHD2D/README.md)。当前为预研原型，Boss/精英行为和美术等尚未完整达到主策划案验收标准。

## 获取完整资源

本仓库使用 Git LFS 保存UE资源、打包程序与其他大二进制文件。请安装 Git LFS，再克隆：

```sh
git lfs install
git clone https://github.com/QIQIdeqi/MPLJSS.git
cd MPLJSS
git lfs pull
```

仅下载网页上的单个LFS文件可能得到指针文本；运行当前Demo需要完整的 `03_Build/HD2D_PC_UI/Windows` 目录。UE缓存、编译中间产物及本机运行存档不纳入版本控制。

运行包仅保留最新版HD2D_PC_UI。完整便携ZIP位于该目录内；先全部解压，再双击启动Demo.cmd，无需安装UE。字体调试按F7，小号固定，中号/大号独立调整。

旧包已移至本地04_Archive，未永久删除：自动审批拒绝了递归删除操作。该归档不纳入Git。

UE关卡/技能工具：02_Prototype/AlchemyHD2D/打开关卡与技能编辑器.cmd；使用说明00_Doc/工具/UE关卡与技能编辑器使用说明.md。当前普通小怪无血条，Boss条位于顶部，所有掉落图标放大并区分类型。

## 2026-10-30 策划与 Greyford 场景

- 持续确认记录：[关卡](00_Doc/关卡策划_持续确认记录.md)、[系统](00_Doc/系统/1.5系统_持续设计记录.md)、[数值](00_Doc/数值/1.6数值_持续设计记录.md)。已确认规则、候选方案与待验证内容分别保留在记录中。
- Greyford 包含村庄走查地图、村庄外围战斗试玩地图、16项首版素材及原生编辑工具。草原试玩复用角色、敌人、技能和闪避，进度仅保留在内存中。
- 启动入口、地图编辑及重建方法见[Greyford使用说明](02_Prototype/AlchemyHD2D/Docs/Greyford灰盒与素材使用说明.txt)。需要UE5.8编辑器与本地编译；启动脚本的引擎路径和工程别名需与本机安装匹配。
- [场景与验证记录](00_Doc/场景设计/2026-10-30_Greyford/)保留P0/P1/P2阶段结果；最新战斗适配以p2-combat-visual-verification.json为准，之前阶段的“未接入”说明是当时状态。同步后的精简原始证据见该目录verification/。
- 本次更新未重新打包Windows试玩ZIP；03_Build中的现有试玩包仍为此前商人反馈版本。自动路线检查与代理键盘操作不代表真人手感、平衡或性能验收；部分地表重复纹理与接缝仍待美术复核。
