# 村庄补齐素材生成记录

模式：change / sprite-gen + 原生 GPT imagegen。参考：ArtSource/Greyford20261030/Cottage.png。未使用 Grok 或付费 API。文件均归档在 SSD 项目内。

以下为提示词整理版，不是逐字调用日志：保持温暖木石配色、块状像素、硬边轮廓、左上受光；48 度俯视正交三分之四游戏视角；单个独立道具，透明 RGBA，完整轮廓，不含角色、背景、文字、UI、外投影。主体：长椅、木桶、花盆、街灯、药草种植床、蔬菜种植行、开放式炼金作坊、石柱雾门、木制水车、苔藓溪岸石、短石墙。桥木纹采用不透明方形纹理。

原始输出保存为 *-source.png；确定性归一化裁剪透明边、最近邻缩放，512×512，脚点 (256,488)，保留透明。WoodGrain 不透明。manifest.json 记录每项来源尺寸、alpha 包围框及散列。引擎内为独立材质和可编辑 Actor；图片生成不代表关卡验证，验证见 Evidence/Greyford/VillageLife/verification.json。
