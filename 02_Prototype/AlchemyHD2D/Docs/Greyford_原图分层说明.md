# 格雷弗德原图分层动态版

用户于 2026-10-30 确认采用“原图分层做可玩 2.5D”：保留指定插画的构图和细节，补独立通行、碰撞、遮挡和可控角色。

## 画面和比例

- 原图：`ArtSource/GreyfordReference20261030/VillageReference.png`，1672×941，原始 PNG 未重绘或缩放后替换。
- 原图中成年人约高 50～55 像素，以 52 像素对应 180 厘米标定。画面宽约 57.88 米，地面投影纵深约 43.83 米。
- 当前主角首个正面帧实际轮廓高 206/256，画布边长 224 厘米，因此可见高度约 180.25 厘米，在原图尺寸下约 52.07 像素。装备轮廓宽度并非统一人体宽度。
- 保持 48° 正交方向与场景原构图，镜头默认放大 2 倍，视野宽约 28.94 米。平滑跟随主角，30 厘米小死区、指数平滑速率 10/s，镜头边界限制在原图内。窗口宽高比变化时调整可见范围，不拉伸场景。ReferenceZoom 可在世界 Actor 的 Reference 分类编辑；检查参数 -GreyfordReferenceOverview 显示全图。
- 村庄镜头关闭额外曝光增亮、暗角、泛光、抗锯齿平滑及电影色调曲线；草原和 Boss 使用原有镜头。

## 可玩内容

WASD 移动，Space 闪避，靠近小屋门前按 F 强化、作坊前按 F 查看图鉴、右侧雾门前按 F 出发。图中水井、树冠、建筑与桥栏分配深度遮挡。桥面通路按可见木板范围制作，溪水和建筑不允许穿越。桥的绘制高度已经包含在预渲染投影中，不是新增可跳跃的三维高差。

按用户澄清只移除原图的 8 名居民，保留红发主角测试跟随。采用原生 ChatGPT imagegen 生成对齐的无人补图和独立水车；仅在 clean_patch_rects 指定的小区域替换原图，不覆盖整张画面。原图文件保留不变。

水车以约 18 秒一周转动；溪流以 6 秒双相采样循环并限定在水色区域；两处烟囱用 5.5 秒循环的半透明烟团上升。均为 Unreal 原生材质随时间运行，其他树木与灯光仍为静态。

## Unreal 编辑入口

打开 `/Game/Greyford/Maps/Greyford_Flow` 进入完整流程。村庄子关卡为 `/Game/Greyford/Maps/Village_Reference`。旧 `/Game/Greyford/Maps/Village_Blockout` 保留为历史版本。

- `Greyford/Reference/DepthLayers`：37 个局部遮挡层及完整背景，共用原图和局部补图。桥栏按横梁与立柱分别描边，保留空隙；建筑、斜向围栏用分段接地基线匹配沿横坐标变化的深度。
- `Greyford/Reference/walk` 与 `blocked`：13 个通行区、33 个阻挡区；原居民脚点的 8 个阻挡已移除。选择 Region Actor 的 `Outline` 组件可手动调整封闭轮廓、增删顶点及输入坐标，支持撤销和关卡保存。入口 `Tools/编辑村庄碰撞.cmd`，详见[碰撞编辑器说明](Greyford_碰撞编辑器.md)。
- `Greyford/Reference/Ambient`：水车、溪流、烟雾三个可在关卡编辑器中单独选中的动态层。
- `Greyford/Reference/Navigation`：设施交互点、寻路节点和 16 个检查目标。
- `Tools/GreyfordReference.json`：原图像素坐标、图层轮廓、设施位置及道路定义。
- `Tools/GreyfordAmbient.py`：局部补图与三个原生动态材质的生成代码。
- `Tools/BuildGreyfordReference.py`：从上述数据导入纹理、重建分层，并将流程根关卡接到新村庄。默认保留已有手调碰撞；仅 `-GreyfordReplaceCollision` 明确从 JSON 替换碰撞区域。

这是保持固定构图的预渲染场景。图层用于前后遮挡；原图底层仍含完整建筑，因此移动某栋建筑的美术时还需要同步重绘底图。它不是可任意转动镜头、重排房屋的完整三维模型集合。

## 碰撞实现与空间复查

村庄使用半径 30cm 的脚底圆形碰撞，草原/Boss 的原碰撞参数保持。`BuildReferenceBoundary` 提取通行区并集的外轮廓，合并处不产生空气墙；运动、可站立判断和寻路共用连续圆形扫掠，避免旧离散采样漏过窄边角。33 个物件占地按原图落地位置描绘，不以树冠和屋顶范围代替脚底碰撞。

空间检查入口为 `Tools/TestGreyfordSpatial.ps1`；`Tools/GreyfordSpatial.json` 记录原图像素坐标与是否可站立的预期；`GreyfordSpatial.inl` 执行生产移动、全图网格扫掠、连通性、逐点走到与 D3D12 截图。详细结果写入 `Evidence/Greyford/Spatial`。

当前碰撞与遮挡结果见 [全图复查记录](Greyford_碰撞层级复查.md)：最终打包版 111 个语义点、55 条目标路径通过，全图 27,168 次移动探测无穿越阻挡。

## 上一版验证记录

上一版静态全图记录保存在 `Evidence/Greyford/Reference/`；本轮动态与跟随镜头记录保存在 `Evidence/Greyford/Ambient/`，入口 `Tools/TestGreyfordAmbient.ps1`。以最终生成的 `verification.json` 为验收结果，不用地图保存成功替代运行验证。

动态版本（21:45 交付）最终包：1280×720、1024×768、全图模式各 42 项检查通过；5 点移动录制 625 帧，镜头全程不越界。水车、溪流、两处烟雾的局部变化和静态屋顶控制区分别核对；31.25 秒 H.264 视频完整解码通过。Research 冒烟通过。原图居民不再包含脚点阻挡，路径查询改为 5cm 采样和 2cm 余量，避免新开放路线擦角。
