# PixelFX 接入与使用

用户于 2026-10-31 确认：今后美术制作特效优先选用 [patch-gg/pixelfx](https://github.com/patch-gg/pixelfx)。当前锁定提交 `fe7103c36d94e02f2d7df7d8f7a341e493837cde`，源码与声明保存在 `ThirdParty/PixelFX/`。扩展其他效果时先检查上游图层、角色占位图和使用范围，再导出。

## 当前三项

| 预设 | 使用位置 | 人物比例和播放 |
| --- | --- | --- |
| `BP_PixelFX_Hit` | `DamageEnemy` 中的通用命中；已有专用 Niagara 命中保留其数据配置 | 普通敌人用 2.2 cm/源像素，精英按 1.65 倍；0.5 秒后回收 |
| `BP_PixelFX_Poison` | 可拖入关卡的循环美术特效；预览展示穿行及桥栏遮挡 | 4 cm/源像素，横向 spread 0.72，烟雾前后深度相差 140 cm；循环 4 秒 |
| `BP_PixelFX_Portal` | 草原满 300 秒后生成的 Boss 入口 | 4.2 cm/源像素，主体门洞约 244 cm 高；当前人物可见身高约 180 cm；循环 2.4 秒 |

毒雾本次提供美术 Actor，未绑定新增伤害或中毒规则。Boss 入口沿用现有可达落点、按 F 确认、取消、独立 Boss 场景以及战后回村流程。

## 在关卡编辑器调整

1. 内容浏览器打开 `/Game/VFX/PixelFX/`，拖入三个 `BP_PixelFX_*` 预设之一。Actor 的原点是特效落脚点。
2. 详情面板的 **PixelFX** 分类可修改 `Effect`、`Pixel Scale`、`Opacity`、`Glow Strength`、`Mirror` 和 `Lifetime`。尺寸优先改 `Pixel Scale`；使用 Transform 缩放时保持三个轴一致。
3. `Lifetime = 0` 使用预设寿命：命中 0.5 秒；毒雾和传送门持续循环。关卡编辑器显示首帧，点击播放查看动画。
4. 原图分层村庄使用 48° 相机。特效运行时跟随当前相机朝向，四张色彩/发光卡片分别进行深度测试；`Translucency Sort Priority = 0`。不要把排序优先级拉高来强制覆盖建筑或人物。
5. 这些 Actor 不参与碰撞和导航。手工摆放不会改变已有碰撞编辑结果。

当前村庄采用地面坐标 `Z=0`。可直接填写本次预览位置：广场 `X=-567.69, Y=468.12, Z=0`；桥面 `X=1595.77, Y=-673.08, Z=0`，再沿 XY 平面微调。

## 复现与维护

- `node Tools/ExportPixelFX.mjs`：从锁定的上游子集生成透明序列图集、独立光层及 `ArtSource/PixelFX/manifest.json`；无需 npm 安装。
- Unreal Python 执行 `Tools/ImportPixelFX.py`：导入 9 张图集及 2 个基础材质。色彩使用透明混合，发光使用加法混合；像素过滤、无 mip、深度测试开启。
- 编译编辑器后执行 `Tools/SetupPixelFXPresets.py`：生成内容浏览器中的三个蓝图预设。
- `Tools/PreviewPixelFX.ps1`：运行 D3D12 实机预览、录制检查序列，生成 MP4。预览使用隔离存档，不写玩家进度。
- 本次源码保留 MIT `LICENSE` 和 `NOTICE.md`；未引入 gallery 字体。

## 2026-10-31 验证结果

编辑器构建通过；新进程读回 9 张图集、2 个深度测试开启的材质及 3 个蓝图预设通过。D3D12 实机捕获 400 帧，检查了受击触发、人物穿过烟层、传送门前后遮挡与桥栏遮挡；村庄→草原→五分钟 Boss 传送→回村共 42 项状态边界检查通过。

视频位于工作区 `03_Build/Previews/PixelFX_命中_毒雾_传送门_2026-10-31.mp4`：H.264、1280×720、20 fps、20 秒、静音；ffprobe 与完整解码通过。预览用 2.6 倍镜头近看特效，常规游戏相机设置沿用原值。

证据：`Evidence/PixelFX/verification.json`、`assets-readback.json`、`capture.log`、`flow.log` 和 `CurrentFlow/`。本次没有更新 Windows 试玩包，也不代表人工平衡或性能验收。`Content/Legal/PixelFX/` 的许可和署名已配置为下次打包随包复制。
