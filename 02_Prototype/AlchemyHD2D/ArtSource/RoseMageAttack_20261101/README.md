# 莉莉塔三向攻击制作输入

新增Side/Back各8帧，Front复用现有正面偏三分之四8帧。总计24个运行帧，其中12个新绘中间姿态、4个复用中立端点、8个原Front帧。以[原生工具提示与来源](PROVENANCE.md)及`prompts/`保留生成记录。

`Side/Back/run/raw`是最终青底清稿；`curated`是现有sprite-gen组件提取结果。`Runtime`包含两张4096×512透明图集、接触表、单次GIF及静态验证记录。GIF末帧额外停留供预览，不修改运行时10fps/0.8秒时序。派生提取预览、重复帧及失败候选只留SSD，不同步Git。

重建顺序（从工程目录，既有Pillow环境与SSD安装的sprite-gen）：

```powershell
python -X utf8 Tools/PrepareRoseMageAttack.py
python -X utf8 Tools/PackRoseMageAttack.py
# 用UE PythonScript commandlet执行Tools/ImportRoseMageAttack.py，仅保存两张新纹理。
```

不运行CLI生成或依赖Codex默认图片目录。脚本读取现有raw；生成新候选需另行使用记录的原生工具提示，不用运行静态准备脚本冒充重新绘制。

每半段以中立帧标定一次统一尺度，保留弯膝/举杖的真实相对高度，不按每帧总包围盒重新拉伸。脚线488，横向沿用原方向中立实测脚质心（Side232.305、Back214.077），误差≤0.5px；首尾像素与原中立图一致。Back重排把真正伸杖置于零基第4帧。最终最小上/左右余量Side33px、Back72px，底边均24px；无cyan、无裁切。

静态`Runtime/verification.json`只记录图片打包时的检查范围；当前UE验证及限制见[原生验收](../../Docs/Verification/RoseMageAttack_20261101/README.md)。新稿中间帧较旧中立稍鲜亮，整体色彩与动作连续性仍应由真人试玩判断。
