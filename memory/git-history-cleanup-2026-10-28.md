# Git 远端历史瘦身

用户已明确授权清理远端历史旧大文件，覆盖此前“不改写历史”的约定。

清理策略：保留当前生产文件及源码、文档的有效提交历史；从历史中移除当前已删除的路径，以及当前版本不再使用的 LFS 指针和超过 1 MiB 的旧普通 blob。最新提交的整个 tree 必须在清理前后完全一致。远端现场只有 main，无其他分支、标签或 PR 引用。

清理前 main：`9bd0f18184f6e0a943aaaeb8e2b45b62ec59bfc0`，tree `8e6dc523065978deabc03edba77b6676ac85bd79`，17 个提交。历史引用 471 个不同 LFS 对象，共 7311495528 bytes；当前保留 145 个，共 381246648 bytes。

本机恢复资料位于 SSD 的 `01_Skill/tmp/history-rewrite-20261028`，此目录被 ignore，不上传：

- `before-cleanup.bundle`：完整 Git refs/提交/tree/blob 备份，已通过 git bundle verify。Git bundle 不包含 LFS 实体文件；旧 LFS 仍留在 GitHub 后台，当前 LFS 和此前未验证远端的本机独有对象保持原状。
- `analysis.json`、路径白名单、清除 blob 清单和 filter-repo commit-map：用于核对与恢复旧提交映射。
- 独立改写仓库、从远端新克隆的验收目录：主工作工程的未跟踪素材、存档和运行环境不参与改写。

注意：GitHub 官方说明，删除 Git/LFS 历史引用后，旧 LFS 对象仍可能计入存储配额。清理后台对象需要 GitHub Support 协助，或删除重建仓库。本次不删除仓库、不发送支持请求，因此不会把历史引用缩减描述为后台配额已经释放。

协作者应备份本机未提交工作后重新克隆；不要把旧历史合并回 main。旧提交号只在本机备份和清理映射中用于追溯，之后以远端新历史为准。

官方说明：https://docs.github.com/en/repositories/working-with-files/managing-large-files/removing-files-from-git-large-file-storage

验收结果：新历史 main 为 `b02ce92341f7d14bb3e481d76afc1c54e431953c`，仍保留 17 个提交；清理前后最新 tree 相同。重新从 GitHub 克隆并下载全部 145 个 LFS 文件成功，git lfs fsck 通过；试玩 ZIP 和 Skill 源码 ZIP 的 SHA256 与全部条目 CRC 校验通过。新克隆 Git pack 7848943 bytes，所需 LFS 381246648 bytes，下载数据合计约 389 MB。原始场景和游戏二进制没有改动，沿用此前打包测试结果，无需重新构建。

GitHub Support 选择性清理对象清单另存 `github-lfs-support-object-list-2026-10-28.json`：326 个过期对象、145 个必须保留对象。仅准备清单，没有发送请求，也没有删除 GitHub 仓库。若以后清理后台配额，可使用该清单明确保留范围。
