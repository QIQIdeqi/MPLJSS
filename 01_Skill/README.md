# 项目对应的 Skill 原件

远端保留 Skill 原始材料与版本记录，运行环境在本机重建：

- `sprite-gen-3.5.0-source.zip`：来自 `aldegad/sprite-gen` 固定提交 `419f02cd54b4181e33689759d4ee9c1ef0006301` 的源码包，包含 SKILL.md、脚本、文档、上游测试源码和许可证。清单、SHA256 与校验结果见 `sprite-gen-source-original.json`。
- `installed/awesome-gamedev-agent-skills`：已安装的固定版本 Skill 快照；版本记录见同目录上层安装清单。
- `gameplay-creative-director.zip`、`senior-game-systems-designer.zip` 及相应安装目录：策划类 Skill 原件与可读入口。
- `sprite-gen.ps1`、安装说明和安装清单：本项目的 Windows 调用方式与版本信息。

不上传虚拟环境、下载模型、FFmpeg 等工具二进制、个人偏好、临时文件和缓存。sprite-gen 的本机工作安装目录为 `installed/sprite-gen`；从源码包恢复后需按其 pyproject.toml 安装依赖，不能把原件压缩包当作已安装环境。

游戏侧的生图实验、动作对照视频、测试地图和验证输出保留在本机，不是分发试玩包的内容。必要生产源图在 UE 工程的 `ArtSource`，生产资源在 `Content`。

## Story Skills

- 来源：https://github.com/danjdewhurst/story-skills
- 版本：0.24.1；固定提交 `87cb3894c73dd8deb1920ca04c213176bb4666fb`。
- 按官方项目级手动安装方式，24 个技能及完整参考文件位于 `.agents/skills/`，供支持该目录的 Agent 发现；新会话中检查技能发现状态。
- 上游 README 与 MIT 许可证：`story-skills/`；文件 SHA256 和安装记录：`story-skills-install.json`。
- 无需全局安装，使用 Node 18+ 运行：`node .agents/skills/story-maintenance/scripts/story.js --help`。
- 当前游戏故事正文继续以 `00_Doc/故事/` 为准；本次仅安装工具，不初始化或迁移故事项目。CLI 的结构化检查需 Story Skills 项目格式，不能直接当作现有正文的验收结果。
