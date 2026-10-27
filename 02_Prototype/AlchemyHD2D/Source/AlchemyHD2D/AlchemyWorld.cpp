#include "AlchemyWorld.h"
#include "Modules/ModuleManager.h"
#include "Engine/StaticMeshActor.h"
#include "Engine/StaticMesh.h"
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
#include "Misc/CommandLine.h"
#include "Misc/Parse.h"
#include "Misc/FileHelper.h"
#include "HAL/PlatformFileManager.h"
#include "Fonts/CompositeFont.h"
#include "UnrealClient.h"

IMPLEMENT_PRIMARY_GAME_MODULE(FDefaultGameModuleImpl, AlchemyHD2D, "AlchemyHD2D");

namespace {
const TCHAR* SkillNames[]={TEXT("试作魔弹"),TEXT("炎弹"),TEXT("寒霜环"),TEXT("雷链"),TEXT("酸蚀瓶"),TEXT("石刺"),TEXT("炽焰波"),TEXT("兽核脉冲"),TEXT("虚空噬弹"),TEXT("根须脉冲"),TEXT("灰烬弹"),TEXT("灼热旋流"),TEXT("炎陨药瓶"),TEXT("凝露针"),TEXT("寒霜花"),TEXT("冰潮涌动"),TEXT("以太碎片"),TEXT("奥术脉冲"),TEXT("星坠裂隙"),TEXT("蒸汽爆裂"),TEXT("雷焰爆裂"),TEXT("霜刃"),TEXT("霜雷风暴"),TEXT("混融酸滴"),TEXT("原初催化弹")};
const TCHAR* MaterialNames[]={TEXT("火粉"),TEXT("露水"),TEXT("魔法碎片"),TEXT("兽核"),TEXT("虚空晶"),TEXT("根须心")};
// Configuration tables: stable skill IDs 0..9 retained, new skills append at 10..24.
const int32 CombinationSkills[7][3]={{10,1,5},{13,14,15},{16,3,17},{19,6,12},{11,20,18},{21,2,22},{23,4,24}};
const int32 CombinationMasks[]={1,2,4,3,5,6,7};
const TCHAR* CombinationNames[]={TEXT("火粉反应"),TEXT("露水反应"),TEXT("魔法反应"),TEXT("火露混合"),TEXT("火魔混合"),TEXT("露魔混合"),TEXT("三料混合")};
const float QualityWeights[8][3]={{70,20,10},{65,22,13},{60,25,15},{50,30,20},{45,32,23},{40,33,27},{35,34,31},{30,35,35}};
enum ECast { Bolt, Direct, SelfArea, TargetArea, Bounce };
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
const int32 Weights[6][7]={{70,30,0,0,0,0,0},{35,45,20,0,0,0,0},{0,25,35,40,0,0,0},{0,0,25,35,20,20,0},{0,0,0,25,30,25,20},{0,0,0,20,25,30,25}};
const float EnemyHP[]={16,22,32,35,50,48,75,320,280,420,6000};
const float TuneHP[]={14,20,29,32,45,43,68};
const float EnemySpeed[]={320,220,200,270,310,180,140,240,200,160,180};
const float EnemyContact[]={6,7,8,6,10,7,11,12,8,14,12};
const float TuneContact[]={5,6,7,5,9,6,9};
const int32 Prices[4][5]={{60,90,130,180,240},{80,120,170,230,300},{70,100,140,190,250},{50,80,120,170,230}};
const TCHAR* TalentNames[]={TEXT("生命强化"),TEXT("伤害强化"),TEXT("移动强化"),TEXT("吸引范围")};
const FLinearColor Gold(0.82f,0.58f,0.25f), Teal(0.18f,0.75f,0.65f), Ink(0.025f,0.045f,0.06f), Muted(0.5f,0.62f,0.63f);
// Layout A: design X is screen-right, design Y is screen-down; default camera yaw is 90.
// Rows: design left/top/width/height in units (1 unit = 100 cm).
const FVector4 LayoutRects[]={
    FVector4(-42,-22,14,3),FVector4(-39,-12,4,7),FVector4(26,-23,14,3),FVector4(36,-13,4,8),
    FVector4(-42,19,14,3),FVector4(-39,28,4,6),FVector4(26,19,14,3),FVector4(36,28,4,6)
};
FVector DesignPosition(float X,float Y) { return FVector(-100*X,-100*Y,0); }
float EnemyRadius(int Type) { return Type==10?110.f:Type>=7?70.f:35.f; }
}

AAlchemyMode::AAlchemyMode() { DefaultPawnClass=nullptr; HUDClass=AAlchemyHUD::StaticClass(); }
void AAlchemyMode::StartPlay() { Super::StartPlay(); GetWorld()->SpawnActor<AAlchemyWorld>(); }
AAlchemyWorld::AAlchemyWorld() { PrimaryActorTick.bCanEverTick=true; }

void AAlchemyWorld::BeginPlay() {
    Super::BeginPlay();
    bSmoke=FParse::Param(FCommandLine::Get(),TEXT("AlchemySmoke"));
    bCapture=FParse::Param(FCommandLine::Get(),TEXT("AlchemyCapture")) || FParse::Param(FCommandLine::Get(),TEXT("AlchemyLayoutCapture")) || FParse::Param(FCommandLine::Get(),TEXT("AlchemyUI"));
    Progress=(bSmoke || bCapture)?nullptr:Cast<UAlchemyProgress>(UGameplayStatics::LoadGameFromSlot(TEXT("AlchemyResearch_v1"),0));
    const bool HadSave=Progress!=nullptr;
    if(!Progress && !bSmoke && !bCapture) Progress=Cast<UAlchemyProgress>(UGameplayStatics::LoadGameFromSlot(TEXT("AlchemyResearch_backup"),0));
    if(!Progress && !bSmoke && !bCapture && UGameplayStatics::DoesSaveGameExist(TEXT("AlchemyResearch_v1"),0)) {
        UE_LOG(LogTemp,Error,TEXT("ALCH002 cannot load primary or backup save; refusing to overwrite player progress"));
        FPlatformMisc::RequestExitWithStatus(false,1);return;
    }
    if (!Progress) Progress=NewObject<UAlchemyProgress>(this);
    if (Progress->Talents.Num()!=4) Progress->Talents={0,0,0,0};
    if(Progress->SchemaVersion<2) {
        const bool Played=Progress->Coins>0 || !Progress->Recipes.IsEmpty() || !Progress->Chains.IsEmpty() || Progress->Talents.ContainsByPredicate([](int32 L){return L>0;});
        // Back up the old object before adding new semantic records; isolated QA never writes player saves.
        if(HadSave && !bSmoke && !bCapture && !UGameplayStatics::SaveGameToSlot(Progress,TEXT("AlchemyResearch_backup"),0)) {
            UE_LOG(LogTemp,Error,TEXT("ALCH002 migration backup failed; primary save left unchanged"));
            FPlatformMisc::RequestExitWithStatus(false,1);return;
        }
        MigrateProgress(Played);
    }
    Levels.Init(0,UE_ARRAY_COUNT(Skills));Levels[0]=1;
    UIFont=NewObject<UFont>(this); UIFont->FontCacheType=EFontCacheType::Runtime;
    FTypefaceEntry Face; Face.Name=FName("Regular");
    Face.Font=FFontData(FPaths::EngineContentDir()/TEXT("Slate/Fonts/DroidSansFallback.ttf"),EFontHinting::Default,EFontLoadingPolicy::LazyLoad);
    UIFont->GetMutableInternalCompositeFont().DefaultTypeface.Fonts.Add(Face);
    auto PC=GetWorld()->GetFirstPlayerController();
    PC->bShowMouseCursor=true; PC->bEnableClickEvents=true; PC->bEnableMouseOverEvents=true;
    PC->SetInputMode(FInputModeGameAndUI().SetHideCursorDuringCapture(false));
    Camera=GetWorld()->SpawnActor<ACameraActor>(); Camera->SetActorRotation(FRotator(-CameraPitch,90,0)); PC->SetViewTarget(Camera);
    auto Sun=GetWorld()->SpawnActor<ADirectionalLight>(FVector::ZeroVector,FRotator(-52,-35,0));
    Sun->GetLightComponent()->SetIntensity(3.5f); Sun->GetLightComponent()->SetLightColor(FLinearColor(1.0f,0.84f,0.64f));
    auto Sky=GetWorld()->SpawnActor<ASkyLight>(); Sky->GetLightComponent()->SetIntensity(0.9f);
    Sky->GetLightComponent()->SetLightColor(FLinearColor(0.42f,0.62f,0.73f));
    auto PP=GetWorld()->SpawnActor<APostProcessVolume>(); PP->bUnbound=true;
    PP->Settings.bOverride_VignetteIntensity=true; PP->Settings.VignetteIntensity=0.3f;
    PP->Settings.bOverride_BloomIntensity=true; PP->Settings.BloomIntensity=0.35f;
    BuildScene(false); UpdateCamera(1); Message(TEXT("欢迎来到烛苔村。WASD 移动，靠近设施按 F。"));
    UE_LOG(LogTemp,Display,TEXT("ALCHEMY_READY UE5.8 HD2D research; W0 initial=8; cap=300"));
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
    auto M=UMaterialInstanceDynamic::Create(Material(Shape==TEXT("Sphere") || Shape==TEXT("Cylinder")?TEXT("M_Disc"):TEXT("M_World")),this);
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
void AAlchemyWorld::UpdateSprite(AStaticMeshActor* Body,const FString& Name,FVector Pos,float Width,float Height,bool Flip) {
    Body->SetActorLocation(Pos+FVector(0,0,Height*0.46f));
    const FVector Normal=bUprightSprites?FVector(0,-1,0):-Camera->GetActorForwardVector();
    Body->SetActorRotation(FRotationMatrix::MakeFromXZ(Camera->GetActorRightVector(),Normal).Rotator());
    Body->SetActorScale3D(FVector((Flip?-1:1)*Width/100,Height/100,1));
    Body->GetStaticMeshComponent()->SetMaterial(0,Material(TEXT("M_")+Name+(bLitSprites?TEXT("_Lit"):TEXT(""))));
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
    for(auto A:Scene) if(IsValid(A)) A->Destroy();
    Scene.Empty(); Obstacles.Empty(); Enemies.Empty(); Shots.Empty(); Drops.Empty(); Effects.Empty();
    bCombat=Combat; bRunEnded=false; PlayerPos=Combat?FVector::ZeroVector:FVector(0,-200,0); Panel.Empty();
    const float X=Combat?14222:4800, Y=Combat?10760:3800;
    auto Floor=Mesh(TEXT("Cube"),FVector(0,0,0),FVector(X/100,Y/100,1),FLinearColor::White);
    Floor->GetStaticMeshComponent()->SetMaterial(0,Material(TEXT("M_Grass")));
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
    PlayerShadow=Mesh(TEXT("Sphere"),PlayerPos+FVector(0,0,5),FVector(0.85f,0.5f,0.04f),FLinearColor(0.015f,0.028f,0.025f));
    Player=Sprite(TEXT("Hero0_0"),PlayerPos,120,160);
}

bool AAlchemyWorld::Walkable(FVector P,float Radius) const {
    const float X=bCombat?7060:2350,Y=bCombat?5330:1850;
    if(FMath::Abs(P.X)>X-Radius || FMath::Abs(P.Y)>Y-Radius) return false;
    for(const auto& O:Obstacles) if(FMath::Abs(P.X-O.Center.X)<O.Half.X+Radius && FMath::Abs(P.Y-O.Center.Y)<O.Half.Y+Radius) return false;
    return true;
}
FVector AAlchemyWorld::Move(FVector P,FVector Delta,float Radius) const {
    // Substeps keep dash movement from tunnelling through narrow scene obstacles.
    int Steps=FMath::Max(1,FMath::CeilToInt(Delta.Size()/25)); Delta/=Steps;
    for(int i=0;i<Steps;i++) {
        if(Walkable(P+FVector(Delta.X,0,0),Radius)) P.X+=Delta.X;
        if(Walkable(P+FVector(0,Delta.Y,0),Radius)) P.Y+=Delta.Y;
    }
    return P;
}
bool AAlchemyWorld::SegmentClear(FVector A,FVector B,float Radius) const {
    if(!Walkable(A,Radius) || !Walkable(B,Radius)) return false;
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
    const float Radius=EnemyRadius(E.Type);
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
    C->ProjectionMode=bPerspective?ECameraProjectionMode::Perspective:ECameraProjectionMode::Orthographic;
    C->SetOrthoWidth(ViewWidth); C->SetFieldOfView(50); C->bConstrainAspectRatio=false;
    C->PostProcessSettings.bOverride_DepthOfFieldFocalDistance=true;
    C->PostProcessSettings.DepthOfFieldFocalDistance=ViewWidth/2/FMath::Tan(FMath::DegreesToRadians(25.f));
    C->PostProcessSettings.bOverride_DepthOfFieldFstop=true; C->PostProcessSettings.DepthOfFieldFstop=bDepthOfField?1.8f:32;
    Camera->SetActorRotation(FRotator(-CameraPitch,90,0));
    int VX=1280,VY=720; GetWorld()->GetFirstPlayerController()->GetViewportSize(VX,VY);
    const float Aspect=VY>0?float(VX)/VY:16.f/9;
    const float HalfHeight=ViewWidth/(2*Aspect*FMath::Sin(FMath::DegreesToRadians(CameraPitch)));
    const float BoundX=bCombat?7111:2400, BoundY=bCombat?5380:1900;
    FVector Target=PlayerPos;
    Target.X=FMath::Clamp(Target.X,-FMath::Max(0.f,BoundX-ViewWidth/2),FMath::Max(0.f,BoundX-ViewWidth/2));
    Target.Y=FMath::Clamp(Target.Y,-FMath::Max(0.f,BoundY-HalfHeight),FMath::Max(0.f,BoundY-HalfHeight));
    const float Distance=ViewWidth/2/FMath::Tan(FMath::DegreesToRadians(25.f));
    Camera->SetActorLocation(Target-Camera->GetActorForwardVector()*Distance);
}
void AAlchemyWorld::Ring(FVector P,float Radius,FLinearColor Color,float Duration) {
    auto A=Mesh(TEXT("Cylinder"),P+FVector(0,0,4),FVector(Radius/50,Radius/50,0.015f),Color);
    A->GetStaticMeshComponent()->SetCastShadow(false); Effects.Add({A,Duration,Duration,Radius});
}
void AAlchemyWorld::Message(FString Value) { Toast=Value; ToastTime=4; }
bool AAlchemyWorld::SaveProgress() {
    if(bSmoke || bCapture) return true;
    bool OK=UGameplayStatics::SaveGameToSlot(Progress,TEXT("AlchemyResearch_v1"),0);
    if(!OK) Message(TEXT("保存失败，进度仍在内存中。请重试。"));
    return OK;
}
void AAlchemyWorld::MigrateProgress(bool Played) {
    if(Progress->SchemaVersion>=2) return;
    Progress->TutorialComplete=Played; Progress->Combinations.Empty(); Progress->ChainsV2.Empty();
    Progress->SchemaVersion=2;
}
bool AAlchemyWorld::TutorialActive() const {return bCombat && !Progress->TutorialComplete;}
void AAlchemyWorld::TutorialSupply(FVector Position) {
    if(!TutorialActive() || TutorialSkill>=0 || bTutorialSupplyDone || RunTime<35) return;
    for(int M=0;M<3;M++) {
        bool Available=Inventory[M]>0;
        for(const auto& D:Drops) if(D.Kind==M && D.Count>0 && Walkable(D.Pos,18)) Available=true;
        if(!Available) {Drop(Position,M);return;}
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
    int Total=0;for(int V:Selected) Total+=V;
    if(Total>=10 || Selected[I]>=Inventory[I]) return;
    if(TutorialActive() && (TutorialSkill>=0 || I>=3 || Selected[I]>=1)) {
        Message(TutorialSkill>=0?TEXT("先关闭界面，让新技能一次命中至少2个敌人。"):TEXT("首次教学：三种普通材料各投入1个。"));return;
    }
    Selected[I]++;
}
void AAlchemyWorld::StartRun() {
    RunTime=0; Kills=0; RunCoins=0; CraftCount=0; ChainCount=0; bBossSpawned=false;
    Inventory={0,0,0,0,0,0}; Selected=Inventory; Levels.Init(0,UE_ARRAY_COUNT(Skills));Levels[0]=1; Equipped={0}; Bag.Empty();
    TutorialSkill=-1;bTutorialSupplyDone=false;
    MaxHP=(bTune001B?120:100)+Progress->Talents[0]*10; HP=MaxHP;
    DodgeCD=DodgeTime=HurtInv=DodgeInv=0; SpawnCD=2.6f; NextElite=90; EliteIndex=0;
    for(float& T:SkillCD) T=0;
    for(int C=0;C<UE_ARRAY_COUNT(Chains);C++) ChainCD[C]=Chains[C].CD;
    BuildScene(true);
    UpdateCamera(0);
    for(int i=0;i<8;i++) SpawnEnemy(Random.FRand()<0.7f?0:1);
    Message(TEXT("腐化林地 · 技能自动释放；Tab 打开炼金台。"));
}
void AAlchemyWorld::EndRun(bool Won) {
    if(bRunEnded) return;
    bRunEnded=true; bWon=Won;
    const int Old=Progress->Coins; Progress->Coins+=RunCoins;
    if(!SaveProgress()) { Progress->Coins=Old; Panel=TEXT("savefailed"); return; }
    ResultCoins=RunCoins; RunCoins=0; Panel=Won?TEXT("victory"):TEXT("defeat");
    UE_LOG(LogTemp,Display,TEXT("ALCHEMY_RESULT won=%d time=%.2f kills=%d coins=%d crafts=%d chains=%d"),Won,RunTime,Kills,ResultCoins,CraftCount,ChainCount);
}
bool AAlchemyWorld::CraftOptions(TArray<int32>& Options,TArray<float>& WeightsOut,FString& Reason,int32& Combination) const {
    Options.Empty();WeightsOut.Empty();Reason.Empty();Combination=-1;
    if(!bCombat || bRunEnded) {Reason=TEXT("请在战斗中炼金");return false;}
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
        for(int S=7;S<=9;S++) {bool Match=true;for(int I=0;I<6;I++) Match &= Selected[I]==Recipes[S][I];if(Match) Options.Add(S);}
        if(Options.IsEmpty()) {Reason=TEXT("精英材料使用专属固定配方");return false;}
        WeightsOut.Add(100);
    } else {
        for(int C=0;C<7;C++) if(Mask==CombinationMasks[C]) Combination=C;
        if(Combination<0) {Reason=TEXT("请选择有效材料组合");return false;}
        for(int Q=0;Q<3;Q++) {Options.Add(CombinationSkills[Combination][Q]);WeightsOut.Add(QualityWeights[Total-3][Q]);}
    }
    bool Excluded=false;
    for(int I=Options.Num()-1;I>=0;I--) {
        int S=Options[I];
        if(Levels[S]>=5 || (Levels[S]==0 && Equipped.Num()>=6 && Bag.Num()>=6)) {Options.RemoveAt(I);WeightsOut.RemoveAt(I);Excluded=true;}
    }
    if(Options.IsEmpty()) {Reason=TEXT("全部结果已满级或无存放空间，材料不消耗");return false;}
    float Sum=0;for(float W:WeightsOut) Sum+=W;for(float& W:WeightsOut) W=W*100/Sum;
    if(Excluded) Reason=TEXT("已排除满级/无法存放结果，显示本次实际概率");
    return true;
}
bool AAlchemyWorld::Craft() {
    TArray<int32> Options;TArray<float> WeightsOut;FString Reason;int Combination;
    if(!CraftOptions(Options,WeightsOut,Reason,Combination)) {Message(Reason);return false;}
    float Roll=Random.FRand()*100;int Match=Options.Last();
    for(int I=0;I<Options.Num();I++) {Roll-=WeightsOut[I];if(Roll<0) {Match=Options[I];break;}}
    for(int i=0;i<6;i++) Inventory[i]-=Selected[i];
    if(Levels[Match]==0) { if(Equipped.Num()<6) Equipped.Add(Match); else Bag.Add(Match); }
    Levels[Match]++; CraftCount++; Selected={0,0,0,0,0,0};
    if(Combination>=0) Progress->Combinations.AddUnique(Combination);
    if(TutorialActive()) {TutorialSkill=Match;bTutorialSupplyDone=true;}
    Progress->Recipes.AddUnique(Match); SaveProgress();
    Message(FString::Printf(TEXT("炼制成功：%s · Lv.%d"),SkillNames[Match],Levels[Match])); return true;
}

bool AAlchemyWorld::FindSpawnPoint(int Type,FVector& P) {
    // Candidate rectangle lies outside the current orthographic viewport, not merely a player-radius circle.
    int VX=1280,VY=720; GetWorld()->GetFirstPlayerController()->GetViewportSize(VX,VY);
    const float HH=ViewWidth/(2*FMath::Max(0.5f,float(VX)/FMath::Max(1,VY))*FMath::Sin(FMath::DegreesToRadians(CameraPitch)));
    const FVector Focus=Camera->GetActorLocation()+Camera->GetActorForwardVector()*(ViewWidth/2/FMath::Tan(FMath::DegreesToRadians(25.f)));
    const auto Accept=[&](FVector Candidate) {
        Candidate.Z=0;
        if(!Walkable(Candidate,EnemyRadius(Type)) || (Type==10 && FVector::Dist2D(Candidate,PlayerPos)<800)) return false;
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
    FVector P;
    if(!FindSpawnPoint(Type,P)) {UE_LOG(LogTemp,Warning,TEXT("ALCHEMY_SPAWN_NO_LEGAL_POINT type=%d time=%.2f"),Type,RunTime);return;}
    FAlchemyEnemy E; E.Type=Type; E.Pos=P;
    const int Minute=FMath::Min(6,int(RunTime/60));
    E.HP=E.MaxHP=Type==10?6000:FMath::RoundToFloat((Type<7&&bTune001B?TuneHP[Type]:EnemyHP[Type])*(1+0.12f*Minute));
    E.Speed=EnemySpeed[Type]*(Type==10?1:1+0.025f*FMath::Min(4,Minute));
    E.Contact=Type<7&&bTune001B?TuneContact[Type]:EnemyContact[Type];
    const float Scale=Type==10?3:Type>=7?2:1;
    E.Body=Sprite(FString::Printf(TEXT("Enemy%d"),FMath::Min(Type,9)),P,100*Scale,100*Scale);
    E.Shadow=Mesh(TEXT("Sphere"),P+FVector(0,0,4),FVector(0.7f*Scale,0.45f*Scale,0.03f),FLinearColor(0.02f,0.03f,0.03f));
    Enemies.Add(E);
}
void AAlchemyWorld::SpawnWave() {
    const int W=FMath::Min(5,int(RunTime/60));
    int Count=Enemies.Num()<Minimum[W]?FMath::Min(Refill[W],Minimum[W]-Enemies.Num()):Batch[W];
    Count=FMath::Min(Count,300-Enemies.Num());
    for(int i=0;i<Count;i++) { int Roll=Random.RandRange(1,100),Type=0; while(Type<6 && (Roll-=Weights[W][Type])>0) Type++; SpawnEnemy(Type); }
}
int32 AAlchemyWorld::Nearest(FVector P,float Range,const TArray<int32>& Exclude) const {
    int Result=-1; float Best=Range*Range;
    for(int i=0;i<Enemies.Num();i++) if(Enemies[i].HP>0 && !Exclude.Contains(i)) {
        float D=FVector::DistSquared2D(P,Enemies[i].Pos); if(D<Best) { Best=D; Result=i; }
    }
    return Result;
}
void AAlchemyWorld::Fire(FVector From,FVector Target,float Damage,FLinearColor Color,bool Hostile,float Speed) {
    FAlchemyShot S; S.Pos=From; S.Velocity=(Target-From).GetSafeNormal2D()*Speed; S.Damage=Damage; S.Hostile=Hostile;
    S.Body=Mesh(TEXT("Sphere"),From+FVector(0,0,65),FVector(0.22f),Color); Shots.Add(S);
}
void AAlchemyWorld::DamageEnemy(int Index,float Damage) { if(Enemies.IsValidIndex(Index)) Enemies[Index].HP-=Damage; }
int32 AAlchemyWorld::Area(FVector P,float Radius,float Damage,FLinearColor Color,float Slow,float Factor) {
    Ring(P,Radius,Color);int Hits=0;
    for(auto& E:Enemies) if(E.HP>0 && FVector::Dist2D(P,E.Pos)<=Radius) {
        Hits++;E.HP-=Damage;
        if(Slow>0) {if(E.Slow<=0) E.SlowFactor=Factor;else E.SlowFactor=FMath::Min(E.SlowFactor,Factor);E.Slow=FMath::Max(E.Slow,Slow);}
    }
    return Hits;
}
void AAlchemyWorld::Hurt(float Damage) {
    if(HurtInv>0 || DodgeInv>0 || HP<=0) return;
    HP=FMath::Max(0.f,HP-Damage); HurtInv=0.65f; Ring(PlayerPos,65,FLinearColor(0.7f,0.12f,0.1f));
    if(HP<=0) EndRun(false);
}
void AAlchemyWorld::Drop(FVector P,int Kind,int Count) {
    FAlchemyDrop D; D.Pos=P; D.Kind=Kind; D.Count=Count;
    if(Kind>=6) D.Body=Sheet(TEXT("Chest"),P,75,75);
    else if(Kind>=0) D.Body=Sheet(TEXT("Bottle"),P,45,45);
    else D.Body=Mesh(TEXT("Sphere"),P+FVector(0,0,8),FVector(0.25f),Gold);
    Drops.Add(D);
}

void AAlchemyWorld::CastSkills(float Dt) {
    for(int S:Equipped) {
        const auto& K=Skills[S];SkillCD[S]-=Dt;if(SkillCD[S]>0) continue;
        int N=Nearest(PlayerPos,K.Range);if(N<0) continue;
        SkillCD[S]=K.CD;
        float Damage=FMath::RoundToFloat(K.Damage*(1+0.15f*(Levels[S]-1)+0.05f*Progress->Talents[1]));
        int Hits=0;
        if(K.Cast==Bolt) {Fire(PlayerPos,Enemies[N].Pos,Damage,S==1?FLinearColor(.95f,.3f,.08f):Teal);Shots.Last().Life=K.Range/1000;}
        else if(K.Cast==SelfArea || K.Cast==TargetArea) Hits=Area(K.Cast==SelfArea?PlayerPos:Enemies[N].Pos,K.Radius,Damage,Teal,K.Slow,K.Factor);
        else {
            TArray<int32> Used;
            for(int J=0;J<K.Targets && N>=0;J++) {
                Used.Add(N);auto& E=Enemies[N];DamageEnemy(N,Damage);Hits++;Ring(E.Pos,45,Gold,.2f);
                if(K.Slow>0) {E.SlowFactor=E.Slow>0?FMath::Min(E.SlowFactor,K.Factor):K.Factor;E.Slow=FMath::Max(E.Slow,K.Slow);}
                N=K.Cast==Bounce?Nearest(E.Pos,K.Range,Used):-1;
            }
        }
        TutorialHit(S,Hits);
    }
    for(int C=0;C<UE_ARRAY_COUNT(Chains);C++) {
        const auto& K=Chains[C];
        if(!Equipped.Contains(K.A) || !Equipped.Contains(K.B)) continue;
        ChainCD[C]-=Dt;if(ChainCD[C]>0) continue;ChainCD[C]=K.CD;
        int N=Nearest(PlayerPos,1000);if(N<0) continue;
        const float Damage=FMath::RoundToFloat(K.Damage*(1+.05f*Progress->Talents[1]));
        if(K.Targets>0) {
            TArray<int32> Used;
            for(int J=0;J<K.Targets && N>=0;J++) {
                Used.Add(N);auto& E=Enemies[N];DamageEnemy(N,Damage);Ring(E.Pos,45,Gold,.2f);
                E.SlowFactor=E.Slow>0?FMath::Min(E.SlowFactor,K.Factor):K.Factor;E.Slow=FMath::Max(E.Slow,K.Slow);
                N=Nearest(E.Pos,1000,Used);
            }
        } else Area(Enemies[N].Pos,K.Radius,Damage,Gold,K.Slow,K.Factor);
        ChainCount++;
        if(!Progress->ChainsV2.Contains(C)) {Progress->ChainsV2.Add(C);SaveProgress();Message(FString(TEXT("连锁发现："))+K.Name);}
    }
}

void AAlchemyWorld::Action(FString Id) {
    if(bRunEnded) {
        if(Panel==TEXT("savefailed")) {
            if(Id==TEXT("retry")) {bRunEnded=false; EndRun(bWon);} return;
        }
        if(Id==TEXT("close")) Id=TEXT("village");
        if(Id!=TEXT("village")) return;
    }
    if(Id==TEXT("close")) { Panel.Empty(); PendingTalent=-1; return; }
    if(Id==TEXT("start")) { StartRun(); return; }
    if(Id==TEXT("village")) {
        if(bCombat && Panel!=TEXT("victory") && Panel!=TEXT("defeat")) { EndRun(false); if(Panel==TEXT("savefailed")) return; }
        Inventory={0,0,0,0,0,0}; Selected=Inventory; Levels.Init(0,UE_ARRAY_COUNT(Skills));Levels[0]=1; Equipped={0}; Bag.Empty(); BuildScene(false); return;
    }
    if(Id==TEXT("return")) { Panel=TEXT("confirmreturn"); return; }
    if(Id==TEXT("craft")) { Craft(); return; }
    if(Id==TEXT("clear")) { Selected={0,0,0,0,0,0}; return; }
    if(Id==TEXT("alchemy") || Id==TEXT("codex") || Id==TEXT("skills") || Id==TEXT("talents") || Id==TEXT("level") || Id==TEXT("research")) { Panel=Id; return; }
    if(Id==TEXT("ortho")) bPerspective=!bPerspective;
    if(Id==TEXT("lit")) bLitSprites=!bLitSprites;
    if(Id==TEXT("upright")) bUprightSprites=!bUprightSprites;
    if(Id==TEXT("dof")) bDepthOfField=!bDepthOfField;
    if(Id==TEXT("tilt")) CameraPitch=CameraPitch==48?35:48;
    if(Id==TEXT("tune") && !bCombat) bTune001B=!bTune001B;
    if(Id==TEXT("drop") && !bCombat) bDrop001=!bDrop001;
    if(Id.StartsWith(TEXT("add"))) {AddMaterial(FCString::Atoi(*Id.Mid(3)));return;}
    if(Id.StartsWith(TEXT("sub"))) { int I=FCString::Atoi(*Id.Mid(3)); if(Selected.IsValidIndex(I)) Selected[I]=FMath::Max(0,Selected[I]-1); return; }
    if(Id==TEXT("codexprev")) {CodexPage=FMath::Max(0,CodexPage-1);return;}
    if(Id==TEXT("codexnext")) {CodexPage=FMath::Min(3,CodexPage+1);return;}
    if(Id.StartsWith(TEXT("recipe")) && bCombat && !TutorialActive()) {
        int S=FCString::Atoi(*Id.Mid(6));
        if(S>=7 && S<=9 && Progress->Recipes.Contains(S)) {for(int I=0;I<6;I++) Selected[I]=Recipes[S][I];Panel=TEXT("alchemy");}
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
        int I=FCString::Atoi(*Id.Mid(3)); if(I<0 || I>=4) return;
        int L=Progress->Talents[I]; if(L>=5 || (I>0 && Progress->Talents[I-1]<1)) return;
        if(Progress->Coins<Prices[I][L]) { Message(TEXT("货币不足")); return; }
        PendingTalent=I; Panel=TEXT("confirmbuy"); return;
    }
    if(Id==TEXT("confirmbuy") && !bCombat && PendingTalent>=0) {
        const int I=PendingTalent,L=Progress->Talents[I];
        if(L<5 && (I==0 || Progress->Talents[I-1]>=1) && Progress->Coins>=Prices[I][L]) {
            Progress->Coins-=Prices[I][L]; Progress->Talents[I]++;
            if(!SaveProgress()) {Progress->Coins+=Prices[I][L]; Progress->Talents[I]--;}
        }
        PendingTalent=-1; Panel=TEXT("talents"); return;
    }
}

void AAlchemyWorld::Tick(float Dt) {
    Super::Tick(Dt); Dt=FMath::Min(Dt,0.1f); VisualTime+=Dt; ToastTime-=Dt;
    auto PC=GetWorld()->GetFirstPlayerController(); if(!PC || !Player) return;
    if(PC->WasInputKeyJustPressed(EKeys::F1)) Action(TEXT("ortho"));
    if(PC->WasInputKeyJustPressed(EKeys::F2)) Action(TEXT("lit"));
    if(PC->WasInputKeyJustPressed(EKeys::F3)) Action(TEXT("upright"));
    if(PC->WasInputKeyJustPressed(EKeys::F4)) Action(TEXT("tilt"));
    if(PC->WasInputKeyJustPressed(EKeys::F5)) Action(TEXT("dof"));
    if(PC->WasInputKeyJustPressed(EKeys::LeftBracket)) ViewWidth=FMath::Max(1800.f,ViewWidth-200);
    if(PC->WasInputKeyJustPressed(EKeys::RightBracket)) ViewWidth=FMath::Min(3600.f,ViewWidth+200);
    if(!bRunEnded && PC->WasInputKeyJustPressed(EKeys::F6)) Panel=Panel==TEXT("research")?TEXT(""):TEXT("research");
    if(PC->WasInputKeyJustPressed(EKeys::Escape)) {
        if(bRunEnded) Action(Panel==TEXT("savefailed")?TEXT("retry"):TEXT("village"));
        else Panel=Panel.IsEmpty()?TEXT("pause"):TEXT("");
    }
    if(!bRunEnded && bCombat && PC->WasInputKeyJustPressed(EKeys::Tab)) Panel=Panel==TEXT("alchemy")?TEXT(""):TEXT("alchemy");
    if(!bRunEnded && PC->WasInputKeyJustPressed(EKeys::C)) Panel=Panel==TEXT("codex")?TEXT(""):TEXT("codex");
    if(!bRunEnded && bCombat && PC->WasInputKeyJustPressed(EKeys::B)) Panel=Panel==TEXT("skills")?TEXT(""):TEXT("skills");
    if(bSmoke) SmokeCheck(Dt);
    if(bCapture && FParse::Param(FCommandLine::Get(),TEXT("AlchemyLayoutCapture"))) {
        if(CaptureStep==0 && VisualTime>2) {BuildScene(true);CameraPitch=90;ViewWidth=20000;bPerspective=false;CaptureStep++;}
        UpdateCamera(Dt);
        if(CaptureStep==1 && VisualTime>4) {FScreenshotRequest::RequestScreenshot(FPaths::ProjectDir()/TEXT("Evidence/LayoutA_Top.png"),false,false);CaptureStep++;}
        else if(CaptureStep==2 && VisualTime>5) {CameraPitch=48;ViewWidth=2844;PlayerPos=DesignPosition(-35,-28);UpdateSprite(Player,TEXT("Hero0_0"),PlayerPos,120,160);PlayerShadow->SetActorLocation(PlayerPos);CaptureStep++;}
        else if(CaptureStep==3 && VisualTime>7) {FScreenshotRequest::RequestScreenshot(FPaths::ProjectDir()/TEXT("Evidence/LayoutA_Local.png"),false,false);CaptureStep++;}
        else if(CaptureStep==4 && VisualTime>9) {UE_LOG(LogTemp,Display,TEXT("ALCHEMY_LAYOUT_CAPTURE_DONE"));FPlatformMisc::RequestExit(false);CaptureStep++;}
        return;
    }
    if(bCapture && FParse::Param(FCommandLine::Get(),TEXT("AlchemyUI"))) {
        // Isolated interactive UI check: no real save load/write, no cheat path in ordinary play.
        if(CaptureStep==0 && VisualTime>2) {StartRun();Inventory={10,10,10,1,1,1};Panel=TEXT("alchemy");CaptureStep=1;}
    }
    else if(bCapture) {
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
    UpdateCamera(Dt);
    if(!Panel.IsEmpty()) {
        Player->SetActorHiddenInGame(false);
        UpdateSprite(Player,TEXT("Hero0_0"),PlayerPos,120,160);
        for(auto& E:Enemies) {float Scale=E.Type==10?3:E.Type>=7?2:1; UpdateSprite(E.Body,FString::Printf(TEXT("Enemy%d"),FMath::Min(E.Type,9)),E.Pos,100*Scale,100*Scale);}
        return;
    }
    const float Horizontal=(PC->IsInputKeyDown(EKeys::D)?1:0)-(PC->IsInputKeyDown(EKeys::A)?1:0);
    const float Vertical=(PC->IsInputKeyDown(EKeys::W)?1:0)-(PC->IsInputKeyDown(EKeys::S)?1:0);
    FVector Direction=Camera->GetActorRightVector().GetSafeNormal2D()*Horizontal+Camera->GetActorForwardVector().GetSafeNormal2D()*Vertical;
    Direction=Direction.GetSafeNormal(); if(!Direction.IsNearlyZero()) LastDirection=Direction;
    DodgeCD=FMath::Max(0.f,DodgeCD-Dt); HurtInv=FMath::Max(0.f,HurtInv-Dt); DodgeInv=FMath::Max(0.f,DodgeInv-Dt);
    if(PC->WasInputKeyJustPressed(EKeys::SpaceBar) && DodgeCD<=0) {DodgeCD=2; DodgeTime=0.24f; DodgeInv=0.65f; DodgeDirection=LastDirection;}
    FVector Delta=Direction*500*(1+0.03f*Progress->Talents[2])*Dt;
    if(DodgeTime>0) {float Step=FMath::Min(Dt,DodgeTime); DodgeTime-=Step; Delta=DodgeDirection*(280/0.24f)*Step;}
    PlayerPos=Move(PlayerPos,Delta);
    const int Frame=Direction.IsNearlyZero()?0:int(VisualTime*9)%4;
    UpdateSprite(Player,FString::Printf(TEXT("Hero%d_%d"),LastDirection.Y>0?1:0,Frame),PlayerPos+FVector(0,0,Direction.IsNearlyZero()?0:FMath::Sin(VisualTime*18)*2),120,160,FVector::DotProduct(LastDirection,Camera->GetActorRightVector())<0);
    Player->SetActorHiddenInGame((HurtInv>0 || DodgeInv>0) && int(VisualTime*16)%2==0);
    PlayerShadow->SetActorLocation(PlayerPos+FVector(0,0,5));
    if(!bCombat) {
        if(PC->WasInputKeyJustPressed(EKeys::F)) {
            if(FVector::Dist2D(PlayerPos,FVector(-600,100,0))<280) Panel=TEXT("talents");
            else if(FVector::Dist2D(PlayerPos,FVector(600,100,0))<280) Panel=TEXT("codex");
            else if(FVector::Dist2D(PlayerPos,FVector(0,1050,0))<300) Panel=TEXT("level");
        }
        return;
    }
    RunTime+=Dt; SpawnCD-=Dt; ContactCD-=Dt;
    if(SpawnCD<=0) {SpawnWave(); SpawnCD=Interval[FMath::Min(5,int(RunTime/60))];}
    if(RunTime>=NextElite && NextElite<1800) {int Before=Enemies.Num(); SpawnEnemy(7+EliteIndex%3); if(Enemies.Num()>Before) {NextElite+=90; EliteIndex++;}}
    if(RunTime>=300 && RunTime-Dt<300) Message(TEXT("最终 BOSS 即将出现 · 10 秒预警"));
    if(RunTime>=310 && !bBossSpawned) {int Before=Enemies.Num(); SpawnEnemy(10); bBossSpawned=Enemies.Num()>Before; if(bBossSpawned) Message(TEXT("腐化之源 · BOSS 原型战"));}
    CastSkills(Dt);
    for(auto& E:Enemies) {
        if(E.HP<=0) continue;
        E.AttackCD-=Dt; E.Slow=FMath::Max(0.f,E.Slow-Dt);
        if(E.Type==10 && E.HP<=3000 && !E.Phase2) {E.Phase2=true; E.Transition=2; Message(TEXT("BOSS 第二阶段 · 2秒转换，可继续攻击"));}
        if(E.Transition>0) { E.Transition-=Dt; continue; }
        FVector To=(PlayerPos-E.Pos); float Dist=To.Size2D();
        if(E.Windup>0) {
            E.Windup-=Dt;
            if(E.Windup<=0) {
                const float Radius=E.Type==10?360:E.Type>=7?270:E.Type==6?180:160;
                Ring(E.Aim,Radius,FLinearColor(0.75f,0.15f,0.07f),0.2f);
                if(FVector::Dist2D(PlayerPos,E.Aim)<Radius+45) Hurt(E.Type==10?34:E.Type>=7?26:E.Type==6?(bTune001B?15:18):(bTune001B?12:14));
                E.AttackCD=E.Type==10?(E.Phase2?6.8f:8):E.Type>=7?7:E.Type==6?3.5f:2.8f;
            }
        } else if(E.AttackCD<=0 && (E.Type==2 || E.Type==6 || E.Type>=7) && Dist<(E.Type>=7?500:200)) {
            E.Windup=E.Type==10?1.1f:E.Type>=7?0.9f:E.Type==6?0.75f:0.55f; E.Aim=E.Type>=7?PlayerPos:E.Pos;
            Ring(E.Aim,E.Type==10?360:E.Type>=7?270:160,FLinearColor(0.4f,0.15f,0.08f),E.Windup);
        } else {
            bool Ranged=E.Type==3 || E.Type==5 || E.Type==8;
            if(Ranged && Dist<750 && Dist>200 && E.AttackCD<=0) {
                Fire(E.Pos,PlayerPos,E.Type==3?(bTune001B?9:10):E.Type==5?(bTune001B?10:12):16,FLinearColor(0.7f,0.22f,0.5f),true,E.Type==3?650:580); E.AttackCD=E.Type==5?3.2f:2.8f;
            }
            if(!Ranged || Dist>550 || Dist<200) {
                if(Ranged && Dist<200) E.Pos=Move(E.Pos,-To.GetSafeNormal2D()*E.Speed*Dt,EnemyRadius(E.Type));
                else Chase(E,Dt);
            }
            if(Dist<(E.Type>=7?110:75) && E.AttackCD<=0) { Hurt(E.Contact); E.AttackCD=1; }
        }
        const float Scale=E.Type==10?3:E.Type>=7?2:1;
        UpdateSprite(E.Body,FString::Printf(TEXT("Enemy%d"),FMath::Min(E.Type,9)),E.Pos,100*Scale,100*Scale,To.X<0);
        E.Shadow->SetActorLocation(E.Pos+FVector(0,0,4));
    }
    if(!Panel.IsEmpty()) return;
    for(int i=Shots.Num()-1;i>=0;i--) {
        auto& S=Shots[i]; S.Life-=Dt;
        // Segment substeps also protect fast projectile hits at lower frame rates.
        const int Steps=FMath::Max(1,FMath::CeilToInt(S.Velocity.Size()*Dt/20));
        for(int j=0;j<Steps && S.Life>0;j++) {
            S.Pos+=S.Velocity*Dt/Steps;
            if(!Walkable(S.Pos,18)) {S.Life=0; break;}
            if(S.Hostile) {if(FVector::Dist2D(S.Pos,PlayerPos)<63) {Hurt(S.Damage); S.Life=0;}}
            else {int N=Nearest(S.Pos,55); if(N>=0) {DamageEnemy(N,S.Damage); Ring(S.Pos,35,Teal,0.15f); S.Life=0;}}
        }
        if(!Panel.IsEmpty()) return;
        S.Body->SetActorLocation(S.Pos+FVector(0,0,65));
        if(S.Life<=0) {S.Body->Destroy(); Shots.RemoveAtSwap(i);}
    }
    for(int i=Enemies.Num()-1;i>=0;i--) if(Enemies[i].HP<=0) {
        auto E=Enemies[i]; E.Body->Destroy(); E.Shadow->Destroy(); Enemies.RemoveAtSwap(i); Kills++;
        TutorialSupply(E.Pos);
        if(E.Type==10) {EndRun(true); break;}
        if(E.Type>=7) {Drop(E.Pos,6+E.Type-7); Drop(E.Pos,-1,10);}
        else {
            if(Random.FRand()<0.7f) Drop(E.Pos,-1);
            if(Random.FRand()<(bDrop001?0.154f:0.22f)) {float R=Random.FRand(); Drop(E.Pos,R<0.4f?0:R<0.75f?1:2);}
        }
    }
    if(!Panel.IsEmpty()) return;
    for(int i=Drops.Num()-1;i>=0;i--) {
        auto& D=Drops[i]; float Dist=FVector::Dist2D(D.Pos,PlayerPos);
        if(Dist>(D.Kind>=6?220:250*(1+0.1f*Progress->Talents[3]))) continue;
        if(D.Kind>=6) {
            int Special=D.Kind-3,SpecialAdded=Inventory[Special]<10?1:0,CommonAdded=0;
            Inventory[Special]=FMath::Min(10,Inventory[Special]+1);
            for(int j=0;j<4;j++) {float R=Random.FRand();int Kind=R<0.4f?0:R<0.75f?1:2; if(Inventory[Kind]<10) {Inventory[Kind]++;CommonAdded++;}}
            Message(FString::Printf(TEXT("精英宝箱实际入库：专属 ×%d，普通 ×%d%s"),SpecialAdded,CommonAdded,SpecialAdded+CommonAdded<5?TEXT("；素材已满，超额不入库"):TEXT("")));
        } else if(D.Kind<0) RunCoins+=D.Count;
        else if(Inventory[D.Kind]>=10) Message(TEXT("素材已满"));
        else Inventory[D.Kind]=FMath::Min(10,Inventory[D.Kind]+D.Count);
        D.Body->Destroy(); Drops.RemoveAtSwap(i);
    }
    for(int i=Effects.Num()-1;i>=0;i--) {
        auto& E=Effects[i]; E.Life-=Dt;
        if(E.Total<1) {float Scale=FMath::Lerp(0.8f,1.1f,1-E.Life/E.Total); E.Body->SetActorScale3D(FVector(E.Radius/50*Scale,E.Radius/50*Scale,0.015f));}
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
    Progress=NewObject<UAlchemyProgress>(this);Progress->Coins=123;Progress->Recipes={1,7};Progress->Chains={0,1};Progress->Talents={1,2,0,0};
    MigrateProgress(true);
    Check(Progress->Coins==123 && Progress->Recipes.Contains(1) && Progress->Recipes.Contains(7) && Progress->TutorialComplete && Progress->Combinations.IsEmpty() && Progress->ChainsV2.IsEmpty() && Progress->Talents[1]==2,TEXT("legacy_semantic_migration"));
    TArray<uint8> Bytes;bool Saved=UGameplayStatics::SaveGameToMemory(Progress,Bytes);
    auto Loaded=Saved?Cast<UAlchemyProgress>(UGameplayStatics::LoadGameFromMemory(Bytes)):nullptr;
    Check(Loaded && Loaded->Coins==123 && Loaded->SchemaVersion==2 && Loaded->TutorialComplete,TEXT("save_roundtrip"));
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
        Tables &= Craft() && Progress->Combinations.Contains(G);
    }
    Check(Tables && Unique.Num()==21,TEXT("7_groups_21_skills_8_probability_rows_and_crafting"));
    Levels.Init(0,25);Levels[0]=1;Equipped={0};Bag.Empty();Inventory={10,10,10,0,0,0};Selected={1,1,1,0,0,0};Levels[23]=5;
    bool Filter=CraftOptions(Options,W,Reason,C) && Options.Num()==2 && FMath::IsNearlyEqual(W[0],200.f/3,.001f) && FMath::IsNearlyEqual(W[1],100.f/3,.001f);
    Levels[4]=5;Levels[24]=5;auto Before=Inventory;
    Check(Filter && !Craft() && Before==Inventory,TEXT("filter_renormalization_and_all_blocked_no_cost"));
    Levels.Init(0,25);Levels[0]=1;Equipped={0,1,2,3,5,6};Bag={7,8,9,10,11,12};Selected={1,1,1,0,0,0};
    bool Capacity=!CraftOptions(Options,W,Reason,C);Levels[4]=1;
    Capacity &= CraftOptions(Options,W,Reason,C) && Options.Num()==1 && Options[0]==4 && W[0]==100 && Craft() && Levels[4]==2;
    Check(Capacity,TEXT("capacity_filters_new_but_allows_existing_upgrade"));
    Levels.Init(0,25);Levels[0]=1;Equipped={0};Bag.Empty();Inventory={3,3,3,1,1,1};Selected={1,0,1,1,0,0};
    Check(Craft() && Levels[7]==1 && Inventory[3]==0,TEXT("elite_fixed_recipe_preserved"));
    Selected={1,1,1,0,1,0};Before=Inventory;Check(!Craft() && Inventory==Before,TEXT("invalid_special_no_cost"));
    const auto ClearEnemies=[&]() {for(auto& E:Enemies) {E.Body->Destroy();E.Shadow->Destroy();}Enemies.Empty();};
    ClearEnemies();SpawnEnemy(0);SpawnEnemy(0);
    for(int I=0;I<Enemies.Num();I++) {Enemies[I].Pos=FVector(200+I*40,0,0);Enemies[I].HP=10000;Enemies[I].MaxHP=10000;}
    Progress=NewObject<UAlchemyProgress>(this);MigrateProgress(false);StartRun();ClearEnemies();
    RunTime=34;TutorialSupply(PlayerPos);bool Supply=Drops.IsEmpty();RunTime=35;
    TutorialSupply(PlayerPos);Supply &= Drops.Num()==1;TutorialSupply(PlayerPos);Supply &= Drops.Num()==2;TutorialSupply(PlayerPos);Supply &= Drops.Num()==3;TutorialSupply(PlayerPos);Supply &= Drops.Num()==3 && bTutorialSupplyDone;
    Check(Supply,TEXT("tutorial_35s_one_missing_per_kill_no_duplicate_ground_drop"));
    Inventory={3,3,3,0,0,0};Selected={0,0,0,0,0,0};AddMaterial(0);AddMaterial(0);AddMaterial(3);
    bool Tutorial=Selected[0]==1 && Selected[3]==0;AddMaterial(1);AddMaterial(2);Tutorial &= Craft() && TutorialSkill>=0;
    int TS=TutorialSkill;Before=Inventory;Selected={1,1,1,0,0,0};Tutorial &= !Craft() && Inventory==Before;
    TutorialHit(TS,1);Tutorial &= !Progress->TutorialComplete;TutorialHit(0,2);Tutorial &= !Progress->TutorialComplete;
    SpawnEnemy(0);SpawnEnemy(0);for(int I=0;I<Enemies.Num();I++) {Enemies[I].Pos=FVector(200+40*I,0,0);Enemies[I].HP=10000;}
    Equipped={TS};SkillCD[TS]=0;CastSkills(.01f);Tutorial &= Progress->TutorialComplete;
    Check(Tutorial,TEXT("tutorial_click_limits_random_AOE_and_actual_two_target_cast"));
    Progress->TutorialComplete=false;StartRun();Check(TutorialSkill==-1 && !bTutorialSupplyDone && TutorialActive() && CraftCount==0,TEXT("incomplete_tutorial_restarts_next_run"));
    Progress->TutorialComplete=true;StartRun();ClearEnemies();SpawnEnemy(0);Enemies[0].Pos=FVector(200,0,0);Enemies[0].HP=100000;
    bool ChainOK=true;
    for(int I=0;I<10;I++) {
        Equipped={Chains[I].A,Chains[I].B};for(float& CD:SkillCD) CD=100;
        ChainCD[I]=Chains[I].CD;int Count=ChainCount;CastSkills(5);float Left=ChainCD[I];
        ChainOK &= Count==ChainCount && FMath::IsNearlyEqual(Left,Chains[I].CD-5);
        Equipped={Chains[I].A};CastSkills(3);ChainOK &= FMath::IsNearlyEqual(ChainCD[I],Left);
        Equipped={Chains[I].A,Chains[I].B};CastSkills(Left+.01f);ChainOK &= ChainCount==Count+1 && Progress->ChainsV2.Contains(I);
    }
    ClearEnemies();Equipped={Chains[0].A,Chains[0].B};ChainCD[0]=.1f;int Count=ChainCount;CastSkills(1);
    ChainOK &= ChainCount==Count && ChainCD[0]==Chains[0].CD;
    Check(ChainOK,TEXT("10_chains_full_initial_CD_unequip_freeze_resume_and_no_target"));
    bool EffectsOK=true;
    for(int S=0;S<25;S++) {
        ClearEnemies();SpawnEnemy(0);SpawnEnemy(0);
        for(int I=0;I<2;I++) {Enemies[I].Pos=FVector(100+I*40,0,0);Enemies[I].HP=10000;}
        Equipped={S};Levels[S]=1;SkillCD[S]=0;int ShotsBefore=Shots.Num();CastSkills(.01f);
        EffectsOK &= Skills[S].Cast==Bolt?Shots.Num()>ShotsBefore:Enemies[0].HP<10000;
    }
    Check(EffectsOK,TEXT("all_25_skill_cast_paths"));
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
        Selected={2,0,1,0,0,0}; Require(Craft() && CraftCount==1 && Inventory[0]==1 && Inventory[2]==2,TEXT("valid_random_combination"));
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
        NextElite=360;EliteIndex=3;RunTime=359.98f;SmokeTime=0;SmokeStep=5;
    } else if(SmokeStep==5 && SmokeTime>0.3f) {
        Require(RunTime>=360 && NextElite==450 && EliteIndex==4,TEXT("elite_at_360_during_boss"));
        UE_LOG(LogTemp,Display,TEXT("ALCHEMY_SMOKE_PASS"));
        FFileHelper::SaveStringToFile(TEXT("PASS: Layout A geometry, coordinates, paths and pursuit at three radii; spawn coverage; initial spawn, tuning, recipes, material cap, pause, camera, boss timeline, elite at 360\n"),*(FPaths::ProjectDir()/TEXT("Evidence/smoke-result.txt")));
        FPlatformMisc::RequestExit(false); SmokeStep=6;
    }
}

void AAlchemyHUD::Text(const FString& Value,float X,float Y,float Size,FLinearColor Color) {
    DrawText(Value,Color,X*S,Y*S,World->UIFont,Size/16*S,false);
}
void AAlchemyHUD::Box(float X,float Y,float W,float H,FLinearColor Color) {DrawRect(Color,X*S,Y*S,W*S,H*S);}
void AAlchemyHUD::Button(const FString& Id,const FString& Label,float X,float Y,float W,bool Enabled) {
    float MX=0,MY=0; GetOwningPlayerController()->GetMousePosition(MX,MY);
    const bool Hover=MX>=X*S && MX<=(X+W)*S && MY>=Y*S && MY<=(Y+34)*S;
    Box(X,Y,W,34,Enabled?(Hover?FLinearColor(0.15f,0.29f,0.29f):FLinearColor(0.08f,0.15f,0.18f)):FLinearColor(0.06f,0.08f,0.09f));
    Box(X,Y,3,34,Enabled?Gold:Muted); Text(Label,X+12,Y+7,15,Enabled?FLinearColor(0.9f,0.88f,0.79f):Muted);
    if(Enabled) AddHitBox(FVector2D(X*S,Y*S),FVector2D(W*S,34*S),FName(*Id),true);
}
void AAlchemyHUD::NotifyHitBoxClick(FName Name) {
    if(!World) return;
    FString Id=Name.ToString();
    if(Id.StartsWith(TEXT("material"))) DragMaterial=FCString::Atoi(*Id.Mid(8));
    else World->Action(Id);
}

void AAlchemyHUD::DrawHUD() {
    Super::DrawHUD();
    if(!World) {for(TActorIterator<AAlchemyWorld> I(GetWorld());I;++I) {World=*I;break;}}
    if(!World || !Canvas) return;
    S=FMath::Min(Canvas->SizeX/1280.f,Canvas->SizeY/720.f);
    if(DragMaterial>=0 && GetOwningPlayerController()->WasInputKeyJustReleased(EKeys::LeftMouseButton)) {
        float MX=0,MY=0;GetOwningPlayerController()->GetMousePosition(MX,MY);MX/=S;MY/=S;
        int I=DragMaterial;DragMaterial=-1;
        float SourceY=220+(I%3)*72;
        bool Source=I<3 ? (MX>=700 && MX<=1000 && MY>=SourceY && MY<=SourceY+34) : (MX>=700 && MX<=1000 && MY>=445 && MY<=479);
        if(World->Panel==TEXT("alchemy") && (Source || (MX>=265 && MX<=655 && MY>=205 && MY<=455))) World->AddMaterial(I);
    }
    if(World->Panel!=TEXT("alchemy")) DragMaterial=-1;
    Box(0,0,1280,80,FLinearColor(0.02f,0.035f,0.045f,0.94f));
    Text(TEXT("冒牌炼金术士"),28,12,26,Gold); Text(TEXT("HD 2.5D / 可玩预研 0.1"),30,49,12,Muted);
    Text(World->bCombat?TEXT("腐化林地"):TEXT("烛苔村 · 据点"),310,20,20);
    Text(World->bCombat?FString::Printf(TEXT("%02d:%02d   击败 %d   本局金币 %d"),int(World->RunTime)/60,int(World->RunTime)%60,World->Kills,World->RunCoins):FString::Printf(TEXT("永久金币 %d   /   三座设施可交互"),World->Progress->Coins),310,49,13,Muted);
    Button(TEXT("research"),TEXT("F6  画面实验"),1050,22,200);
    Box(0,660,1280,60,FLinearColor(0.02f,0.035f,0.045f,0.94f));
    Text(TEXT("WASD 移动   Space 闪避   F 设施   Tab 炼金   C 图鉴   B 技能   Esc 暂停"),28,687,13,Muted);
    if(World->bCombat) {
        Box(30,102,220,10,Ink); Box(30,102,220*World->HP/World->MaxHP,10,Teal);
        Text(FString::Printf(TEXT("生命 %.0f / %.0f    闪避 %.1fs"),World->HP,World->MaxHP,World->DodgeCD),30,120,14);
        for(int i=0;i<3;i++) Text(FString::Printf(TEXT("%s %d/10"),MaterialNames[i],World->Inventory[i]),30,160+i*24,14,i==0?Gold:i==1?FLinearColor(0.4f,0.7f,0.9f):Teal);
        for(int i=0;i<World->Equipped.Num();i++) {
            int K=World->Equipped[i]; Box(285+i*116,600,108,46,Ink);
            Text(SkillNames[K],294+i*116,607,13); Text(FString::Printf(TEXT("Lv.%d"),World->Levels[K]),294+i*116,626,12,Gold);
        }
        if(World->TutorialActive()) {
            const bool Ready=World->Inventory[0]>0 && World->Inventory[1]>0 && World->Inventory[2]>0;
            Text(World->TutorialSkill>=0?TEXT("关闭界面：新技能一次命中至少2个敌人"):Ready?TEXT("材料已齐！点击入口或按 Tab 开始炼金"):TEXT("战斗收集三类材料，约35秒后补缺"),285,165,15,Gold);
            if(Ready && World->TutorialSkill<0 && World->Panel.IsEmpty()) Button(TEXT("alchemy"),TEXT("Tab 首次炼金 →"),480,198,280);
        }
        if(World->RunTime>=300 && !World->bBossSpawned) {Box(400,100,480,48,Ink); Text(FString::Printf(TEXT("BOSS 将在 %.1f 秒后出现"),310-World->RunTime),440,112,22,Gold);}
        for(auto& E:World->Enemies) if(E.Type==10) {
            Box(420,100,440,12,Ink); Box(420,100,440*FMath::Max(0.f,E.HP/E.MaxHP),12,Gold); Text(TEXT("腐化之源 · 招式简化原型"),500,120,16); break;
        }
    } else if(World->Panel.IsEmpty()) {
        for(int i=0;i<3;i++) {
            FVector P=i==0?FVector(-600,100,180):i==1?FVector(600,100,180):FVector(0,1050,410);
            FVector2D Screen; GetOwningPlayerController()->ProjectWorldLocationToScreen(P,Screen);
            Text(i==0?TEXT("[F] 强化台"):i==1?TEXT("[F] 配方图鉴"):TEXT("[F] 进入腐化林地"),Screen.X/S-65,Screen.Y/S-25,16,Gold);
        }
    }
    if(!World->Panel.IsEmpty()) {
        Box(0,80,1280,580,FLinearColor(0.01f,0.02f,0.03f,0.58f)); Box(230,110,820,495,Ink);
        Box(230,110,820,3,Gold); Button(TEXT("close"),TEXT("Esc 关闭"),875,128,145);
        const FString P=World->Panel;
        FString Title=P==TEXT("alchemy")?TEXT("炼金台 · 战斗已暂停"):P==TEXT("codex")?TEXT("配方与连锁图鉴"):P==TEXT("skills")?TEXT("装备 6 / 储备 6"):P==TEXT("talents")?TEXT("线性天赋树"):P==TEXT("research")?TEXT("HD2.5D 画面实验"):P==TEXT("level")?TEXT("选择关卡"):P==TEXT("victory")?TEXT("胜利 · 已结算"):P==TEXT("defeat")?TEXT("本局结束 · 已结算"):P==TEXT("confirmbuy")?TEXT("确认购买"):P==TEXT("confirmreturn")?TEXT("返回据点？"):P==TEXT("savefailed")?TEXT("保存失败，货币未到账"):TEXT("暂停");
        Text(Title,260,135,24,Gold);
        if(P==TEXT("research")) {
            Text(TEXT("每次只切换一项，观察像素清晰度、立体感和角色融入。"),260,185,14,Muted);
            Button(TEXT("ortho"),World->bPerspective?TEXT("F1 透视镜头"):TEXT("F1 正交镜头"),270,230,330);
            Button(TEXT("lit"),World->bLitSprites?TEXT("F2 角色接受光照"):TEXT("F2 角色自发光"),640,230,330);
            Button(TEXT("upright"),World->bUprightSprites?TEXT("F3 竖直角色平面"):TEXT("F3 完全面向相机"),270,280,330);
            Button(TEXT("tilt"),FString::Printf(TEXT("F4 俯角 %.0f°"),World->CameraPitch),640,280,330);
            Button(TEXT("dof"),World->bDepthOfField?TEXT("F5 景深开启"):TEXT("F5 景深关闭"),270,330,330);
            Text(TEXT("[ / ] 调整视野宽度；正交默认 2844 cm。"),270,385,15);
            Text(TEXT("默认：48°斜俯视 + 正交 + 清晰像素 + 3D光影。"),270,420,15,Teal);
            Button(TEXT("tune"),World->bTune001B?TEXT("TUNE-001B 测试值"):TEXT("原始战斗基线"),270,470,330,!World->bCombat);
            Button(TEXT("drop"),World->bDrop001?TEXT("随机材料 15.4%"):TEXT("随机材料 22%"),640,470,330,!World->bCombat);
            Text(TEXT("测试值切换仅限据点；正交视角下景深差异可能不明显。"),270,530,13,Muted);
        } else if(P==TEXT("alchemy")) {
            Text(TEXT("左侧炼金炉 · 右侧背包；点击或拖入1个，点击炉内材料取回"),260,180,13,Muted);
            Box(265,205,390,250,FLinearColor(.06f,.13f,.14f));
            int Total=0;for(int V:World->Selected) Total+=V;
            Text(FString::Printf(TEXT("炼金炉  投入 %d / 10"),Total),280,220,19,Gold);
            int Next=-1;if(World->TutorialActive() && World->TutorialSkill<0) for(int I=0;I<3;I++) if(World->Selected[I]==0) {Next=I;break;}
            for(int I=0;I<6;I++) {
                if(I<3) {
                    Button(FString::Printf(TEXT("sub%d"),I),FString::Printf(TEXT("%s ×%d  点击取回"),MaterialNames[I],World->Selected[I]),280,265+I*48,355,World->Selected[I]>0);
                    Button(FString::Printf(TEXT("material%d"),I),FString::Printf(TEXT("%s%s  可用%d"),Next==I?TEXT("→ "):TEXT(""),MaterialNames[I],World->Inventory[I]-World->Selected[I]),700,220+I*72,300,World->Inventory[I]>World->Selected[I] && (!World->TutorialActive() || (World->TutorialSkill<0 && World->Selected[I]<1)));
                } else {
                    Text(FString::Printf(TEXT("%s %d 已投%d"),MaterialNames[I],World->Inventory[I]-World->Selected[I],World->Selected[I]),270+(I-3)*250,442,12,Muted);
                    Button(FString::Printf(TEXT("add%d"),I),TEXT("+"),270+(I-3)*250,465,60,!World->TutorialActive());
                    Button(FString::Printf(TEXT("sub%d"),I),TEXT("-"),340+(I-3)*250,465,60,World->Selected[I]>0);
                }
            }
            TArray<int32> Options;TArray<float> Chances;FString Reason;int Combination;
            bool Valid=World->CraftOptions(Options,Chances,Reason,Combination);
            FString Probability;
            if(Valid && Combination>=0) {
                for(int Q=0;Q<3;Q++) {int I=Options.Find(CombinationSkills[Combination][Q]);Probability+=FString::Printf(TEXT("%s %.1f%%  "),Q==0?TEXT("低"):Q==1?TEXT("中"):TEXT("高"),I>=0?Chances[I]:0);}
            } else if(Valid) Probability=TEXT("精英专属固定配方 · 100%");
            else Probability=TEXT("投料后显示本次品质概率");
            Text(Probability,280,413,13,Teal);
            if(Valid) Button(TEXT("craft"),TEXT("开始炼金"),270,515,230);
            Button(TEXT("clear"),TEXT("清空投料"),525,515,230);Button(TEXT("codex"),TEXT("图鉴"),780,515,220);
            Text(Reason.IsEmpty()?(World->TutorialActive()?TEXT("首次限定三料各1个，品质正常随机；合成后关闭界面体验群攻"):TEXT("材料种类决定组合，总量影响品质；生成结果后扣除材料")):Reason,270,565,12,Gold);
            if(DragMaterial>=0) {float MX,MY;GetOwningPlayerController()->GetMousePosition(MX,MY);Text(MaterialNames[DragMaterial],MX/S+15,MY/S,16,Gold);}
        } else if(P==TEXT("codex")) {
            Button(TEXT("codexprev"),TEXT("上一页"),270,178,130);Button(TEXT("codexnext"),TEXT("下一页"),870,178,130);
            Text(FString::Printf(TEXT("%d/4  组合 / 技能 / 连锁 / 精英"),World->CodexPage+1),430,185,14,Muted);
            if(World->CodexPage==0) for(int C=0;C<7;C++) {
                bool Known=World->Progress->Combinations.Contains(C);
                Text(Known?CombinationNames[C]:TEXT("未发现的材料组合"),270,235+C*43,16,Known?Gold:Muted);
                Text(Known?TEXT("三个品质结果；材料比例不改变组合"):TEXT("尝试不同普通材料种类"),500,238+C*43,12,Muted);
            }
            if(World->CodexPage==1) for(int C=0;C<7;C++) for(int Q=0;Q<3;Q++) {
                int K=CombinationSkills[C][Q];bool Known=World->Progress->Recipes.Contains(K);
                Text(Known?FString::Printf(TEXT("%s  %s"),Q==0?TEXT("低"):Q==1?TEXT("中"):TEXT("高"),SkillNames[K]):TEXT("未发现的技能"),270+Q*250,235+C*43,14,Known?Gold:Muted);
            }
            if(World->CodexPage==2) for(int C=0;C<10;C++) {
                const auto& K=Chains[C];bool Known=World->Progress->ChainsV2.Contains(C);
                int X=270+(C%2)*380,Y=235+(C/2)*62;
                Text(K.Name,X,Y,15,Gold);
                Text(Known?FString::Printf(TEXT("%s + %s / %.0fs"),SkillNames[K.A],SkillNames[K.B],K.CD):TEXT("同时装备互补技能，触发后揭示条件"),X,Y+25,11,Known?Teal:Muted);
                if(Known) Text(FString::Printf(TEXT("伤害%.0f  %s%.1f  减速%.0f%%/%.1fs"),K.Damage,K.Targets?TEXT("目标数"):TEXT("半径"),K.Targets?float(K.Targets):K.Radius/100,(1-K.Factor)*100,K.Slow),X,Y+43,10,Muted);
            }
            if(World->CodexPage==3) for(int K=7;K<=9;K++) {
                bool Known=World->Progress->Recipes.Contains(K);int Y=240+(K-7)*95;
                Text(Known?SkillNames[K]:TEXT("未发现的精英配方"),270,Y,16,Known?Gold:Muted);
                if(Known) {FString Cost;for(int M=0;M<6;M++) if(Recipes[K][M]) Cost+=FString::Printf(TEXT("%s×%d "),MaterialNames[M],Recipes[K][M]);Text(Cost,270,Y+25,12);Button(FString::Printf(TEXT("recipe%d"),K),TEXT("填入素材"),780,Y,220,World->bCombat && !World->TutorialActive());}
            }
        } else if(P==TEXT("skills")) {
            Text(TEXT("选中储备技能，再选装备位交换；原技能放回储备。"),260,185,14,Muted);
            for(int i=0;i<6;i++) {
                bool Has=World->Equipped.IsValidIndex(i); FString Label=Has?FString::Printf(TEXT("%d %s Lv.%d"),i+1,SkillNames[World->Equipped[i]],World->Levels[World->Equipped[i]]):TEXT("空装备位");
                Button(FString::Printf(TEXT("equip%d"),i),Label,270,225+i*48,330,World->SelectedBag>=0 && i!=0);
                bool HasBag=World->Bag.IsValidIndex(i);
                Button(FString::Printf(TEXT("bag%d"),i),HasBag?FString::Printf(TEXT("%s %s"),World->SelectedBag==i?TEXT("> "):TEXT(""),SkillNames[World->Bag[i]]):TEXT("空储备位"),640,225+i*48,330,HasBag);
            }
        } else if(P==TEXT("talents")) {
            Text(FString::Printf(TEXT("永久金币 %d；前一个天赋达到 Lv.1 即解锁下一个。"),World->Progress->Coins),260,185,14,Muted);
            for(int i=0;i<4;i++) {
                int L=World->Progress->Talents[i]; bool Open=i==0 || World->Progress->Talents[i-1]>=1;
                Text(FString::Printf(TEXT("%d  %s  Lv.%d/5 %s"),i+1,TalentNames[i],L,Open?TEXT(""):TEXT("锁定")),275,235+i*72,18);
                Button(FString::Printf(TEXT("buy%d"),i),L>=5?TEXT("已满级"):FString::Printf(TEXT("购买 %d 金币"),Prices[i][L]),730,225+i*72,230,Open && L<5);
            }
        } else if(P==TEXT("level")) {
            Text(TEXT("腐化林地 · 固定地图 · 自动战斗与炼金"),270,225,22);
            Text(TEXT("5:00 预警，5:10 最终 BOSS；击败 BOSS 胜利。"),270,280,16,Muted);
            Text(TEXT("当前敌人表现及 BOSS 招式为可玩原型，详见实现对照。"),270,320,14,Gold);
            Button(TEXT("start"),TEXT("进入关卡"),270,420,300);
        } else if(P==TEXT("confirmbuy") && World->PendingTalent>=0) {
            int I=World->PendingTalent,L=World->Progress->Talents[I];
            Text(FString::Printf(TEXT("%s：Lv.%d → Lv.%d，花费 %d 金币。"),TalentNames[I],L,L+1,Prices[I][L]),270,250,20);
            Button(TEXT("confirmbuy"),TEXT("确认购买并保存"),270,350,300); Button(TEXT("talents"),TEXT("取消"),620,350,200);
        } else if(P==TEXT("confirmreturn")) {
            Text(TEXT("已拾取金币结算；本局材料与技能清空。"),270,260,20);
            Button(TEXT("village"),TEXT("确认返回"),270,360,300); Button(TEXT("close"),TEXT("继续战斗"),620,360,200);
        } else if(P==TEXT("victory") || P==TEXT("defeat")) {
            Text(FString::Printf(TEXT("生存 %02d:%02d   击败 %d   炼制 %d   连锁 %d"),int(World->RunTime)/60,int(World->RunTime)%60,World->Kills,World->CraftCount,World->ChainCount),270,250,20);
            Text(FString::Printf(TEXT("本局到账 %d 金币；配方与连锁发现永久保留。"),World->ResultCoins),270,300,18,Teal);
            Button(TEXT("village"),TEXT("返回据点"),270,420,300);
        } else if(P==TEXT("savefailed")) {
            Text(TEXT("本局金币仍待结算。重试成功后才能离开。"),270,250,20,Gold);
            Button(TEXT("retry"),TEXT("重试保存"),270,350,300);
        } else {
            Button(TEXT("close"),TEXT("继续"),270,230,300); Button(TEXT("codex"),TEXT("配方图鉴"),270,285,300);
            if(World->bCombat) {Button(TEXT("alchemy"),TEXT("炼金台"),640,230,300); Button(TEXT("return"),TEXT("返回据点"),640,285,300);}
            else {Button(TEXT("talents"),TEXT("永久成长"),640,230,300); Button(TEXT("level"),TEXT("关卡选择"),640,285,300);}
        }
    }
    if(World->ToastTime>0) {Box(250,610,780,36,FLinearColor(0.03f,0.07f,0.075f,0.95f));Text(World->Toast,270,619,14,Gold);}
}
