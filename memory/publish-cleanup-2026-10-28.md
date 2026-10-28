# 最新 Windows 包、历史清理和 Skill 原件

用户要求：重新打包最新 Windows 测试版；历史素材只留必要版本；远端仅保存必要记忆、文档、可构建工程、试玩包及对应 Skill 原件，排除测试输出和缓存。

- 最新完整 ZIP 310278471 bytes，SHA256 `23fedf8d698c40aaff600b0ab117d6b3ce9250dc7ecf8460033bf76cce6c2fdd`。43 个条目全部 CRC 校验通过，无 Saved、Evidence、PDB；完整解压后运行 EXE，ALCHEMY_SMOKE_PASS 与 ALCH002_TEST_PASS 均通过。
- UAT 最终打包成功；打包 EXE 的真实 D3D12 V3 自动测试通过：左走右瞄、脚底稳定、药瓶破碎和清理、受击恢复、死亡末帧与禁止死亡后移动。原生资产校验 141 个，0 错误、0 警告。不是人工完整通关或性能验收。
- 首轮 V3 测试因高速运行时第二次自动攻击干扰碎瓶清理断言而失败；只修正测试夹具为单发，不改变正常攻击规则，再重新打包并复测通过。
- 清理 V1/V2、过期一次性脚本和未引用的旧 Lab 素材。04_Archive 已移入回收站，四份独有存档按哈希备份于工程 Saved/SaveBackups；原试玩存档已恢复到本机新版运行目录，存档不上传。
- `.gitignore` 排除原始生图实验、测试地图、Evidence、测试工具、日志、解压 Windows 目录、虚拟环境和缓存；此前已跟踪的相应内容已移出索引。本机当前实验素材和验证证据保留。QQ 机器人功能脚本保持原状。
- Git 保留生产 Source/Config/Content、ArtSource/AlchemistCombatV3、必要生产工具、文档、memory、Skill 原件及最新完整试玩 ZIP。构建依赖的原生测试源码仍保留，保证工程可编译。
- sprite-gen 上游固定提交 `419f02cd54b4181e33689759d4ee9c1ef0006301`，3.5.0 完整源码原件 ZIP 51101351 bytes，SHA256 `94ae017c5fe1d1cfe26ccc61210e5733e2e675b42e65d04fbcbe0b762e0fd7d0`；658 条目，SKILL.md 与 Git blob 一致。游戏开发 Skill 快照及策划类原始 ZIP 同样保留。
- 打包后的可再生成缓存和 ZIP 校验临时目录已移入回收站；明细见 post-package-cache-cleanup-2026-10-28.json。没有清空回收站。
- 普通删除提交只缩减远端当前版本；旧 Git/LFS 历史不会自动消失，本次不改写历史。

核对记录：packaged-latest.json、history-cleanup-2026-10-28.json、01_Skill/sprite-gen-source-original.json；本机详细日志和画面在工程 Evidence/PackagedLatest 及试玩 Windows/AlchemyHD2D/Evidence/AlchemistCombatV3。
