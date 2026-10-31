# 莉莉塔方向攻击素材来源

2026-11-01。工程名RoseMage对应用户已确认的莉莉塔；本批延续当前工程服装、玫瑰杖和像素表现，不新增人设或天生魔力设定。

## 来源与制作

- 正面：直接保留`../BattlePresentation_20261031/RoseMage/T_RoseMageAttack.png`及原八帧来源，是已有正面偏三分之四动作，不是新绘严格正视。
- 侧/背：以同目录`T_RoseMageSide.png`、`T_RoseMageBack.png`为唯一方向/身份基准，使用内置`image_gen`工具生成四帧前摇、四帧释放两段，再用相同工具清理成纯青色背景；不是CLI/API付费路线。
- 最终生成提示：`prompts/Side-windup.txt`、`Side-release.txt`、`Back-windup.txt`、`Back-release.txt`；每张再执行`prompts/background-cleanup.txt`。创作图先由原生工具绘制，后由现有sprite-gen组件提取与技术打包，不以旋转静态图伪造动作。
- 内置工具默认文件被复制到本项目SSD，所有导入/重建入口读取本项目ArtSource。淘汰的裁切长条和灰色光晕候选留在SSD `Evidence/RoseMageAttack_20261101/rejected`，不作为生产帧。

最终清稿对应内置工具结果：

| 方向/片段 | 原生结果文件 |
| --- | --- |
| Side/windup | exec-711fba18-f6ef-4863-832c-30f249d2a60a.png |
| Side/release | exec-cf46e431-1dce-491c-ba2e-f9673048cad6.png |
| Back/windup | exec-f80282cb-e768-45e8-b8db-1cddb28b83c0.png |
| Back/release | exec-81ca7dec-233a-49f6-ad8a-99723e9383fd.png |

各输入/输出哈希以同目录运行验证记录为准；不依赖Codex默认生成目录重建。

## 规范与边界

运行单格512×512，脚线488、身体约320px；8格1行、10fps、0.8秒非循环，0.4秒出手。新侧/背中立首尾帧复用已确认静态方向图，其余中间姿态为新绘。左向继续镜像侧图；镜像不承诺非对称配饰左右不变。

生成候选不等于生产通过。提取、统一尺度、帧序、透明边缘与原生游戏渲染必须分别核对；运行验证与限制写入本轮制作人报告。不改变技能数值、移动步态策略或伤害规则。
