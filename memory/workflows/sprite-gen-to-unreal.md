# 炼金术士素材生成到 Unreal 的已验证流程

用户于 2026-10-28 明确要求将本聊天流程保存到记忆。此文档是项目内流程入口，配合每日 memory 使用，后续任务先读此文档，再核对现场。

## 工作目录与工具

- 工作区：`D:/06_独立游戏/00_冒牌炼金术士`，所有正式素材、视频、脚本、证据和项目 memory 放在这个 SSD 工作区。
- UE 工程：`02_Prototype/AlchemyHD2D/AlchemyHD2D.uproject`。本机 `D:/03_UEProject/AlchemyHD2DResearch` 是指向它的 Junction；跨会话先验证映射与引擎版本，再使用别名路径。当前实测引擎为 UE 5.8.4。
- sprite-gen 3.5.0，安装记录 `01_Skill/sprite-gen-install.json`，固定上游提交 `419f02cd54b4181e33689759d4ee9c1ef0006301`。通过 `01_Skill/sprite-gen.ps1` 调用 SSD 内 `.venv`，不依赖随意选取的系统 Python。
- FFmpeg、img2webp 与 RIFE 的安装脚本/校验记录保留在 `scripts/`、`01_Skill/*install.json`。虚拟环境、下载工具、模型、临时目录、个人偏好是本地运行数据，不上传 Git。
- 按用户默认使用 stop-that-shit；编码配合 ponytail full。每次结束追加工作区及对应 UE 工程的 `memory/YYYY-MM-DD.md`，最终给三个可继续输入的提示示例。

## 已确认的生成路线

1. 用户选择 GPT 动作帧路线，不使用 Grok；当前聊天原生 imagegen 可用。独立 sprite-gen 的 Codex 子进程不能获取原生生图能力，因此由聊天工具生成动作条，再交给原生 CLI 提取/合成。遇到 GPT 不可用时按已有约定说明，不静默切换收费 API。
2. 锁定侧视朝右、正面、背面三张角色基准：棕红发、护目镜、青绿色外套、米色围巾、药瓶腰带、右手炼金杖。投瓶用空闲左手。向左当前使用侧面镜像，会同时镜像配件左右。
3. 每种动作分别生成一个横向动作条，不让模型一次画多行图集。用 sprite-gen `prepare` 生成规范提示和布局；保留原始输出、方向基准及 request。内置生图默认输出位置的项目图片及时复制到 SSD 工作区，再由工作区路径调用。
4. `extract` 使用原生 components；确有需要才试原生 projection。禁止自行等宽切片冒充提取结果。独立碎片分组错误时先尝试原生选项，保留失败对照，再重生易分组的连通飞溅，不手画补帧。
5. 执行 `compose-atlas`、`compose-gif`、`preview`、`inspect`、`inspect-motion`，读报告并实际看图和运动。死亡必须从站立跌到低位倒地，保持末帧，不循环起身；不要按每帧高度单独放大尸体。
6. 用 FFmpeg 按 manifest 帧率合成 H.264 MP4，使用 ffprobe 与全视频解码验证。人物动作对照与真实 UE 自动测试录像分别交付；固定模拟截图合成录像不作为帧率性能或人工游玩证据。

## 当前资产与播放约定

- 最新交付：`03_Build/sprite-gen/alchemist-combat-v3-20261028`，含透明帧、图集、manifest、QA、视频、素材包及 `verification.json`。V1/V2 保留作历史对照。
- 三张角色图集为 1536×1280，每格256×256，六列五行：待机4帧4fps、走路6帧8fps、投掷6帧8fps、受击4帧10fps、死亡6帧8fps。
- 药瓶弹体独立透明图；破碎效果为512×128、四帧12fps，玻璃碎片和琥珀药液。末帧面积小是有意消散，保留报告警告；背面旧待机低运动量警告也保留。
- 当前走路仍未做脚接触/步幅标定，不能称为严格校准的循环步态。

## Unreal 接入与容易复发的问题

- `Tools/ImportAlchemistSpriteLab.py` 导入生产角色到 `/Game/Characters/Alchemist`，弹体/破碎图集到 `/Game/Art`，更新独立测试地图与 BP。生产目录加入 AlwaysCook。
- 材质为 Unlit + Translucent，纹理 Alpha 显式接 Opacity；NEAREST、无 Mip、保留 Alpha。连接 TextureSample 的实际第一个 UV 输入并断言所有关键连线。曾出现 UV 连错和背景黑块，必须看真实渲染确认。
- 动态实例的父对象必须是基础 Material 或 MaterialInstanceConstant；不能用另一个 MID 作父实例。碎瓶曾因此显示错误，修复后需检查日志无 invalid-parent 警告并看实际橙色飞溅。
- 平面本地 Y 朝视觉下方。脚底锚点 y=232，世界中心用视觉上方向偏移；误用向下轴会把整个角色埋进地面。不能只看逻辑 PASS。
- 共享 `FAlchemistSpriteAnimation` 驱动独立 Lab 与现有 `AAlchemyWorld`。保留原输入框架、空格闪避、自动施法、伤害/冷却/射程和关卡波次。
- 防滑行规则：移动时保持实际移动方向的走路状态，弹体独立瞄准敌人；停下才播定脚全身投掷，投掷中开始移动立刻恢复走路。不是分层上半身投掷实现。药瓶前摇0.25秒后从玩家当前位置释放。
- 真实受伤触发0.4秒受击，原0.65秒无敌时间不变，受击动作期间保持可见。HP归零触发死亡，原结算/保存流程不变，HUD等0.75秒倒地结束再显示菜单，尸体保持末帧，停止移动。

## 验证与交付

1. 修改前保存当前编辑器的 dirty packages，再关闭占用工程 DLL 的进程；不要直接丢弃 Research 关卡修改。改前快照在 `04_Archive/` 本地保留。
2. 使用工程现有 Build.bat 流程编译 Editor，导入资源，等待导入完成后再运行消费这些资产的测试。
3. 运行 `Tools/Smoke.ps1`，要求 `ALCHEMY_SMOKE_PASS`、`ALCH002_TEST_PASS`；角色测试参数 `-SpriteLabSmoke`、`-AlchemyCharacterSmoke` 和 `-AlchemyCharacterV3Smoke`。
4. V3 在真实 Research 地图注入 A 键，核对向左位移/走路、向右弹道、脚底稳定、真实碎瓶播放与清理、受击恢复、死亡停帧及死亡后不移动；还要跑真实 D3D12，查截图并排除材质错误。
5. 证据在工程 `Evidence/AlchemistCombatV3` 与 `alchemist-combat-v3-*.log`。源代码/命令行 PASS、真实渲染、物理 UI 操作、打包 EXE、人工试玩是不同验证层级，不能混为完成。
6. 正式入口 `启动正式战斗角色测试.cmd`；动画对照入口 `启动炼金术士动画测试.cmd`，Lab 用 H受击、J死亡、R重置。此轮角色更新只进入最新工程，未重新打包旧试玩 EXE。

## Git 同步规则

使用现有 `origin` 与当前用户授权分支，发布前实时核对，不凭历史提交号判断。保存源代码、资产、说明、安装清单、测试证据及项目 memory；媒体/UE 二进制按仓库 LFS 规则上传。排除缓存、虚拟环境、模型下载、个人配置、临时文件、凭据和本地归档。推送后比较 HEAD、origin/main、远端 ls-remote，确认工作区与 LFS 无待处理；新鲜验证记录也应落入项目 memory。

## 已验证的工程清理方式

2026-10-28推送前清理了UE可再生成目录：Intermediate、失败的Intermediate_UnicodeAttempt、DerivedDataCache、Saved下Cooked/StagedBuilds/Temp/Logs/Crashes/MaterialStats/ShaderDebugInfo/Shaders/UnrealBuildTool，以及EditorOpenOrder.log。505个文件共5.713GiB已移入回收站，明细见同级上层cleanup-2026-10-28.json。保留Source、Config、Content、ArtSource、当前Binaries、验证证据、存档、Autosaves、编辑器配置和独有截图。清理前确认对应UE进程已退出，解析并校验每个绝对目标确在工程内，不对链接目录执行递归清理。回收站未清空时只称工程目录体积减少，不称磁盘空间释放。
## 最新分发与 Skill 原件（2026-10-28，覆盖上文历史状态）

- sprite-gen 固定上游版本的完整源码原件为 `01_Skill/sprite-gen-3.5.0-source.zip`，包含 SKILL.md、脚本、文档和许可证；版本与哈希见同目录 `sprite-gen-source-original.json`。其他游戏开发 Skill 快照、原始 ZIP 和安装记录一并保留。虚拟环境、模型、工具下载和个人偏好不上传。
- 最新试玩包为 `03_Build/HD2D_PC_UI/冒牌炼金术士_Demo_Win64_最新测试版.zip`。克隆后执行 git lfs pull，完整解压到所在目录，再运行启动Demo.cmd。远端不重复保存解压的 Windows 目录。
- 2026-10-28 已重新打包，打包 EXE 的标准烟雾检查和真实 D3D12 V3 检查通过，摘要与 ZIP 哈希见 `memory/packaged-latest.json`。不能据此宣称人工完整通关或性能验收。
- V1/V2 历史素材已清理，需要时从 Git 历史恢复；当前原始动作条、视频、测试地图和 Evidence 仅留本机。Git 保留生产 Source/Config/Content、必要 ArtSource、文档、memory、Skill 原件和完整试玩 ZIP。
- 生产重导入可使用 `ArtSource/AlchemistCombatV3` 的三张人物图集、药瓶和破碎图集，不依赖已忽略的生图工作目录。
- `04_Archive` 已移入回收站；四份独有存档保存在工程 `Saved/SaveBackups/history-cleanup-20261028`，不上传存档。后续打包不再生成历史归档目录。
- Git 删除与 ignore 仅缩减当前版本，旧 Git/LFS 历史对象不会因普通提交消失；未经额外授权不改写历史。
