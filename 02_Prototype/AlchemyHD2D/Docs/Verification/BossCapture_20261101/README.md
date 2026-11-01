# 制作人：当前Boss检验入口与暂停截图

2026-11-01，北京时间；基线`2ed2afa`。战斗/QA岗位只读核对冲刺锁向、虚实轮廓、出手/收招和两波重瞄准时序，与当前HUD映射一致，未确认新的招式规则问题。制作人检查实际入口与图像后修复两处验收工具问题。

## 已修复

- TestBossPlan.ps1原默认运行存在的10月30日包，无法代表当前源码。现在默认使用当前UnrealEditor-Cmd工程；显式`-BuildDirectory Greyford_BossPlan_Win64_20261030`保留历史包路径，原首个位置参数与-Visual仍兼容。可用-EngineRoot指定引擎；日志用current/packaged和时间戳区分。
- 原暂停捕获发出截图请求即清空Panel，旧脚本返回PASS但图里没有暂停面板。现在等待截图完成，实际检查skills面板、已绘制的返回按钮和Boss时钟冻结后再继续；捕获包含UMG。脚本要求七张图均为本次生成，再归档到该次日志同名目录，当前模式另要求暂停帧检查标志。

| 图 | 证据 |
| --- | --- |
| 旧PASS却没有暂停面板 | [修复前](baseline-paused.png) |
| 当前技能面板与返回按钮 | [修复后](fixed-paused.png) |
| 冲刺锁向与参考HUD | [当前帧](fixed-dash-locked.png) |
| 第二波锁向与参考HUD | [当前帧](fixed-second-wave-lock.png) |

制作人已查看这四张原生图，未编辑图像。暂停帧是截图夹具修复，不宣称玩家正常暂停原先没有面板。

## 验证

默认入口实际执行当前工程Boss规则28条全过；规则运行在截图夹具修改前，生产招式代码本轮没有变化。随后当前视觉捕获产生七张新图，暂停帧原生断言及结束标志通过；1280×720/60FPS，夹具会设置初始顺序、冻结技能冷却并在指定时刻重定位玩家，不能当作自然实战成功率。

默认当前工程、显式历史包的参数路由分别经Windows PowerShell拦截Start-Process检查；后者没有再次运行历史包或验证其玩法。Editor/Game构建均通过；378份受保护文件SHA256不变。[结果与日志/图片哈希](verification.json)。此前会被覆盖的Visual帧已归档项目SSD Evidence/BossCapture_20261101/previous-visual，基线与修复原始日志另留项目Evidence。

复跑：`Tools/TestBossPlan.ps1`检查当前规则，`Tools/TestBossPlan.ps1 -Visual`捕获当前表现；历史包须显式传-BuildDirectory，不再通过默认行为混淆两个版本。当前源码/引擎模块需先编译；旧包不因本次源码更新而变化。

未证明招式每一帧、复杂同屏特效判读、真实锁音可听辨、全部画幅或真人平衡/性能；本轮只读复核与定点捕获也不能替代这些验收。未修改生产招式/数值、Widget资产、地图、玩家存档，未Cook、打包或发布。长期目标继续。
