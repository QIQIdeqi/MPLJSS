import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { FileBlob, SpreadsheetFile, Workbook } from '@oai/artifact-tool';

const root = path.resolve(process.env.ALCHEMY_ROOT || path.join(path.dirname(fileURLToPath(import.meta.url)), '../../..'));
const out = path.join(root, 'outputs/five_regions_art_20261124');
await fs.mkdir(out, {recursive:true});
if (process.argv.includes('--reference')) {
  const old = await SpreadsheetFile.importXlsx(await FileBlob.load(path.join(root, 'outputs/first_level_art_20261105/第一关_场景美术需求案.xlsx')));
  console.log((await old.inspect({kind:'sheet,table',maxChars:2000,tableMaxRows:2,tableMaxCols:5})).ndjson);
  const png = await old.render({sheetName:'物件需求',range:'A6:J8',scale:1,format:'png'});
  await fs.writeFile(path.join(out,'_build/reference_layout.png'),new Uint8Array(await png.arrayBuffer()));
  process.exit(0);
}

const game = path.join(root,'02_Prototype/AlchemyGodot');
const regions = [
  {id:'greyford_01',name:'格雷弗德外围',theme:'暖绿草甸与林缘',decision:'沿疏林绕群，再返回空地回收。',route:'宽阔土路和疏林间隙',boss:'腐化之源',bossTest:'开阔内场练习横躲冲锋与穿扇射。',ground:'暖绿草甸',a:'捆扎草垛',b:'乡野路牌',styleA:'金黄干草，麻绳捆扎，低矮结实',styleB:'旧木双向牌，叶片少量攀附，无文字',sizeA:112,sizeB:120,collisionA:'60×22',collisionB:'20×14'},
  {id:'trade_road_02',name:'旧商路与受灾村庄',theme:'灰黄旧路与受损村落',decision:'先清织网者打通缺口，或沿岔路绕行。',route:'弯曲商路连接岔巷和货车侧路',boss:'织网型首领',bossTest:'看扇面蛛丝，选缺口或提前绕行。',ground:'灰黄压实旧路',a:'断裂石墙',b:'受损手推车',styleA:'土灰旧石、断面和少量碎石',styleB:'灰褐旧木板、偏斜车轮、空车斗',sizeA:180,sizeB:176,collisionA:'96×20',collisionB:'85×32'},
  {id:'manor_03',name:'贵族庄园',theme:'青灰庭砖与修剪花园',decision:'预读孢子覆盖，沿仍畅通的环路转区。',route:'庭院格网与花园环路，路口留空',boss:'赤斑菇首领',bossTest:'预读覆盖顺序，利用孢子消散空隙。',ground:'青灰庭院石砖',a:'修剪树篱',b:'石制花盆',styleA:'方整矮篱，顶部圆叶簇，少量石边',styleB:'灰石短柱花盆，薰紫小花与绿叶',sizeA:156,sizeB:128,collisionA:'100×22',collisionB:'44×25'},
  {id:'pilgrimage_04',name:'朝圣路',theme:'冷灰山道与歇脚地',decision:'诱导扑咬与俯冲，再横向让位。',route:'纵向大道与开阔歇脚地相连',boss:'突袭型首领',bossTest:'诱导直线俯冲，保留二次转向余地。',ground:'冷灰砾石山道',a:'苔痕路碑',b:'石制灯龛',styleA:'冷灰立石，抽象浅青刻痕，苔痕贴底',styleB:'灰石小龛和石帽，琥珀暖光内腔',sizeA:140,sizeB:144,collisionA:'35×20',collisionB:'32×22'},
  {id:'capital_05',name:'王都下城',theme:'深灰城砖与交汇街口',decision:'优先保住出口，在交叉火力中换街。',route:'街巷格网汇入广场，至少两条退路',boss:'国王（形象占位）',bossTest:'在冲锋与分区落击间读出安全方向。',ground:'深灰城街铺石',a:'旧铁街灯',b:'废砖墙角',styleA:'细长旧铁柱，单盏封闭暖灯，方形底脚',styleB:'红褐砖与深灰基石，裂边和少量落砖',sizeA:164,sizeB:184,collisionA:'20×18',collisionB:'110×22'}
];

const font='Microsoft YaHei';
const green='#365844', pale='#EEF4ED', ink='#203228', gold='#A8823D';
function base(sheet,range){sheet.showGridLines=false;sheet.getRange(range).format={font:{name:font,size:11,color:ink},verticalAlignment:'center',wrapText:true};sheet.tabColor=green;}
function title(sheet,text,end='K') {sheet.getRange(`A2:${end}2`).merge();sheet.getRange('A2').values=[[text]];sheet.getRange(`A2:${end}2`).format={font:{name:font,size:16,bold:true,color:ink},wrapText:false,rowHeightPx:32,borders:{bottom:{style:'thin',color:gold}}};}
function header(sheet,address){sheet.getRange(address).format={fill:green,font:{name:font,size:11,bold:true,color:'#FFFFFF'},horizontalAlignment:'center',verticalAlignment:'center',rowHeightPx:34,borders:{insideVertical:{style:'thin',color:'#FFFFFF'}}};}
function widths(sheet,widths){widths.forEach((width,i)=>sheet.getRangeByIndexes(0,i,80,1).format.columnWidthPx=width);}
async function imageAt(sheet,p,row,col,w=120,h=112){const b=await fs.readFile(p);sheet.images.add({dataUrl:'data:image/png;base64,'+b.toString('base64'),anchor:{from:{row,col,rowOffsetPx:8,colOffsetPx:8},extent:{widthPx:w,heightPx:h}}});}

let rows=[],refs=[];
for(const r of regions){
  const folder=path.join(game,'art/regions',r.id);
  rows.push([r.name,r.ground,r.theme,'256×256 px\n不透明，可平铺','普通与 Boss 基础地表','保持细节低对比，不画固定物件或大块投影。四边连续，和草、泥、石过渡时检查接缝。','普通：按地表权重抽取\nBoss：沿用同主题地表','本轮生成\n工程接入测试','','无脚点，无碰撞','P0']);refs.push(path.join(folder,'ground.png'));
  for(const [name,label,style,size,collision] of [['prop_a',r.a,r.styleA,r.sizeA,r.collisionA],['prop_b',r.b,r.styleB,r.sizeB,r.collisionB]]){
    rows.push([r.name,label,style,'256×256 px\n透明底，脚线 y=232 px','普通绕行参照\nBoss 外圈主题布景','独立透明画片，底部不带矩形地面或烘焙长影。保持侧面和顶面体积，缩小后仍读得出轮廓。不得占主路、出生与传送保护区。',`普通：${name==='prop_a'?'1～3':'1～2'} 件／区块\nBoss 外圈：1～2 件\n密度：不另限制（-1～-1）`,'本轮生成\n工程接入测试','',`PNG 脚点 (128,232) px\n起测显示 ${size}×${size} px\n脚底碰撞 ${collision} px`,'P0']);refs.push(path.join(folder,name+'.png'));
  }
}
const shared=[
 ['橡树','黄绿厚树冠，清楚的树干与根脚','art/oak.png','普通场地标与遮挡','普通每块 6～10 棵，首关自定义值保留；Boss 大树仅外围，不进入主要战斗净空。树冠挡莉莉塔时淡出恢复。','普通：6～10 棵／区块\nBoss：外围布景','脚线 y=488 px\n树干碰撞 29×22 px'],
 ['灌木','矮叶丛，少量细碎花草','art/bush.png','降低地面空旷感','维持低轮廓，不挡预警。底部透明，场地内可无碰撞。','按各关素材池权重\nCount 与 Density 可另调','脚线 y=488 px\n无碰撞'],
 ['短木篱','暖褐旧木横梁和短立柱','art/fence.png','短障碍和路线参照','按脚底细长占地碰撞，留绕行口，不能围出封闭小笼子。Boss 仅外圈。','按各关素材池权重\nCount 与 Density 可另调','脚线 y=488 px\n起测碰撞 68×18 px'],
 ['木箱与麻袋','木板箱、粗麻袋，紧凑小组合','art/crates.png','回收点与生活痕迹','不要带整片地板。低机位检查箱底贴地，保留小体积和清楚脚线。Boss 仅外圈。','按各关素材池权重\nCount 与 Density 可另调','脚线 y=488 px\n起测碰撞 50×26 px']
];
for(const [name,style,file,use,desc,quantity,feet] of shared){rows.push(['五关共用',name,style,'512×512 px\n透明底',use,desc,quantity,'沿用现有素材\n可按统一画风精修','',feet,'P1']);refs.push(path.join(game,file));}
const future=[
 ['格雷弗德外围','腐化根簇','枯枝与暗绿根团','首关 Boss 外圈识别','只放场外或无碰撞外圈。压低发光，不与蓝弹和橙色冲锋混淆。','1～2 簇／Boss 场','art/boss_corruption.png'],
 ['旧商路与受灾村庄','破损路障与残网','破木架、细白蛛丝','织网 Boss 外圈识别','丝网画片和实体木架分离。美术不自行增加阻挡或伤害区，实际蛛丝由特效和玩法生成。','1～2 组／Boss 场','art/regions/trade_road_02/prop_a.png'],
 ['贵族庄园','染孢庭院花坛','低石边、枯紫花丛','孢群 Boss 外圈识别','低矮轮廓，内场不画静态大孢子云，避免与可伤害区域混淆。','1～2 组／Boss 场','art/regions/manor_03/prop_b.png'],
 ['朝圣路','坍塌石碑座','冷灰石座、断裂碑片','俯冲 Boss 外圈识别','断口和石底清楚。中央横移空间保持通畅，不用高石柱切断读招视野。','1～2 组／Boss 场','art/regions/pilgrimage_04/prop_a.png'],
 ['王都下城','残破王城界碑','旧城基石、破损纹章','国王 Boss 外圈识别','图案使用抽象纹章，不新增故事文字。中央四分区危险提示留给实时效果。','1～2 组／Boss 场','art/regions/capital_05/prop_b.png']
];
for(const [region,name,style,use,desc,quantity,ref] of future){rows.push([region,name,style,'建议 256×256 px\n透明底，脚线 y=232 px',use,desc,quantity+'\n正式配置前不计入当前随机池','后续正式美术需求\n参考图仅看材质','', '建议脚点 (128,232) px\n无碰撞外圈装饰优先','P1']);refs.push(path.join(game,ref));}
const instructions=[
 ['范围','本表仅含五关地表、摆件、Boss 外圈布景。角色与怪物动画继续由对应角色、怪物档案维护。'],
 ['PNG 尺寸','本轮新增纹理和物件均为 256×256 px。已有共享素材维持 512×512 px。交付图不应以拉伸图像代替正确比例。'],
 ['地表','不透明 PNG，四边无缝，低对比、均匀细节。地表上不画固定箱子、树、路灯、长投影或敌人。草地、泥地、石地分别出图，混合由材质完成。'],
 ['透明物件','独立 PNG 保留真实透明度，不带白底、黑底或棋盘底。贴地污渍、长影和积雪由独立层或运行材质处理。'],
 ['脚点','新增 256×256 px 画布统一脚点 (128,232) px。共享 512×512 px 素材统一脚线 y=488 px。脚点指物件与地面接触处，不是影子底部。'],
 ['显示比例','新增物件在关卡中的建议显示画布为 112～184 px 的正方形，具体值见需求页。保持源图长宽比，不把竖灯柱横向拉宽。'],
 ['碰撞','碰撞只覆盖脚底实体占地。树冠、花叶、路牌箭头、灯光不参与实体阻挡。表中碰撞为起测 px 值，最终以关卡配置为准。'],
 ['数量与密度','每标准区块 1280×720 px。CountRange 表示该素材每区块数量范围。DensityRange 为可用格数的比例。两者同时设置时取交集，不能设成互相矛盾的范围。'],
 ['当前随机配置','新特色 a 物件普通 1～3 件、b 物件普通 1～2 件。Boss 外圈 a/b 各 1～2 件。新特色物件的 DensityRange=(-1,-1)，即不另限制。'],
 ['保护空间','出生、主路、传送门接近路线留通。Boss 中央与主要躲招区域净空。普通无限场没有封边红线，Boss 有限场保留边界提示。'],
 ['遮挡','前景树冠与高物件遮住莉莉塔时淡出；实体脚底和可读的边界保持。透明图边缘不允许黑块和明显暗边。'],
 ['光照与天气','不要烘焙强暖黄光或大块黑影。使用中性底色，检查白天、黄昏、夜晚以及雨雪。积雪以地面、树冠和屋顶独立覆盖渐积渐融。'],
 ['验收画面','至少检查 1280×720 px 与 1920×1080 px 窗口，中间透视机位与前后遮挡。地表须检查 2×2 平铺接缝和草泥石过渡。'],
 ['美术交付','PNG 与可编辑源文件同名，优先按关卡目录组织。正式重绘直接沿用 ground / prop_a / prop_b 等稳定资源名，改画布或脚点时同步通知技术美术。'],
 ['状态含义','“本轮生成”是已经生成的工程测试素材，仍可由美术精修。“沿用现有”是原工程素材。“后续正式美术需求”尚未生成和接入。'],
 ['参考图','每项均嵌入参考图。未来 Boss 外圈需求的图仅供材质和画风参考，不代表已生成相应新物件。'],
 ['策划依据','已批准的五关玩法预览与 Git 现行场景、关卡正文。五关方向：格雷弗德外围、旧商路与受灾村庄、贵族庄园、朝圣路、王都下城。']
];

const wb=Workbook.create();
const columns=['关卡','物件名称','样式','尺寸（px）','作用','物件需求描述','数量与密度','制作状态','参考图','脚点与碰撞','优先级'];
const report=[];
for (let regionIndex=0;regionIndex<regions.length;regionIndex++) {
  const region=regions[regionIndex];
  const sheet=wb.worksheets.add(region.name);
  base(sheet,'A1:K40');
  title(sheet,region.name+' 美术需求');
  widths(sheet,[150,140,200,185,185,350,235,150,150,250,85]);
  sheet.getRange('A3:K3').merge();
  sheet.getRange('A3').values=[['2026-11-24　'+region.theme+'。'+region.decision]];
  sheet.getRange('A3:K3').format={rowHeightPx:32,font:{name:font,size:11,color:'#5C6D60'}};
  sheet.getRange('A4:K4').merge();
  sheet.getRange('A4').values=[['主通路：'+region.route+'。Boss：'+region.boss+'。'+region.bossTest]];
  sheet.getRange('A4:K4').format.rowHeightPx=32;
  sheet.getRange('A6:K6').values=[columns];header(sheet,'A6:K6');
  const selected=[];
  rows.forEach((row,i)=>{if(row[0]===region.name||row[0]==='五关共用')selected.push({row:[region.name,...row.slice(1)],ref:refs[i],sourceIndex:i});});
  const last=6+selected.length;
  sheet.getRange(`A7:K${last}`).values=selected.map(item=>item.row);
  sheet.getRange(`A7:K${last}`).format.rowHeightPx=154;
  for(let i=0;i<selected.length;i++){
    const row=7+i;
    sheet.getRange(`A${row}:K${row}`).format.fill=i%2===0?pale:'#FFFFFF';
    sheet.getRange(`A${row}:B${row}`).format.font.bold=true;
    await imageAt(sheet,selected[i].ref,row-1,8,128,128);
  }
  const table=sheet.tables.add(`A6:K${last}`,true,'RegionArtNeeds'+(regionIndex+1));table.showFilterButton=true;
  sheet.freezePanes.freezeRows(6);sheet.freezePanes.freezeColumns(2);
  sheet.getRange('A16:K16').merge();
  sheet.getRange('A16').values=[['布置与交付规范']];
  sheet.getRange('A16:K16').format={rowHeightPx:30,fill:green,font:{name:font,size:11,color:'#FFFFFF',bold:true}};
  const localNotes=[
    ['场地','普通关使用无限区块，每标准区块 1280×720 px。Boss 使用独立有限场，中央保留走位空间。数量范围按单个区块计算。'],
    ['Boss 入口','5 分钟后可自愿挑战 Boss。可选事件不拦主路，不锁 Boss 入口。新关 Boss 美术名称和图形为测试概念，未新增剧情设定。'],
    ...instructions
  ];
  for(let i=0;i<localNotes.length;i++){
    const n=17+i;
    sheet.getRange(`A${n}`).values=[[localNotes[i][0]]];
    sheet.getRange(`B${n}:K${n}`).merge();
    sheet.getRange(`B${n}`).values=[[localNotes[i][1]]];
    sheet.getRange(`A${n}:K${n}`).format={rowHeightPx:36,fill:i%2===0?pale:'#FFFFFF'};
  }
  report.push({sheet:region.name,rows:selected.length,images:selected.length,originalDetailIndices:selected.map(x=>x.sourceIndex),norms:localNotes.length});
}
wb.recalculate();
await fs.writeFile(path.join(out,'_build/workbook_inspect.ndjson'),(await wb.inspect({kind:'sheet,table',maxChars:5000,tableMaxRows:2,tableMaxCols:5})).ndjson);
for(let i=0;i<regions.length;i++){
  const png=await wb.render({sheetName:regions[i].name,range:'A2:K10',scale:1,format:'png'});
  await fs.writeFile(path.join(out,'_build','分关验片_'+regions[i].id+'.png'),new Uint8Array(await png.arrayBuffer()));
}
const footer=await wb.render({sheetName:regions[0].name,range:'A13:K24',scale:1,format:'png'});
await fs.writeFile(path.join(out,'_build','分关规范验片.png'),new Uint8Array(await footer.arrayBuffer()));
await (await SpreadsheetFile.exportXlsx(wb)).save(path.join(out,'五关_场景美术需求案.xlsx'));
await fs.writeFile(path.join(out,'_build/five_sheet_structure.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({sheets:report,totalRows:report.reduce((a,s)=>a+s.rows,0),totalImages:report.reduce((a,s)=>a+s.images,0)}));
