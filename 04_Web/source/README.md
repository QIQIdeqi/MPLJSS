# 冒牌炼金术士 · 官网与策划档案

构建：`python build.py`。构建工具 Markdown 位于 SSD 的 `../tooling/python`；需要时运行 `python -m pip install Markdown --target ../tooling/python`。部署目录为 `dist`，静态 HTML/CSS/JS，无运行时依赖。

官网包含玩法、标明类型的项目影像、当前 UE 工程试玩入口。旧 Windows 下载链接已从本源码移除；策划区从本项目 Git 正文及配套记录生成只读快照，支持全文检索、图片与表格阅读、Markdown 下载和 GitHub 编辑入口。修改策划应继续在 `00_Doc/协作策划/` 进行，然后重建与发布，网站不自动写回或自动同步。

新站默认私有。本仓库的源码快照已更新，线上站点需另行部署才会同步此入口变化。

本目录有独立 Sites Git 仓库；不要把父项目的未提交改动加入此仓库。
