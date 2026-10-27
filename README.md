# MPLJSS · 冒牌炼金术士

UE5.8 全2D片 HD2.5D 可玩原型与项目策划工作区。

| 目录 | 内容 |
|---|---|
| `00_Doc` | 关卡、战斗、系统、数值策划案，修改意见与商业分析 |
| `01_Skill` | 本项目使用的策划 Skill 与原始包 |
| `02_Prototype/AlchemyHD2D` | UE5.8.4 工程、源码、原生资源、原创占位图、工具与验证证据 |
| `03_Build/HD2D_ALCH002` | 当前ALCH-002 Windows 可运行包；下载完整目录后双击 `启动Demo.cmd` |
| `memory` | 项目决策、操作、验证与未完成事项记录 |
| `logs` / `scripts` | 工作区日志与辅助脚本 |

详细玩法、操作、编译方式及未完成范围见 [工程说明](02_Prototype/AlchemyHD2D/README.md)。当前为预研原型，Boss/精英行为和美术等尚未完整达到主策划案验收标准。

## 获取完整资源

本仓库使用 Git LFS 保存UE资源、打包程序与其他大二进制文件。请安装 Git LFS，再克隆：

```sh
git lfs install
git clone https://github.com/QIQIdeqi/MPLJSS.git
cd MPLJSS
git lfs pull
```

仅下载网页上的单个LFS文件可能得到指针文本；运行当前Demo需要完整的 `03_Build/HD2D_ALCH002/Windows` 目录。UE缓存、编译中间产物及本机运行存档不纳入版本控制。
