# STIX 运行态字体候选

2026-11-01，从本机Matplotlib分发中的STIXGeneral.ttf及LICENSE_STIX原样复制，来源与字节哈希见[provenance.json](provenance.json)。没有下载、修改或重新生成字体。

完整版权、Matplotlib原有OTF→TTF转换说明与SIL OFL 1.1文本保留在[LICENSE_STIX](LICENSE_STIX)。本项目未重命名字体或改字形。

该文件只由`Tools/TestReference60.ps1 -STIX`启用的隔离夹具读取，临时替换五个头部字段的FontInfo；不写Widget蓝图、不替换现行DejaVu字体、不作为当前正式美术结论。普通Reference60命令和正常游戏仍使用现有字体。

这是ArtSource中的观察候选，不是Content内导入字体资产，也不代表Windows发布包已经更新。候选的字形/宽高需以原生截图判断；不能用PIL墨框或许可存在代替UI视觉验收。
