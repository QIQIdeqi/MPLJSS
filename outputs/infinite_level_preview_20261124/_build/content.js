// 五关玩法与美术方向提案；不写入 Godot。节奏数值仅供此预览演示。
// 首关首领“已有”指工程已有招式；本页画面仍是示意。其余首领均为概念。
window.PREVIEW_LEVELS = [
  {
    id: "greyford_01",
    name: "格雷弗德外围",
    subtitle: "第一关 · 草甸与林缘",
    theme: "暖绿草甸、裸土、矮篱与疏林",
    accent: "#a5bc75",
    primary: ["slime", "skeleton", "wolf"],
    bossKind: "boss",
    decision: "沿疏林绕开怪群，再回到空地收取材料。",
    priority: "先处理挡住回收路线的近战怪，再沿空地收取材料。",
    event: { title: "林缘收集点", description: "可选支路上的材料空地，绕行回收或沿主路继续均可。" },
    boss: {
      name: "腐化之源",
      label: "已有",
      test: "用开阔场地练习横向躲冲锋，再从扇形弹间穿过。",
      moves: ["蓄力后直线冲锋", "停步释放扇形弹"]
    },
    tagline: "绕开再回收",
    description: "从草甸学会绕群与回收，疏林和矮篱提供参照，主路保持开阔。"
  },
  {
    id: "trade_road_02",
    name: "旧商路与受灾村庄",
    subtitle: "第二关 · 商路与岔巷",
    theme: "灰黄土路、断墙、货车与受损房屋",
    accent: "#d1a36a",
    primary: ["spider", "skeleton", "water"],
    bossKind: "spider",
    decision: "选择先清织网者打通捷径，还是绕开蛛丝继续前进。",
    priority: "优先处理封住退路的织网者，再避开水弹与近战包夹。",
    event: { title: "路障旁的物资", description: "可选物资在货车侧面，引走追兵后回收，主路始终留通。" },
    boss: {
      name: "织网型首领",
      label: "概念示意",
      test: "辨认扇面蛛丝与落网区域，选择穿过缺口或提前绕行。",
      moves: ["扇面喷吐蛛丝", "示警区域落下蛛网"]
    },
    tagline: "岔路换线",
    description: "旧商路串起受灾村庄，蛛丝改变局部路线，清敌或绕路各有取舍。"
  },
  {
    id: "manor_03",
    name: "贵族庄园",
    subtitle: "第三关 · 庭院与花园",
    theme: "青灰石路、修剪树篱、花坛与庭院",
    accent: "#ba91ba",
    primary: ["mushroom", "spider", "skeleton"],
    bossKind: "mushroom",
    decision: "判断哪条花园环路仍然畅通，提前绕开孢子和蛛丝。",
    priority: "优先清除持续播撒孢子的怪物，避免和蛛丝叠成包围。",
    event: { title: "庭院孢子支路", description: "可选庭院支路短时出现孢子，主路保持畅通，可择机绕入。" },
    boss: {
      name: "赤斑菇首领",
      label: "概念示意",
      test: "辨认孢子覆盖顺序，提前换区并利用消散后的空隙。",
      moves: ["分区播撒延迟孢子", "环形扩散后留出缺口"]
    },
    tagline: "读路再转区",
    description: "庭院与花园交替展开，树篱组织环路，孢子封路促使玩家提前转区。"
  },
  {
    id: "pilgrimage_04",
    name: "朝圣路",
    subtitle: "第四关 · 长路与歇脚地",
    theme: "冷灰石道、路旁石碑、水洼与开阔歇脚地",
    accent: "#85bdc8",
    primary: ["wolf", "bat", "water"],
    bossKind: "bat",
    decision: "诱导扑咬与俯冲沿原方向出招，再横向换位避开夹击。",
    priority: "先读灰狼扑咬和蝙蝠俯冲，再找空隙处理远处流水灵。",
    event: { title: "路旁歇脚地", description: "可选歇脚地提供回收空间，也可沿畅通主路继续推进。" },
    boss: {
      name: "突袭型首领",
      label: "概念示意",
      test: "诱导直线俯冲后横向换位，留出余地应对二次转向。",
      moves: ["示警后直线俯冲", "停顿后二次转向突袭"]
    },
    tagline: "诱导后横移",
    description: "长石道连接开阔歇脚地，扑咬与俯冲叠加水弹，诱导后横移脱身。"
  },
  {
    id: "capital_05",
    name: "王都下城",
    subtitle: "第五关 · 街巷与广场",
    theme: "深灰铺石、密集街屋、拱门与交汇广场",
    accent: "#cf8e83",
    primary: ["skeleton", "water", "spider", "bat"],
    bossKind: "boss",
    decision: "根据远程攻击的方向穿过街口，在广场回收后选择下一条巷路。",
    priority: "先清织网与远程怪保住出口，再处理逼近的近战怪。",
    event: { title: "街口交叉压力", description: "可选广场遭遇聚集多向怪群；主路另有通口，可主动绕开。" },
    boss: {
      name: "国王",
      label: "概念示意",
      test: "在冲锋与分区攻击之间判断安全方向，美术形象暂用占位。",
      moves: ["蓄力冲锋迫使横向让位", "分区示警后轮流落击"]
    },
    tagline: "交叉压迫下换线",
    description: "街巷汇入交叉广场，近远程组合压缩路线，开放出口保留主动换线机会。"
  }
];

window.PREVIEW_PHASES = [
  { start: 0, end: 30, name: "认识战场", intensity: 0.18, type: "teach", interval: 1.00, cap: 12, note: "按本关组合先放易读的单一威胁，认识普攻、材料与路线。" },
  { start: 30, end: 65, name: "第一次合围", intensity: 0.38, type: "pressure", interval: 0.80, cap: 20, note: "逐步增加追击怪，推动绕群，保留明显脱身口。" },
  { start: 65, end: 80, name: "回收与整备", intensity: 0.20, type: "rest", interval: 1.30, cap: 14, note: "降低新增压力，回到击杀处收料并整理接下来的路线。" },
  { start: 80, end: 130, name: "第一次换线", intensity: 0.52, type: "pressure", interval: 0.65, cap: 28, note: "分批加入机动怪，借地形练习转弯和换路线。" },
  { start: 130, end: 145, name: "整理构筑", intensity: 0.24, type: "rest", interval: 1.10, cap: 18, note: "留出回收和观察能力搭配的窗口，场上残留怪仍需处理。" },
  { start: 145, end: 210, name: "远近配合", intensity: 0.64, type: "pressure", interval: 0.55, cap: 36, note: "按关卡逐步混入远程怪，推动侧移与提前绕路。" },
  { start: 210, end: 230, name: "地标与收集", intensity: 0.28, type: "rest", interval: 1.00, cap: 24, note: "降低刷怪速度，利用地标确认回收路线。" },
  { start: 230, end: 285, name: "开门前高峰", intensity: 0.86, type: "peak", interval: 0.45, cap: 48, note: "近远程形成组合压力，仍保留可读的躲避通道。" },
  { start: 285, end: 300, name: "挑战前整顿", intensity: 0.32, type: "rest", interval: 0.95, cap: 28, note: "预告五分钟开放首领入口，整理材料与下一段路线。" },
  { start: 300, end: 345, name: "继续成长", intensity: 0.70, type: "pressure", interval: 0.43, cap: 48, note: "首领入口已开放；可自由挑战，也可留下继续成长。" },
  { start: 345, end: 375, name: "循环高峰", intensity: 0.95, type: "peak", interval: 0.35, cap: 48, note: "持续三十秒的组合压力，奖励提前规划路线。" },
  { start: 375, end: 390, name: "循环喘息", intensity: 0.34, type: "rest", interval: 1.05, cap: 28, note: "十五秒回收窗口；之后重复四十五秒压力、三十秒高峰、十五秒喘息。" }
];
