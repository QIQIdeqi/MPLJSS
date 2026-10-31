# 返村控制状态证据

2026-11-01，北京时间；基线 `f59649b8056ca33b01595b62efb79a3626f2ddd5`。修正局内运动/无敌计时残留到村庄：闪避途中赢下Boss时，剩余DodgeTime在结算冻结，返村继续冲刺；致死伤害留下的HurtInv则会让健康角色继续闪烁。

- 旧逻辑26项中5失败：胜利返村计时未清、无输入冲刺、闪烁，以及死亡返村计时未清、继承受伤闪烁。
- 生产仅在 `BuildScene(false)` 清零DodgeCD/DodgeTime/HurtInv/DodgeInv。原StartRun已清理这四项，现补局外建场边界；Boss入场直接SwitchGreyfordStage(2)，不经过这个边界，继承规则保持。
- 1280×720，60与10 FPS各26项通过；制作人39条/33种、死亡离场与升级恢复19条/19种回归通过。Editor/Game编译及376原文件保护见[verification.json](verification.json)。

专项先在真实初始村庄寻找350cm畅通廊道，且返村后重新确认，避免障碍恰好挡住残余冲刺而造成假通过。真实Space输入启动闪避，在其剩余期间调用生产DamageEnemy击杀实际Boss，再由生产Tick处理死亡及胜利；17币单次入账。随后在新局外围以真实Hurt致死，等待自然死亡结束才返村，5币单次入账。每条返村路径观察0.35秒生产Tick，逐帧累积PlayerPos最大偏移与IsHidden，校验无WASD时不漂移、不隐藏。

| 60 FPS最终原图 | 内容 |
| --- | --- |
| [Boss胜利返村](victory-return.png) | 正常站立、提示已结算 |
| [外围死亡返村](defeat-return.png) | 恢复健康站立、无继承受伤闪烁 |

两图未经编辑，已目检；静态图只作返村外观佐证，动态证据是逐Tick状态检查。10 FPS原图与基线失败图/日志保留本地SSD `Evidence/ReturnControl_20261101/`，不把静态图当作过程录像。

复跑：先编译Editor，执行 `Tools/TestReturnControl.ps1`，或加 `-FPS 10`。使用隔离Progress和定点场景；Boss准备倒计时只在夹具置0，自动施法由夹具关闭，击杀通过生产DamageEnemy，不冒充自然完整Boss对局。失败路径此次是外围死亡，不声称覆盖全部Boss致死场景、真人手感、音频或磁盘故障。

不修改场景/美术、伤害/奖励、教学、Boss自由入场或品质配置。旧Windows包未重打。
