# 官网源码与部署记录

> 当前游戏源码入口为 [Godot 工程](../02_Prototype/AlchemyGodot/README.md)。下文的 Unreal 下载及部署记录对应历史版本。

策划正文继续在`00_Doc/协作策划/`维护，网站是只读快照。此次仅归档和同步Git，没有重新部署。

- `source/`：独立Sites工作区`alchemy-official/`的build.py、check_site.py、README.md源码快照。原独立Git仓库及其.openai配置保持本地，不作为主仓库子模块上传。
- `migrations/2026-10-30_cloudbase/public/`：已准备的静态站点快照；`deployment-state.json`与`migration-verification.json`是当时部署与验证记录，不代表本轮重新核验线上状态。迁移说明中的“未部署”为早期准备阶段状态。
- `verification/`：当时页面截图与验证记录。未据此声称已验证所有大陆手机网络。

恢复构建时，将`source/`三个文件复制到本地`04_Web/alchemy-official/`（不要覆盖已有编辑），从该目录执行`python build.py`和`python check_site.py`。按其README将Markdown安装到SSD的`04_Web/tooling/python`。构建还需要项目素材与本地`02_Prototype/AlchemyHD2D/Evidence/ALCH002_Alchemy.png`；后者的共享副本放在本目录`source-inputs/`，新电脑可复制回该位置。`source/README.md`是原始说明快照，部署状态以迁移记录为准。

`migrations/2026-10-30_cloudbase/` 是当时的部署快照，旧 ZIP 下载及 `prepare.py` 的重建依赖已于2026-11-04从当前仓库移除，不再作为现行下载入口。官网源码 `source/build.py` 已改为指向当前 UE 工程试玩说明；本轮仅更新 Git 源码，没有重新部署网站或清除外部站点存储。
