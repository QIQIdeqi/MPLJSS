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

## 历史清理后的协作规则（2026-10-28）

用户随后明确授权清理远端历史旧大文件，已改写 main，保留最新版完整文件树和必要代码、文档记录。详情见 `memory/git-history-cleanup-2026-10-28.md` 与对应 verification JSON。后续以新历史为准；协作者先备份未提交工作再重新克隆，不合并旧历史回 main。旧提交映射和 Git bundle 只留 SSD 的 ignored 临时目录。GitHub 后台旧 LFS 配额清除与提交历史改写是两个步骤，不把新克隆体积缩减当成配额已释放。

## Boss 视觉与战斗更新（2026-10-29）

本机已拉取 V0.2 提交 09b1219 并在其上增加 Boss 清场直接结算、封闭战圈、三类预警攻击、半血强化和新的 Boss 立绘。立绘用本聊天原生 GPT 生图，经 sprite-gen 原生 slice-sheet 做单图透明裁切与尺寸规范化，再用 Unreal 原生导入；不是多帧动作生产。人物 V3 动作维持原素材。Boss 脚底基线为 432/448，绘制偏移沿 CameraUp，受击缩放保持落脚点。

Boss 规则、原玩法和人物 V3 回归通过，真实渲染核对 1280×720 与 2560×1080；摘要 `memory/gameplay-update-2026-10-29.json`。当前修改在本机工程，未推送、未重打包旧 Windows ZIP；新测试入口 `02_Prototype/AlchemyHD2D/启动Boss战测试.cmd` 不覆盖玩家存档。

事件/商人当前为讨论方案，用户已确认货位允许重复但至少两种；不把方案写成已经实现的功能。

## 商人实现及独立美术（2026-10-29，覆盖上文历史状态）

- 商人系统已发布于967cacb之前的功能提交8c54e89；不是未实现提案。规则见工程Docs/Merchant.md，原版发布记录memory/merchant-release-2026-10-29.json。
- 后续独立立绘用本聊天原生GPT新生图，保留ArtSource/MerchantWanderer_20261029.png与完整提示词、哈希provenance；sprite-gen 3.5.0原生slice-sheet单图1x1、alpha-floor64、contain、384x448、baseline432、target408，输出MerchantWanderer.png。所有消费路径在SSD，未切换Grok或付费API。
- Tools/ImportMerchantArt.py导入生产图及Lit/Unlit材质，创建M_MerchantArrival/M_MerchantSpark两个可参数化原生材质。运行时替换Hero0/Lectern组合，脚底定位沿CameraUp乘208/448×当前高度；保留交互圈，新增柔和阴影。
- 独立出场由两个动态炼金环、12枚聚拢光点及既有Niagara短促Burst组成，1.4秒显现落定；暂停跟随交易，完成或提前离场清理。单张立绘并非生成多帧动作。商人随机流与交易参数未改变。
- 商人规则现34项（包含出场开始、暂停、落脚清理和中途取消），4000货位抽样保留。AlchemyMerchantCapture现每分辨率9帧，额外记录出场起始/聚拢/落定；不再按旧版6帧验证。最新Windows实包/ZIP/Git验证以memory/merchant-art-release-2026-10-29.json和当日日志为准，不将编辑器画面当实包证据。

## 商人逐帧动作（2026-10-29，最新）
- 当前商人已由单图升级为逐帧待机/招手。原静态图仍作生成参考；ArtSource/MerchantAnimation保留原生GPT两动作条、图集、manifest、request及提示词/哈希。Native components提取与原生compose产生6列2行2304x896，每格384x448、脚底432；待机4帧4fps，招手6帧6fps。未自行等宽切片或补绘帧。
- ImportMerchantAnimation.py导入MerchantAnimated与Lit/Unlit材质；UpdateMerchantVisual按缓存MID更新UV，固定世界位置/脚底。入场招手一次、近距按8秒冷却再招手，交易与暂停冻结，结束恢复待机，离场重置。旧ImportMerchantArt.py维护静态参考与出场材质。
- 当前MerchantSmoke42项，MerchantCapture每分辨率19帧（原9帧加6招手和4待机）。编辑器双分辨率、Windows实包回归与D3D12验证通过，最新分发摘要memory/merchant-animation-release-2026-10-29.json。GIF帧预览仅本地，wave GIF重复展示不改变运行时非循环招手/冷却规则。
- inspect-motion对单脚接触仍needs-review，招手近似中立端点保留全部原时长；不把运动存在/脚底像素相同当成严格步态标定。源生成提示词与一次裁切重生成原因见provenance。

## 商人成交反馈与离场（2026-10-29，最新覆盖）
- 最新实现增加购买/刷新支出声、出售收款声与金币HUD弧线，反馈仅成功后触发、从不二次改余额。MerchantSay短句覆盖世界气泡及商店底部，使用VisualTime；角色动作、冷却与1.6秒离场使用战斗时间。BeginMerchantDeparture立即禁交易，告别复用6帧wave，缩放与收束/散点由运行时驱动；Boss/结算/切图强制CloseMerchant。
- 两个原创合成WAV和生成/导入工具保留在ArtSource/MerchantAudio及Tools，Game/Art/Audio会随AlwaysCook打入。普通启动现启用声音；自动规则测试可-nosound，真实音频验证用-AlchemyMerchantCapture -AlchemyRecordMerchantAudio -AudioMixer并分析导出混音，不声称耳听通过。
- MerchantSmoke现52项；MerchantCapture现每组24图，新增支出/收入金币中间态与告别/收束/结束三阶段。最新Windows/音频/ZIP/Git记录见memory/merchant-feedback-release-2026-10-29.json。
- UE5.8.4曾出现Cooked Zen项目端口与暂存启动端口不一致。当前项目DefaultGame.ini显式bUseZenStore=False，使用SSD文件式Cook+IoStore；Saved旧Cooked缓存被隔离而非删除，正式SaveGames不动，不更改全局Zen服务。
