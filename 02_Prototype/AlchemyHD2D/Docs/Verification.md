# 验证记录

## PC字体与HUD更新（2026-10-27）

- 依据game-ui-ux调整。直接从UE本机Font.cpp核对动态UFont默认LegacyFontSize=9，HUD.cpp确认旧DrawText路径会缩放旧字形。新Canvas文本使用FSlateFontInfo显式字号，增加100%/115%/130%切换、持久化、中文自动换行、对比度、较大按钮、图鉴分页及PC键盘焦点。绘制移至AlchemyHUD.inl，与战斗配置保持同一编译单元。
- 编辑器1280×720、1920×1080、2560×1080各11帧原生渲染，日志均有ALCHEMY_PC_UI_CAPTURE_PASS，无PC_UI_OVERFLOW或PC_UI_BUTTON_OVERFLOW。帧与日志见Evidence/PC_UI及pc-ui-{1280,1920,2560}.log；覆盖默认及130%字号的主要界面，不代表每种字号每个界面组合都已穷举。
- Computer Use真实窗口验证100→115→130字号变化；130%下拖拽火粉、↓聚焦露水并Enter投入、点击魔法碎片与确认炼金，实际完成0→1→2→3投料和随机合成。隔离-AlchemyUI不读写玩家存档，测试进程正常退出。
- 最终Editor/Game编译及UAT Build/Cook/Stage/Archive成功，退出0，完整新包在03_Build/HD2D_PC_UI。保留旧目录，两个旧启动入口与LaunchDemo.ps1均指向新版。旧ALCH002包已有主存档在目标不存在时复制到新包本地Saved/SaveGames，复制前后SHA256一致，源文件保留；运行存档受Git忽略规则保护。
- 最终独立EXE的Tools/Smoke.ps1 -Packaged退出0；12组ALCH002_CHECK、ALCH002_TEST_PASS及ALCHEMY_SMOKE_PASS通过。存档回读检查包含UITextScale=1.3。最终EXE另用真实RHI运行1080p全11帧界面检查，退出0并有ALCHEMY_PC_UI_CAPTURE_PASS，无文本/按钮超宽标记。
- 最终SHA256 A6E4D4D10061B31A92DD4AEF5A4E8A92D8AA4D305DA46DAF8CFB625136E2BB96，与编译产物一致。摘要Evidence/pc-ui-final-verification.json；打包日志pc-ui-package.log；独立界面日志pc-ui-packaged-render.log。独立包截图已查看，选取炼金130%保存为Evidence/PC_UI/Packaged_1920x1080_Alchemy130.png。
- 记录修复：截图辅助代码int参数调用Sin/Cos产生重载歧义，显式转float后编译通过；独立渲染后的PowerShell验收曾写错Select-String位置参数，修正为具名LiteralPath/Pattern后核对真实成功日志，没有为此重复运行渲染。通知改为完整顶栏覆盖，避免只遮一部分标题。

边界：未进行4K、多显示器DPI切换、200%文字缩放、真实手柄或正常五分钟可用性研究。保留Canvas原型架构，没有宣称完成UMG/事件驱动HUD重构。具体设计说明见Docs/PC_UI.md。

## ALCH-002原型实施（2026-10-27）

本轮实际引擎为UE5.8.4，Build.version与进程日志均为CL58902052；下文5.8.2记录为历史环境。

- 已实现七种材料组合、21个普通技能，另保留3个精英技能与初始魔弹；技能配置保留旧ID并追加新ID。普通投料3–10，8行品质权重、候选过滤和实际概率显示；满级或无空间结果不抽取，全不可接收不扣料。
- 已实现十组替换连锁、独立冷却、首次等待完整冷却、卸装保留剩余、无目标重新冷却、实际首次触发后新图鉴解锁。
- 已实现首次教学三料各1、35秒后按击杀补缺、主动入口、单次群体命中完成、未完成重试与永久完成状态。老档有金币/天赋/发现证据时免教学；成长和原技能发现保留，新组合和新连锁重新发现。
- 编辑器与Game目标编译成功，UAT Build/Cook/Stage/Archive退出0。归档后对奥术脉冲作纯C++配置修正为最多跳跃5目标；重新编译编辑器与Game成功。旧归档EXE覆盖遇到“user-mapped section open”，当时未找到仍运行的AlchemyHD2D.exe，未终止其他进程；最终使用同次烘焙资源和最终编译的EXE/PDB生成独立HD2D_ALCH002目录。后续Build脚本默认归档至新目录。
- 最终包：`03_Build/HD2D_ALCH002/启动Demo.cmd`。旧启动入口优先转向新包；不把旧目录中的中间二进制认作最终候选。
- 最终EXE的`Tools/Smoke.ps1 -Packaged`退出0，含12个`ALCH002_CHECK ... PASS`、`ALCH002_TEST_PASS`和`ALCHEMY_SMOKE_PASS`，覆盖七组/21技能/8行权重、容量与升级、精英固定配方、教学补缺/投料/实际双目标命中/重试、十连锁卸装冷却、25个技能施法分支、旧字段语义迁移与SaveGame内存序列化回读。同时通过既有布局、暂停、库存上限、相机与5:00/5:10/6:00事件回归。
- Computer Use在隔离`-AlchemyUI`进程实际点击火粉、拖入露水、点击魔法碎片、取回露水再投回、确认炼金；看到数量0→1→2→3、70/20/10概率、入口按钮随条件显隐、各材料10→9以及混融酸滴生成。隔离进程不读写玩家存档，测试后退出。证据`Evidence/ALCH002_Alchemy.png`为UE的F9原生截图，不含其他应用画面。
- 证据：`Evidence/alch002-package.log`、`alch002-build-game.log`、`smoke.log`、`packaged-layout-smoke.log`、`alch002-ui.log`、`alch002-packaged-exe-hash.json`。最终EXE SHA256为`ECA92C8DF0FCD87C9B6130770904E2497820BA7E3DFDC10A02188A7ACF3397CA`，与编译源产物一致。

限制：迁移测试为构造旧字段状态和内存存档回读，未拿真实玩家存档做破坏性试验；只有空存档或零收获旧玩家无法可靠识别为老玩家。尚未进行正常五分钟人工流程、40–60秒目标达成率、材料效率/品质强度/连锁获取平衡、多人反馈或满场性能验证。当前效果为Plane/Ring原型表现；不能把功能通过等同于玩法已平衡。

日期：2026-10-26。引擎：UE5.8.2，Win64 Development。本版定位为全2D片可玩预研。

最终交付：`03_Build/HD2D_v0_1`，UAT打包退出码0，`BUILD SUCCESSFUL`。将完整包从工程目录移至工作区03_Build后再次启动，独立EXE的13项烟雾检查全部通过（`Evidence/packaged-smoke.log`）；实际RHI渲染输出5张截图（`Evidence/packaged-capture.log`）。

独立包的渲染截图保存在 `03_Build/HD2D_v0_1/Windows/AlchemyHD2D/Evidence`。已直接检查村庄截图，原矩形阴影已移除，中文与像素卡片可显示。已在最终独立版以原生输入点按A/D，观察场景相对位移方向，并用鼠标点击验证正交/透视按钮实际切换。Windows自动化不支持持续按住键，本次UI输入检查采用点按；未据此声称完整移动手感验收。

独立程序已恢复默认正交镜头，并保留在村庄供用户继续体验。EXE校验值保存在 `Evidence/packaged-exe-hash.json`。

## 已通过的逻辑检查

`Tools/Smoke.ps1` 在真实UE进程中执行；`Evidence/smoke.log` 中有13项 `ALCHEMY_CHECK_OK` 及 `ALCHEMY_SMOKE_PASS`。

| 检查 | 结果 |
|---|---|
| 开局8只、玩家120HP测试配置 | 通过 |
| 无效组合不扣料、有效炎弹扣料、满级不扣料 | 通过 |
| 世界边界禁止通行 | 通过 |
| D方向取镜头右向量 | 通过；该机位镜头右方是世界-X，避免原输入反向 |
| 全部可见静态网格为Plane | 通过，逐个检查场景Actor实际网格名 |
| 模态界面冻结生存时钟 | 通过 |
| 材料上限10 | 通过 |
| 正交/透视切换 | 通过 |
| 5:00预警、5:10生成Boss | 通过，测试进程跳时验证，正常流程不跳时 |

## 图像证据

UE的FScreenshotRequest直接输出1280×720游戏帧；不是概念效果图。

- `01_Village.png`：村庄、像素角色、全2D片建筑及设施。
- `02_Research.png`：HD2.5D实验面板。
- `03_Combat.png`：战斗构图。
- `04_Alchemy.png`：炼金界面。
- `05_Perspective_Lit.png`：透视与受光对照。

`-AlchemyCapture` 进程为了截图单独调整怪物位置与临时材料，不写入用户进度。这些截图只能证明渲染结果和界面存在，不能证明正常游玩时已自然获得这些素材/敌人位置。

## 不由本次检查证明的事项

没有完整打完正常5分钟流程、没有全技能与所有保存失败路径回归、没有数百敌人性能测量、没有验证玩家理解与平衡改善。完整Boss招式、精英行为、设置和存档容错仍未达到主案要求。具体已做/未做见README。

## 布局 A 实施补记（2026-10-26）

本轮用户授权逐项评审布局、采用待决规则并落地UE。布局采用14222×10760cm、中央(0,0)出生、48×32设计单位空场、四组共8段矩形。设计坐标默认转换为UE(-100x,-100y)。战斗随机树不再带碰撞，装饰保留外围；村庄不改。

四案顶部增加统一实施说明，关卡经验占位改为货币/材料；HTML V0.3记录10项本轮采用、4项待验收。生成加权抽样、补充上限、精英时序和5:00/5:10不改；满额宝箱显示实际入库，不宣称溢出奖励已经获得。

- 编辑器构建成功；独立Win64 Development构建、Cook、Stage和Archive成功，UAT退出0（BUILD SUCCESSFUL），归档到原03_Build/HD2D_v0_1。
- 编辑器游戏进程和最终独立EXE均通过：8段布局、坐标方向、普通35/精英70/Boss110cm三半径27条路径、27次中心/边缘/角落生成、三种半径实际绕墙移动、已有炼金/库存/暂停/相机和5:00/5:10/6:00事件。
- 可复跑：Tools/Smoke.ps1；独立版用Tools/Smoke.ps1 -Packaged。GUI EXE通过隐藏Start-Process显式等待，检查真实ExitCode及通过标记，避免使用未更新的LASTEXITCODE。最终独立进程退出0且含ALCHEMY_SMOKE_PASS。
- 原始日志：Evidence/smoke.log、packaged-layout-smoke.log。新EXE的SHA256在packaged-exe-hash.json。
- UE实际渲染：Evidence/LayoutA_Top.png、LayoutA_Local.png；已直接查看。隔离截图只展示布局，不是完整正常战斗录像，不写玩家进度。
- HTML离线Edge检查通过，10/4状态过滤、两尺度几何、交互、JSON导出、来源路径与移动宽度正常；额外逐项对比HTML障碍坐标和C++ FVector4数组完全一致。

限制：未完成正常五分钟人工试玩、动态满场性能、材料与战斗平衡对照或完整Boss五招空间验收。可见性图用于这8段固定矩形，不宣称通用NavMesh或动态障碍系统。原型Boss仍为简化行为，已实现不能当作全部主案已验收。

## ALCH-002 原型实施与独立包（2026-10-27）

当前候选为 `03_Build/HD2D_ALCH002`，实际引擎为 UE5.8.4。七组21普通技能、3–10自由投料、品质候选过滤、首次教学、新十连锁及旧字段语义迁移已接入原型。最终包的12组 `ALCH002_CHECK` 均为 PASS，并同时包含 `ALCH002_TEST_PASS` 和 `ALCHEMY_SMOKE_PASS`，见 `Evidence/packaged-layout-smoke.log`。

最终EXE校验记录见 `Evidence/alch002-packaged-exe-hash.json`；界面证据见 `Evidence/ALCH002_Alchemy.png`。构建、打包与界面检查过程见本日工作区 memory。旧 `HD2D_v0_1` 含本轮中间归档，最终验证以新目录为准。

这些检查不代表平衡通过；尚未完成正常五分钟人工试玩、40–60秒首次教学达成率、满场性能及真实用户旧档的破坏性迁移测试。原型候选数值和老玩家识别边界见规则补充与工程README。

## Router：字号、受击反馈和Niagara（2026-10-27，当前候选）

当前入口仍为03_Build/HD2D_PC_UI/启动Demo.cmd。本轮重新Build/Cook/Stage/Archive成功，UAT退出0，详见Evidence/feedback-package.log。字号标准100%不变，中档103.5%、大档117%，相对旧中/大档均减少10%；实现及边界见Docs/CombatFeedback.md。

- 最终独立包15组ALCH002_CHECK全部PASS，包含单体/范围实际伤害飘字、面板暂停及到期清理、烘焙Niagara资产与字号循环；ALCH002_TEST_PASS和ALCHEMY_SMOKE_PASS均存在。日志Evidence/packaged-layout-smoke.log。
- 独立包真实RHI在1920×1080隔离反馈场景退出0，ALCHEMY_FEEDBACK_CAPTURE_PASS；真实粒子峰值1470、累计12组件，结束组件与数字均0。暂停时Niagara总Age保持1.650不变。日志Evidence/feedback-packaged-render.log，结果Evidence/Feedback/packaged-result.txt。
- 已直接查看独立包冰蓝爆发、伤害数字和血条截图Evidence/Feedback/Packaged_Frost_Arcane.png；编辑器命中/爆发截图也已检查。隔离捕获按固定位置和伤害构造场景，不等于正常五分钟玩法自然发生的画面，不读写真实进度。
- 最终EXE SHA256：74753B24BE71C56E64A749DD5875864A683FBF5EF64EF78A8D149B4C9C32B389。打包前后本地玩家主存档SHA256一致。汇总Evidence/feedback-final-verification.json。
- 此轮UI旧三分辨率检查为上一版字号的历史证据；本轮主要对更小的字号循环与1080p战斗反馈做检查，未声称重新人工检查全部33帧。未完成正常五分钟试玩、数百敌人性能测试或每个技能独立特效的正式美术验收。

## 分层字体调试与便携包（当前候选）

F7或面板右上入口打开字体调试。小号固定100%，中号/大号默认85%/80%，可±1%/±5%，范围50%–120%，立即保存。分层逻辑共用于测量、绘制、换行和按钮文字居中，点击区域不变。详见PC_UI.md。

- 最终Win64包Build/Cook/Stage/Archive成功；15组ALCH002_CHECK和ALCH002_TEST_PASS、ALCHEMY_SMOKE_PASS通过。覆盖分组步进、小号不变、上下限、面板入口及保存序列化。初次失败来自浮点比较过严，Game实际0.799999952/0.789999962，与显示80/79一致；使用0.0001容差后通过，保留首轮日志。
- 完整ZIP解压到Evidence下另一条含空格路径，直接用解压出的启动Demo.cmd（937字节，含参数转发和缺文件诊断）启动；原生1280×720全11帧完成，ALCHEMY_PC_UI_CAPTURE_PASS，无文字/按钮越界标记。已直接查看字体调试帧，样例中号75%、大号70%（测试值），小号不变。证据FontDebug_Packaged_720.png、FontDebug_PC_UI/及font-debug-portable-render.log。
- Tools/LaunchDemo.cmd为启动脚本源，Build.ps1和ExportDemo.ps1均复制它；运行用相对路径Windows bootstrap，无需本机UE。ZIP不含Saved/Evidence/PDB，完整解压后运行；只转发CMD/EXE或LFS指针不构成完整运行包。未声称在朋友机器上测试。
- ZIP：03_Build/HD2D_PC_UI/冒牌炼金术士_Demo_Win64_字体调试.zip。EXE/ZIP最终SHA256和大小见Evidence/font-debug-final-verification.json。玩家现有主存档哈希不变。
- 自动审批拒绝递归删除（未返回具体理由），因此改为可恢复归档：旧两个包移至04_Archive/旧版运行包_2026-10-27；过期ZIP和完整解压测试副本也归档到04_Archive，未永久删除。03_Build只剩HD2D_PC_UI。旧存档另有workspace memory/archives备份，归档/私人存档不纳入Git。

本轮没有重新做完整五分钟试玩、满场性能或朋友机器的驱动/运行库兼容性验收。当前字体百分比是可调整起点，最终舒适度由用户试玩确定。

## 用户确认中号90%、大号72%（2026-10-28，当前）
默认值、恢复推荐值、保存回读检查与说明文档统一90/72，小号不变。UAT Build/Cook/Stage/Archive成功，最终独立包15组ALCH002检查及ALCHEMY_SMOKE_PASS通过；1280×720共11帧PC UI真实RHI检查PASS，无越界标记，直接查看Evidence/Font_90_72.png确认90%/72%及恢复按钮标签。现有存档个人设置保留，可按F7恢复推荐值应用新预设。完整包为03_Build/HD2D_PC_UI/冒牌炼金术士_Demo_Win64_字体90_72.zip；旧85/80 ZIP移至本地04_Archive，03_Build内只保留当前ZIP。哈希见Evidence/font-9072-verification.json。

## 关卡/技能编辑工具、血条与掉落（2026-10-28，当前）

- 用户明确确认：普通小怪不显示血条；精英常驻，Boss条移至顶部参考Y=102（1080p下Y=153）。已直接查看最终独立包Tools_Packaged_HUD_Drops.png：包含受伤普通怪、精英、Boss和10个掉落示例，计数elite_bars=1、boss_y=102、drops=10，ALCHEMY_TOOL_CAPTURE_PASS。
- 原生UE关卡工具：Research保存24×18个600cm地格和8个手工碰撞块，共440个可编辑Actor；素材面板预置40张工程贴图；种子随机、锁格、光标涂格、图片/材质/变换及碰撞微调。运行直接读取编辑后地图；未减少波次、怪物上限或改Boss时间轴。
- 四张原生DataTable：DT_Skills(25)、DT_Recipes(10)、DT_Chains(10)、DT_Quality(8)，包含技能/配方/权重/连锁、施法、Niagara、颜色、倍率、保留时间、弹丸速度和减速参数；运行与HUD已读表。可追加连续技能/连锁/精英配方ID。CPP旧表仅用于首次种子和历史基线校验。
- 编辑器8项测试通过：确定性种子、锁格、涂格、地图保存重开材质/位置、技能CSV数值回读、坏数值拒绝、原始数据恢复、11个按钮声明符合UE的CallInEditor且ParmsSize==0条件。校验功能改为void ValidateDesign按钮，bool ValidateLibrary保留作API，避免按钮被UE隐藏。TestDesignTools-final.log、designer-tests.txt记录。
- 原生编辑器API已实际打开4个DataTable编辑器，有对应Opening Asset editor事件；窗口列表确认DataTable窗口。Windows处于锁屏，无法完成真实鼠标点击和按钮视觉布局检查，已明确记录，不以锁屏图充当UE截图。designer-ui-api.json与designer-ui-api-final.log为API证据。
- 金币使用Coin专用图标，六种材料各有独立像素图标，宝箱沿用工程素材；显示尺寸金币95、材料105、宝箱160cm，替代原25/45/75量级。掉落概率、数量、拾取规则沿用原逻辑。
- 最终Editor与Win64 Build/Cook/Stage/Archive成功，独立包16组ALCH002_CHECK、ALCH002_TEST_PASS和ALCHEMY_SMOKE_PASS通过。新增组检查改技能/追加技能映射、权重、零概率过滤、连锁、特效引用、大掉落及减速叠加；修正弹丸初次减速直接使用配置Factor，已有减速才取更强倍率。
- 打开编辑器入口：工程根目录打开关卡与技能编辑器.cmd；默认先编译模块，支持-EngineRoot/UE_ENGINE_ROOT/已知安装位置。ExecCmds启动Focus脚本，不使用会自动退出的ExecutePythonScript。脚本已做语法检查；Windows PowerShell入口实际编译和打开编辑器通过。编辑完整UE工程，不在试玩EXE里提供编辑界面。
- 使用说明：00_Doc/工具/UE关卡与技能编辑器使用说明.md；默认表CSV快照：Docs/DesignerCSV。试玩ZIP保持字体90_72文件名，维持已分享的GitHub链接；ExportDemo先写新包，再把旧包可恢复归档并替换，避免截断正在使用的旧ZIP。归档、缓存和个人存档保持Git忽略。
- 最终EXE/ZIP哈希见Evidence/designer-final-verification.json。未完成物理解锁后的UI点击、正常五分钟人工体验、满场性能或技能平衡验收。

### 2026-10-28 解锁后原生编辑器点击复核
实际点击通过：随机生成、视口选择单格与位置修改、四张原生DataTable入口。测试改动已撤销，地图及表资产未修改。首屏镜头错误由Python Rotator位置参数顺序导致，现以pitch/yaw/roll明确命名；预览灯同步修正，重新启动后Lit模式地图可见。此前“桌面锁屏、点击未测”是历史状态，此项现已补验。

### 随机按钮自动换种子
Randomize每次自动生成不同于上次的Seed；GenerateFromSeed按当前Seed复现。编辑器编译成功，TestDesignTools-reroll.log与designer-tests.txt共9项检查PASS（含new_seed_per_click），锁格与原有数据表检查通过。使用说明已更新。

### 2026-10-28 斜俯视镜头最终验收
- Editor与Win64完整BuildCookRun成功；最终包camera-packaged-smoke.log包含ALCH002_TEST_PASS、shared_oblique_camera_preset和ALCHEMY_SMOKE_PASS，LayoutCheck涵盖边界27个生成点屏外投影。
- TestDesignTools-camera.log及designer-tests.txt：10项编辑检查PASS，含camera_settings_save_reload和13按钮元数据校验。
- 最终包1920x1080实际RHI捕获PASS；已直接查看Camera_Oblique_Combat_1080.png。编辑器恢复预览按钮真实点击通过，Camera_Editor_Preview.png展示参数与视口。
- 最终参数50°俯角/35°水平FOV/3200cm，透视与竖直角色；原配色保留。源参考画面不构成精确参数测量。现有2D片和地格不会因镜头调整自动获得参考图中的悬崖与完整立体美术。
- 校验值及边界见Evidence/camera-final-verification.json；ZIP已刷新。未做远端推送。

### 当前生效：用户要求恢复此前视角（2026-10-28）
本次50°透视/竖直角色与共享镜头预览已撤回。当前游戏48°正交、宽2844cm、角色面向相机；编辑45°布局总览。自动换Seed和复现功能保留，用户地图/技能改动保留。
Editor与Win64打包成功，最终包Smoke与重新捕获的1080p旧视角画面通过。9项编辑测试最终PASS；最初CSV导出受旧文件写入失败影响，已改用新路径并重跑，通过标记见TestDesignTools-camera-revert-final.log。当前证据camera-revert-final-verification.json；前次镜头验证仅历史记录，不再代表当前版本。
