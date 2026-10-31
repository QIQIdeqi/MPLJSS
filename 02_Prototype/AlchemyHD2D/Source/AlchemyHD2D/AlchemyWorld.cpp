#include "AlchemyWorld.h"
#include "BattleReferenceWidget.h"
#include "Camera/PlayerCameraManager.h"
#include "Blueprint/UserWidget.h"
#include "PixelFXActor.h"
#include "Dom/JsonObject.h"
#include "Serialization/JsonSerializer.h"
#include "HAL/IConsoleManager.h"
#include "Modules/ModuleManager.h"
#include "Engine/StaticMeshActor.h"
#include "Engine/TargetPoint.h"
#include "Engine/LevelStreaming.h"
#include "TimerManager.h"
#if WITH_EDITOR
#include "ShaderCompiler.h"
#include "AssetCompilingManager.h"
#endif
#include "GameFramework/PlayerStart.h"
#include "Engine/StaticMesh.h"
#include "Engine/Texture2D.h"
#include "Sound/SoundBase.h"
#include "AudioMixerBlueprintLibrary.h"
#include "Engine/Canvas.h"
#include "Engine/Font.h"
#include "Components/StaticMeshComponent.h"
#include "Components/DirectionalLightComponent.h"
#include "Components/SkyLightComponent.h"
#include "Components/PointLightComponent.h"
#include "Camera/CameraActor.h"
#include "Camera/CameraComponent.h"
#include "Engine/DirectionalLight.h"
#include "Engine/SkyLight.h"
#include "Engine/PointLight.h"
#include "Engine/PostProcessVolume.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "Kismet/GameplayStatics.h"
#include "EngineUtils.h"
#include "InputCoreTypes.h"
#include "Misc/Paths.h"
#include "Misc/App.h"
#include "Misc/CommandLine.h"
#include "Misc/Parse.h"
#include "Misc/FileHelper.h"
#include "HAL/PlatformFileManager.h"
#include "Fonts/CompositeFont.h"
#include "UnrealClient.h"
#include "CanvasItem.h"
#include "Framework/Application/SlateApplication.h"
#include "Fonts/FontMeasure.h"
#include "Rendering/SlateRenderer.h"
#include "NiagaraSystem.h"
#include "NiagaraComponent.h"
#include "NiagaraFunctionLibrary.h"
#include "NiagaraSystemInstanceController.h"
#include "NiagaraSystemInstance.h"
#include "NiagaraEmitterInstance.h"
#include "NiagaraDataSetAccessor.h"
#include "AlchemyVFXBuilder.inl"

IMPLEMENT_PRIMARY_GAME_MODULE(FDefaultGameModuleImpl, AlchemyHD2D, "AlchemyHD2D");

namespace {
const TCHAR* SkillNames[]={TEXT("试作魔弹"),TEXT("炎弹"),TEXT("寒霜环"),TEXT("雷链"),TEXT("酸蚀瓶"),TEXT("石刺"),TEXT("炽焰波"),TEXT("兽核脉冲"),TEXT("虚空噬弹"),TEXT("根须脉冲"),TEXT("灰烬弹"),TEXT("灼热旋流"),TEXT("炎陨药瓶"),TEXT("凝露针"),TEXT("寒霜花"),TEXT("冰潮涌动"),TEXT("以太碎片"),TEXT("奥术脉冲"),TEXT("星坠裂隙"),TEXT("蒸汽爆裂"),TEXT("雷焰爆裂"),TEXT("霜刃"),TEXT("霜雷风暴"),TEXT("混融酸滴"),TEXT("原初催化弹")};
const TCHAR* MaterialNames[]={TEXT("火粉"),TEXT("露水"),TEXT("魔法碎片"),TEXT("兽核"),TEXT("虚空晶"),TEXT("根须心")};
// Configuration tables: stable skill IDs 0..9 retained, new skills append at 10..24.
const int32 CombinationSkills[7][3]={{10,1,5},{13,14,15},{16,3,17},{19,6,12},{11,20,18},{21,2,22},{23,4,24}};
const int32 CombinationMasks[]={1,2,4,3,5,6,7};
const TCHAR* CombinationNames[]={TEXT("火粉反应"),TEXT("露水反应"),TEXT("魔法反应"),TEXT("火露混合"),TEXT("火魔混合"),TEXT("露魔混合"),TEXT("三料混合")};
const float QualityWeights[8][3]={{70,20,10},{65,22,13},{60,25,15},{50,30,20},{45,32,23},{40,33,27},{35,34,31},{30,35,35}};
// ALCH-003: special (nuclear) proc chance by total input 3..10, linear 5% -> 1%.
const float SpecialProcChance[8]={5.00f,4.43f,3.86f,3.29f,2.71f,2.14f,1.57f,1.00f};
using ECast=EAlchemyCast;
constexpr auto Bolt=ECast::Bolt,Direct=ECast::Direct,SelfArea=ECast::SelfArea,TargetArea=ECast::TargetArea,Bounce=ECast::Bounce;
struct FSkillConfig {float Damage,CD,Range,Radius,Slow,Factor; ECast Cast; int32 Targets;};
// Distances are cm. Provisional tuning: stone CD 2s, shard 2 targets, frost needle slow.
const FSkillConfig Skills[]={
 {18,1,900,0,0,1,Bolt,1},{26,1.8f,900,0,0,1,Bolt,1},{14,3.2f,1000,220,1,.75f,SelfArea,1},
 {20,2.8f,900,0,0,1,Bounce,3},{28,3.8f,1000,180,0,1,TargetArea,1},{38,2,800,0,0,1,Direct,1},
 {30,4.4f,1000,240,0,1,TargetArea,1},{44,4.5f,900,240,0,1,TargetArea,1},{58,4.8f,900,0,0,1,Bolt,1},{32,4,1000,240,1.2f,.65f,SelfArea,1},
 {18,1.5f,900,0,0,1,Bolt,1},{20,4,1000,160,0,1,TargetArea,1},{44,5,1000,260,0,1,TargetArea,1},
 {18,1.6f,600,0,.8f,.9f,Direct,1},{25,3,1000,200,1,.85f,SelfArea,1},{36,4.5f,1000,300,1.5f,.65f,SelfArea,1},
 {12,2.8f,900,0,0,1,Bounce,2},{30,2.5f,900,0,0,1,Bounce,5},{44,4.5f,1000,250,0,1,TargetArea,1},
 {20,2.5f,1000,160,0,1,TargetArea,1},{46,4.8f,1000,220,0,1,TargetArea,1},{20,2.3f,600,0,.8f,.9f,Direct,1},
 {42,4.5f,1000,280,1.2f,.7f,SelfArea,1},{22,2.6f,1000,160,0,1,TargetArea,1},{48,5.2f,1000,280,0,1,TargetArea,1}
};
struct FChainConfig {const TCHAR* Name; int32 A,B; float CD,Damage,Radius,Slow,Factor; int32 Targets;};
const FChainConfig Chains[]={
 {TEXT("火花余烬"),10,6,12,36,240,0,1,0},{TEXT("沸腾腐蚀"),11,4,13,40,250,0,1,0},
 {TEXT("天火坠雷"),12,20,16,54,300,0,1,0},{TEXT("寒露封结"),13,2,12,30,250,1.5f,.65f,0},
 {TEXT("冰潮共振"),14,15,14,42,320,1.5f,.6f,0},{TEXT("冻电跃击"),21,3,12,34,0,1,.8f,3},
 {TEXT("奥术共鸣"),16,17,13,38,260,0,1,0},{TEXT("星裂石刺"),18,5,14,46,280,0,1,0},
 {TEXT("原初蒸爆"),19,24,14,44,280,0,1,0},{TEXT("元素过载"),22,1,15,48,280,0,1,0}
};
const int32 Recipes[10][6]={{0,0,0,0,0,0},{2,0,1,0,0,0},{0,2,1,0,0,0},{1,0,2,0,0,0},{1,1,1,0,0,0},{1,2,0,0,0,0},{2,1,0,0,0,0},{1,0,1,1,0,0},{0,1,1,0,1,0},{1,1,0,0,0,1}};
const int32 Minimum[]={18,30,45,60,75,90}, Batch[]={2,3,4,5,6,6}, Refill[]={8,8,10,10,12,12};
const float Interval[]={2.6f,2.2f,1.9f,1.6f,1.4f,1.35f};
// TALENT-001 revised (系统 UI V0.2): 10 independent upgrades, no linear unlock tree.
// All are freely purchasable with enough coins. Max level 5 for stats, 1 for one-shot unlocks.
// Index order matches the document 3.2 table:
//   0 生命  1 攻击  2 移速  3 幸运  4 冷却  5 暴击  6 暴伤  7 防御  8 技能刷新  9 材料掉落
const TCHAR* TalentNames[]={TEXT("生命强化"),TEXT("攻击强化"),TEXT("移动速度"),TEXT("幸运增加"),TEXT("技能冷却"),TEXT("暴击增加"),TEXT("暴伤增加"),TEXT("防御增加"),TEXT("技能刷新"),TEXT("材料掉落提高")};
// Per-level costs. Stats use 5 levels (Lv1..Lv5); one-shot unlocks use a single cost (Lv0->Lv1).
const int32 TalentMaxLevel[10]={5,5,5,5,5,5,5,5,1,1};
const int32 TalentCosts[10][5]={
    {60,90,130,180,240},     // 生命强化
    {80,120,170,230,300},    // 攻击强化
    {70,100,140,190,250},    // 移动速度
    {50,80,120,170,230},     // 幸运增加（暂无玩法效果）
    {90,130,185,250,330},    // 技能冷却
    {100,145,205,280,370},   // 暴击增加
    {90,135,195,270,360},    // 暴伤增加
    {110,160,225,305,400},   // 防御增加
    {280,0,0,0,0},           // 技能刷新（一次性）
    {320,0,0,0,0}            // 材料掉落提高（一次性）
};
const TCHAR* TalentDescriptions[10]={
    TEXT("每级最大生命值 +10"),
    TEXT("每级所有普通技能伤害 +5%（加算）"),
    TEXT("每级移动速度 +3%（加算）"),
    TEXT("当前版本暂不生效"),
    TEXT("每级普通技能冷却时间减少 4%"),
    TEXT("每级暴击率 +2 个百分点"),
    TEXT("基础暴击倍率 150%，每级 +10 个百分点"),
    TEXT("每级受到的敌方伤害减少 2%"),
    TEXT("解锁后每次普通炼金结果可免费刷新一次"),
    TEXT("普通材料掉落概率相对提高 30%")
};
constexpr int32 TalentNodeCount=10;
// Codex: monster and material codex data (system UI V0.2 §4.6). Elite materials are disabled.
const TCHAR* MonsterNames[]={TEXT("腐化鼠"),TEXT("泥团怪"),TEXT("游荡骷髅"),TEXT("毒囊虫"),TEXT("暗影猎犬"),TEXT("游荡术徒"),TEXT("石甲蛮徒"),TEXT("腐化巨蜥"),TEXT("蚀雾术士"),TEXT("根须守卫"),TEXT("腐化之源")};
const TCHAR* MonsterDescriptions[]={
    TEXT("成群的腐化啮齿动物，行动迅速，成群结队逼近玩家。"),
    TEXT("缓慢但耐打的泥沼生物，靠接触造成持续伤害。"),
    TEXT("游荡的骸骨战士，靠近后用近战挥击攻击。"),
    TEXT("会喷射毒液的虫类，远程投射攻击。"),
    TEXT("行动迅速的猎犬，负责逼迫玩家走位。"),
    TEXT("使用远程法术的术徒，发射投射物。"),
    TEXT("身披石甲的蛮徒，行动缓慢但重击凶猛。"),
    TEXT("体型庞大的巨蜥精英，拥有扫尾强力攻击。"),
    TEXT("释放蚀雾弹的术士精英，腐蚀爆发范围攻击。"),
    TEXT("盘踞的根须守卫精英，地裂强力攻击。"),
    TEXT("Demo 唯一最终 BOSS，双阶段战斗，击败后胜利。")
};
const TCHAR* MaterialCodexNames[]={TEXT("火粉"),TEXT("露水"),TEXT("魔法碎片")};
const TCHAR* MaterialCodexDescriptions[]={
    TEXT("橙红色粉末，带少量火星，用于火焰、爆炸类炼金。"),
    TEXT("浅蓝色水珠，用于冰霜、减速类炼金。"),
    TEXT("紫蓝色小晶片，带微弱魔法光效，用于雷电、奥术类炼金。")
};
const FLinearColor Gold(0.82f,0.58f,0.25f), Teal(0.18f,0.75f,0.65f), Ink(0.025f,0.045f,0.06f), Muted(0.5f,0.62f,0.63f);
// Layout A: design X is screen-right, design Y is screen-down; default camera yaw is 90.
// Rows: design left/top/width/height in units (1 unit = 100 cm).
const FVector4 LayoutRects[]={
    FVector4(-42,-22,14,3),FVector4(-39,-12,4,7),FVector4(26,-23,14,3),FVector4(36,-13,4,8),
    FVector4(-42,19,14,3),FVector4(-39,28,4,6),FVector4(26,19,14,3),FVector4(36,28,4,6)
};
FVector DesignPosition(float X,float Y) { return FVector(-100*X,-100*Y,0); }

}

#include "AlchemyDesignRuntime.inl"
#include "AlchemyEnemyRuntime.inl"
#include "GreyfordCombat.inl"
#include "GreyfordFlow.inl"
#include "BattleReferenceScene.inl"
#include "VillagePerspective.inl"

AAlchemyMode::AAlchemyMode() { DefaultPawnClass=nullptr; HUDClass=AAlchemyHUD::StaticClass(); }
void AAlchemyMode::StartPlay() { Super::StartPlay(); GetWorld()->SpawnActor<AAlchemyWorld>(); }
AAlchemyWorld::AAlchemyWorld() { PrimaryActorTick.bCanEverTick=true; }

void AAlchemyWorld::BeginPlay() {
    Super::BeginPlay();
#if WITH_EDITOR
    if(FParse::Param(FCommandLine::Get(),TEXT("AlchemyBuildVFX"))) {
        bool OK=AlchemyVFXBuilder::Build();FPlatformMisc::RequestExitWithStatus(false,OK?0:1);return;
    }
#endif
    bSmoke=FParse::Param(FCommandLine::Get(),TEXT("AlchemySmoke"));
    bCapture=FParse::Param(FCommandLine::Get(),TEXT("AlchemyCapture")) || FParse::Param(FCommandLine::Get(),TEXT("AlchemyLayoutCapture")) || FParse::Param(FCommandLine::Get(),TEXT("AlchemyUI")) || FParse::Param(FCommandLine::Get(),TEXT("AlchemyPCCapture")) || FParse::Param(FCommandLine::Get(),TEXT("AlchemyFeedbackCapture")) || FParse::Param(FCommandLine::Get(),TEXT("AlchemyToolsCapture")) || FParse::Param(FCommandLine::Get(),TEXT("AlchemyCharacterSmoke")) || FParse::Param(FCommandLine::Get(),TEXT("AlchemyCharacterV3Smoke"));
    bCapture |= FParse::Param(FCommandLine::Get(),TEXT("AlchemyBossSmoke")) || FParse::Param(FCommandLine::Get(),TEXT("AlchemyBossCapture"));
    bCapture |= FParse::Param(FCommandLine::Get(),TEXT("AlchemyBossPreview")) || FParse::Param(FCommandLine::Get(),TEXT("PlannedBossTest")) || FParse::Param(FCommandLine::Get(),TEXT("PlannedBossPreview")) || FParse::Param(FCommandLine::Get(),TEXT("PlannedBossCapture"));
    bCapture |= FParse::Param(FCommandLine::Get(),TEXT("AlchemyMerchantSmoke")) || FParse::Param(FCommandLine::Get(),TEXT("AlchemyMerchantCapture")) || FParse::Param(FCommandLine::Get(),TEXT("AlchemyMerchantPreview"));
    bCapture |= FParse::Param(FCommandLine::Get(),TEXT("GreyfordSpatialTest"));
    bCapture |= FParse::Param(FCommandLine::Get(),TEXT("PixelFXCapture"));
    bCapture |= FParse::Param(FCommandLine::Get(),TEXT("ProducerRegression")) || FParse::Param(FCommandLine::Get(),TEXT("UIV02Test"));
    bCapture |= FParse::Param(FCommandLine::Get(),TEXT("VillagePerspectiveTest")) || FParse::Param(FCommandLine::Get(),TEXT("VillagePresentationTest")) || FParse::Param(FCommandLine::Get(),TEXT("UnifiedPresentationTest"));
    bCapture |= FParse::Param(FCommandLine::Get(),TEXT("Reference60Test"));
    bCapture |= FParse::Param(FCommandLine::Get(),TEXT("BattlePresentationTest")) || FParse::Param(FCommandLine::Get(),TEXT("BattlePresentationCapture"));
    bCapture |= bGreyfordScene && (!bGreyfordFlow || FParse::Param(FCommandLine::Get(),TEXT("GreyfordFlowTest")) || FParse::Param(FCommandLine::Get(),TEXT("GreyfordAmbientTest")));
    const FString SaveSlot=bGreyfordFlow?TEXT("GreyfordDemo_v1"):TEXT("AlchemyResearch_v1");
    const FString BackupSlot=bGreyfordFlow?TEXT("GreyfordDemo_backup"):TEXT("AlchemyResearch_backup");
    if(!LoadDesignConfig()) {
        SetActorTickEnabled(false);
#if WITH_EDITOR
        if(GetWorld()->WorldType==EWorldType::PIE && GEditor) {GEditor->RequestEndPlayMap();return;}
#endif
        FPlatformMisc::RequestExitWithStatus(false,1);return;
    }
    Progress=(bSmoke || bCapture)?nullptr:Cast<UAlchemyProgress>(UGameplayStatics::LoadGameFromSlot(SaveSlot,0));
    const bool HadSave=Progress!=nullptr;
    if(!Progress && !bSmoke && !bCapture) Progress=Cast<UAlchemyProgress>(UGameplayStatics::LoadGameFromSlot(BackupSlot,0));
    if(!Progress && !bSmoke && !bCapture && UGameplayStatics::DoesSaveGameExist(SaveSlot,0)) {
        UE_LOG(LogTemp,Error,TEXT("ALCH002 cannot load primary or backup save; refusing to overwrite player progress"));
        FPlatformMisc::RequestExitWithStatus(false,1);return;
    }
    if (!Progress) Progress=NewObject<UAlchemyProgress>(this);
    if(Progress->SchemaVersion<3) {
        const bool Played=Progress->Coins>0 || !Progress->Recipes.IsEmpty() || !Progress->Chains.IsEmpty() || Progress->Talents.ContainsByPredicate([](int32 L){return L>0;});
        // Back up the old object before adding new semantic records; isolated QA never writes player saves.
        if(HadSave && !bSmoke && !bCapture && !UGameplayStatics::SaveGameToSlot(Progress,BackupSlot,0)) {
            UE_LOG(LogTemp,Error,TEXT("ALCH002 migration backup failed; primary save left unchanged"));
            FPlatformMisc::RequestExitWithStatus(false,1);return;
        }
        MigrateProgress(Played);
    }
    // Normalize only after the untouched old object has been backed up and migrated.
    if(Progress->Talents.Num()!=TalentNodeCount) Progress->Talents.SetNumZeroed(TalentNodeCount);
    if(FMath::IsNearlyEqual(Progress->UITextScale,1.15f,.001f)) Progress->UITextScale=1.035f;
    else if(FMath::IsNearlyEqual(Progress->UITextScale,1.3f,.001f)) Progress->UITextScale=1.17f;
    Progress->UITextScale=1; // Retained only to read older saves; use independent font groups now.
    Progress->MediumTextScale=FMath::Clamp(Progress->MediumTextScale,.5f,1.2f);
    Progress->LargeTextScale=FMath::Clamp(Progress->LargeTextScale,.5f,1.2f);
    PotionBreakAtlas=LoadObject<UTexture2D>(nullptr,TEXT("/Game/Art/T_PotionBreakAtlas.T_PotionBreakAtlas"));
    Levels.Init(0,NumSkills());Levels[0]=1;
    ImpactFX=LoadObject<UNiagaraSystem>(nullptr,TEXT("/Game/VFX/NS_AlchemyImpact.NS_AlchemyImpact"));
    BossLockSound=LoadObject<USoundBase>(nullptr,TEXT("/Game/Art/Audio/S_BossLock.S_BossLock"));
    MerchantBuySound=LoadObject<USoundBase>(nullptr,TEXT("/Game/Art/Audio/S_MerchantBuy.S_MerchantBuy"));
    MerchantSellSound=LoadObject<USoundBase>(nullptr,TEXT("/Game/Art/Audio/S_MerchantSell.S_MerchantSell"));
    MerchantCoinTexture=LoadObject<UTexture2D>(nullptr,TEXT("/Game/Art/Coin.Coin"));
    BlastFX=LoadObject<UNiagaraSystem>(nullptr,TEXT("/Game/VFX/NS_AlchemyBlast.NS_AlchemyBlast"));
    TrailFX=LoadObject<UNiagaraSystem>(nullptr,TEXT("/Game/VFX/NS_AlchemyTrail.NS_AlchemyTrail"));
    ParticleMaterial=LoadObject<UMaterialInterface>(nullptr,TEXT("/Game/VFX/M_AlchemyParticle.M_AlchemyParticle"));
    BattlePortrait=LoadObject<UTexture2D>(nullptr,TEXT("/Game/Characters/RoseMage/T_RoseMagePortrait.T_RoseMagePortrait"));
    UIFont=NewObject<UFont>(this); UIFont->FontCacheType=EFontCacheType::Runtime;
    FTypefaceEntry Face; Face.Name=FName("Regular");
    Face.Font=FFontData(FPaths::EngineContentDir()/TEXT("Slate/Fonts/DroidSansFallback.ttf"),EFontHinting::Default,EFontLoadingPolicy::LazyLoad);
    UIFont->GetMutableInternalCompositeFont().DefaultTypeface.Fonts.Add(Face);
    auto PC=GetWorld()->GetFirstPlayerController();
    PC->bShowMouseCursor=true; PC->bEnableClickEvents=true; PC->bEnableMouseOverEvents=true;
    PC->SetInputMode(FInputModeGameAndUI().SetHideCursorDuringCapture(false));
    Camera=GetWorld()->SpawnActor<AAlchemyCamera>(); Camera->SetActorRotation(FRotator(-CameraPitch,90,0)); PC->SetViewTarget(Camera);
    if(!bGreyfordScene) {
    auto Sun=GetWorld()->SpawnActor<ADirectionalLight>(FVector::ZeroVector,FRotator(-52,-35,0));
    Sun->GetLightComponent()->SetIntensity(3.5f); Sun->GetLightComponent()->SetLightColor(FLinearColor(1.0f,0.84f,0.64f));
    auto Sky=GetWorld()->SpawnActor<ASkyLight>(); Sky->GetLightComponent()->SetIntensity(0.9f);
    Sky->GetLightComponent()->SetLightColor(FLinearColor(0.42f,0.62f,0.73f));
    }
    auto PP=GetWorld()->SpawnActor<APostProcessVolume>(); PP->bUnbound=true;
    PP->Settings.bOverride_VignetteIntensity=true; PP->Settings.VignetteIntensity=0.18f;
    PP->Settings.bOverride_BloomIntensity=true; PP->Settings.BloomIntensity=0.22f;
    if(bGreyfordFlow)Mats.Add(TEXT("BossMeadow"),LoadObject<UMaterialInterface>(nullptr,TEXT("/Game/ReferenceBattle/M_BossMeadow.M_BossMeadow")));
    BuildScene(false); UpdateCamera(1); Message(TEXT("欢迎来到烛苔村。WASD 移动，靠近设施按 F。"));
    auto WidgetClass=LoadClass<UBattleReferenceWidget>(nullptr,TEXT("/Game/UI/Reference/WBP_BattleReference.WBP_BattleReference_C"));
    BattleWidget=CreateWidget<UBattleReferenceWidget>(PC,WidgetClass?WidgetClass:UBattleReferenceWidget::StaticClass());
    if(BattleWidget){BattleWidget->InitializeForWorld(this);BattleWidget->AddToViewport(0);}
    UE_LOG(LogTemp,Display,TEXT("ALCHEMY_READY UE5.8 HD2D research; W0 initial=8; cap=300"));
    if(bGreyfordScene) {
        if(!bGreyfordFlow){Progress->TutorialComplete=true;StartRun();}
        else Message(TEXT("格雷弗德村庄 · WASD移动，靠近设施按F；前往村口雾门出发。"));
        if(FParse::Param(FCommandLine::Get(),TEXT("GreyfordCombatTest")))StartGreyfordReview();
    }
    const bool DefaultBattle=GetWorld()->GetMapName().Contains(TEXT("BattleReference"));
    if(DefaultBattle || FParse::Param(FCommandLine::Get(),TEXT("AlchemyStartCombat")) || FParse::Param(FCommandLine::Get(),TEXT("AlchemyCharacterSmoke")) || FParse::Param(FCommandLine::Get(),TEXT("AlchemyCharacterV3Smoke"))) StartRun();
    if(DefaultBattle)UE_LOG(LogTemp,Display,TEXT("DEFAULT_BATTLE_READY stage=%d combat=%d reference=%d"),GreyfordStage,bCombat,bBattleReference);
    if(FParse::Param(FCommandLine::Get(),TEXT("AlchemyBossPreview"))) {
        Progress->TutorialComplete=true;StartRun();RunTime=310;
        Inventory={6,6,6,1,1,1};Equipped={0,1,2,3};for(int S:Equipped) Levels[S]=2;
    }
    if(bGreyfordFlow && (FParse::Param(FCommandLine::Get(),TEXT("PlannedBossPreview")) || FParse::Param(FCommandLine::Get(),TEXT("PlannedBossCapture")))) {
        Progress->TutorialComplete=true;StartRun();GreyfordPortalReady=true;GreyfordPortalPos=PlayerPos;EnterGreyfordBoss();
        if(FParse::Param(FCommandLine::Get(),TEXT("PlannedBossCapture"))){Enemies[0].BossSequence=1;Enemies[0].BossAttack=1;for(float& CD:SkillCD)CD=10000;}
    }
    if(FParse::Param(FCommandLine::Get(),TEXT("AlchemyMerchantPreview"))) {
        Progress->TutorialComplete=true;StartRun();RunTime=80;NextMerchantTime=80;RunCoins=80;Inventory={3,4,2,1,0,0};
    }
}

UMaterialInterface* AAlchemyWorld::Material(const FString& Name) {
    if (auto P=Mats.Find(Name)) return *P;
    auto M=LoadObject<UMaterialInterface>(nullptr,*(TEXT("/Game/Art/")+Name+TEXT(".")+Name));
    Mats.Add(Name,M); return M;
}
AStaticMeshActor* AAlchemyWorld::Mesh(const FString& Shape,FVector Pos,FVector Scale,FLinearColor Tint,bool Solid) {
    auto A=GetWorld()->SpawnActor<AStaticMeshActor>(Pos,FRotator::ZeroRotator);
    A->SetMobility(EComponentMobility::Movable);
    // Every visible mesh is a 2D plane: terrain, props, characters and effects.
    A->GetStaticMeshComponent()->SetStaticMesh(LoadObject<UStaticMesh>(nullptr,TEXT("/Engine/BasicShapes/Plane.Plane")));
    A->SetActorScale3D(Scale); A->SetActorEnableCollision(false);
    A->GetStaticMeshComponent()->SetCastShadow(false);
    auto Base=Material(Shape==TEXT("Sphere") || Shape==TEXT("Cylinder")?TEXT("M_Disc"):TEXT("M_World"));
    if(bBattleReference && Shape==TEXT("Cylinder"))if(auto Disc=Mats.FindRef(TEXT("BattleReference_Disc")))Base=Disc;
    auto M=UMaterialInstanceDynamic::Create(Base,this);
    M->SetVectorParameterValue(TEXT("Tint"),Tint); A->GetStaticMeshComponent()->SetMaterial(0,M);
    if (Solid) Obstacles.Add({FVector2D(Pos),FVector2D(Scale.X*50,Scale.Y*50)});
    Scene.Add(A); return A;
}
AStaticMeshActor* AAlchemyWorld::Sprite(const FString& Name,FVector Pos,float Width,float Height) {
    auto A=Mesh(TEXT("Plane"),Pos,FVector(1),FLinearColor::White);
    A->GetStaticMeshComponent()->SetCastShadow(false);
    UpdateSprite(A,Name,Pos,Width,Height); return A;
}
AStaticMeshActor* AAlchemyWorld::Sheet(const FString& Name,FVector Pos,float Width,float Height) {
    auto A=Sprite(Name,Pos,Width,Height);
    A->GetStaticMeshComponent()->SetMaterial(0,Material(TEXT("M_")+Name+TEXT("_Lit")));
    A->GetStaticMeshComponent()->SetCastShadow(false);
    return A;
}
void AAlchemyWorld::UpdateSprite(AStaticMeshActor* Body,const FString& Name,FVector Pos,float Width,float Height,bool Flip,UMaterialInterface* OverrideMaterial) {
    Body->SetActorLocation(Pos+(bGreyfordFlow?Camera->GetActorUpVector()*(Height*.46f):FVector(0,0,Height*.46f)));
    const FVector Normal=bUprightSprites?FVector(0,-1,0):-Camera->GetActorForwardVector();
    Body->SetActorRotation(FRotationMatrix::MakeFromXZ(Camera->GetActorRightVector(),Normal).Rotator());
    Body->SetActorScale3D(FVector((Flip?-1:1)*Width/100,Height/100,1));
    auto Wanted=OverrideMaterial?OverrideMaterial:Material(TEXT("M_")+Name+(bLitSprites?TEXT("_Lit"):TEXT("")));
    if(Body->GetStaticMeshComponent()->GetMaterial(0)!=Wanted) Body->GetStaticMeshComponent()->SetMaterial(0,Wanted);
}
void AAlchemyWorld::Tree(FVector P,float Size,bool Solid) {
    auto Shadow=Mesh(TEXT("Sphere"),P+FVector(0,0,3),FVector(1.5f,0.8f,1)*Size,FLinearColor(0.055f,0.09f,0.075f));
    Shadow->GetStaticMeshComponent()->SetCastShadow(false);
    Sheet(FString::Printf(TEXT("Tree%d"),int(FMath::Abs(P.X+P.Y))%3),P,320*Size,480*Size);
    if(Solid) Obstacles.Add({FVector2D(P),FVector2D(34*Size)});
}
void AAlchemyWorld::House(FVector P,FLinearColor Roof) {
    auto Shadow=Mesh(TEXT("Sphere"),P+FVector(0,0,3),FVector(5.5f,2.5f,1),FLinearColor(0.06f,0.09f,0.075f));
    Shadow->GetStaticMeshComponent()->SetCastShadow(false);
    Sheet(P.X<0?TEXT("House0"):TEXT("House1"),P,650,600);
    Obstacles.Add({FVector2D(P),FVector2D(230,100)});
}

void AAlchemyWorld::BuildScene(bool Combat) {
    ClearBattleReferenceScene();
    ClearPixelFX();
    CloseMerchant();
    EndBossArena();
    for(auto& FX:NiagaraFX) if(IsValid(FX.Component)) FX.Component->DestroyComponent();
    NiagaraFX.Empty();DamageNumbers.Empty();
    for(auto A:Scene) if(IsValid(A)) A->Destroy();
    Scene.Empty(); Obstacles.Empty(); Enemies.Empty(); Shots.Empty(); Drops.Empty(); Effects.Empty();
    bCombat=Combat; bRunEnded=false; PlayerPos=Combat?FVector::ZeroVector:FVector(0,-200,0); Panel.Empty();
    const bool Authored=Designer && Designer->bUseInGame;
    if(Designer) Designer->SetRuntimeVisible(bGreyfordScene || (Combat && Authored));
    const float X=Combat?(Authored?(CombatHalfSize.X+51)*2:14222):4800, Y=Combat?(Authored?(CombatHalfSize.Y+50)*2:10760):3800;
    if(bGreyfordScene) BuildGreyfordScene();
    else {
    auto Floor=Mesh(TEXT("Cube"),FVector(0,0,0),FVector(X/100,Y/100,1),FLinearColor::White);
    Floor->GetStaticMeshComponent()->SetMaterial(0,Material(TEXT("M_Grass")));
    if(!Combat || !Authored) {
    auto Road=Mesh(TEXT("Cube"),FVector(0,0,1),FVector(Combat?9:25,Y/100,0.02f),FLinearColor::White);
    Road->GetStaticMeshComponent()->SetMaterial(0,Material(TEXT("M_Dirt")));
    auto Across=Mesh(TEXT("Cube"),FVector(0,Combat?800:100,2),FVector(X/100,4,0.02f),FLinearColor::White);
    Across->GetStaticMeshComponent()->SetMaterial(0,Material(TEXT("M_Dirt")));
    FRandomStream Decor(108);
    for(int i=0;i<(Combat?240:60);i++) {
        FVector P(Decor.FRandRange(-X*0.48f,X*0.48f),Decor.FRandRange(-Y*0.48f,Y*0.48f),0);
        if(FMath::Abs(P.X)<550 || (!Combat && P.Y>-700 && P.Y<900)) continue;
        // Combat trees are perimeter decoration only: the eight layout rectangles own collision.
        if(Combat && FMath::Abs(P.X)<6500 && FMath::Abs(P.Y)<4800) continue;
        Tree(P,Decor.FRandRange(0.65f,1.2f),!Combat);
    }
    for(int i=0;i<(Combat?250:100);i++) {
        FVector P(Decor.FRandRange(-X*0.48f,X*0.48f),Decor.FRandRange(-Y*0.48f,Y*0.48f),10);
        if(FMath::Abs(P.X)<500) continue;
        Sheet(TEXT("Rock"),P,Decor.FRandRange(35.f,70.f),50);
        
    }
    }
    if(!Combat) {
        House(FVector(-1150,650,0),FLinearColor(0.2f,0.29f,0.28f));
        House(FVector(1100,700,0),FLinearColor(0.3f,0.16f,0.12f));
        House(FVector(-1450,-550,0),FLinearColor(0.26f,0.21f,0.16f));
        // Three walk-up facilities: upgrade cauldron, recipe lectern, battle portal.
        Sheet(TEXT("Cauldron"),FVector(-600,100,0),180,240);
        Sheet(TEXT("Lectern"),FVector(600,100,0),180,240);
        Sheet(TEXT("Portal"),FVector(0,1050,0),420,560);
        Obstacles.Add({FVector2D(-600,100),FVector2D(60,40)});
        Obstacles.Add({FVector2D(600,100),FVector2D(60,40)});
        Ring(FVector(0,1050,0),130,Teal,100000);
        for(FVector P:{FVector(-600,100,170),FVector(600,100,200),FVector(0,1050,200)}) {
            auto L=GetWorld()->SpawnActor<APointLight>(P,FRotator::ZeroRotator);
            L->PointLightComponent->SetIntensity(1800); L->PointLightComponent->SetAttenuationRadius(500); L->PointLightComponent->SetLightColor(Teal); Scene.Add(L);
        }
    } else if(Authored) {
        for(TActorIterator<AAlchemyTileCell> It(GetWorld());It;++It) if(It->GetOwner()==Designer && It->bBlocksMovement) Obstacles.Add({FVector2D(It->GetActorLocation()),It->WorldHalfSize()});
        UE_LOG(LogTemp,Display,TEXT("ALCHEMY_AUTHORED_LAYOUT obstacles=%d seed=%d"),Obstacles.Num(),Designer->Seed);
    } else {
        auto Clearing=Mesh(TEXT("Cube"),FVector(0,0,3),FVector(48,32,1),FLinearColor(0.14f,0.23f,0.19f));
        Clearing->GetStaticMeshComponent()->SetCastShadow(false);
        for(const auto& R:LayoutRects) {
            const FVector P=DesignPosition(R.X+R.Z/2,R.Y+R.W/2);
            auto Block=Mesh(TEXT("Cube"),P+FVector(0,0,5),FVector(R.Z,R.W,1),FLinearColor(0.28f,0.36f,0.34f),true);
            Block->GetStaticMeshComponent()->SetCastShadow(false);
        }
        UE_LOG(LogTemp,Display,TEXT("ALCHEMY_LAYOUT_A obstacles=%d spawn=(0,0) design_to_world=(-100x,-100y)"),Obstacles.Num());
    }
    // A row of painted rock sheets communicates the map boundary.
    for(int Side:{-1,1}) {
        for(float YPos=-Y/2;YPos<=Y/2;YPos+=220) Sheet(TEXT("Rock"),FVector(Side*(X/2-40),YPos,0),260,180);
        for(float XPos=-X/2;XPos<=X/2;XPos+=220) Sheet(TEXT("Rock"),FVector(XPos,Side*(Y/2-40),0),260,180);
    }
    }
    PlayerShadow=Mesh(TEXT("Sphere"),PlayerPos+FVector(0,0,5),FVector(0.85f,0.5f,0.04f),FLinearColor(0.015f,0.028f,0.025f));
    PlayerShadow->GetStaticMeshComponent()->SetMaterial(0,Material(TEXT("M_SoftShadow")));
    Player=Sprite(TEXT("Hero0_0"),PlayerPos,120,160);
    const bool LegacyCharacter=FParse::Param(FCommandLine::Get(),TEXT("AlchemyCharacterSmoke")) || FParse::Param(FCommandLine::Get(),TEXT("AlchemyCharacterV3Smoke"));
    const bool CharacterReady=LegacyCharacter?CharacterAnimation.Initialize(this,Player->GetStaticMeshComponent()):CharacterAnimation.InitializeRoseMage(this,Player->GetStaticMeshComponent());
    ensureMsgf(CharacterReady,TEXT("Missing imported alchemist character assets"));
    UpdateCharacterVisual(0,false);
}

bool AAlchemyWorld::Walkable(FVector P,float Radius) const {
    if(bGreyfordReference || bBattleReference)return ReferenceWalkable(P,Radius);
    const float X=(bCombat || bGreyfordFlow)?CombatHalfSize.X:2350,Y=(bCombat || bGreyfordFlow)?CombatHalfSize.Y:1850;
    if(FMath::Abs(P.X)>X-Radius || FMath::Abs(P.Y)>Y-Radius) return false;
    if(bGreyfordFlow && GreyfordStage==2 && FMath::Square(P.X/(1600-Radius))+FMath::Square(P.Y/(1300-Radius))>1) return false;
    if(bBossArenaActive && !(bGreyfordFlow && GreyfordStage==2) && FVector::DistSquared2D(P,BossArenaCenter)>FMath::Square(FMath::Max(0.f,BossArenaRadius-Radius))) return false;
    for(const auto& O:Obstacles) if(FMath::Abs(P.X-O.Center.X)<O.Half.X+Radius && FMath::Abs(P.Y-O.Center.Y)<O.Half.Y+Radius) return false;
    return true;
}
FVector AAlchemyWorld::Move(FVector P,FVector Delta,float Radius) const {
    // Substeps keep dash movement from tunnelling through narrow scene obstacles.
    int Steps=FMath::Max(1,FMath::CeilToInt(Delta.Size()/25)); Delta/=Steps;
    for(int i=0;i<Steps;i++) {
        const auto Clear=[&](FVector End){return (bGreyfordReference || bBattleReference)?ReferenceSweep(P,End,Radius):Walkable(End,Radius);};
        if((bGreyfordReference || bBattleReference) && Clear(P+Delta)){P+=Delta;continue;}
        if(Clear(P+FVector(Delta.X,0,0))) P.X+=Delta.X;
        if(Clear(P+FVector(0,Delta.Y,0))) P.Y+=Delta.Y;
    }
    if(bGreyfordFlow)P.Z=GreyfordSurfaceHeight(P);
    return P;
}
bool AAlchemyWorld::SegmentClear(FVector A,FVector B,float Radius) const {
    if(!Walkable(A,Radius) || !Walkable(B,Radius)) return false;
    if(bGreyfordReference || bBattleReference)return ReferenceSweep(A,B,Radius);
    for(const auto& O:Obstacles) {
        float Near=0,Far=1;
        bool Hit=true;
        for(int Axis=0;Axis<2;Axis++) {
            const float Start=Axis==0?A.X:A.Y, D=(Axis==0?B.X:B.Y)-Start;
            const float C=Axis==0?O.Center.X:O.Center.Y,H=(Axis==0?O.Half.X:O.Half.Y)+Radius;
            if(FMath::Abs(D)<KINDA_SMALL_NUMBER) {if(Start<=C-H || Start>=C+H) {Hit=false;break;}}
            else {
                float T0=(C-H-Start)/D,T1=(C+H-Start)/D;
                if(T0>T1) Swap(T0,T1);
                Near=FMath::Max(Near,T0); Far=FMath::Min(Far,T1);
                if(Near>Far) {Hit=false;break;}
            }
        }
        if(Hit) return false;
    }
    return true;
}
bool AAlchemyWorld::FindPath(FVector From,FVector To,float Radius,TArray<FVector>& Path) const {
    Path.Empty();
    if(!Walkable(From,Radius) || !Walkable(To,Radius)) return false;
    if(SegmentClear(From,To,Radius)) {Path.Add(To);return true;}
    TArray<FVector> Nodes={From,To};
    if(bGreyfordReference || bBattleReference)for(auto P:ReferenceNodes)if(Walkable(P,Radius))Nodes.Add(P);
    for(const auto& O:Obstacles) for(int X:{-1,1}) for(int Y:{-1,1}) {
        FVector P(O.Center.X+X*(O.Half.X+Radius+20),O.Center.Y+Y*(O.Half.Y+Radius+20),0);
        if(Walkable(P,Radius)) Nodes.Add(P);
    }
    // Small authored visibility graph; recompute only on obstruction and a one-second timer.
    TArray<float> Cost; Cost.Init(TNumericLimits<float>::Max(),Nodes.Num()); Cost[0]=0;
    TArray<int32> Prev; Prev.Init(INDEX_NONE,Nodes.Num());
    TArray<bool> Done; Done.Init(false,Nodes.Num());
    for(int Step=0;Step<Nodes.Num();Step++) {
        int U=INDEX_NONE;
        for(int I=0;I<Nodes.Num();I++) if(!Done[I] && Cost[I]<TNumericLimits<float>::Max() && (U==INDEX_NONE || Cost[I]<Cost[U])) U=I;
        if(U==INDEX_NONE) break;
        if(U==1) {for(int I=1;I!=0;I=Prev[I]) Path.Insert(Nodes[I],0);return true;}
        Done[U]=true;
        for(int V=1;V<Nodes.Num();V++) if(!Done[V]) {
            const float C=Cost[U]+FVector::Dist2D(Nodes[U],Nodes[V]);
            if(C<Cost[V] && SegmentClear(Nodes[U],Nodes[V],Radius)) {Cost[V]=C;Prev[V]=U;}
        }
    }
    return false;
}
void AAlchemyWorld::Chase(FAlchemyEnemy& E,float Dt) {
    const float Radius=EnemyRadius(E);
    E.RepathCD-=Dt;
    FVector Goal=PlayerPos;
    // A player may fit closer to an obstacle than a larger enemy. Approach a legal nearby point.
    if(!Walkable(Goal,Radius)) {
        float Best=TNumericLimits<float>::Max(); bool Found=false;
        for(float R:{150.f,250.f,400.f}) {
            for(int I=0;I<16;I++) {
                const float A=I*2*PI/16;
                const FVector P=PlayerPos+FVector(FMath::Cos(A)*R,FMath::Sin(A)*R,0);
                const float D=FVector::DistSquared2D(P,E.Pos);
                if(Walkable(P,Radius) && D<Best) {Goal=P;Best=D;Found=true;}
            }
            if(Found) break;
        }
        if(!Found) return;
    }
    FVector Target=Goal;
    if(SegmentClear(E.Pos,Goal,Radius)) E.Path.Empty();
    else {
        if(E.RepathCD<=0) {FindPath(E.Pos,Goal,Radius,E.Path);E.RepathCD=1.f;}
        while(!E.Path.IsEmpty() && FVector::Dist2D(E.Pos,E.Path[0])<25) E.Path.RemoveAt(0);
        if(E.Path.IsEmpty()) return;
        Target=E.Path[0];
    }
    const FVector To=Target-E.Pos;
    const float Step=FMath::Min(To.Size2D(),E.Speed*(E.Slow>0?E.SlowFactor:1)*Dt);
    E.Pos=Move(E.Pos,To.GetSafeNormal2D()*Step,Radius);
}
void AAlchemyWorld::UpdateCamera(float Delta) {
    auto C=Camera->GetCameraComponent();
    if(bBattleReference || bReferenceBossScene){UpdateBattleReferenceCamera(Delta);return;}
    CastChecked<UAlchemyCameraComponent>(C)->ProjectionOffset=FVector2D::ZeroVector;
    if(bGreyfordReference && bPerspective){
        CameraPitch=60;CameraFOV=50;C->ProjectionMode=ECameraProjectionMode::Perspective;C->SetFieldOfView(CameraFOV);C->bConstrainAspectRatio=false;
        C->bOverrideAspectRatioAxisConstraint=true;C->SetAspectRatioAxisConstraint(EAspectRatioAxisConstraint::AspectRatio_MaintainXFOV);
        C->PostProcessSettings.bOverride_VignetteIntensity=true;C->PostProcessSettings.VignetteIntensity=0;
        C->PostProcessSettings.bOverride_ToneCurveAmount=true;C->PostProcessSettings.ToneCurveAmount=0;
        C->PostProcessSettings.bOverride_AutoExposureBias=true;C->PostProcessSettings.AutoExposureBias=0;
        C->PostProcessSettings.bOverride_AutoExposureMinBrightness=true;C->PostProcessSettings.AutoExposureMinBrightness=1;
        C->PostProcessSettings.bOverride_AutoExposureMaxBrightness=true;C->PostProcessSettings.AutoExposureMaxBrightness=1;
        C->PostProcessSettings.bOverride_ExpandGamut=true;C->PostProcessSettings.ExpandGamut=0;
        C->PostProcessSettings.bOverride_BloomIntensity=true;C->PostProcessSettings.BloomIntensity=0;
        C->PostProcessSettings.bOverride_DepthOfFieldFstop=true;C->PostProcessSettings.DepthOfFieldFstop=32;
        Camera->SetActorRotation(FRotator(-60,90,0));
        const double FullW=1672*180./52,FullH=941*180./52,Sin=FMath::Sin(FMath::DegreesToRadians(48.));
        int VX=1280,VY=720;GetWorld()->GetFirstPlayerController()->GetViewportSize(VX,VY);
        const double Aspect=VX>0 && VY>0?double(VX)/VY:16./9;
        C->SetAspectRatio(float(Aspect));
        const double Tangent=FMath::Tan(FMath::DegreesToRadians(CameraFOV*.5));
        ViewWidth=float(FMath::Min(FullW/FMath::Max(1.f,ReferenceZoom)*Aspect/(16./9),FullH*Aspect));
        const double BX=(FullW-ViewWidth)*.5,BY=(FullH-ViewWidth/Aspect)/(2*Sin);
        FVector Goal=PlayerPos+FVector(0,100,0);Goal.Z=0;
        Goal.X=FMath::Clamp(Goal.X,-BX,BX);Goal.Y=FMath::Clamp(Goal.Y,-BY,BY);
        if(!ReferenceCameraReady || Delta<=0){ReferenceCameraFocus=Goal;ReferenceCameraReady=true;}
        else {
            FVector Desired=ReferenceCameraFocus;
            for(int Axis=0;Axis<2;Axis++){const double D=Goal[Axis]-Desired[Axis];Desired[Axis]+=FMath::Sign(D)*FMath::Max(0.,FMath::Abs(D)-30);}
            ReferenceCameraFocus=FMath::Lerp(ReferenceCameraFocus,Desired,1-FMath::Exp(-10*Delta));
        }
        ReferenceCameraFocus.X=FMath::Clamp(ReferenceCameraFocus.X,-BX,BX);ReferenceCameraFocus.Y=FMath::Clamp(ReferenceCameraFocus.Y,-BY,BY);
        Camera->SetActorLocation(ReferenceCameraFocus-Camera->GetActorForwardVector()*(ViewWidth/(2*Tangent)));
        UpdateVillagePerspectiveCards(true);return;
    }
    C->SetAutoCalculateOrthoPlanes(!bGreyfordReference);
    C->PostProcessSettings.bOverride_AutoExposureBias=bGreyfordReference;C->PostProcessSettings.AutoExposureBias=0;
    C->PostProcessSettings.bOverride_VignetteIntensity=true;C->PostProcessSettings.VignetteIntensity=bGreyfordReference?0:.18f;
    C->PostProcessSettings.bOverride_BloomIntensity=true;C->PostProcessSettings.BloomIntensity=bGreyfordReference?0:.22f;
    C->PostProcessSettings.bOverride_ToneCurveAmount=true;C->PostProcessSettings.ToneCurveAmount=bGreyfordReference?0:1;
    if(bGreyfordReference){
        UpdateVillagePerspectiveCards(false);
        C->SetUpdateOrthoPlanes(false);C->SetOrthoNearClipPlane(0);C->SetOrthoFarClipPlane(50000);
        CameraPitch=48;
        int VX=1280,VY=720;GetWorld()->GetFirstPlayerController()->GetViewportSize(VX,VY);
        const float Aspect=VX>0 && VY>0?float(VX)/VY:16.f/9;
        const bool Overview=FParse::Param(FCommandLine::Get(),TEXT("GreyfordReferenceOverview"));
        const float FullWidth=1672*180.f/52,FullHeight=941*180.f/52,Sin=FMath::Sin(FMath::DegreesToRadians(48.f));
        ViewWidth=FMath::Min(FullWidth/(Overview?1:FMath::Max(1.f,ReferenceZoom)),FullHeight*Aspect);
        C->ProjectionMode=ECameraProjectionMode::Orthographic;C->SetOrthoWidth(ViewWidth);
        C->bConstrainAspectRatio=false;C->SetAspectRatio(Aspect);
        C->bOverrideAspectRatioAxisConstraint=true;C->SetAspectRatioAxisConstraint(EAspectRatioAxisConstraint::AspectRatio_MaintainXFOV);
        const float BX=FMath::Max(0.f,(FullWidth-ViewWidth)/2),BY=FMath::Max(0.f,(FullHeight-ViewWidth/Aspect)/(2*Sin));
        FVector Goal=Overview?FVector::ZeroVector:PlayerPos+FVector(0,100,0);Goal.Z=0;
        Goal.X=FMath::Clamp(Goal.X,-BX,BX);Goal.Y=FMath::Clamp(Goal.Y,-BY,BY);
        if(!ReferenceCameraReady || Delta<=0){ReferenceCameraFocus=Goal;ReferenceCameraReady=true;}
        else {
            FVector Desired=ReferenceCameraFocus;
            for(int Axis=0;Axis<2;Axis++){const float D=Goal[Axis]-Desired[Axis];Desired[Axis]+=FMath::Sign(D)*FMath::Max(0.f,FMath::Abs(D)-30.f);}
            ReferenceCameraFocus=FMath::Lerp(ReferenceCameraFocus,Desired,1-FMath::Exp(-10*Delta));
        }
        ReferenceCameraFocus.X=FMath::Clamp(ReferenceCameraFocus.X,-BX,BX);ReferenceCameraFocus.Y=FMath::Clamp(ReferenceCameraFocus.Y,-BY,BY);
        Camera->SetActorRotation(FRotator(-48,90,0));Camera->SetActorLocation(ReferenceCameraFocus-Camera->GetActorForwardVector()*9000);return;
    }
    C->ProjectionMode=bPerspective?ECameraProjectionMode::Perspective:ECameraProjectionMode::Orthographic;
    C->SetOrthoWidth(bBossArenaActive?FMath::Max(ViewWidth,3600.f):ViewWidth); C->SetFieldOfView(CameraFOV); C->bConstrainAspectRatio=false;
    C->PostProcessSettings.bOverride_DepthOfFieldFocalDistance=true;
    C->PostProcessSettings.DepthOfFieldFocalDistance=ViewWidth/2/FMath::Tan(FMath::DegreesToRadians(CameraFOV*.5f));
    C->PostProcessSettings.bOverride_DepthOfFieldFstop=true; C->PostProcessSettings.DepthOfFieldFstop=bDepthOfField?1.8f:32;
    Camera->SetActorRotation(FRotator(-CameraPitch,90,0));
    int VX=1280,VY=720; GetWorld()->GetFirstPlayerController()->GetViewportSize(VX,VY);
    const float Aspect=VY>0?float(VX)/VY:16.f/9;
    if(bGreyfordScene) {
        C->bOverrideAspectRatioAxisConstraint=true;
        C->SetAspectRatioAxisConstraint(EAspectRatioAxisConstraint::AspectRatio_MaintainXFOV);
        C->SetAspectRatio(Aspect);
    }
    const float HalfHeight=ViewWidth/(2*Aspect*FMath::Sin(FMath::DegreesToRadians(CameraPitch)));
    const float BoundX=bGreyfordFlow?(GreyfordStage==2?1600:7111):bCombat?7111:2400;
    const float BoundY=bGreyfordFlow?(GreyfordStage==2?1300:5380):bCombat?5380:1900;
    FVector Target=bBossArenaActive?BossArenaCenter:PlayerPos;
    Target.X=FMath::Clamp(Target.X,-FMath::Max(0.f,BoundX-ViewWidth/2),FMath::Max(0.f,BoundX-ViewWidth/2));
    Target.Y=FMath::Clamp(Target.Y,-FMath::Max(0.f,BoundY-HalfHeight),FMath::Max(0.f,BoundY-HalfHeight));
    const float Distance=ViewWidth/2/FMath::Tan(FMath::DegreesToRadians(CameraFOV*.5f));
    Camera->SetActorLocation(Target-Camera->GetActorForwardVector()*Distance);
}
void AAlchemyWorld::Ring(FVector P,float Radius,FLinearColor Color,float Duration) {
    // Enemy windup colors stay as readable ground telegraphs, independent of decorative Niagara.
    if(bCombat && Duration<1 && !(Color.R>.35f && Color.G<.2f) && BlastFX && !bSmoke) {
        SpawnVFX(Radius>100?BlastFX:ImpactFX,P+FVector(0,0,35),Color,FMath::Clamp(Radius/180,.25f,1.6f),1.25f);return;
    }
    auto A=Mesh(TEXT("Cylinder"),P+FVector(0,0,bBattleReference?-6:4),FVector(Radius/50,Radius/50,0.015f),Color);
    A->GetStaticMeshComponent()->SetCastShadow(false); Effects.Add({A,Duration,Duration,Radius});
}
void AAlchemyWorld::Message(FString Value) { Toast=Value; ToastTime=4; }
bool AAlchemyWorld::SaveProgress() {
    if(bSmoke || bCapture) return true;
    bool OK=UGameplayStatics::SaveGameToSlot(Progress,bGreyfordFlow?TEXT("GreyfordDemo_v1"):TEXT("AlchemyResearch_v1"),0);
    if(!OK) Message(TEXT("保存失败，进度仍在内存中。请重试。"));
    return OK;
}
void AAlchemyWorld::MigrateProgress(bool Played) {
    if(Progress->SchemaVersion>=3) return;
    // v2 -> v3: 4 talents -> 10 independent upgrades; fold one-shot flags into Talents[8]/[9].
    if(Progress->SchemaVersion<2) {
        Progress->TutorialComplete=Played; Progress->Combinations.Empty(); Progress->ChainsV2.Empty();
    }
    TArray<int32> Old=Progress->Talents;
    Progress->Talents.Init(0,TalentNodeCount);
    if(Old.IsValidIndex(0)) Progress->Talents[0]=Old[0]; // 生命
    if(Old.IsValidIndex(1)) Progress->Talents[1]=Old[1]; // 攻击/伤害
    if(Old.IsValidIndex(2)) Progress->Talents[2]=Old[2]; // 移动
    // Old[3] (吸引范围) is intentionally dropped per system UI V0.2.
    if(Progress->RefreshUnlocked) Progress->Talents[8]=1;
    if(Progress->DropRateUnlocked) Progress->Talents[9]=1;
    Progress->RefreshUnlocked=Progress->DropRateUnlocked=false;
    Progress->SchemaVersion=3;
}
bool AAlchemyWorld::TutorialActive() const {return bCombat && !Progress->TutorialComplete && (!bGreyfordFlow || GreyfordStage==1);}
void AAlchemyWorld::TutorialSupply(FVector Position) {
    if(!TutorialActive() || TutorialSkill>=0 || bTutorialSupplyDone || RunTime<35) return;
    for(int M=0;M<3;M++) {
        bool Available=Inventory[M]>0;
        TArray<FVector> Path;
        for(const auto& D:Drops) if(D.Kind==M && D.Count>0 && FindPath(PlayerPos,D.Pos,45,Path)) Available=true;
        if(!Available) {Drop(FindPath(PlayerPos,Position,45,Path)?Position:PlayerPos,M);return;}
    }
    bTutorialSupplyDone=true;
}
void AAlchemyWorld::TutorialHit(int32 Skill,int32 Hits) {
    if(TutorialActive() && Skill==TutorialSkill && Hits>=2) {
        Progress->TutorialComplete=true;SaveProgress();
        Message(TEXT("首次教学完成！自由投料已开放，可尝试更多材料组合。"));
    }
}
void AAlchemyWorld::AddMaterial(int32 I) {
    if(!bCombat || !Selected.IsValidIndex(I)) return;
    // 系统 UI V0.2：精英专属材料（I>=3）不可投入炼金锅。
    if(I>=3) { Message(TEXT("该材料暂未开放，不可投入。")); return; }
    int Total=0;for(int V:Selected) Total+=V;
    if(Total>=10 || Selected[I]>=Inventory[I]) return;
    if(TutorialActive() && (TutorialSkill>=0 || I>=3 || Selected[I]>=1)) {
        Message(TutorialSkill>=0?TEXT("先关闭界面，让新技能一次命中至少2个敌人。"):TEXT("首次教学：三种普通材料各投入1个。"));return;
    }
    Selected[I]++;
}
void AAlchemyWorld::StartRun() {
    ResetMerchant();
    RunTime=0; Kills=0; RunCoins=0; CraftCount=0; ChainCount=0; bBossSpawned=false;
    Inventory={0,0,0,0,0,0}; Selected=Inventory; Levels.Init(0,NumSkills());Levels[0]=1; Equipped={0}; Bag.Empty();
    TutorialSkill=-1;bTutorialSupplyDone=false;TutorialEncounterPending=false;TutorialEncounterRetry=0;
    // RESULT-001/EXP-001 run-local state resets.
    PendingResultSkill=-1; PendingResultCombination=-1; PendingResultTotal=0; PendingIsNuclear=false; PendingRefreshed=false;
    RunLevel=1; RunXP=0; PendingLevelUps=0;LevelupChoices[0]=LevelupChoices[1]=LevelupChoices[2]=-1;for(int A=0;A<7;A++) RunAttrs[A]=0;
    // 开局高级材料 removed per system UI V0.2 (not among the 10 upgrades).
    MaxHP=(bTune001B?120:100)+Progress->Talents[0]*10; HP=MaxHP;
    DodgeCD=DodgeTime=HurtInv=DodgeInv=0; SpawnCD=2.6f; NextElite=90; EliteIndex=0;
    for(float& T:SkillCD) T=0;
    for(int C=0;C<NumChains();C++) ChainCD[C]=ChainConfig(C).CD;
    BuildScene(true);
    GreyfordPortalReady=false;GreyfordPortal=nullptr;GreyfordPortalRetry=300;
    UpdateCamera(0);
    for(int i=0;i<8;i++) SpawnEnemy(Random.FRand()<0.7f?0:1);
    Message(bGreyfordScene?TEXT("村庄外围试玩 · WASD移动 / 空格闪避 / Q炼金 / R重新开始"):TEXT("腐化林地 · 技能自动释放；Q 打开炼金台。"));
}
void AAlchemyWorld::EndRun(bool Won) {
    if(bRunEnded) return;
    CloseMerchant();
    EndBossArena();PendingLevelUps=0;
    bRunEnded=true; bWon=Won;
    if(Won) Progress->Monsters.AddUnique(10); // Discover the defeated Boss; use this settlement save, without adding drops.
    // EXP-001/PAUSE-001: clear run-local xp/attributes and pending results on run end.
    RunLevel=1; RunXP=0; for(int A=0;A<7;A++) RunAttrs[A]=0;
    PendingResultSkill=-1; PendingIsNuclear=false; StartMaterialChoice=-1;
    const int Old=Progress->Coins; Progress->Coins+=RunCoins;
    if(!SaveProgress()) { Progress->Coins=Old; Panel=TEXT("savefailed"); return; }
    ResultCoins=RunCoins; RunCoins=0; Panel=Won?TEXT("victory"):TEXT("defeat");
    UE_LOG(LogTemp,Display,TEXT("ALCHEMY_RESULT won=%d time=%.2f kills=%d coins=%d crafts=%d chains=%d"),Won,RunTime,Kills,ResultCoins,CraftCount,ChainCount);
}
float AAlchemyWorld::ResultQualityWeight(int32 Total,int32 Quality,bool Nuclear) const {
    const int Row=FMath::Clamp(Total-3,0,7);
    if(!Nuclear)return QualityWeight(Row,Quality);
    return Quality==0?QualityWeight(Row,0)+(QualityWeight(Row,1)+QualityWeight(Row,2))*.5f:QualityWeight(Row,Quality)*.5f;
}
bool AAlchemyWorld::CraftOptions(TArray<int32>& Options,TArray<float>& WeightsOut,FString& Reason,int32& Combination,bool Nuclear) const {
    Options.Empty();WeightsOut.Empty();Reason.Empty();Combination=-1;
    if(!bCombat || bRunEnded) {Reason=TEXT("请在战斗中炼金");return false;}
    if(PendingResultSkill>=0 || PendingIsNuclear) {Reason=TEXT("请先接收本次炼金结果");return false;}
    int Total=0,Mask=0;bool Special=false;
    for(int I=0;I<6;I++) {
        if(Selected[I]<0 || Selected[I]>Inventory[I]) {Reason=TEXT("材料库存不足");return false;}
        Total+=Selected[I];if(I<3 && Selected[I]) Mask|=1<<I;if(I>=3 && Selected[I]) Special=true;
    }
    if(TutorialActive()) {
        if(TutorialSkill>=0) {Reason=TEXT("关闭界面，让新技能一次命中至少2个敌人");return false;}
        if(Special || Selected[0]!=1 || Selected[1]!=1 || Selected[2]!=1) {Reason=TEXT("首次教学：三种普通材料各投入1个");return false;}
    }
    if(Total<3 || Total>10) {Reason=TEXT("单次需要3–10个材料");return false;}
    if(Special) {
        for(int R=7;R<RuntimeRecipes.Num();R++) {const auto& K=RuntimeRecipes[R];bool Match=true;for(int I=0;I<6;I++) Match &= Selected[I]==K.Costs[I];if(Match) {Options.Add(K.LowSkill);WeightsOut.Add(100);}}
        if(Options.IsEmpty()) {Reason=TEXT("精英材料使用专属固定配方");return false;}

    } else {
        for(int C=0;C<7;C++) if(Mask==RuntimeRecipes[C].Mask) Combination=C;
        if(Combination<0) {Reason=TEXT("请选择有效材料组合");return false;}
        for(int Q=0;Q<3;Q++) {Options.Add(CombinationSkill(Combination,Q));WeightsOut.Add(ResultQualityWeight(Total,Q,Nuclear));}
    }
    bool Excluded=false;
    for(int I=Options.Num()-1;I>=0;I--) {
        int S=Options[I];
        if(WeightsOut[I]<=0 || Levels[S]>=5 || (Levels[S]==0 && Equipped.Num()>=6 && Bag.Num()>=6)) {Options.RemoveAt(I);WeightsOut.RemoveAt(I);Excluded=true;}
    }
    if(Options.IsEmpty()) {Reason=TEXT("全部有效概率结果已满级或无存放空间，材料不消耗");return false;}
    float Sum=0;for(float W:WeightsOut) Sum+=W;for(float& W:WeightsOut) W=W*100/Sum;
    if(Excluded) Reason=TEXT("已排除满级/无法存放结果，显示本次实际概率");
    return true;
}
bool AAlchemyWorld::Craft() {
    TArray<int32> Options;TArray<float> WeightsOut;FString Reason;int Combination;
    if(!CraftOptions(Options,WeightsOut,Reason,Combination)) {Message(Reason);return false;}
    int Total=0;for(int i=0;i<6;i++) Total+=Selected[i];
    // ALCH-003: special (nuclear) proc only applies to normal-material free-pour alchemy (Combination>=0),
    // never to elite fixed recipes.
    const bool EligibleSpecial = Combination>=0 && !TutorialActive();
    // ALCH-003: nuclear clearing is additional; lower this craft's quality weights before filtering.
    const bool Special=EligibleSpecial && Random.FRand()*100 < SpecialProcChance[FMath::Clamp(Total-3,0,7)];
    if(Special && !CraftOptions(Options,WeightsOut,Reason,Combination,true)) {Message(Reason);return false;}
    // Deduct exactly once, after the final candidate set is known to be receivable.
    for(int i=0;i<6;i++) Inventory[i]-=Selected[i];
    Selected={0,0,0,0,0,0};
    float Roll=Random.FRand()*100;int Match=Options.Last();
    for(int I=0;I<Options.Num();I++) {Roll-=WeightsOut[I];if(Roll<0) {Match=Options[I];break;}}
    // RESULT-001: stage the result for the dedicated result page; do not equip yet.
    PendingResultSkill=Match; PendingResultCombination=Combination; PendingResultTotal=Total;
    PendingIsNuclear=Special; PendingRefreshed=false;
    CraftCount++;
    if(Special)TriggerNuclear();
    Panel=TEXT("result");
    return true;
}

void AAlchemyWorld::TriggerNuclear() {
    // ALCH-003: instantly kill every surviving normal enemy (types 0..6), one death event each.
    // Elites (7..9) and the final boss (10) are untouched. Kill, stat and drops all run normally.
    int Cleared=0;
    for(int i=Enemies.Num()-1;i>=0;i--) {
        if(Enemies[i].HP<=0 || Enemies[i].Type>=7) continue;
        auto E=Enemies[i]; E.Body->Destroy(); E.Shadow->Destroy(); Enemies.RemoveAtSwap(i); Kills++; Cleared++;
        SpawnVFX(ImpactFX,E.Pos+FVector(0,0,50),FLinearColor(.4f,.8f,.6f),.7f,1);
        TutorialSupply(E.Pos);
        // EXP-001: normal enemy always drops one XP orb (Kind -2).
        Drop(E.Pos,-2,E.Type);
        if(Random.FRand()<0.7f) Drop(E.Pos,-1);
        if(Random.FRand()<MaterialDropChance()) {float R=Random.FRand(); Drop(E.Pos,R<0.4f?0:R<0.75f?1:2);}
    }
    Message(FString::Printf(TEXT("核弹炼金！清除普通怪 ×%d"),Cleared));
}

void AAlchemyWorld::AcceptPendingResult() {
    if(PendingResultSkill<0) {Panel.Empty();return;}
    const int Match=PendingResultSkill;
    if(Levels[Match]==0) { if(Equipped.Num()<6) Equipped.Add(Match); else Bag.Add(Match); }
    Levels[Match]++;
    if(PendingResultCombination>=0) Progress->Combinations.AddUnique(PendingResultCombination);
    if(TutorialActive()) {TutorialSkill=Match;bTutorialSupplyDone=true;if(bGreyfordFlow && GreyfordStage==1)TutorialEncounterPending=true;}
    Progress->Recipes.AddUnique(Match); SaveProgress();
    Message(FString::Printf(TEXT("已接收：%s · Lv.%d"),SkillName(Match),Levels[Match]));
    PendingResultSkill=-1; PendingResultCombination=-1; PendingIsNuclear=false; Panel.Empty();
}

void AAlchemyWorld::RerollPendingResult() {
    // RESULT-001: same-combination reroll; extra nuclear reward does not replace the skill.
    if(PendingRefreshed || PendingResultSkill<0 || PendingResultCombination<0) return;
    if(Progress->Talents[8]<=0) { Message(TEXT("尚未解锁技能刷新")); return; }
    TArray<int32> Options;TArray<float> W;
    // Temporarily restore the staged total's weight row via combination + total.
    const int Total=PendingResultTotal, C=PendingResultCombination;
    if(Total<3 || Total>10 || C<0 || C>=7) return;
    for(int Q=0;Q<3;Q++) {
        int S=CombinationSkill(C,Q);
        if(S==PendingResultSkill) continue; // exclude the current staged result
        if(Levels[S]>=5 || (Levels[S]==0 && Equipped.Num()>=6 && Bag.Num()>=6)) continue;
        const float Weight=ResultQualityWeight(Total,Q,PendingIsNuclear);
        if(Weight>0){Options.Add(S);W.Add(Weight);}
    }
    if(Options.IsEmpty()) {Message(TEXT("没有其他可接收结果，无法刷新"));return;}
    float Sum=0;for(float x:W) Sum+=x;
    float Roll=Random.FRand()*Sum;int Match=Options.Last();
    for(int I=0;I<Options.Num();I++) {Roll-=W[I];if(Roll<0){Match=Options[I];break;}}
    PendingResultSkill=Match; PendingRefreshed=true;
    Message(TEXT("已刷新技能结果"));
}

int32 AAlchemyWorld::RequiredXP(int32 Level) const {
    // 系统 UI V0.2 §7.2：升级门槛表（Lv.1→2 到 Lv.9→10）。
    static const int32 Thresholds[9]={20,30,45,65,90,120,155,195,240};
    if(Level<1) return Thresholds[0];
    if(Level>9) return Thresholds[8];
    return Thresholds[Level-1];
}

void AAlchemyWorld::GrantXP(float Amount) {
    RunXP += Amount * (1.f + 0.10f * RunAttrs[5]);
    while(RunXP >= RequiredXP(RunLevel)) {
        RunXP -= RequiredXP(RunLevel);
        RunLevel++;PendingLevelUps++;
    }
    if(Panel!=TEXT("levelup")) RollLevelupChoices();
}
void AAlchemyWorld::RollLevelupChoices() {
    if(PendingLevelUps<=0) return;
    if(PendingResultSkill>=0 || PendingIsNuclear){Panel=TEXT("result");return;}
    if(LevelupChoices[0]>=0) {Panel=TEXT("levelup");return;} // Reopening a modal keeps the offered choices.
    // 系统 UI V0.2 §7.3：生命+20(5) 伤害+10%(5) 移速+5%(5) 范围+10%(5) 减伤+5pp(6) 经验+10%(5) 回复+1/s(5)
    static const int32 MaxLayers[7]={5,5,5,5,6,5,5};
    TArray<int32> Pool;
    for(int A=0;A<7;A++) if(RunAttrs[A]<MaxLayers[A]) Pool.Add(A);
    if(Pool.IsEmpty()) {PendingLevelUps=0;return;}
    LevelupChoices[0]=LevelupChoices[1]=LevelupChoices[2]=-1;
    for(int I=0;I<3 && !Pool.IsEmpty();I++) {
        const int Pick=Pool[Random.RandRange(0,Pool.Num()-1)];LevelupChoices[I]=Pick;Pool.Remove(Pick);
    }
    Panel=TEXT("levelup");
}

void AAlchemyWorld::ApplyRunAttr(int32 AttrIndex) {
    if(AttrIndex<0 || AttrIndex>=7) return;
    RunAttrs[AttrIndex]++;
    if(AttrIndex==0) { MaxHP += 20; HP = FMath::Min(HP+20, MaxHP); }
}

bool AAlchemyWorld::TalentNodeUnlocked(int32 Node) const {
    // System UI V0.2: all upgrades are independently open, no prerequisite chain.
    return Node>=0 && Node<TalentNodeCount;
}
bool AAlchemyWorld::TalentNodeDone(int32 Node) const {
    if(Node<0 || Node>=TalentNodeCount) return false;
    return Progress->Talents[Node] >= TalentMaxLevel[Node];
}
void AAlchemyWorld::BuyTalentNode(int32 Node) {
    if(Node<0 || Node>=TalentNodeCount || TalentNodeDone(Node)) return;
    const int32 L=Progress->Talents[Node];
    if(L<0 || L>=TalentMaxLevel[Node]) return;
    const int32 Cost=TalentCosts[Node][L];
    if(Progress->Coins<Cost) { Message(TEXT("货币不足")); return; }
    Progress->Coins-=Cost;
    Progress->Talents[Node]++;
    if(!SaveProgress()) { Progress->Coins+=Cost; Progress->Talents[Node]--; }
}

FString AAlchemyWorld::ChainHintFor(int32 Skill) const {
    // RESULT-001/CODEX-001: show full chain info only for discovered chains; otherwise a vague clue.
    for(int C=0;C<NumChains();C++) {
        const auto& K=ChainConfig(C);
        if(K.A!=Skill && K.B!=Skill) continue;
        int Other=K.A==Skill?K.B:K.A;
        if(Progress->ChainsV2.Contains(C)) {
            return FString::Printf(TEXT("连锁：%s（与 %s 同时装备触发，冷却%.0f秒）"),*K.Name,SkillName(Other),K.CD);
        }
        // Vague clue by element of the partner skill is not available without full data; use a generic hint.
        return TEXT("该技能可能与另一类技能产生共鸣，等待实战发现。");
    }
    return TEXT("当前尚无专属连锁。");
}

float AAlchemyWorld::MaterialDropChance() const {
    // DROP-001 baseline (22% x 70% = 15.4% by default), then 材料掉落提高 (Talents[9]) x1.30.
    float Chance = bDrop001 ? 0.154f : 0.22f;
    if(Progress->Talents[9]>0) Chance *= 1.30f;
    return Chance;
}

bool AAlchemyWorld::FindSpawnPoint(int Type,FVector& P) {
    if(bBattleReference && RuntimeEnemies.IsValidIndex(Type) && EnemyDefinition(Type).Archetype!=10)return BattleFindSpawn(Type,P);
    if(!RuntimeEnemies.IsValidIndex(Type))return false;
    if(EnemyDefinition(Type).Archetype==10) {
        for(int I=0;I<48;I++) {
            const float Angle=I*2*PI/48;
            const FVector Candidate=PlayerPos+FVector(FMath::Cos(Angle),FMath::Sin(Angle),0)*900;
            if(Walkable(Candidate,EnemyRadius(Type))) {P=Candidate;return true;}
        }
        return false;
    }
    // Candidate rectangle lies outside the current orthographic viewport, not merely a player-radius circle.
    int VX=1280,VY=720; GetWorld()->GetFirstPlayerController()->GetViewportSize(VX,VY);
    const float HH=ViewWidth/(2*FMath::Max(0.5f,float(VX)/FMath::Max(1,VY))*FMath::Sin(FMath::DegreesToRadians(CameraPitch)));
    const FVector Focus=Camera->GetActorLocation()+Camera->GetActorForwardVector()*(ViewWidth/2/FMath::Tan(FMath::DegreesToRadians(CameraFOV*.5f)));
    const auto Accept=[&](FVector Candidate) {
        Candidate.Z=0;
        if(!Walkable(Candidate,EnemyRadius(Type)) || (EnemyDefinition(Type).Archetype==10 && FVector::Dist2D(Candidate,PlayerPos)<800)) return false;
        P=Candidate;return true;
    };
    for(int i=0;i<40;i++) {
        if(i%2) P=Focus+FVector((Random.RandRange(0,1)?1:-1)*(ViewWidth/2+220),Random.FRandRange(-HH-200,HH+200),0);
        else P=Focus+FVector(Random.FRandRange(-ViewWidth/2-200,ViewWidth/2+200),(Random.RandRange(0,1)?1:-1)*(HH+220),0);
        if(Accept(P)) return true;
    }
    // Deterministic perimeter sweep avoids a scheduled event depending only on random retries.
    for(int I=0;I<=24;I++) {
        const float T=I/24.f;
        for(int Side:{-1,1}) {
            if(Accept(Focus+FVector(Side*(ViewWidth/2+220),FMath::Lerp(-HH-200,HH+200,T),0))) return true;
            if(Accept(Focus+FVector(FMath::Lerp(-ViewWidth/2-200,ViewWidth/2+200,T),Side*(HH+220),0))) return true;
        }
    }
    return false;
}
void AAlchemyWorld::SpawnEnemy(int Type) {
    if(!RuntimeEnemies.IsValidIndex(Type)){UE_LOG(LogTemp,Warning,TEXT("ALCHEMY_ENEMY_ID_INVALID %d"),Type);return;}
    const auto& K=EnemyDefinition(Type);
    if(bBossSpawned && K.Archetype!=10) return;
    FVector P;
    if(!FindSpawnPoint(Type,P)) {UE_LOG(LogTemp,Warning,TEXT("ALCHEMY_SPAWN_NO_LEGAL_POINT type=%d time=%.2f"),Type,RunTime);return;}
    FAlchemyEnemy E;E.Type=K.Archetype;E.Definition=Type;E.Pos=P;
    const int Minute=FMath::Max(0,int(RunTime/60));
    const float HPBase=bTune001B && K.TunedHP>=0?K.TunedHP:K.HP;
    E.HP=E.MaxHP=FMath::RoundToFloat(HPBase*(1+K.HPPerMinute*FMath::Min(K.HPMinuteCap,Minute)));
    E.Speed=K.Speed*(1+K.SpeedPerMinute*FMath::Min(K.SpeedMinuteCap,Minute));
    E.Contact=bTune001B && K.TunedContactDamage>=0?K.TunedContactDamage:K.ContactDamage;
    E.Body=Sprite(K.SpriteKey.IsEmpty()?FString(TEXT("Enemy0")):K.SpriteKey,P,K.VisualSize.X,K.VisualSize.Y);
    const float Scale=K.CollisionRadius/35;
    E.Shadow=Mesh(TEXT("Sphere"),P+FVector(0,0,4),FVector(.7f*Scale,.45f*Scale,.03f),FLinearColor(.02f,.03f,.03f));
    if(bBattleReference)if(auto Shadow=Mats.FindRef(TEXT("BattleReference_Shadow")))E.Shadow->GetStaticMeshComponent()->SetMaterial(0,Shadow);
    if(E.Type==10)UpdateBossVisual(E);else UpdateEnemyVisual(E);
    Enemies.Add(E);
}
void AAlchemyWorld::SpawnWave() {
    if(bBossSpawned) return;
    const int W=FMath::Min(5,int(RunTime/60));
    int Count=Enemies.Num()<Minimum[W]?FMath::Min(Refill[W],Minimum[W]-Enemies.Num()):Batch[W];
    if(bGreyfordFlow && RunTime>=300)Count=FMath::CeilToInt(Count*(1+.2f*(1+FMath::FloorToInt((RunTime-300)/30))));
    Count=FMath::Min(Count,300-Enemies.Num());
    float Sum=0;for(const auto& K:RuntimeEnemies)if(K.Archetype<7)Sum+=K.SpawnWeights[W];
    if(Sum<=0)return;
    for(int i=0;i<Count;i++){float Roll=Random.FRand()*Sum;for(int ID=0;ID<RuntimeEnemies.Num();ID++){const auto& K=RuntimeEnemies[ID];if(K.Archetype>=7 || K.SpawnWeights[W]<=0)continue;Roll-=K.SpawnWeights[W];if(Roll<=0){SpawnEnemy(ID);break;}}}
}
int32 AAlchemyWorld::Nearest(FVector P,float Range,const TArray<int32>& Exclude) const {
    int Result=-1; float Best=Range*Range;
    for(int i=0;i<Enemies.Num();i++) if(Enemies[i].HP>0 && !Exclude.Contains(i)) {
        float D=FVector::DistSquared2D(P,Enemies[i].Pos); if(D<Best) { Best=D; Result=i; }
    }
    return Result;
}
void AAlchemyWorld::Fire(FVector From,FVector Target,float Damage,FLinearColor Color,bool Hostile,float Speed,UNiagaraSystem* TrailSystem,UNiagaraSystem* HitSystem,float Lifetime,float EffectScale,float HitLife,bool Potion) {
    FAlchemyShot S; S.Pos=From; S.Velocity=(Target-From).GetSafeNormal2D()*Speed; S.Damage=Damage; S.Hostile=Hostile;
    S.Life=Lifetime;S.EffectScale=EffectScale;S.HitLife=HitLife;S.Color=Color;S.HitEffect=HitSystem?HitSystem:ImpactFX.Get();
    S.Trail=SpawnVFX(TrailSystem?TrailSystem:TrailFX.Get(),From+FVector(0,0,65),Color,.6f*EffectScale,Lifetime+(Potion?.35f:.1f));
    S.Potion=Potion;S.NewPotion=Potion;S.ReleaseDelay=Potion?CharacterAnimation.ReleaseTime():0;
    if(Potion) {
        const FVector D=(Target-From).GetSafeNormal2D();
        CharacterAnimation.Throw(FVector2D(FVector::DotProduct(D,Camera->GetActorRightVector().GetSafeNormal2D()),FVector::DotProduct(D,Camera->GetActorForwardVector().GetSafeNormal2D())));
        S.Body=Sprite(TEXT("PotionProjectile"),From+FVector(0,0,90),36,44);
        S.Body->SetActorHiddenInGame(true);
        if(S.Trail.IsValid()) S.Trail->SetVisibility(false);
    } else {
        S.Body=Mesh(TEXT("Sphere"),From+FVector(0,0,65),FVector(Hostile?.36f:.22f),Color);
        if(Hostile) {
            auto M=UMaterialInstanceDynamic::Create(Material(TEXT("M_HostileBolt")),this);M->SetVectorParameterValue(TEXT("Tint"),Color);
            S.Body->GetStaticMeshComponent()->SetMaterial(0,M);
            S.Body->SetActorRotation(FRotationMatrix::MakeFromXZ(Camera->GetActorRightVector(),-Camera->GetActorForwardVector()).Rotator());
        }
    }
    Shots.Add(S);
}
UNiagaraComponent* AAlchemyWorld::SpawnVFX(UNiagaraSystem* System,FVector Position,FLinearColor Color,float Scale,float Life) {
    if(bSmoke || Scale<=0 || !System || !ParticleMaterial || NiagaraFX.Num()>=48) return nullptr;
    auto* C=UNiagaraFunctionLibrary::SpawnSystemAtLocation(GetWorld(),System,Position,FRotator::ZeroRotator,FVector(Scale),false,false,ENCPoolMethod::None,false);
    if(!C) return nullptr;
    auto* MaterialInstance=UMaterialInstanceDynamic::Create(ParticleMaterial,C);MaterialInstance->SetVectorParameterValue(TEXT("Tint"),Color);
    C->SetVariableMaterial(TEXT("User.FXMaterial"),MaterialInstance);C->AddTickPrerequisiteActor(this);C->Activate(true);
    FAlchemyNiagaraFX FX;FX.Component=C;FX.Life=Life;NiagaraFX.Add(FX);VFXSpawnCount++;return C;
}
void AAlchemyWorld::UpdateFeedback(float Dt) {
    const bool Paused=!Panel.IsEmpty();
    for(auto& FX:NiagaraFX) if(IsValid(FX.Component)) {
        FX.Component->SetPaused(Paused);
        // SetPaused on the component ignores draining one-shots; pause their live instance as well.
        auto Controller=FX.Component->GetSystemInstanceController();if(Controller.IsValid()) Controller->SetPaused(Paused);
    }
    if(Paused) return;
    for(int I=NiagaraFX.Num()-1;I>=0;I--) {
        auto& FX=NiagaraFX[I];FX.Life-=Dt;
        if(FX.Life<=0 || !IsValid(FX.Component)) {if(IsValid(FX.Component)) FX.Component->DestroyComponent();NiagaraFX.RemoveAtSwap(I);}
    }
    for(int I=DamageNumbers.Num()-1;I>=0;I--) {DamageNumbers[I].Life-=Dt;if(DamageNumbers[I].Life<=0) DamageNumbers.RemoveAtSwap(I);}
}
void AAlchemyWorld::DamageEnemy(int Index,float Damage,FLinearColor Color,UNiagaraSystem* HitSystem,float EffectScale,float HitLife) {
    if(!Enemies.IsValidIndex(Index) || Damage<=0 || Enemies[Index].HP<=0) return;
    auto& E=Enemies[Index];const float Actual=FMath::Min(E.HP,Damage);E.HP-=Actual;E.HitFlash=.1f;
    if(DamageNumbers.Num()>=96) DamageNumbers.RemoveAt(0);
    FAlchemyDamageNumber Number;Number.Position=E.Pos+FVector(0,0,EnemyDefinition(E).VisualSize.Y+20);Number.Value=Actual;Number.Lane=DamageSerial++%3-1;DamageNumbers.Add(Number);
    if(EffectScale>0 && HitFXThisFrame++<6) {
        if(!HitSystem || HitSystem==ImpactFX.Get()) {
            auto FX=SpawnPixelFX(0,E.Pos,(E.Type>=7?1.65f:1.f)*EffectScale);
            if(FX){FX->Mirror=FVector::DotProduct(E.Pos-PlayerPos,Camera->GetActorRightVector())<0;PixelFXHitCount++;}
        } else SpawnVFX(HitSystem,E.Pos+FVector(0,0,65),Color,(E.Type>=7?.5f:.3f)*EffectScale,HitLife);
    }
}
void AAlchemyWorld::SlowEnemy(int32 Index,float Duration,float Factor) {
    if(Duration<=0 || !Enemies.IsValidIndex(Index)) return;
    auto& E=Enemies[Index];E.SlowFactor=E.Slow>0?FMath::Min(E.SlowFactor,Factor):Factor;E.Slow=FMath::Max(E.Slow,Duration);
}
int32 AAlchemyWorld::Area(FVector P,float Radius,float Damage,FLinearColor Color,float Slow,float Factor,UNiagaraSystem* CastSystem,UNiagaraSystem* HitSystem,float EffectScale,float CastLife,float HitLife) {
    if(EffectScale>0) {if(CastSystem) SpawnVFX(CastSystem,P+FVector(0,0,35),Color,FMath::Clamp(Radius/180,.25f,1.6f)*EffectScale,CastLife);else Ring(P,Radius,Color);}int Hits=0;
    for(int I=0;I<Enemies.Num();I++) if(Enemies[I].HP>0 && FVector::Dist2D(P,Enemies[I].Pos)<=Radius) {
        auto& E=Enemies[I];Hits++;DamageEnemy(I,Damage,Color,HitSystem,EffectScale,HitLife);
        SlowEnemy(I,Slow,Factor);
    }
    return Hits;
}
void AAlchemyWorld::Hurt(float Damage) {
    if(HurtInv>0 || DodgeInv>0 || HP<=0) return;
    // Defense reduction: 防御增加 (Talents[7]) 2%/level + 局内伤害减少 (RunAttrs[4]) 5%/level.
    float Reduction=0.02f*Progress->Talents[7]+0.05f*RunAttrs[4];
    float Reduced=FMath::Max(1.f,FMath::RoundToFloat(Damage*(1.f-FMath::Min(0.95f,Reduction))));
    HP=FMath::Max(0.f,HP-Reduced); HurtInv=0.65f; if(HP>0)Ring(PlayerPos,65,FLinearColor(0.7f,0.12f,0.1f));
    if(HP<=0) {CharacterAnimation.Die();EndRun(false);}
    else CharacterAnimation.Hit();
}
void AAlchemyWorld::Drop(FVector P,int Kind,int Count) {
    if(bCollectBossRewards) {CollectDrop(Kind,Count,true);return;}
    FAlchemyDrop D; D.Pos=P; D.Kind=Kind; D.Count=Count;
    const TCHAR* Icons[]={TEXT("FirePowder"),TEXT("Dew"),TEXT("MagicShard"),TEXT("BeastCore"),TEXT("VoidCrystal"),TEXT("RootHeart")};
    if(Kind>=6) D.Body=Sprite(TEXT("Chest"),P,160,160);
    else if(Kind>=0 && Kind<6) D.Body=Sprite(Icons[Kind],P,105,105);
    else if(Kind==-2) D.Body=Sprite(TEXT("Coin"),P,72,72); // XP orb (reuses a small pickup sprite)
    else D.Body=Sprite(TEXT("Coin"),P,95,95);
    Drops.Add(D);
}

void AAlchemyWorld::CastSkills(float Dt) {
    // EXP-001: skill range attribute scales range/radius values (not projectile speed or target count).
    const float RangeScale=1.f+0.10f*RunAttrs[3];
    // TALENT: cooldown reduction (Talents[4]) and crit chance/damage (Talents[5]/[6]).
    const float CooldownScale=1.f-0.04f*Progress->Talents[4];
    const float CritChance=0.02f*Progress->Talents[5];
    const float CritMult=1.50f+0.10f*Progress->Talents[6];
    for(int S:Equipped) {
        const auto& K=SkillConfig(S);SkillCD[S]-=Dt;if(SkillCD[S]>0) continue;
        const float Range=K.Range*RangeScale, Radius=K.Radius*RangeScale;
        int N=Nearest(PlayerPos,Range);if(N<0) continue;
        SkillCD[S]=K.CD*CooldownScale;
        float Damage=FMath::RoundToFloat(K.Damage*(1+0.15f*(Levels[S]-1)+0.05f*Progress->Talents[1]+0.10f*RunAttrs[1]));
        if(Random.FRand()<CritChance) Damage=FMath::RoundToFloat(Damage*CritMult);
        int Hits=0;
        const FLinearColor Color=K.Color;
        if(K.Cast==Bolt) {Fire(PlayerPos,Enemies[N].Pos,Damage,Color,false,K.ProjectileSpeed,K.TrailEffect,K.HitEffect,Range/K.ProjectileSpeed,K.EffectScale,K.HitLife,S==0);Shots.Last().Slow=K.Slow;Shots.Last().SlowFactor=K.Factor;}
        else if(K.Cast==SelfArea || K.Cast==TargetArea) Hits=Area(K.Cast==SelfArea?PlayerPos:Enemies[N].Pos,Radius,Damage,Color,K.Slow,K.Factor,K.CastEffect,K.HitEffect,K.EffectScale,K.CastLife,K.HitLife);
        else {
            TArray<int32> Used;
            for(int J=0;J<K.Targets && N>=0;J++) {
                Used.Add(N);auto& E=Enemies[N];DamageEnemy(N,Damage,Color,K.HitEffect,K.EffectScale,K.HitLife);Hits++;
                SlowEnemy(N,K.Slow,K.Factor);
                N=K.Cast==Bounce?Nearest(E.Pos,Range,Used):-1;
            }
        }
        TutorialHit(S,Hits);
    }
    for(int C=0;C<NumChains();C++) {
        const auto& K=ChainConfig(C);
        if(!Equipped.Contains(K.A) || !Equipped.Contains(K.B)) continue;
        ChainCD[C]-=Dt;if(ChainCD[C]>0) continue;ChainCD[C]=K.CD;
        int N=Nearest(PlayerPos,K.Range);if(N<0) continue;
        const float Damage=FMath::RoundToFloat(K.Damage*(1+.05f*Progress->Talents[1]));
        if(K.Targets>0) {
            TArray<int32> Used;
            for(int J=0;J<K.Targets && N>=0;J++) {
                Used.Add(N);auto& E=Enemies[N];DamageEnemy(N,Damage,K.Color,K.HitEffect,K.EffectScale,K.HitLife);
                SlowEnemy(N,K.Slow,K.Factor);
                N=Nearest(E.Pos,K.Range,Used);
            }
        } else Area(Enemies[N].Pos,K.Radius,Damage,K.Color,K.Slow,K.Factor,K.CastEffect,K.HitEffect,K.EffectScale,K.CastLife,K.HitLife);
        ChainCount++;
        if(!Progress->ChainsV2.Contains(C)) {Progress->ChainsV2.Add(C);SaveProgress();Message(FString(TEXT("连锁发现："))+K.Name);}
    }
}

void AAlchemyWorld::TogglePanel(const FString& Id) {
    if(PendingResultSkill>=0 || PendingIsNuclear){Panel=TEXT("result");return;}
    if(PendingLevelUps>0){RollLevelupChoices();return;}
    Panel=Panel==Id?TEXT(""):Id;
}

void AAlchemyWorld::Action(FString Id) {
    if((PendingResultSkill>=0 || PendingIsNuclear) && Id!=TEXT("acceptresult") && Id!=TEXT("reroll")) {Panel=TEXT("result");return;}
    if(bGreyfordFlow && GreyfordFlowAction(Id))return;
    if(Id==TEXT("merchantopen")) {OpenMerchant();return;}
    if(Id.StartsWith(TEXT("merchantbuy"))) {BuyMerchant(FCString::Atoi(*Id.Mid(11)));return;}
    if(Id==TEXT("merchantrefresh")) {RefreshMerchant();return;}
    if(Id.StartsWith(TEXT("merchantsellall"))) {SellMerchant(FCString::Atoi(*Id.Mid(15)),true);return;}
    if(Id.StartsWith(TEXT("merchantsell"))) {SellMerchant(FCString::Atoi(*Id.Mid(12)));return;}
    if(Id==TEXT("merchantconfirm")) {ConfirmMerchantSale();return;}
    if(Id==TEXT("textsize") || Id==TEXT("fonts")) {Panel=TEXT("fonts");return;}
    if(Id.StartsWith(TEXT("fontm")) || Id.StartsWith(TEXT("fontl")) || Id==TEXT("fontreset")) {
        const float OldM=Progress->MediumTextScale,OldL=Progress->LargeTextScale;
        if(Id==TEXT("fontreset")) {Progress->MediumTextScale=.9f;Progress->LargeTextScale=.72f;}
        else {
            const float Steps[]={-.05f,-.01f,.01f,.05f};int I=FCString::Atoi(*Id.Right(1));
            if(I<0 || I>3) return;
            float& Value=Id.StartsWith(TEXT("fontm"))?Progress->MediumTextScale:Progress->LargeTextScale;
            Value=FMath::Clamp(FMath::RoundToFloat((Value+Steps[I])*100)/100,.5f,1.2f);
        }
        if(!SaveProgress()) {Progress->MediumTextScale=OldM;Progress->LargeTextScale=OldL;Message(TEXT("字号保存失败，请重试。"));}
        return;
    }
    if(bRunEnded) {
        if(Panel==TEXT("savefailed")) {
            if(Id==TEXT("retry")) {bRunEnded=false; EndRun(bWon);} return;
        }
        if(Id==TEXT("close")) Id=TEXT("village");
        if(Id!=TEXT("village")) return;
    }
    if(Id==TEXT("close")) {
        if(Panel==TEXT("merchantconfirm")) {MerchantSellKind=-1;MerchantSellCount=0;Panel=TEXT("merchant");return;}
        if(Panel==TEXT("levelup") && PendingLevelUps>0) return;
        if(Panel==TEXT("result") && (PendingResultSkill>=0 || PendingIsNuclear)) return; // must resolve the result
        Panel.Empty(); PendingTalent=-1; return;
    }
    if(Id==TEXT("start")) { StartRun(); return; }
    if(Id==TEXT("village")) {
        if(bGreyfordScene) {StartRun();return;}
        if(bCombat && Panel!=TEXT("victory") && Panel!=TEXT("defeat")) { EndRun(false); if(Panel==TEXT("savefailed")) return; }
        Inventory={0,0,0,0,0,0}; Selected=Inventory; Levels.Init(0,NumSkills());Levels[0]=1; Equipped={0}; Bag.Empty(); BuildScene(false); return;
    }
    if(Id==TEXT("pausebtn")) { if(bCombat && !bRunEnded && Panel.IsEmpty()) Panel=TEXT("pause"); return; }
    if(Id==TEXT("return")) { Panel=TEXT("confirmreturn"); return; }
    if(Id==TEXT("craft")) { Craft(); return; }
    if(Id==TEXT("acceptresult")) { AcceptPendingResult(); return; }
    if(Id==TEXT("reroll")) { RerollPendingResult(); return; }
    if(Id.StartsWith(TEXT("pick"))) {
        const int Choice=FCString::Atoi(*Id.Mid(4));
        if(Panel!=TEXT("levelup") || PendingLevelUps<=0 || (Choice!=LevelupChoices[0] && Choice!=LevelupChoices[1] && Choice!=LevelupChoices[2])) return;
        ApplyRunAttr(Choice);PendingLevelUps--;LevelupChoices[0]=LevelupChoices[1]=LevelupChoices[2]=-1;Panel.Empty();RollLevelupChoices();return;
    }
    if(Id.StartsWith(TEXT("startmat"))) { StartMaterialChoice=FCString::Atoi(*Id.Mid(8)); Panel=TEXT("level"); return; }
    if(Id.StartsWith(TEXT("fill")) && (Panel==TEXT("alchemy") || Panel==TEXT("codex")) && bCombat) {
        // CODEX-002: notes and legacy codex use the same discovered-combination fill action.
        if(TutorialActive()){Message(TEXT("首次教学请三种普通材料各投入1个"));return;}
        int C=FCString::Atoi(*Id.Mid(4)); if(C<0 || C>=7) return;
        if(!Progress->Combinations.Contains(C)) return;
        int Needed[3]={0,0,0};
        int Mask=RuntimeRecipes[C].Mask; // 1=fire,2=dew,4=magic
        if(Mask==7) {Needed[0]=Needed[1]=Needed[2]=1;}
        else {
            // Fill by combination table order: single=3, dual=first2+second1, triple=1 each.
            if((Mask&1)) Needed[0]++; if((Mask&2)) Needed[1]++; if((Mask&4)) Needed[2]++;
            int Count=Needed[0]+Needed[1]+Needed[2];
            if(Count==1) { if(Needed[0]) Needed[0]=3; else if(Needed[1]) Needed[1]=3; else Needed[2]=3; }
            else if(Count==2) { int First=-1; if(Needed[0]) First=0; else if(Needed[1]) First=1; else First=2; int Second=(First==0)?(Needed[1]?1:2):(First==1)?(Needed[2]?2:0):(Needed[0]?0:1); Needed[First]=2; Needed[Second]=1; }
        }
        bool Enough=true; for(int M=0;M<3;M++) if(Inventory[M]<Needed[M]) Enough=false;
        if(!Enough) {Message(TEXT("材料不足，无法一键填充"));return;}
        Selected={0,0,0,0,0,0}; for(int M=0;M<3;M++) Selected[M]=Needed[M];
        Panel=TEXT("alchemy");
        return;
    }
    if(Id==TEXT("clear")) { Selected={0,0,0,0,0,0}; return; }
    if(Id==TEXT("alchemy") || Id==TEXT("codex") || Id==TEXT("skills") || Id==TEXT("talents") || Id==TEXT("level") || Id==TEXT("research")) { Panel=Id; return; }
    if(bBattleReference && (Id==TEXT("ortho") || Id==TEXT("tilt"))){Message(TEXT("参考场景固定为透视俯角60°，避免画面与碰撞错位"));return;}
    if(Id==TEXT("ortho")) bPerspective=!bPerspective;
    if(Id==TEXT("lit")) bLitSprites=!bLitSprites;
    if(Id==TEXT("upright")) bUprightSprites=!bUprightSprites;
    if(Id==TEXT("dof")) bDepthOfField=!bDepthOfField;
    if(Id==TEXT("tilt")) CameraPitch=CameraPitch==48?35:48;
    if(Id==TEXT("tune") && !bCombat) bTune001B=!bTune001B;
    if(Id==TEXT("drop") && !bCombat) bDrop001=!bDrop001;
    if(Id.StartsWith(TEXT("add"))) {AddMaterial(FCString::Atoi(*Id.Mid(3)));return;}
    if(Id.StartsWith(TEXT("sub"))) { int I=FCString::Atoi(*Id.Mid(3)); if(Selected.IsValidIndex(I)) Selected[I]=FMath::Max(0,Selected[I]-1); return; }
    if(Id.StartsWith(TEXT("furnace"))) { int I=FCString::Atoi(*Id.Mid(7)); if(Selected.IsValidIndex(I)) Selected[I]=FMath::Max(0,Selected[I]-1); return; }
    if(Id==TEXT("codexprev")) {CodexPage=FMath::Max(0,CodexPage-1);return;}
    if(Id==TEXT("codexnext")) {CodexPage=FMath::Min(2,CodexPage+1);return;}
    if(Id.StartsWith(TEXT("recipe")) && bCombat && !TutorialActive()) {
        int S=FCString::Atoi(*Id.Mid(6));
        if(S>=0 && S<NumSkills() && Progress->Recipes.Contains(S)) {for(int I=0;I<6;I++) Selected[I]=RecipeCost(S,I);Panel=TEXT("alchemy");}
        return;
    }
    if(Id.StartsWith(TEXT("bag"))) { SelectedBag=FCString::Atoi(*Id.Mid(3)); return; }
    if(Id.StartsWith(TEXT("equip"))) {
        int I=FCString::Atoi(*Id.Mid(5)); if(!Bag.IsValidIndex(SelectedBag)) return;
        if(TutorialActive()) {Message(TEXT("先用新范围技能命中至少2个敌人，再管理技能。"));return;}
        if(Equipped.Num()<6) { Equipped.Add(Bag[SelectedBag]); Bag.RemoveAt(SelectedBag); }
        else if(Equipped.IsValidIndex(I) && I!=0) Swap(Equipped[I],Bag[SelectedBag]);
        SelectedBag=-1; return;
    }
    if(Id.StartsWith(TEXT("buy")) && !bCombat) {
        int I=FCString::Atoi(*Id.Mid(3)); if(I<0 || I>=TalentNodeCount) return;
        if(!TalentNodeUnlocked(I) || TalentNodeDone(I)) return;
        PendingTalent=I; Panel=TEXT("confirmbuy"); return;
    }
    if(Id==TEXT("confirmbuy") && !bCombat && PendingTalent>=0) {
        BuyTalentNode(PendingTalent);
        PendingTalent=-1; Panel=TEXT("talents"); return;
    }
}

void AAlchemyWorld::Tick(float Dt) {
    Super::Tick(Dt); Dt=FMath::Min(Dt,0.1f); VisualTime+=Dt; ToastTime-=Dt;
    UpdateMerchantFeedback();
    HitFXThisFrame=0;
    auto PC=GetWorld()->GetFirstPlayerController(); if(!PC || !Player) return;
    if(bGreyfordReference && FParse::Param(FCommandLine::Get(),TEXT("PixelFXCapture"))){PixelFXCheck(Dt);return;}
    if(bGreyfordScene && !bGreyfordFlow && !GreyfordReviewActive && PC->WasInputKeyJustPressed(EKeys::R))StartRun();
    if(bGreyfordReference && FParse::Param(FCommandLine::Get(),TEXT("GreyfordSpatialTest"))){GreyfordSpatialCheck(Dt);return;}
    if(bGreyfordReference && FParse::Param(FCommandLine::Get(),TEXT("GreyfordAmbientTest"))){GreyfordAmbientCheck(Dt);return;}
    if(bGreyfordFlow && FParse::Param(FCommandLine::Get(),TEXT("GreyfordFlowTest")))GreyfordFlowCheck(Dt);
    if(GreyfordReviewActive && Panel==TEXT("levelup"))Action(FString::Printf(TEXT("pick%d"),LevelupChoices[0]));
    if(GreyfordReviewActive && bRunEnded){GreyfordReviewOK=false;FinishGreyfordReview();return;}
    if(PC->WasInputKeyJustPressed(EKeys::F1)) Action(TEXT("ortho"));
    if(PC->WasInputKeyJustPressed(EKeys::F2)) Action(TEXT("lit"));
    if(PC->WasInputKeyJustPressed(EKeys::F3)) Action(TEXT("upright"));
    if(PC->WasInputKeyJustPressed(EKeys::F4)) Action(TEXT("tilt"));
    if(PC->WasInputKeyJustPressed(EKeys::F5)) Action(TEXT("dof"));
    if(PC->WasInputKeyJustPressed(EKeys::LeftBracket)) ViewWidth=FMath::Max(1800.f,ViewWidth-200);
    if(PC->WasInputKeyJustPressed(EKeys::RightBracket)) ViewWidth=FMath::Min(3600.f,ViewWidth+200);
    if(!bRunEnded && PC->WasInputKeyJustPressed(EKeys::F7)) TogglePanel(TEXT("fonts"));
    if(!bRunEnded && PC->WasInputKeyJustPressed(EKeys::F6)) TogglePanel(TEXT("research"));
    if(PC->WasInputKeyJustPressed(EKeys::Escape)) {
        if(bRunEnded) Action(Panel==TEXT("savefailed")?TEXT("retry"):TEXT("village"));
        else if(Panel.IsEmpty()) Panel=TEXT("pause");else Action(TEXT("close"));
    }
    if(!bRunEnded && bCombat && PC->WasInputKeyJustPressed(EKeys::Q)) TogglePanel(TEXT("alchemy"));
    if(!bRunEnded && !bCombat && PC->WasInputKeyJustPressed(EKeys::C)) TogglePanel(TEXT("codex"));
    if(!bRunEnded && bCombat && PC->WasInputKeyJustPressed(EKeys::B)) TogglePanel(TEXT("skills"));
    if(FParse::Param(FCommandLine::Get(),TEXT("UIV02Test"))){UIV02Check(Dt);return;}
    if((FParse::Param(FCommandLine::Get(),TEXT("BattlePresentationTest")) || FParse::Param(FCommandLine::Get(),TEXT("BattlePresentationCapture"))) && BattlePresentationCheck(Dt))return;
    if(FParse::Param(FCommandLine::Get(),TEXT("UnifiedPresentationTest")) && UnifiedPresentationCheck(Dt))return;
    if(FParse::Param(FCommandLine::Get(),TEXT("VillagePresentationTest")) && VillagePresentationCheck(Dt))return;
    if(FParse::Param(FCommandLine::Get(),TEXT("VillagePerspectiveTest")) && VillagePerspectiveCheck(Dt))return;
    if(FParse::Param(FCommandLine::Get(),TEXT("Reference60Test")) && Reference60Check(Dt))return;
    if(FParse::Param(FCommandLine::Get(),TEXT("ProducerRegression"))){ProducerRegression();return;}
    if(FParse::Param(FCommandLine::Get(),TEXT("PlannedBossTest"))){PlannedBossCheck(Dt);return;}
    if(FParse::Param(FCommandLine::Get(),TEXT("PlannedBossCapture")))PlannedBossCapture();
    if(bSmoke) SmokeCheck(Dt);
    if(FParse::Param(FCommandLine::Get(),TEXT("AlchemyMerchantSmoke"))) {MerchantSmoke(Dt);return;}
    if(FParse::Param(FCommandLine::Get(),TEXT("AlchemyMerchantCapture"))) MerchantCapture(Dt);
    if(FParse::Param(FCommandLine::Get(),TEXT("AlchemyBossSmoke"))) {BossSmoke(Dt);return;}
    if(FParse::Param(FCommandLine::Get(),TEXT("AlchemyBossCapture"))) BossPresentationCapture(Dt);
    if(FParse::Param(FCommandLine::Get(),TEXT("AlchemyCharacterSmoke"))) CharacterSmoke(Dt);
    if(FParse::Param(FCommandLine::Get(),TEXT("AlchemyCharacterV3Smoke"))) CharacterV3Smoke(Dt);
    if(bCapture && FParse::Param(FCommandLine::Get(),TEXT("AlchemyToolsCapture"))) {CaptureTools(Dt);return;}
    if(bCapture && FParse::Param(FCommandLine::Get(),TEXT("AlchemyFeedbackCapture"))) {CaptureFeedback(Dt);return;}
    if(bCapture && FParse::Param(FCommandLine::Get(),TEXT("AlchemyPCCapture"))) {
        if(VisualTime>2+CaptureStep*1.2f) {
            switch(CaptureStep) {
                case 0: BuildScene(false);ToastTime=0;break;
                case 1:
                    StartRun();RunTime=47;Kills=18;RunCoins=12;Inventory={5,4,3,1,1,1};Equipped={0,4,6,1,3,2};for(int K:Equipped) Levels[K]=2;
                    for(int I=0;I<Enemies.Num();I++) {Enemies[I].Pos=FVector(FMath::Cos(float(I))*650,FMath::Sin(float(I))*650,0);UpdateSprite(Enemies[I].Body,TEXT("Enemy0"),Enemies[I].Pos,100,100);}
                    ToastTime=0;break;
                case 2: Panel=TEXT("alchemy");Selected={1,1,1,0,0,0};break;
                case 3: Progress->MediumTextScale=.9f;Progress->LargeTextScale=.72f;break;
                case 4: Panel=TEXT("codex");CodexPage=1;for(int K=1;K<25;K++) Progress->Recipes.AddUnique(K);break;
                case 5: CodexPage=2;for(int C=0;C<10;C++) Progress->ChainsV2.AddUnique(C);break;
                case 6: Panel=TEXT("skills");Bag={10,11,12,13,14,15};SelectedBag=0;break;
                case 7: Panel=TEXT("talents");break;
                case 8: Panel=TEXT("fonts");break;
                case 9: Panel=TEXT("pause");break;
                case 10: Panel=TEXT("victory");ResultCoins=12;break;
                default: UE_LOG(LogTemp,Display,TEXT("ALCHEMY_PC_UI_CAPTURE_PASS"));FPlatformMisc::RequestExit(false);return;
            }
            UpdateCamera(0);int X=0,Y=0;PC->GetViewportSize(X,Y);
            FString Folder=FPaths::ProjectDir()/TEXT("Evidence/PC_UI");IFileManager::Get().MakeDirectory(*Folder,true);
            FScreenshotRequest::RequestScreenshot(Folder/FString::Printf(TEXT("PC_%dx%d_%02d.png"),X,Y,CaptureStep),false,false);
            UE_LOG(LogTemp,Display,TEXT("PC_UI_FRAME step=%d viewport=%dx%d scale=%.2f panel=%s"),CaptureStep,X,Y,Progress->UITextScale,*Panel);
            CaptureStep++;
        }
        UpdateCamera(Dt);return;
    }
    if(bCapture && FParse::Param(FCommandLine::Get(),TEXT("AlchemyLayoutCapture"))) {
        if(CaptureStep==0 && VisualTime>2) {BuildScene(true);CameraPitch=90;ViewWidth=20000;bPerspective=false;CaptureStep++;}
        UpdateCamera(Dt);
        if(CaptureStep==1 && VisualTime>4) {FScreenshotRequest::RequestScreenshot(FPaths::ProjectDir()/TEXT("Evidence/LayoutA_Top.png"),false,false);CaptureStep++;}
        else if(CaptureStep==2 && VisualTime>5) {CameraPitch=48;ViewWidth=2844;PlayerPos=DesignPosition(-35,-28);UpdateCharacterVisual(0,false);PlayerShadow->SetActorLocation(VillageVisualPoint(PlayerPos));CaptureStep++;}
        else if(CaptureStep==3 && VisualTime>7) {FScreenshotRequest::RequestScreenshot(FPaths::ProjectDir()/TEXT("Evidence/LayoutA_Local.png"),false,false);CaptureStep++;}
        else if(CaptureStep==4 && VisualTime>9) {UE_LOG(LogTemp,Display,TEXT("ALCHEMY_LAYOUT_CAPTURE_DONE"));FPlatformMisc::RequestExit(false);CaptureStep++;}
        return;
    }
    if(bCapture && FParse::Param(FCommandLine::Get(),TEXT("AlchemyUI"))) {
        // Isolated interactive UI check: no real save load/write, no cheat path in ordinary play.
        if(CaptureStep==0 && VisualTime>2) {StartRun();Inventory={10,10,10,1,1,1};Panel=TEXT("alchemy");CaptureStep=1;}
    }
    else if(bCapture && !bGreyfordScene && !FParse::Param(FCommandLine::Get(),TEXT("AlchemyCharacterSmoke")) && !FParse::Param(FCommandLine::Get(),TEXT("AlchemyCharacterV3Smoke")) && !FParse::Param(FCommandLine::Get(),TEXT("AlchemyBossCapture")) && !FParse::Param(FCommandLine::Get(),TEXT("AlchemyBossPreview")) && !FParse::Param(FCommandLine::Get(),TEXT("AlchemyMerchantCapture")) && !FParse::Param(FCommandLine::Get(),TEXT("AlchemyMerchantPreview"))) {
        const auto Capture=[this](const TCHAR* Name) {
            FScreenshotRequest::RequestScreenshot(FPaths::ProjectDir()/TEXT("Evidence")/Name,false,false);
        };
        if(CaptureStep==0 && VisualTime>4) { Capture(TEXT("01_Village.png")); CaptureStep++; }
        else if(CaptureStep==1 && VisualTime>5) { Panel=TEXT("research"); CaptureStep++; }
        else if(CaptureStep==2 && VisualTime>6) { Capture(TEXT("02_Research.png")); CaptureStep++; }
        else if(CaptureStep==3 && VisualTime>7) { StartRun(); CaptureStep++; }
        else if(CaptureStep==4 && VisualTime>9) {
            for(int i=0;i<8;i++) SpawnEnemy(i%7);
            // Capture-only composition, isolated from the normal run and save data.
            for(int i=0;i<Enemies.Num();i++) Enemies[i].Pos=PlayerPos+FVector(FMath::Cos(i*0.8f)*600,FMath::Sin(i*0.8f)*500,0);
            CaptureStep++;
        }
        else if(CaptureStep==5 && VisualTime>10) { Capture(TEXT("03_Combat.png")); CaptureStep++; }
        else if(CaptureStep==6 && VisualTime>11) { Inventory={3,3,3,0,0,0}; Panel=TEXT("alchemy"); CaptureStep++; }
        else if(CaptureStep==7 && VisualTime>12) { Capture(TEXT("04_Alchemy.png")); CaptureStep++; }
        else if(CaptureStep==8 && VisualTime>13) { BuildScene(false); bPerspective=true; bLitSprites=true; CaptureStep++; }
        else if(CaptureStep==9 && VisualTime>15) { Capture(TEXT("05_Perspective_Lit.png")); CaptureStep++; }
        else if(CaptureStep==10 && VisualTime>16) {UE_LOG(LogTemp,Display,TEXT("ALCHEMY_CAPTURE_DONE")); FPlatformMisc::RequestExit(false); CaptureStep++;}
    }
    if(PendingResultSkill>=0 || PendingIsNuclear)Panel=TEXT("result");
    else if(PendingLevelUps>0 && Panel.IsEmpty()) RollLevelupChoices();
    if(!bGreyfordReference && !bBattleReference && !bReferenceBossScene)UpdateCamera(Dt);
    UpdateFeedback(Dt);
    if(!Panel.IsEmpty()) {
        if(bGreyfordReference)UpdateCamera(Dt);
        Player->SetActorHiddenInGame(false);
        UpdateCharacterVisual(CharacterAnimation.Dead?Dt:0,false);
        for(auto& E:Enemies) {if(E.Type==10)UpdateBossVisual(E);else UpdateEnemyVisual(E);}
        return;
    }
    const float Horizontal=(PC->IsInputKeyDown(EKeys::D)?1:0)-(PC->IsInputKeyDown(EKeys::A)?1:0);
    const float Vertical=(PC->IsInputKeyDown(EKeys::W)?1:0)-(PC->IsInputKeyDown(EKeys::S)?1:0);
    FVector Direction=Camera->GetActorRightVector().GetSafeNormal2D()*Horizontal+Camera->GetActorForwardVector().GetSafeNormal2D()*Vertical;
    Direction=Direction.GetSafeNormal();
    if(GreyfordReviewActive)Direction=UpdateGreyfordReview(Dt,Direction);
    if(!Direction.IsNearlyZero()) LastDirection=Direction;
    DodgeCD=FMath::Max(0.f,DodgeCD-Dt); HurtInv=FMath::Max(0.f,HurtInv-Dt); DodgeInv=FMath::Max(0.f,DodgeInv-Dt);
    if((PC->WasInputKeyJustPressed(EKeys::SpaceBar) || GreyfordReviewDodge) && DodgeCD<=0) {
        DodgeCD=2; DodgeTime=0.24f; DodgeInv=0.65f; DodgeDirection=LastDirection;
        if(GreyfordReviewActive)GreyfordDodges++;
    }
    FVector Delta=Direction*500*(1+0.03f*Progress->Talents[2]+0.05f*RunAttrs[2])*Dt;
    if(DodgeTime>0) {float Step=FMath::Min(Dt,DodgeTime); DodgeTime-=Step; Delta=DodgeDirection*(280/0.24f)*Step;}
    const FVector PreviousPos=PlayerPos;
    PlayerPos=PlannedPlayerMove(Delta,Dt);
    if(bBattleReference)PlayerPos=Move(PreviousPos,BattlePlayerPoint(PlayerPos)-PreviousPos,45);
    if(bGreyfordReference || bBattleReference || bReferenceBossScene)UpdateCamera(Dt);
    UpdateCharacterVisual(Dt,!PlayerPos.Equals(PreviousPos));
    Player->SetActorHiddenInGame(!CharacterAnimation.Hurting && (HurtInv>0 || DodgeInv>0) && int(VisualTime*16)%2==0);
    PlayerShadow->SetActorLocation(VillageVisualPoint(PlayerPos+FVector(0,0,bBattleReference?-8:5)));
    if(bGreyfordFlow && GreyfordPortalReady && GreyfordStage==1 && PC->WasInputKeyJustPressed(EKeys::F) && FVector::Dist2D(PlayerPos,GreyfordPortalPos)<=220){Panel=TEXT("bossportal");return;}
    if(bCombat && PC->WasInputKeyJustPressed(EKeys::F) && OpenMerchant()) return;
    if(!bCombat) {
        if(PC->WasInputKeyJustPressed(EKeys::F)) {
            if(FVector::Dist2D(PlayerPos,FacilityPosition(0))<280) Panel=TEXT("talents");
            else if(FVector::Dist2D(PlayerPos,FacilityPosition(1))<280) Panel=TEXT("codex");
            else if(FVector::Dist2D(PlayerPos,FacilityPosition(2))<300) Panel=TEXT("level");
        }
        return;
    }
    if(bGreyfordFlow && GreyfordStage==2) {
        GreyfordBossStartFlash=FMath::Max(0.f,GreyfordBossStartFlash-Dt);
        if(GreyfordBossPreparation>0) {
            if(GreyfordBossWarmupFrames>0)--GreyfordBossWarmupFrames;
            else GreyfordBossPreparation=FMath::Max(0.f,GreyfordBossPreparation-Dt);
            if(GreyfordBossPreparation==0)GreyfordBossStartFlash=.35f;
            if(FParse::Param(FCommandLine::Get(),TEXT("GreyfordFlowTest"))) {
                const int Digit=FMath::CeilToInt(GreyfordBossPreparation);
                if(Digit!=GreyfordCountdownCapture) {
                    GreyfordCountdownCapture=Digit;const FString Path=FPaths::ProjectDir()/TEXT("Evidence/Greyford/Flow")/FString::Printf(TEXT("countdown-%d.png"),Digit);FTimerHandle Timer;
                    GetWorld()->GetTimerManager().SetTimer(Timer,[Path](){FScreenshotRequest::RequestScreenshot(Path,false,false);},.1f,false);
                }
            }
            if(GreyfordBossPreparation>0)return;
        }
    }
    RunTime+=Dt; SpawnCD-=Dt; ContactCD-=Dt;
    if(TutorialEncounterPending && bGreyfordFlow && GreyfordStage==1 && RunTime>=TutorialEncounterRetry)SpawnTutorialEncounter();
    UpdateMerchant(Dt);
    // EXP-001: in-run HP regen (1/sec per stack), capped at max HP.
    if(RunAttrs[6]>0) HP=FMath::Min(MaxHP,HP+RunAttrs[6]*Dt);
    if(bGreyfordFlow)UpdateGreyfordPortal();
    else {
        if(RunTime>=300 && RunTime-Dt<300) Message(TEXT("最终 BOSS 即将出现 · 10 秒预警"));
        if(RunTime>=310 && !bBossSpawned) StartBossEncounter();
    }
    // SPAWN-002: once the final boss appears, stop new normal-wave and elite spawns.
    // Boss entry settles all remaining enemies and drops exactly once.
    if(!bBossSpawned) {
        if(SpawnCD<=0) {SpawnWave(); SpawnCD=Interval[FMath::Min(5,int(RunTime/60))];if(bGreyfordFlow && RunTime>=300)SpawnCD/=1+.2f*(1+FMath::FloorToInt((RunTime-300)/30));}
        if(RunTime>=NextElite && NextElite<1800) {const int ID=ChooseEliteDefinition();if(ID<0)NextElite+=90;else{int Before=Enemies.Num();SpawnEnemy(ID);if(Enemies.Num()>Before){NextElite+=90;EliteIndex++;}}}
    }
    if(!Panel.IsEmpty()) return;
    CastSkills(Dt);
    for(auto& E:Enemies) {
        if(E.HP<=0) continue;
        if(E.Type==10) {
            E.HitFlash=FMath::Max(0.f,E.HitFlash-Dt);UpdateBoss(E,Dt);
            UpdateBossVisual(E);continue;
        }
        const auto& K=EnemyDefinition(E);
        E.AttackCD-=Dt;E.Slow=FMath::Max(0.f,E.Slow-Dt);E.HitFlash=FMath::Max(0.f,E.HitFlash-Dt);
        const FVector To=PlayerPos-E.Pos;const float Dist=To.Size2D();
        const bool HasArea=K.Behavior==EAlchemyEnemyBehavior::Area || K.Behavior==EAlchemyEnemyBehavior::Hybrid;
        const bool Ranged=K.Behavior==EAlchemyEnemyBehavior::Ranged || K.Behavior==EAlchemyEnemyBehavior::Hybrid;
        if(E.Windup>0){
            E.Windup-=Dt;
            if(E.Windup<=0){Ring(E.Aim,K.AreaRadius,FLinearColor(.75f,.15f,.07f),.2f);
                const float Damage=bTune001B && K.TunedAreaDamage>=0?K.TunedAreaDamage:K.AreaDamage;
                if(FVector::Dist2D(PlayerPos,E.Aim)<K.AreaRadius+45)Hurt(Damage);
                E.AttackCD=K.AreaCD;}
        }else if(HasArea && E.AttackCD<=0 && Dist<K.AreaTrigger){
            E.Windup=K.AreaWindup;E.Aim=K.AreaAimAtPlayer?PlayerPos:E.Pos;
            Ring(E.Aim,K.AreaRadius,FLinearColor(.4f,.15f,.08f),E.Windup);
        }else{
            if(Ranged && Dist<K.RangedMax && Dist>K.RangedMin && E.AttackCD<=0){
                const float Damage=bTune001B && K.TunedRangedDamage>=0?K.TunedRangedDamage:K.RangedDamage;
                Fire(E.Pos,PlayerPos,Damage,FLinearColor(.7f,.22f,.5f),true,K.RangedSpeed);E.AttackCD=K.RangedCD;
            }
            if(!Ranged || Dist>K.RangedKeepDistance || Dist<K.RangedMin){
                if(Ranged && Dist<K.RangedMin)E.Pos=Move(E.Pos,-To.GetSafeNormal2D()*E.Speed*Dt,EnemyRadius(E));else Chase(E,Dt);
            }
            if(Dist<(E.Type>=7?110:75) && E.AttackCD<=0){Hurt(E.Contact);E.AttackCD=1;}
        }
        UpdateEnemyVisual(E,To.X<0);
        E.Shadow->SetActorLocation(E.Pos+FVector(0,0,bBattleReference?-8:4));
    }
    if(!Panel.IsEmpty()) return;
    UpdateShots(Dt);
    if(!Panel.IsEmpty())return;
    for(int i=Enemies.Num()-1;i>=0;i--) if(Enemies[i].HP<=0) {
        auto E=Enemies[i]; E.Body->Destroy(); E.Shadow->Destroy(); Enemies.RemoveAtSwap(i); Kills++;
        SpawnVFX(ImpactFX,E.Pos+FVector(0,0,50),FLinearColor(.4f,.8f,.6f),.7f,1);
        TutorialSupply(E.Pos);
        if(E.Type==10) {EndRun(true); break;}
        RewardEnemy(E);
    }
    if(!Panel.IsEmpty()) return;
    for(int i=Drops.Num()-1;i>=0;i--) {
        auto& D=Drops[i]; float Dist=FVector::Dist2D(D.Pos,PlayerPos);
        if(Dist>(D.Kind>=6?220:250)) continue;
        CollectDrop(D.Kind,D.Count);
        D.Body->Destroy(); Drops.RemoveAtSwap(i);
    }
    for(int i=Effects.Num()-1;i>=0;i--) {
        auto& E=Effects[i];
        if(E.PotionBreak && E.New) {E.New=false;continue;}
        E.Life-=Dt;
        if(E.PotionBreak) {
            auto M=Cast<UMaterialInstanceDynamic>(E.Body->GetStaticMeshComponent()->GetMaterial(0));
            M->SetVectorParameterValue(TEXT("UVOffset"),FLinearColor(FMath::Min(3,FMath::FloorToInt((E.Total-E.Life)*12))/4.f,0,0,0));
            E.Body->SetActorRotation(FRotationMatrix::MakeFromXZ(Camera->GetActorRightVector(),-Camera->GetActorForwardVector()).Rotator());
        }
        else if(E.Total<1) {float Scale=FMath::Lerp(0.8f,1.1f,1-E.Life/E.Total); E.Body->SetActorScale3D(FVector(E.Radius/50*Scale,E.Radius/50*Scale,0.015f));}
        if(E.Life<=0) {E.Body->Destroy(); Effects.RemoveAtSwap(i);}
    }
    Scene.RemoveAll([](const TObjectPtr<AActor>& A){return !IsValid(A);});
}

void AAlchemyWorld::LayoutCheck() {
    bool OK=Obstacles.Num()==8 && PlayerPos.IsNearlyZero();
    const FVector Saved=PlayerPos;
    const FVector PlanRight=DesignPosition(1,0).GetSafeNormal(),PlanUp=DesignPosition(0,-1).GetSafeNormal();
    OK &= FVector::DotProduct(PlanRight,Camera->GetActorRightVector())>0.99f;
    OK &= FVector::DotProduct(PlanUp,Camera->GetActorForwardVector().GetSafeNormal2D())>0.99f;
    int Paths=0,Spawns=0;
    for(float Radius:{35.f,70.f,110.f}) for(int X:{-1,0,1}) for(int Y:{-1,0,1}) {
        const FVector Target(X*6800.f,Y*5000.f,0);
        TArray<FVector> Path;
        bool Reachable=FindPath(FVector::ZeroVector,Target,Radius,Path);
        FVector Previous=FVector::ZeroVector;
        for(const auto& P:Path) {Reachable &= SegmentClear(Previous,P,Radius);Previous=P;}
        OK &= Reachable; Paths+=Reachable?1:0;
    }
    for(int X:{-1,0,1}) for(int Y:{-1,0,1}) {
        PlayerPos=FVector(X*6800.f,Y*5000.f,0);UpdateCamera(0);
        for(int Type:{0,7,10}) {
            FVector P; const bool Found=FindSpawnPoint(Type,P);
            OK &= Found && Walkable(P,EnemyRadius(Type));Spawns+=Found?1:0;
        }
    }
    PlayerPos=DesignPosition(-35,-14);
    for(int Type:{0,7,10}) {
        FAlchemyEnemy Agent; Agent.Type=Type;Agent.Pos=DesignPosition(-35,-28);Agent.Speed=240;
        OK &= !SegmentClear(Agent.Pos,PlayerPos,EnemyRadius(Type));
        for(int Step=0;Step<1500 && FVector::Dist2D(Agent.Pos,PlayerPos)>30;Step++) {
            Chase(Agent,.02f);OK &= Walkable(Agent.Pos,EnemyRadius(Type));
        }
        OK &= FVector::Dist2D(Agent.Pos,PlayerPos)<=30;
    }
    PlayerPos=Saved;UpdateCamera(0);
    UE_LOG(LogTemp,Display,TEXT("ALCHEMY_LAYOUT_CHECK obstacles=%d paths=%d/27 spawns=%d/27 pursuit=3 radii=35,70,110 result=%s"),Obstacles.Num(),Paths,Spawns,OK?TEXT("PASS"):TEXT("FAIL"));
    if(!OK) {UE_LOG(LogTemp,Error,TEXT("ALCHEMY_SMOKE_FAIL layout_A"));FPlatformMisc::RequestExitWithStatus(false,1);}
}
void AAlchemyWorld::AlchemyCheck() {
    bool OK=true;
    const auto Check=[&](bool Pass,const TCHAR* Name) {OK &= Pass;UE_LOG(LogTemp,Display,TEXT("ALCH002_CHECK %s %s"),Name,Pass?TEXT("PASS"):TEXT("FAIL"));};
    // These legacy checks cover normal quality/acceptance. Pick a deterministic non-nuclear seed.
    const auto CraftAndAccept=[&]() {
        int Seed=1;while(FRandomStream(Seed).FRand()<.05f) Seed++;Random.Initialize(Seed);
        const bool Made=Craft();if(Made) AcceptPendingResult();return Made;
    };
    Progress=NewObject<UAlchemyProgress>(this);Progress->Coins=123;Progress->Recipes={1,7};Progress->Chains={0,1};Progress->Talents={1,2,0,0};
    MigrateProgress(true);
    Check(Progress->Coins==123 && Progress->Recipes.Contains(1) && Progress->Recipes.Contains(7) && Progress->TutorialComplete && Progress->Combinations.IsEmpty() && Progress->ChainsV2.IsEmpty() && Progress->Talents[1]==2,TEXT("legacy_semantic_migration"));
    Progress->UITextScale=1.17f;
    TArray<uint8> Bytes;bool Saved=UGameplayStatics::SaveGameToMemory(Progress,Bytes);
    auto Loaded=Saved?Cast<UAlchemyProgress>(UGameplayStatics::LoadGameFromMemory(Bytes)):nullptr;
    Check(Loaded && Loaded->Coins==123 && Loaded->SchemaVersion==3 && Loaded->TutorialComplete && FMath::IsNearlyEqual(Loaded->UITextScale,1.17f),TEXT("save_roundtrip_including_PC_text_scale"));
    StartRun();TArray<int32> Options;TArray<float> W;FString Reason;int C;
    bool Tables=true;TSet<int32> Unique;
    for(int G=0;G<7;G++) {
        for(int S:CombinationSkills[G]) Unique.Add(S);
        for(int Total=3;Total<=10;Total++) {
            Inventory={10,10,10,0,0,0};Selected={0,0,0,0,0,0};int First=-1;
            for(int M=0;M<3;M++) if(CombinationMasks[G]&(1<<M)) {Selected[M]=1;if(First<0) First=M;}
            int Sum=Selected[0]+Selected[1]+Selected[2];Selected[First]+=Total-Sum;
            Tables &= CraftOptions(Options,W,Reason,C) && C==G && Options.Num()==3;
            if(W.Num()==3) for(int Q=0;Q<3;Q++) Tables &= FMath::IsNearlyEqual(W[Q],QualityWeights[Total-3][Q],.001f);
        }
        Levels.Init(0,25);Levels[0]=1;Equipped={0};Bag.Empty();
        Tables &= CraftAndAccept() && Progress->Combinations.Contains(G);
    }
    Check(Tables && Unique.Num()==21,TEXT("7_groups_21_skills_8_probability_rows_and_crafting"));
    Levels.Init(0,25);Levels[0]=1;Equipped={0};Bag.Empty();Inventory={10,10,10,0,0,0};Selected={1,1,1,0,0,0};Levels[23]=5;
    bool Filter=CraftOptions(Options,W,Reason,C) && Options.Num()==2 && FMath::IsNearlyEqual(W[0],200.f/3,.001f) && FMath::IsNearlyEqual(W[1],100.f/3,.001f);
    Levels[4]=5;Levels[24]=5;auto Before=Inventory;
    Check(Filter && !Craft() && Before==Inventory,TEXT("filter_renormalization_and_all_blocked_no_cost"));
    Levels.Init(0,25);Levels[0]=1;Equipped={0,1,2,3,5,6};Bag={7,8,9,10,11,12};Selected={1,1,1,0,0,0};
    bool Capacity=!CraftOptions(Options,W,Reason,C);Levels[4]=1;
    Capacity &= CraftOptions(Options,W,Reason,C) && Options.Num()==1 && Options[0]==4 && W[0]==100 && CraftAndAccept() && Levels[4]==2;
    Check(Capacity,TEXT("capacity_filters_new_but_allows_existing_upgrade"));
    Levels.Init(0,25);Levels[0]=1;Equipped={0};Bag.Empty();Inventory={3,3,3,1,1,1};Selected={1,0,1,1,0,0};
    Check(CraftAndAccept() && Levels[7]==1 && Inventory[3]==0,TEXT("elite_fixed_recipe_preserved"));
    Selected={1,1,1,0,1,0};Before=Inventory;Check(!Craft() && Inventory==Before,TEXT("invalid_special_no_cost"));
    const auto ClearEnemies=[&]() {for(auto& E:Enemies) {E.Body->Destroy();E.Shadow->Destroy();}Enemies.Empty();};
    ClearEnemies();SpawnEnemy(0);SpawnEnemy(0);
    for(int I=0;I<Enemies.Num();I++) {Enemies[I].Pos=FVector(200+I*40,0,0);Enemies[I].HP=10000;Enemies[I].MaxHP=10000;}
    Progress=NewObject<UAlchemyProgress>(this);MigrateProgress(false);StartRun();ClearEnemies();
    RunTime=34;TutorialSupply(PlayerPos);bool Supply=Drops.IsEmpty();RunTime=35;
    TutorialSupply(PlayerPos);Supply &= Drops.Num()==1;TutorialSupply(PlayerPos);Supply &= Drops.Num()==2;TutorialSupply(PlayerPos);Supply &= Drops.Num()==3;TutorialSupply(PlayerPos);Supply &= Drops.Num()==3 && bTutorialSupplyDone;
    Check(Supply,TEXT("tutorial_35s_one_missing_per_kill_no_duplicate_ground_drop"));
    Inventory={3,3,3,0,0,0};Selected={0,0,0,0,0,0};AddMaterial(0);AddMaterial(0);AddMaterial(3);
    bool Tutorial=Selected[0]==1 && Selected[3]==0;AddMaterial(1);AddMaterial(2);Tutorial &= CraftAndAccept() && TutorialSkill>=0;
    int TS=TutorialSkill;Before=Inventory;Selected={1,1,1,0,0,0};Tutorial &= !Craft() && Inventory==Before;
    TutorialHit(TS,1);Tutorial &= !Progress->TutorialComplete;TutorialHit(0,2);Tutorial &= !Progress->TutorialComplete;
    SpawnEnemy(0);SpawnEnemy(0);for(int I=0;I<Enemies.Num();I++) {Enemies[I].Pos=FVector(200+40*I,0,0);Enemies[I].HP=10000;}
    Equipped={TS};SkillCD[TS]=0;CastSkills(.01f);Tutorial &= Progress->TutorialComplete;
    Check(Tutorial,TEXT("tutorial_click_limits_random_AOE_and_actual_two_target_cast"));
    Progress->TutorialComplete=false;StartRun();Check(TutorialSkill==-1 && !bTutorialSupplyDone && TutorialActive() && CraftCount==0,TEXT("incomplete_tutorial_restarts_next_run"));
    Progress->TutorialComplete=true;StartRun();ClearEnemies();SpawnEnemy(0);Enemies[0].Pos=FVector(200,0,0);Enemies[0].HP=100000;
    bool ChainOK=true;
    for(int I=0;I<10;I++) {
        Equipped={ChainConfig(I).A,ChainConfig(I).B};for(float& CD:SkillCD) CD=100;
        ChainCD[I]=ChainConfig(I).CD;int Count=ChainCount;CastSkills(5);float Left=ChainCD[I];
        ChainOK &= Count==ChainCount && FMath::IsNearlyEqual(Left,ChainConfig(I).CD-5);
        Equipped={ChainConfig(I).A};CastSkills(3);ChainOK &= FMath::IsNearlyEqual(ChainCD[I],Left);
        Equipped={ChainConfig(I).A,ChainConfig(I).B};CastSkills(Left+.01f);ChainOK &= ChainCount==Count+1 && Progress->ChainsV2.Contains(I);
    }
    ClearEnemies();Equipped={ChainConfig(0).A,ChainConfig(0).B};ChainCD[0]=.1f;int Count=ChainCount;CastSkills(1);
    ChainOK &= ChainCount==Count && ChainCD[0]==ChainConfig(0).CD;
    Check(ChainOK,TEXT("10_chains_full_initial_CD_unequip_freeze_resume_and_no_target"));
    bool EffectsOK=true;
    for(int S=0;S<25;S++) {
        ClearEnemies();SpawnEnemy(0);SpawnEnemy(0);
        for(int I=0;I<2;I++) {Enemies[I].Pos=FVector(100+I*40,0,0);Enemies[I].HP=10000;}
        Equipped={S};Levels[S]=1;SkillCD[S]=0;int ShotsBefore=Shots.Num();CastSkills(.01f);
        EffectsOK &= SkillConfig(S).Cast==Bolt?Shots.Num()>ShotsBefore:Enemies[0].HP<10000;
    }
    Check(EffectsOK,TEXT("all_25_skill_cast_paths"));
    ClearEnemies();SpawnEnemy(0);SpawnEnemy(0);DamageNumbers.Empty();
    for(int I=0;I<2;I++) {Enemies[I].HP=Enemies[I].MaxHP=100;Enemies[I].Pos=FVector(100+I*40,0,0);}
    DamageEnemy(0,13);bool Feedback=Enemies[0].HP==87 && DamageNumbers.Num()==1 && DamageNumbers[0].Value==13 && Enemies[0].HitFlash>0;
    Feedback &= Area(FVector(120,0,0),100,11,Teal)==2 && Enemies[0].HP==76 && Enemies[1].HP==89 && DamageNumbers.Num()==3;
    Panel=TEXT("alchemy");UpdateFeedback(.4f);Feedback &= FMath::IsNearlyEqual(DamageNumbers[0].Life,.85f);Panel.Empty();UpdateFeedback(.9f);Feedback &= DamageNumbers.IsEmpty();
    Check(Feedback,TEXT("damage_numbers_single_AOE_pause_and_expiry"));
    Check(ImpactFX && BlastFX && TrailFX && ParticleMaterial && ImpactFX->GetEmitterHandles().Num()>0 && BlastFX->GetEmitterHandles().Num()>0,TEXT("cooked_real_niagara_assets"));
    Action(TEXT("fontreset"));Action(TEXT("fontm0"));Action(TEXT("fontl1"));
    UE_LOG(LogTemp,Display,TEXT("FONT_DEBUG_STEPS medium=%.9f large=%.9f small=%.9f"),Progress->MediumTextScale,Progress->LargeTextScale,Progress->FontSize(18));
    bool Font=FMath::IsNearlyEqual(Progress->MediumTextScale,.85f,.0001f) && FMath::IsNearlyEqual(Progress->LargeTextScale,.71f,.0001f) && Progress->FontSize(18)==18;
    Progress->MediumTextScale=.5f;Action(TEXT("fontm0"));UE_LOG(LogTemp,Display,TEXT("FONT_DEBUG_MIN %.9f"),Progress->MediumTextScale);Font &= FMath::IsNearlyEqual(Progress->MediumTextScale,.5f,.0001f);
    Progress->LargeTextScale=1.2f;Action(TEXT("fontl3"));UE_LOG(LogTemp,Display,TEXT("FONT_DEBUG_MAX %.9f"),Progress->LargeTextScale);Font &= FMath::IsNearlyEqual(Progress->LargeTextScale,1.2f,.0001f);
    Action(TEXT("fontreset"));Action(TEXT("textsize"));UE_LOG(LogTemp,Display,TEXT("FONT_DEBUG_PANEL %s"),*Panel);Font &= Panel==TEXT("fonts");Panel.Empty();
    TArray<uint8> FontBytes;UGameplayStatics::SaveGameToMemory(Progress,FontBytes);auto* FontSave=Cast<UAlchemyProgress>(UGameplayStatics::LoadGameFromMemory(FontBytes));
    UE_LOG(LogTemp,Display,TEXT("FONT_DEBUG_SAVE valid=%d medium=%.9f large=%.9f"),FontSave!=nullptr,FontSave?FontSave->MediumTextScale:0,FontSave?FontSave->LargeTextScale:0);
    Font &= FontSave && FMath::IsNearlyEqual(FontSave->MediumTextScale,.9f,.0001f) && FMath::IsNearlyEqual(FontSave->LargeTextScale,.72f,.0001f);
    Check(Font,TEXT("font_debug_independent_groups_fixed_small_limits_save"));
    Check(CheckDesignRuntime(),TEXT("authored_map_skill_recipe_chain_VFX_and_large_drops"));
    if(!OK) {UE_LOG(LogTemp,Error,TEXT("ALCH002_TEST_FAIL"));FPlatformMisc::RequestExitWithStatus(false,1);}
    else UE_LOG(LogTemp,Display,TEXT("ALCH002_TEST_PASS"));
}
void AAlchemyWorld::SmokeCheck(float Dt) {
    SmokeTime+=Dt;
    auto Require=[](bool OK,const TCHAR* Label){if(!OK) {UE_LOG(LogTemp,Error,TEXT("ALCHEMY_SMOKE_FAIL %s"),Label); FPlatformMisc::RequestExitWithStatus(false,1);} else UE_LOG(LogTemp,Display,TEXT("ALCHEMY_CHECK_OK %s"),Label);};
    if(SmokeStep==0 && SmokeTime>1) {
        Progress=NewObject<UAlchemyProgress>(this); StartRun();
        LayoutCheck();
        Require(Enemies.Num()==8,TEXT("initial_8")); Require(HP==120,TEXT("TUNE001B_HP120"));
        AlchemyCheck();Progress=NewObject<UAlchemyProgress>(this);MigrateProgress(true);StartRun();
        Inventory={3,3,3,0,0,0}; Selected={1,0,0,0,0,0}; auto Before=Inventory;
        Require(!Craft() && Before==Inventory,TEXT("invalid_craft_no_cost"));
        Selected={2,0,1,0,0,0};const bool Crafted=Craft();if(Crafted) AcceptPendingResult();Require(Crafted && CraftCount==1 && Inventory[0]==1 && Inventory[2]==2,TEXT("valid_random_combination"));
        for(int S:CombinationSkills[4]) Levels[S]=5;
        Inventory={3,3,3,0,0,0}; Selected={2,0,1,0,0,0}; Before=Inventory;
        Require(!Craft() && Before==Inventory,TEXT("max_level_no_cost"));
        Require(!Walkable(FVector(9000,0,0)),TEXT("world_bounds"));
        const FVector Right=Camera->GetActorRightVector().GetSafeNormal2D();
        Require(FVector::DotProduct(Right,Camera->GetActorRightVector())>0.99f && Right.X<0,TEXT("screen_relative_right_input"));
        bool AllPlanes=true; for(auto A:Scene) if(auto M=Cast<AStaticMeshActor>(A)) AllPlanes &= M->GetStaticMeshComponent()->GetStaticMesh()->GetName()==TEXT("Plane");
        Require(AllPlanes,TEXT("all_visible_geometry_2D_planes"));
        Panel=TEXT("alchemy"); SmokeTime=0; SmokeStep=1;
    } else if(SmokeStep==1 && SmokeTime>1) {
        Require(RunTime<0.01f,TEXT("modal_freezes_clock")); Panel.Empty(); Inventory[0]=10;
        Drop(PlayerPos,0); SmokeTime=0; SmokeStep=2;
    } else if(SmokeStep==2 && SmokeTime>0.5f) {
        Require(Inventory[0]==10,TEXT("material_cap_10"));
        bPerspective=true; bLitSprites=true; bUprightSprites=true; UpdateCamera(1);
        Require(Camera->GetCameraComponent()->ProjectionMode==ECameraProjectionMode::Perspective,TEXT("camera_projection_toggle"));
        bPerspective=false; bLitSprites=false; bUprightSprites=false;
        // Jump through the threshold only in this explicit test process; normal gameplay remains 5:00 / 5:10.
        RunTime=299.98f; SmokeTime=0; SmokeStep=3;
    } else if(SmokeStep==3 && SmokeTime>0.3f) {
        Require(RunTime>=300 && !bBossSpawned,TEXT("boss_warning_before_spawn"));
        RunTime=309.98f; SmokeTime=0; SmokeStep=4;
    } else if(SmokeStep==4 && SmokeTime>0.3f) {
        Require(bBossSpawned,TEXT("boss_at_310"));
        PendingLevelUps=0;Panel.Empty();
        NextElite=360;EliteIndex=3;RunTime=359.98f;SmokeTime=0;SmokeStep=5;
    } else if(SmokeStep==5 && SmokeTime>0.3f) {
        Require(RunTime>=360 && NextElite==360 && EliteIndex==3 && Enemies.Num()==1,TEXT("no_elites_during_boss"));
        UE_LOG(LogTemp,Display,TEXT("ALCHEMY_SMOKE_PASS"));
        FFileHelper::SaveStringToFile(TEXT("PASS: Layout A, spawn coverage, tuning, recipes, cap, pause, camera, boss entry and no elite spawns during boss\n"),*(FPaths::ProjectDir()/TEXT("Evidence/smoke-result.txt")));
        FPlatformMisc::RequestExit(false); SmokeStep=6;
    }
}

#include "AlchemyBoss.inl"
#include "AlchemyPlannedBoss.inl"
#include "AlchemyPlannedBossChecks.inl"

void AAlchemyWorld::UpdateShots(float Dt) {
    if(!Panel.IsEmpty())return;
    for(int i=Shots.Num()-1;i>=0;i--) {
        auto& S=Shots[i];
        if(S.NewPotion) {S.NewPotion=false;continue;}
        if(S.ReleaseDelay>0) {
            S.ReleaseDelay-=Dt;
            if(S.ReleaseDelay>0) continue;
            S.Pos=PlayerPos;
            S.Body->SetActorHiddenInGame(false);
            if(S.Trail.IsValid()) S.Trail->SetVisibility(true);
            UE_LOG(LogTemp,Display,TEXT("ALCHEMIST_POTION_RELEASE frame=%d time=%.3f"),CharacterAnimation.Frame,CharacterAnimation.Time);
        }
        const float ShotDt=FMath::Max(0.f,Dt-S.SpawnDelay);S.SpawnDelay=0;
        S.Age+=ShotDt;S.Life-=ShotDt;
        // Segment substeps also protect fast projectile hits at lower frame rates.
        if(S.BossWave>=0)UpdatePlannedShot(S,ShotDt);
        const int Steps=FMath::Max(1,FMath::CeilToInt(S.Velocity.Size()*ShotDt/20));
        for(int j=0;j<Steps && S.Life>0 && S.BossWave<0;j++) {
            S.Pos+=S.Velocity*ShotDt/Steps;
            if(!Walkable(S.Pos,18)) {S.Life=0; break;}
            if(S.Hostile) {if(FVector::Dist2D(S.Pos,PlayerPos)<63) {Hurt(S.Damage); S.Life=0;}}
            else {int N=Nearest(S.Pos,55); if(N>=0) {DamageEnemy(N,S.Damage,S.Color,S.HitEffect.Get(),S.EffectScale,S.HitLife);SlowEnemy(N,S.Slow,S.SlowFactor);S.Life=0;}}
        }
        if(!Panel.IsEmpty()) return;
        if(S.Potion) {
            const float Arc=65.f*FMath::Sin(PI*FMath::Min(1.f,S.Age/.6f));
            S.Body->SetActorLocation(S.Pos+FVector(0,0,90+Arc));
            const FQuat Billboard=FRotationMatrix::MakeFromXZ(Camera->GetActorRightVector(),-Camera->GetActorForwardVector()).ToQuat();
            S.Body->SetActorRotation((Billboard*FQuat(FVector::UpVector,S.Age*8)).Rotator());
        } else S.Body->SetActorLocation(S.Pos+FVector(0,0,65));
        if(S.Trail.IsValid()) S.Trail->SetWorldLocation(S.Body->GetActorLocation());
        if(S.Life<=0) {if(S.Potion) SpawnPotionBreak(S.Pos);if(S.Trail.IsValid()) S.Trail->DestroyComponent();S.Body->Destroy(); Shots.RemoveAtSwap(i);}
    }
}

#include "AlchemyMerchant.inl"
#include "AlchemyMerchantChecks.inl"
#include "AlchemyMerchantHUD.inl"
#include "AlchemyHUD.inl"
#include "AlchemyFeedback.inl"
#include "AlchemyToolsChecks.inl"

void AAlchemyWorld::UpdateCharacterVisual(float Delta,bool Moving) {
    if(!Player || !Camera) return;
    const FVector Right=Camera->GetActorRightVector(), Forward=Camera->GetActorForwardVector();
    const FVector2D Direction(FVector::DotProduct(LastDirection,Right.GetSafeNormal2D()),FVector::DotProduct(LastDirection,Forward.GetSafeNormal2D()));
    CharacterAnimation.Advance(Delta,Direction,Moving);
    if(bBattleReference && IsValid(PlayerShadow))if(auto Shadow=Mats.FindRef(TEXT("BattleReference_Shadow")))PlayerShadow->GetStaticMeshComponent()->SetMaterial(0,Shadow);
    const auto Rotation=FRotationMatrix::MakeFromXZ(Right,bUprightSprites && !bGreyfordReference?FVector(0,-1,0):-Forward);
    const float VisualScale=VillageVisualScale(PlayerPos);
    const float Size=CharacterAnimation.SheetWorldSize()*VisualScale;
    // Plane UV V grows downward: its local Y points opposite the visual up direction.
    Player->SetActorLocation(VillageVisualPoint(PlayerPos)-Rotation.GetUnitAxis(EAxis::Y)*CharacterAnimation.FootOffset()*VisualScale);
    Player->SetActorRotation(Rotation.Rotator());
    Player->SetActorScale3D(FVector(CharacterAnimation.Mirror?-Size/100:Size/100,Size/100,1));
}

#include "AlchemistCharacterSmoke.inl"
#include "ProducerRegression.inl"
#include "BattlePresentationChecks.inl"
#include "Reference60Checks.inl"
#include "VillagePerspectiveChecks.inl"
#include "VillagePresentationChecks.inl"
#include "UnifiedPresentationChecks.inl"
#include "UIV02Checks.inl"
#include "PixelFXChecks.inl"

void AAlchemyWorld::SpawnPotionBreak(FVector Position) {
    if(!PotionBreakAtlas || !CharacterAnimation.Material) return;
    auto Body=Mesh(TEXT("Plane"),Position+FVector(0,0,65),FVector(1.6f,1.6f,1),FLinearColor::White);
    Body->GetStaticMeshComponent()->SetCastShadow(false);
    Body->SetActorRotation(FRotationMatrix::MakeFromXZ(Camera->GetActorRightVector(),-Camera->GetActorForwardVector()).Rotator());
    auto Base=LoadObject<UMaterialInterface>(nullptr,TEXT("/Game/Characters/Alchemist/M_AlchemistSprite.M_AlchemistSprite"));
    auto M=UMaterialInstanceDynamic::Create(Base,this);
    M->SetTextureParameterValue(TEXT("SpriteSheet"),PotionBreakAtlas);
    M->SetVectorParameterValue(TEXT("UVScale"),FLinearColor(.25f,1,0,0));
    M->SetVectorParameterValue(TEXT("UVOffset"),FLinearColor(0,0,0,0));
    Body->GetStaticMeshComponent()->SetMaterial(0,M);
    FAlchemyFX FX;FX.Body=Body;FX.Life=FX.Total=4.f/12;FX.PotionBreak=true;Effects.Add(FX);PotionBreakCount++;
}
#include "AlchemistCharacterV3Smoke.inl"

#include "GreyfordSpatial.inl"
