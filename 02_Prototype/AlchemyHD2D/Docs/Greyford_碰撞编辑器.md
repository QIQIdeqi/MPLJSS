# 村庄碰撞编辑器

入口：双击工程 `Tools/编辑村庄碰撞.cmd`。它打开 `Village_Reference`，对齐原图视角并选中水井碰撞。使用 Unreal 原生样条编辑控件，不需要改 JSON 或 C++。

![原图碰撞编辑界面](../../../00_Doc/协作策划/附件/UE_GreyfordCollisionEditor.png)

## 调整一个物件

1. 在右侧 Outliner 搜索物件名称，例如 `WellBase`（井台）、`WellFrontCrate`（井前箱子），或展开 `Greyford/Reference/blocked`。
2. 在 Details 的组件树中点 `Outline (CollisionOutline)`。点选视口中的顶点，用移动工具调整 X/Y；也可在 `Selected Points → Location` 输入精确坐标。Z 保持 0。没有点被选中时，可用 `Select Spline Points` 的首点/前后点按钮选择。
3. 右击样条线或顶点使用 Unreal 的添加/删除点操作；区域至少保留三个点，避免线段交叉。编辑器将其保持为封闭直线多边形。
4. `Ctrl+Z` 撤销，`Ctrl+Y` 重做，`Ctrl+S` 保存关卡。选中 Actor 整体可移动、旋转或缩放整个区域；复制现有 Region 可增加一个物件占地。

红线是禁止站立的物件占地，绿线是允许行走的道路/广场。实际可走范围为绿色区域的并集减去红色区域；脚底圆半径 30cm，因此人物中心会与边界留出距离。碰撞应贴近物件落地位置，不沿屋顶、树冠描边。它不改变美术遮挡图层。

## 保存与试玩

- 选择 Actor 本身，在 Details 搜索 `Collision Layout` 可看到“阻挡区域”“显示碰撞轮廓”，以及“对齐原图编辑视角”“保存本关卡碰撞到源数据”按钮。若视图失去原图角度，重新点对齐按钮；它也会开启视口 Realtime，编辑时保持开启。
- `Ctrl+S` 保存 `.umap`，游戏直接读取关卡里的轮廓。点“保存本关卡碰撞到源数据”会另将本关卡全部红绿区域写回 `Tools/GreyfordReference.json`，保留美术图层、交互点等其他数据；查看“数据保存状态”确认成功。修改定稿后建议两者都保存。
- 试玩要打开根关卡 `/Game/Greyford/Maps/Greyford_Flow` 再 Play，才能保留完整流程与红发主角。停止 Play 后编辑；再次开始 Play 会重新读取边界。单独的 `Village_Reference` 是编辑用子关卡。
- 已打包的 EXE 不会随工程修改而更新；需要重新打包。

## 后续重建

`BuildGreyfordReference.py` 默认保留关卡内已有的 Region，重建美术不会覆盖手调碰撞。只有明确传入 `-GreyfordReplaceCollision` 才从 JSON 替换全部区域；因此替换前先导出手调结果。

## 验证记录

`Tools/TestGreyfordCollisionEditor.py` 检查旧区域迁移、顶点移动、增删点、JSON 导出及地图保存重开。图形界面的改值、撤销和导出截图在 `Evidence/Greyford/CollisionEditor/`；生产碰撞回归记录在同目录的 `Runtime/`。

碰撞编辑只改变占地。前后遮挡与美术层仍沿用当前版本，需要调整遮挡时另行修改对应图层。
