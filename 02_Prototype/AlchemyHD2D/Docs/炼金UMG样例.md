# 炼金 UMG 样例

[Figma 炼金视觉稿](https://www.figma.com/design/UeDgaPrERWr5luHISsO1xr/Untitled?node-id=2067-299)

从 Greyford_Flow 正常进入战斗，首次炼金教学仍走现有教学界面。教学完成后按 Q 进入新版：点击素材或拖到对应料槽／炉口；调整数量，确认两次，起炼后回战场；结果弹出后可接受成品或放弃。换材与同方强化以已携带丹药为目标，使用左右箭头切换。驻留炼制的距离规则沿用原玩法。

| 部件 | 复用方式 |
| --- | --- |
| 边框、标题牌、料槽、按钮、图标 | 源 PNG 在 `ArtSource/AlchemyUI_20261108`，引擎纹理在 `/Game/UI/Alchemy`。面板九宫格、按钮横向三宫格，文字是独立的 UMG TextBlock。 |
| 布局 | 原生 UMG，1280×720 逻辑画布，ScaleBox 等比容纳进窗口。独立图标可换，按键绑定和素材列表来自玩法。 |
| 动效材质 | `M_AlchemyUIFX` 是 UI 材质，运行时实例分别控制投料光环、起炼旋涡、出炉闪光。 |
| 动画 | 投料弧线按 UMG 坐标计算，结果进场由 Widget Animation 控制透明度。 |
| 粒子 | `/Game/VFX/NS_AlchemyFurnaceUI` 是炉口 UI Niagara，使用 CPU UI Sprite Renderer；进入炼制时挂载，离开时释放。 |

布局与动画保存在 Widget Blueprint，玩法绑定代码在 `Source/AlchemyHD2D/AlchemyBrewWidget.cpp`。Figma 下方的合成图鉴位置在试玩保留为同方强化，避免把示意配方当作实际配方或改写现有机制。

重新导入时，在 Unreal Editor 的 Python 环境依次执行 `Tools/ImportAlchemyUI.py` 和 `Tools/BuildFurnaceNiagaraUI.py`。第二个脚本需要本项目的 Editor 模块已编译。

## 在 UMG 设计器里编辑

在内容浏览器打开 `Content/UI/Alchemy/WBP_Alchemy`。选中 `BrewPages`，在 Details 中切换 Active Widget Index：

| 序号 | 页面 |
| --- | --- |
| 0 | 投料与确认 |
| 1 | 炼制中 |
| 2 | 结果对比 |

在 Animations 中打开 `MaterialFlight` 或 `ResultReveal` 调关键帧。投料飞行的起终点会跟随素材按钮和炉口的位置，弧高可在 Class Defaults 的 `FlightArcHeight` 调整。炉口的 UI Niagara 挂在 `FurnaceHost`，移动该节点可调整粒子位置。材质环与旋涡强度继续由游戏状态驱动。

`WBP_AlchemyButton` 和 `WBP_AlchemyMaterialSlot` 可拖进其他 WBP。按钮可设置 Caption、Icon、Caption Size，并可绑定 On Clicked。料槽可设置图标和数量文字。主界面的 `Btn_`、`Slot`、`Data_` 节点名和三页顺序用于连接现有玩法，调整位置、尺寸和视觉时保留这些标识。

现有 WBP 资产是后续编辑入口。首次生成可在 Unreal Editor 的 Python 环境执行 `Tools/BuildAlchemyWidgets.py`。脚本保留现有布局和动画，补齐缺失的字体引用。
