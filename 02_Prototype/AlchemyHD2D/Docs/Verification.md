# 验证记录

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
