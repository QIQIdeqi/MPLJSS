# UI V0.2 本轮原生验证

2026-10-31；基于76ff638整合后的工作区。Editor/Game目标编译通过。全部为隔离测试存档，图片中的金币/发现/强化为测试条件，不是玩家存档或平衡起测值。

| 画幅 | 十项强化 | 炼金笔记 | 战斗提示 | 高ID图鉴 |
| --- | --- | --- | --- | --- |
| 1280x720 | [查看](1280x720/01-ten-upgrades.png) | [查看](1280x720/02-alchemy-notes.png) | [查看](1280x720/03-battle-guidance-toast.png) | [查看](1280x720/04-codex-high-IDs.png) |
| 1024x768 | [查看](1024x768/01-ten-upgrades.png) | [查看](1024x768/02-alchemy-notes.png) | [查看](1024x768/03-battle-guidance-toast.png) | [查看](1024x768/04-codex-high-IDs.png) |
| 2560x1080 | [查看](2560x1080/01-ten-upgrades.png) | [查看](2560x1080/02-alchemy-notes.png) | [查看](2560x1080/03-battle-guidance-toast.png) | [查看](2560x1080/04-codex-high-IDs.png) |

[验证摘要](verification.json)记录每画幅实际日志断言数及去重名称数，重复HUD可用性检查不作为独立功能覆盖。覆盖真实序列化/迁移、全部10项实际购买/扣币、全部7组合分页填入、21个配方映射技能图鉴、Q与Toast绘制、Boss发现与重复结算。

制作人39项、共享近景70项、完整Flow42项、Boss28项回归通过；11份真实存档SHA256保持不变。原生截图经逐类检查，强化截图在切换面板之前单独完成。原始日志与私有存档指纹留SSD Evidence/UIV02_20261031/；本摘要保留日志哈希。未重新Cook、打包或发布Windows试玩，未进行真人平衡/性能/音频验收。
