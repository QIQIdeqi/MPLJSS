# 怪物动态图鉴验证

> 后续自然精英刷新已加入安全预警兜底，见[后续结果](../EliteSpawn_20261101/README.md)。本页中心位置失败仍说明严格脚本生成的边界，不再代表自然刷新没有兜底。

本批基于`b2d1391`，图鉴使用运行DT的行数、名称和可选说明，发现以Definition行ID登记；奖励仍使用Archetype模板。测试追加普通11、精英12、Boss13及长文案14，生产DT仍只有原11行。

| 画幅 | 未发现第三页 | 自填/回退说明与长文案 | 新普通怪第二页 | 新Boss结算 |
| --- | --- | --- | --- | --- |
| 1280×720 | [图](1280x720/01-third-page-unknown.png) | [图](1280x720/02-third-page-known-long-text.png) | [图](1280x720/03-new-normal-second-page.png) | [图](1280x720/04-new-Boss-victory.png) |
| 1024×768 | [图](1024x768/01-third-page-unknown.png) | [图](1024x768/02-third-page-known-long-text.png) | [图](1024x768/03-new-normal-second-page.png) | [图](1024x768/04-new-Boss-victory.png) |
| 2560×1080 | [图](2560x1080/01-third-page-unknown.png) | [图](2560x1080/02-third-page-known-long-text.png) | [图](2560x1080/03-new-normal-second-page.png) | [图](2560x1080/04-new-Boss-victory.png) |

[机器摘要](verification.json)记录实际结果、断言次数、去重名称与原日志哈希；等待期间重复的HUD检查不算独立功能。复跑使用`Tools/TestEnemyCodex.ps1 -Width 1280 -Height 720`，其他画幅同表。原UI、制作人、完整Flow及Boss规则另行回归。

专项使用隔离进度；覆盖普通/精英实际生成与奖励、核弹独立发现、未知隐藏、长文案省略、旧0/7/10发现序列化、真实Tick处理追加Boss死亡、29金币结算及重复结算幂等。发现/金币保存使用真实内存序列化往返，不表示已注入磁盘写入失败；实际玩家存档另核对SHA256。截图中的回归条目和金币是测试条件，部分图有Editor的Preparing Shaders调试字样，不是正式UI。

运行DT升级先备份uasset和CSV，仅将仍为“普通怪N/精英怪N”的0–9行改为原HUD显示名称；逐字段读回保持其他值、作者自定义名和说明。它们仍是工程占位名称，不代表正式故事物种。原始升级/运行日志与私有存档指纹留SSD工程`Evidence/EnemyCodex_20261101/`。

**已知限制：**初次超宽屏中心视角下，200×200、半径70的追加精英12找不到完整屏外位置；延迟到镜头稳定后仍复现。它复制原7的尺寸/碰撞，按生成器代码可推断原模板也受相同约束。生产代码保留待生成并重试。最终图鉴专项在源图已标注的upper_meadow（570,350）位置通过实际生成，未缩小怪物或放宽屏外/路径检查；它不证明中心视角也能即时生成。失败日志保留`wide-center-spawn-limitation.log`，此限制另列工作台待处理。

本批不改变镜头、地形碰撞、经验/掉落参数或生产Boss选择；旧Windows包未重打。不构成真人平衡、性能、音频或完整自然游玩验收。
