# 战斗反馈时序证据

2026-11-01，北京时间；基线 `20199ab1ca695ab3c9c07386c7c28b7198f9b698`。不改伤害、冷却、攻击配置或Boss自由入场。

- 基线专项23项、11失败：6个释放跨界、提前碰撞、尾迹组件提前回收、出生帧预警寿命、末帧预警、暂停保留预警。
- 修正后1280×720，60与10 FPS各23项通过。药瓶分段另覆盖1/60、1/30、0.1秒与半帧/整帧前摇边界。
- A/B调用生产Fire、UpdateShots、UpdateFeedback；C使用实际普通Area行及生产Tick，检查无提前伤害、末帧圈、实际暂停、恢复后落伤与圈回收。
- 尾迹仅证明管理器与Niagara组件寿命，不证明粒子像素可见或真人观感。截图的怪物是当前工程素材，不代表正式怪物美术。
- 莉莉塔43条/37种、Boss28条/28种、制作人39条/33种回归通过。Boss的SpawnDelay由源码复核保持原式，未新增独立出生延迟断言。PotionBreak出生帧UV/寿命兼容由源码复核，未新增四帧截图测试。

| 原生截图 | 观察 |
| --- | --- |
| [旧逻辑60 FPS](baseline-60fps.png) | 最后一个正前摇帧，圈已提前消失 |
| [修正60 FPS](fixed-60fps.png) | 同一边界圈仍存在，角色尚未受伤 |
| [修正10 FPS](fixed-10fps.png) | 大帧长下保留正前摇预警 |

断言、保护文件计数、编译结果与图片SHA256见[verification.json](verification.json)。原始日志/截图保留本地SSD `Evidence/CombatFeedback_20261101/`，汇总不替代原日志。

复跑：先编译Editor，然后执行 `Tools/TestCombatFeedback.ps1` 及 `Tools/TestCombatFeedback.ps1 -FPS 10`。runner仅启动本项目的Editor-Cmd，无需Cook或旧发布包。未打包或更新已发布Windows ZIP；自动验收不替代音效、性能与操作手感试玩。
