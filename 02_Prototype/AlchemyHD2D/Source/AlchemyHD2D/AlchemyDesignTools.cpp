#include "AlchemyDesignTools.h"
#include "AlchemyWorld.h"
#include "Engine/StaticMesh.h"
#include "Engine/World.h"
#include "Engine/Level.h"
#include "Modules/ModuleManager.h"
#include "Engine/Texture2D.h"
#include "EngineUtils.h"
#include "Components/SceneComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "UObject/ConstructorHelpers.h"
#if WITH_EDITOR
#include "AssetRegistry/AssetRegistryModule.h"
#include "Editor.h"

#include "FileHelpers.h"
#include "ScopedTransaction.h"
#include "Subsystems/AssetEditorSubsystem.h"
#include "UObject/SavePackage.h"
#include "Misc/PackageName.h"
#endif

namespace {
template<class T> bool Read(UDataTable* Table,TArray<T>& Out,FString& Error) {
    Out.Empty();
    if(!Table || Table->GetRowStruct()!=T::StaticStruct()) {Error=TEXT("缺少数据表或行结构不匹配");return false;}
    for(int32 I=0;I<Table->GetRowMap().Num();I++) {
        const T* Row=Table->FindRow<T>(FName(*FString::FromInt(I)),TEXT("AlchemyDesign"),false);
        if(!Row) {Error=FString::Printf(TEXT("%s：行ID必须连续，从0开始；缺少%d"),*Table->GetName(),I);return false;}
        Out.Add(*Row);
    }
    return true;
}
}

bool AlchemyDesign::ReadTables(UDataTable* S,UDataTable* R,UDataTable* C,UDataTable* Q,TArray<FAlchemySkillRow>& Skills,TArray<FAlchemyRecipeRow>& Recipes,TArray<FAlchemyChainRow>& Chains,TArray<FAlchemyQualityRow>& Quality,FString& Error) {
    if(!Read(S,Skills,Error)||!Read(R,Recipes,Error)||!Read(C,Chains,Error)||!Read(Q,Quality,Error)) return false;
    if(Skills.Num()<25 || Recipes.Num()<10 || Chains.Num()<10 || Quality.Num()!=8) {Error=TEXT("保留原25技能、7普通+3精英配方，品质权重须8行（投入3–10）");return false;}
    const auto ValidSkill=[&](int32 I){return Skills.IsValidIndex(I);};
    for(int32 I=0;I<Skills.Num();I++) {
        const auto& K=Skills[I];
        if(K.Name.IsEmpty() || !FMath::IsFinite(K.Damage+K.CD+K.Range+K.Radius+K.Slow+K.Factor+K.EffectScale+K.ProjectileSpeed+K.CastLife+K.HitLife) || K.Damage<0 || K.CD<=0 || K.Range<=0 || K.Radius<0 || K.Slow<0 || K.Factor<=0 || K.Factor>1 || K.Targets<1 || K.EffectScale<0 || K.ProjectileSpeed<=0 || K.CastLife<=0 || K.HitLife<=0) {Error=FString::Printf(TEXT("技能行%d：名称、数值或目标数非法"),I);return false;}
    }
    TSet<int32> Masks;
    for(int32 I=0;I<Recipes.Num();I++) {
        const auto& K=Recipes[I];
        if(!ValidSkill(K.LowSkill) || (!K.bElite && (!ValidSkill(K.MidSkill)||!ValidSkill(K.HighSkill)||K.LowSkill==K.MidSkill||K.MidSkill==K.HighSkill||K.LowSkill==K.HighSkill))) {Error=FString::Printf(TEXT("配方行%d：技能ID无效或品质结果重复"),I);return false;}
        if(I<7) {if(K.bElite || K.Mask<1 || K.Mask>7 || Masks.Contains(K.Mask)) {Error=TEXT("普通配方0–6的Mask须覆盖1–7且不重复（火=1、露=2、魔=4）");return false;} Masks.Add(K.Mask);}
        if(I>=7) {
            int Total=0;bool Special=false;
            if(!K.bElite || K.Costs.Num()!=6) {Error=TEXT("精英配方需启用bElite并填写六类材料");return false;}
            for(int M=0;M<6;M++) {if(K.Costs[M]<0 || K.Costs[M]>10) {Error=TEXT("精英材料数量须0–10");return false;} Total+=K.Costs[M];Special |= M>=3 && K.Costs[M]>0;}
            if(Total<3 || Total>10 || !Special) {Error=TEXT("精英配方总量须3–10且包含精英材料");return false;}
        }
    }
    for(int32 I=0;I<Chains.Num();I++) {
        const auto& K=Chains[I];
        if(!ValidSkill(K.A)||!ValidSkill(K.B)||K.A==K.B||K.CD<=0||K.Range<=0||K.Damage<0||K.Radius<0||K.Slow<0||K.Factor<=0||K.Factor>1||K.Targets<0||K.EffectScale<0||K.CastLife<=0||K.HitLife<=0 || !FMath::IsFinite(K.CD+K.Range+K.Damage+K.Radius+K.Slow+K.Factor+K.EffectScale+K.CastLife+K.HitLife)) {Error=FString::Printf(TEXT("连锁行%d：配对技能或数值非法"),I);return false;}
    }
    for(const auto& W:Quality) if(!FMath::IsFinite(W.Low+W.Mid+W.High)||W.Low<0||W.Mid<0||W.High<0||W.Low+W.Mid+W.High<=0) {Error=TEXT("品质权重必须非负且总和大于0");return false;}
    Error.Empty();return true;
}

AAlchemyTileCell::AAlchemyTileCell() {
    RootComponent=CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
    Image=CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Image"));Image->SetupAttachment(RootComponent);
    static ConstructorHelpers::FObjectFinder<UStaticMesh> Plane(TEXT("/Engine/BasicShapes/Plane.Plane"));
    Image->SetStaticMesh(Plane.Object);Image->SetCollisionEnabled(ECollisionEnabled::NoCollision);Image->SetCastShadow(false);
    PrimaryActorTick.bCanEverTick=false;
}
void AAlchemyTileCell::ApplyAppearance() {
    if(!Image) return;
    Image->SetRelativeScale3D(FVector(VisualSize.X/100,VisualSize.Y/100,1));
    Image->SetRelativeLocation(bGround?FVector::ZeroVector:FVector(0,0,VisualSize.Y*.46f));
    Image->SetRelativeRotation(bGround?FRotator::ZeroRotator:FRotationMatrix::MakeFromXZ(FVector(-1,0,0),FVector(0,-1,0)).Rotator());
    if(MaterialOverride) Image->SetMaterial(0,MaterialOverride);
    else if(Texture) {
        const TCHAR* Path=bGround?TEXT("/Game/Design/M_DesignerGround.M_DesignerGround"):TEXT("/Game/Design/M_DesignerSprite.M_DesignerSprite");
        if(auto* Parent=LoadObject<UMaterialInterface>(nullptr,Path)) {auto* M=UMaterialInstanceDynamic::Create(Parent,this);M->SetTextureParameterValue(TEXT("Image"),Texture);Image->SetMaterial(0,M);}
    }
}
void AAlchemyTileCell::OnConstruction(const FTransform& T) {Super::OnConstruction(T);ApplyAppearance();}
void AAlchemyTileCell::PostRegisterAllComponents() {Super::PostRegisterAllComponents();ApplyAppearance();}
void AAlchemyTileCell::BeginPlay() {Super::BeginPlay();ApplyAppearance();}
FVector2D AAlchemyTileCell::WorldHalfSize() const {
    const auto H=CollisionHalfSize*FVector2D(GetActorScale3D().GetAbs());
    const float A=FMath::DegreesToRadians(GetActorRotation().Yaw),C=FMath::Abs(FMath::Cos(A)),S=FMath::Abs(FMath::Sin(A));
    return FVector2D(H.X*C+H.Y*S,H.X*S+H.Y*C);
}
AAlchemyLevelDesigner::AAlchemyLevelDesigner() {RootComponent=CreateDefaultSubobject<USceneComponent>(TEXT("Root"));PrimaryActorTick.bCanEverTick=false;}
void AAlchemyLevelDesigner::ImportPalette() {
#if WITH_EDITOR
    FScopedTransaction Undo(NSLOCTEXT("Alchemy","ImportPalette","Import image palette"));Modify();
    auto& Registry=FModuleManager::LoadModuleChecked<FAssetRegistryModule>(TEXT("AssetRegistry")).Get();
    FARFilter Filter;Filter.PackagePaths.Add(TEXT("/Game/Art"));Filter.ClassPaths.Add(UTexture2D::StaticClass()->GetClassPathName());Filter.bRecursivePaths=true;
    TArray<FAssetData> Assets;Registry.GetAssets(Filter,Assets);Assets.Sort([](const auto& A,const auto& B){return A.AssetName.LexicalLess(B.AssetName);});
    for(const auto& A:Assets) {
        FString Name=A.AssetName.ToString();if(Palette.ContainsByPredicate([&](const auto& B){return B.Name==Name;})) continue;
        FAlchemyTileBrush B;B.Name=Name;B.Texture=Cast<UTexture2D>(A.GetAsset());B.bGround=Name==TEXT("Grass")||Name==TEXT("Dirt")||Name==TEXT("Stone");
        B.RandomWeight=Name==TEXT("Grass")?75:Name==TEXT("Dirt")?20:Name==TEXT("Stone")?5:0;
        B.Material=LoadObject<UMaterialInterface>(nullptr,*(TEXT("/Game/Art/M_")+Name+(B.bGround?TEXT(""):TEXT("_Lit"))));
        if(B.Texture && B.Texture->GetSizeX()>0) B.VisualSize=FVector2D(240,240.f*B.Texture->GetSizeY()/B.Texture->GetSizeX());
        Palette.Add(B);
    }
    Status=FString::Printf(TEXT("已载入%d种图片；RandomWeight>0才参与随机；可直接指定材质"),Palette.Num());MarkPackageDirty();
#endif
}
void AAlchemyLevelDesigner::ApplyBrush(AAlchemyTileCell* C,int32 I) {
    if(!C||!Palette.IsValidIndex(I)) return;
    const auto& B=Palette[I];C->Texture=B.Texture;C->MaterialOverride=B.Material;C->bGround=B.bGround;C->VisualSize=B.bGround?FVector2D(CellSize):B.VisualSize;C->ApplyAppearance();
#if WITH_EDITOR
    C->SetActorLabel(FString::Printf(TEXT("Tile_%02d_%02d_%s"),C->GridX,C->GridY,*B.Name));C->SetFolderPath(TEXT("Alchemy/EditableCells"));
#endif
    C->MarkPackageDirty();
}
void AAlchemyLevelDesigner::Randomize() {
#if WITH_EDITOR
    if(!GetWorld() || GetWorld()->IsGameWorld()) return;
    FScopedTransaction Undo(NSLOCTEXT("Alchemy","RerollGrid","Randomize seed and grid"));Modify();
    const int32 Previous=Seed;
    Seed=static_cast<int32>(FGuid::NewGuid().A & MAX_int32);
    if(Seed==Previous) Seed^=1;
    GenerateFromSeed();
#endif
}
void AAlchemyLevelDesigner::GenerateFromSeed() {
#if WITH_EDITOR
    if(!GetWorld() || GetWorld()->IsGameWorld()) return;
    float Sum=0;for(const auto& B:Palette) Sum+=FMath::Max(0.f,B.RandomWeight);
    if(Sum<=0) {Status=TEXT("请先读取素材，并给至少一个笔刷设置RandomWeight");return;}
    FScopedTransaction Undo(NSLOCTEXT("Alchemy","GenerateGrid","Generate alchemy grid"));Modify();GetLevel()->Modify();
    TSet<FIntPoint> Locked;TArray<AAlchemyTileCell*> Remove;
    for(TActorIterator<AAlchemyTileCell> It(GetWorld());It;++It) if(It->GetOwner()==this && It->GridX>=0 && It->GridY>=0) {if(It->bLockRandom) Locked.Add(FIntPoint(It->GridX,It->GridY));else Remove.Add(*It);}
    for(auto* C:Remove) {C->Modify();GetWorld()->DestroyActor(C,true,true);}
    FRandomStream R(Seed);int32 Added=0;
    for(int Y=0;Y<FMath::Clamp(Rows,1,64);Y++) for(int X=0;X<FMath::Clamp(Columns,1,64);X++) {
        float Roll=R.FRand()*Sum;int Choice=0;for(int I=0;I<Palette.Num();I++) if(Palette[I].RandomWeight>0 && (Roll-=Palette[I].RandomWeight)<=0){Choice=I;break;}
        if(Locked.Contains(FIntPoint(X,Y))) continue;
        FActorSpawnParameters P;P.Owner=this;P.OverrideLevel=GetLevel();P.ObjectFlags|=RF_Transactional;
        auto* C=GetWorld()->SpawnActor<AAlchemyTileCell>(GetActorTransform().TransformPosition(FVector((X-(Columns-1)*.5f)*CellSize,(Y-(Rows-1)*.5f)*CellSize,1)),FRotator::ZeroRotator,P);
        if(C) {C->AttachToActor(this,FAttachmentTransformRules::KeepWorldTransform);C->GridX=X;C->GridY=Y;C->Modify();ApplyBrush(C,Choice);Added++;}
    }
    Status=FString::Printf(TEXT("生成%d格，保留%d个锁定格；Seed=%d。选中格子可改图、材质、大小、碰撞"),Added,Locked.Num(),Seed);MarkPackageDirty();
#endif
}
void AAlchemyLevelDesigner::PaintCell() {
#if WITH_EDITOR
    if(!Palette.IsValidIndex(BrushIndex)) {Status=TEXT("BrushIndex无效");return;}
    const int32 X=FMath::RoundToInt(PaintCursor.X/CellSize+(Columns-1)*.5f),Y=FMath::RoundToInt(PaintCursor.Y/CellSize+(Rows-1)*.5f);
    FScopedTransaction Undo(NSLOCTEXT("Alchemy","PaintCell","Paint grid cell"));
    for(TActorIterator<AAlchemyTileCell> It(GetWorld());It;++It) if(It->GetOwner()==this && It->GridX==X && It->GridY==Y) {It->Modify();ApplyBrush(*It,BrushIndex);It->bLockRandom=true;Status=FString::Printf(TEXT("已修改并锁定(%d,%d)"),X,Y);return;}
    Status=TEXT("光标不在已生成格子内");
#endif
}
void AAlchemyLevelDesigner::RefreshCells() {for(TActorIterator<AAlchemyTileCell> It(GetWorld());It;++It) if(It->GetOwner()==this) It->ApplyAppearance();}
void AAlchemyLevelDesigner::SetRuntimeVisible(bool Visible) {SetActorHiddenInGame(!Visible);
    for(TActorIterator<AActor> It(GetWorld());It;++It) if(It->ActorHasTag(TEXT("AlchemyEditorPreviewLight")) && It->GetRootComponent()) It->GetRootComponent()->SetVisibility(false,true);
    for(TActorIterator<AAlchemyTileCell> It(GetWorld());It;++It) if(It->GetOwner()==this) It->SetActorHiddenInGame(!Visible);}
void AAlchemyLevelDesigner::OpenTable(UDataTable* Table) {
#if WITH_EDITOR
    if(Table && GEditor) GEditor->GetEditorSubsystem<UAssetEditorSubsystem>()->OpenEditorForAsset(Table);
#endif
}
void AAlchemyLevelDesigner::OpenSkills(){OpenTable(SkillTable);} void AAlchemyLevelDesigner::OpenRecipes(){OpenTable(RecipeTable);}
void AAlchemyLevelDesigner::OpenChains(){OpenTable(ChainTable);} void AAlchemyLevelDesigner::OpenQuality(){OpenTable(QualityTable);}
bool AAlchemyLevelDesigner::ValidateLibrary() {
    TArray<FAlchemySkillRow> S;TArray<FAlchemyRecipeRow> R;TArray<FAlchemyChainRow> C;TArray<FAlchemyQualityRow> Q;FString Error;
    bool OK=AlchemyDesign::ReadTables(SkillTable,RecipeTable,ChainTable,QualityTable,S,R,C,Q,Error);
#if WITH_EDITOR
    if(OK) for(const TCHAR* Name:{TEXT("ImportPalette"),TEXT("Randomize"),TEXT("GenerateFromSeed"),TEXT("PaintCell"),TEXT("RefreshCells"),TEXT("OpenSkills"),TEXT("OpenRecipes"),TEXT("OpenChains"),TEXT("OpenQuality"),TEXT("ValidateDesign"),TEXT("CreateStarterTables"),TEXT("SaveDesign")}) {
        UFunction* F=FindFunction(FName(Name));
        if(!F || !F->GetBoolMetaData(TEXT("CallInEditor")) || F->ParmsSize!=0) {OK=false;Error=FString::Printf(TEXT("编辑按钮%s不可见：须CallInEditor且参数空间为0"),Name);break;}
    }
#endif
    Status=OK?FString::Printf(TEXT("校验通过：%d技能、%d配方、%d连锁、%d品质行"),S.Num(),R.Num(),C.Num(),Q.Num()):Error;
    UE_LOG(LogTemp,Display,TEXT("ALCHEMY_DESIGN_VALIDATE %s %s"),OK?TEXT("PASS"):TEXT("FAIL"),*Status);return OK;
}
void AAlchemyLevelDesigner::CreateStarterTables() {
#if WITH_EDITOR
    AAlchemyWorld::CreateDesignTables();
    SkillTable=LoadObject<UDataTable>(nullptr,TEXT("/Game/Design/DT_Skills.DT_Skills"));RecipeTable=LoadObject<UDataTable>(nullptr,TEXT("/Game/Design/DT_Recipes.DT_Recipes"));
    ChainTable=LoadObject<UDataTable>(nullptr,TEXT("/Game/Design/DT_Chains.DT_Chains"));QualityTable=LoadObject<UDataTable>(nullptr,TEXT("/Game/Design/DT_Quality.DT_Quality"));
    MarkPackageDirty();ValidateLibrary();
#endif
}
void AAlchemyLevelDesigner::SaveDesign() {
#if WITH_EDITOR
    if(!ValidateLibrary()) return;
    bool OK=true;for(auto* T:{SkillTable.Get(),RecipeTable.Get(),ChainTable.Get(),QualityTable.Get()}) if(T) {
        FSavePackageArgs A;A.TopLevelFlags=RF_Public|RF_Standalone;OK &= UPackage::SavePackage(T->GetOutermost(),T,*FPackageName::LongPackageNameToFilename(T->GetOutermost()->GetName(),FPackageName::GetAssetPackageExtension()),A);
    }
    OK &= FEditorFileUtils::SaveLevel(GetLevel());Status=OK?TEXT("关卡和技能表已保存"):TEXT("保存失败，请查看Output Log");
#endif
}
