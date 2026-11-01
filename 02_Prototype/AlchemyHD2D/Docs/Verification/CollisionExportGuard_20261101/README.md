# 村庄碰撞导出范围与编辑入口

2026-11-01，北京时间；基线`781aae3`。本轮修复作者工具两处问题，没有改变村庄几何、遮挡层、镜头或交互距离。

## 修复

- SaveCollisionLayout原来在任意Editor关卡都可执行，却固定覆盖Tools/GreyfordReference.json中的walk/blocked。现在仅允许Actor所属关卡包为`/Game/Greyford/Maps/Village_Reference`，错误上下文在读写源文件前返回清晰EditorStatus。在Flow中选中该村庄子关卡所属Actor仍符合规则。
- 编辑入口原来硬找`Reference_blocked_WellBase`，合法重命名后抛StopIteration。现在只筛选真正的Region，优先原井台，否则选择任意Region；全无区域给明确提示，不误选同名其他Actor。

旧48°正交编辑视角对应逻辑坐标和JSON逆变换，不能当作运行60°视角过期而修改。本轮没有动这套校准。

## 验证与边界

完整Editor进程通过Python调用原生导出方法：创建未保存的临时空白地图与默认Region，实际调用SaveCollisionLayout，收到拒绝Status；源JSON SHA256保持。随后只读加载正式Village_Reference，确认关卡身份及46个Region；没有调用合法导出、保存或重建生产地图。退出前重新打开Flow。

复跑：编译Editor后执行`Tools/TestCollisionExportGuard.ps1`，它启动并退出自己的独立Editor进程，180秒上限只终止该次进程。不要在工作中的Editor直接执行Python探针；探针要求专用命令行标志，普通Editor会在操作地图前拒绝运行。

入口脚本通过执行原脚本、替换Unreal接口的三条检查：井台优先、区域已重命名时回退、没有Region时明确失败。这是控制流程检查，不冒充鼠标点击、真实视口对齐或真实改名/保存重开操作。

[verification.json](verification.json)记录原生Editor结果、脚本检查、日志哈希、Editor/Game构建、常规回归和378文件保护；原始脚本/日志在SSD Evidence/CollisionExportGuard_20261101。378包含此前377文件及村庄源JSON，全部未变。

修复前风险来自源码追踪，没有为取得失败截图而在其他关卡调用旧方法覆盖生产JSON。原合法导出序列化主体保持；本轮未重跑旧地图修改/导出专项，也不把只读关卡身份检查说成合法导出已重新验证。未新增碰撞网格、设施临界输入或遮挡观感验收。

未Cook、打包或发布；未改品质目标、满仓选择或暂停的第17问。操作说明同时纠正旧红发角色描述为当前莉莉塔。
