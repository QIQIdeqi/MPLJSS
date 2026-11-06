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
    Image->SetRelativeLocation(bGround?FVector::ZeroVector:FVector(0,0,VisualSize.Y*(FootFraction-.5f)));
    Image->SetRelativeRotation(bGround?FRotator::ZeroRotator:FRotationMatrix::MakeFromXZ(FVector(-1,0,0),FVector(0,-1,0)).Rotator());
    if(!bGround)if(const auto Designer=Cast<AAlchemyLevelDesigner>(GetOwner());Designer && Designer->bCameraFacingObjects){
        const FRotationMatrix CameraBasis(FRotator(-60,90,0));
        Image->SetWorldRotation(FRotationMatrix::MakeFromXZ(CameraBasis.GetUnitAxis(EAxis::Y),-CameraBasis.GetUnitAxis(EAxis::X)).Rotator());
        // Plane UV-up is local -Y. Use the actual scaled visual plane so its configured foot remains at the actor origin.
        const FVector CenterOffset=Image->GetComponentTransform().TransformVector(FVector(0,-100*(FootFraction-.5f),0));
        Image->SetWorldLocation(GetActorLocation()+CenterOffset);
    }
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
    const auto& B=Palette[I];C->Texture=B.Texture;C->MaterialOverride=B.Material;C->bGround=B.bGround;C->BrushName=B.Name;
    C->VisualSize=B.bGround?FVector2D(CellSize):B.VisualSize;C->FootFraction=B.FootFraction;C->bBossInterior=B.bBossInterior;
    C->bBlocksMovement=!B.bGround && B.bBlocksMovement;C->CollisionHalfSize=B.CollisionHalfSize;C->ApplyAppearance();
#if WITH_EDITOR
    if(!GetWorld()->IsGameWorld()){
    C->SetActorLabel(FString::Printf(TEXT("Tile_%02d_%02d_%s"),C->GridX,C->GridY,*B.Name));C->SetFolderPath(TEXT("Alchemy/EditableCells"));
    C->MarkPackageDirty();}
#endif
}
void AAlchemyLevelDesigner::Randomize() {
#if WITH_EDITOR
    if(!GetWorld() || GetWorld()->IsGameWorld()) return;
    FScopedTransaction Undo(NSLOCTEXT("Alchemy","RerollGrid","Randomize seed and grid"));Modify();
    const int32 Previous=Seed;
    Seed=static_cast<int32>(FGuid::NewGuid().A & MAX_int32);
    if(Seed==Previous) Seed^=1;
    if(!GenerateLayers(LayerMask))Seed=Previous;
#endif
}
void AAlchemyLevelDesigner::GenerateFromSeed() {
    GenerateLayers(LayerMask);
}
void AAlchemyLevelDesigner::RandomizeGround(){
#if WITH_EDITOR
    if(!GetWorld() || GetWorld()->IsGameWorld())return;
    FScopedTransaction Undo(NSLOCTEXT("Alchemy","RerollGround","Reroll ground layer"));Modify();
    const int32 Previous=GroundSeedOffset;GroundSeedOffset=int32(FGuid::NewGuid().A&MAX_int32);if(GroundSeedOffset==Previous)GroundSeedOffset^=1;
    if(!GenerateLayers(1))GroundSeedOffset=Previous;
#endif
}
void AAlchemyLevelDesigner::RandomizeObjects(){
#if WITH_EDITOR
    if(!GetWorld() || GetWorld()->IsGameWorld())return;
    FScopedTransaction Undo(NSLOCTEXT("Alchemy","RerollObjects","Reroll object layer"));Modify();
    const int32 Previous=ObjectSeedOffset;ObjectSeedOffset=int32(FGuid::NewGuid().A&MAX_int32);if(ObjectSeedOffset==Previous)ObjectSeedOffset^=1;
    if(!GenerateLayers(2))ObjectSeedOffset=Previous;
#endif
}
bool AAlchemyLevelDesigner::PlacementAllowed(FVector Local,FVector2D Half,bool Blocking,bool BossInterior) const {
    if(FMath::Abs(Local.X)+Half.X>PlayHalfSize.X || FMath::Abs(Local.Y)+Half.Y>PlayHalfSize.Y)return false;
    const FVector2D Point(Local.X,Local.Y);
    for(FVector2D End:ProtectedPoints){
        const double T=End.SizeSquared()>0?FMath::Clamp(FVector2D::DotProduct(Point,End)/End.SizeSquared(),0.,1.):0.;
        if(FVector2D::Distance(Point,End*T)<ProtectedPathHalfWidth+Half.Size())return false;
    }
    if(bBossLayout && (Blocking || !BossInterior)){
        const FVector2D Nearest(FMath::Max(0.,FMath::Abs(Local.X)-Half.X-ObjectSpacing),FMath::Max(0.,FMath::Abs(Local.Y)-Half.Y-ObjectSpacing));
        if(FMath::Square(Nearest.X/BossHalfSize.X)+FMath::Square(Nearest.Y/BossHalfSize.Y)<=1)return false;
    }
    if(CanPlaceObject){
        const FBox Bounds=FBox(FVector(Local.X-Half.X,Local.Y-Half.Y,0),FVector(Local.X+Half.X,Local.Y+Half.Y,0)).TransformBy(GetActorTransform());
        if(!CanPlaceObject(GetActorTransform().TransformPosition(Local),FVector2D(Bounds.GetExtent())))return false;
    }
    return true;
}
bool AAlchemyLevelDesigner::GenerateLayers(int32 InLayerMask) {
    const auto Fail=[&](FString Why){Status=MoveTemp(Why);UE_LOG(LogTemp,Warning,TEXT("ALCHEMY_LAYER_GENERATE_FAIL seed=%d ground=%d objects=%d boss=%d mask=%d %s"),Seed,GroundSeedOffset,ObjectSeedOffset,bBossLayout,InLayerMask,*Status);return false;};
    if(!GetWorld() || InLayerMask<1 || InLayerMask>3 || Columns<1 || Columns>64 || Rows<1 || Rows>64 || !FMath::IsFinite(CellSize) || CellSize<100 || PlayHalfSize.X<=0 || PlayHalfSize.Y<=0 || GroundPatchSize<1 || GroundPatchSize>16 || !FMath::IsFinite(ObjectDensity+ObjectSpacing+ProtectedPathHalfWidth) || ObjectDensity<0 || ObjectDensity>1 || ObjectSpacing<0 || ProtectedPathHalfWidth<100 || BossHalfSize.X<=0 || BossHalfSize.Y<=0)return Fail(TEXT("两层生成参数无效；原布局保留"));
    const bool Editor=!GetWorld()->IsGameWorld();
#if WITH_EDITOR
    TUniquePtr<FScopedTransaction> Undo;
    if(Editor){Undo=MakeUnique<FScopedTransaction>(NSLOCTEXT("Alchemy","GenerateLayers","Generate ground and objects"));Modify();GetLevel()->Modify();}
#endif
    const int32 GridSlots=Columns*Rows;
    TArray<int32> Pools[2];float Totals[2]={0,0};
    bool LayerLimited[2]={false,false};
    TArray<int32> Minimum, Maximum, Counts;
    Minimum.Init(0,Palette.Num());
    Maximum.Init(GridSlots,Palette.Num());
    Counts.Init(0,Palette.Num());
    for(int32 I=0;I<Palette.Num();I++){
        const auto& B=Palette[I];if(!FMath::IsFinite(B.RandomWeight)||B.RandomWeight<0)return Fail(FString::Printf(TEXT("笔刷%s权重无效"),*B.Name));
        const int32 Layer=B.bGround?0:1;
        if ((InLayerMask&(1<<Layer)) && (B.CountRange!=FIntPoint(-1,-1) || B.DensityRange!=FVector2D(-1,-1))) {
            const auto ValidDensity=[](double Value){return Value==-1. || (Value>=0. && Value<=1.);};
            if (B.CountRange.X<-1 || B.CountRange.Y<-1 || !ValidDensity(B.DensityRange.X) || !ValidDensity(B.DensityRange.Y)) {
                return Fail(FString::Printf(TEXT("笔刷%s的数量/密度端点无效"),*B.Name));
            }
            int32 Named=0;
            for (const auto& Other:Palette) Named+=(Other.bGround==B.bGround && Other.Name==B.Name);
            if (B.Name.IsEmpty() || Named!=1) {
                return Fail(FString::Printf(TEXT("范围笔刷%s需要同层唯一名称，以便统计锁定格"),*B.Name));
            }
            LayerLimited[Layer]=true;
            Minimum[I]=FMath::Max(0,B.CountRange.X);
            if (B.CountRange.Y>=0) Maximum[I]=FMath::Min(GridSlots,B.CountRange.Y);
            // Snap numerical noise around an integer slot before taking the inclusive limits.
            const auto SlotsAtDensity=[&](double Value) {
                const double Slots=Value*GridSlots;
                const double Rounded=FMath::RoundToDouble(Slots);
                return FMath::IsNearlyEqual(Slots,Rounded,1.e-9)?Rounded:Slots;
            };
            if (B.DensityRange.X>=0.) Minimum[I]=FMath::Max(Minimum[I],FMath::CeilToInt32(SlotsAtDensity(B.DensityRange.X)));
            if (B.DensityRange.Y>=0.) Maximum[I]=FMath::Min(Maximum[I],FMath::FloorToInt32(SlotsAtDensity(B.DensityRange.Y)));
            if (Minimum[I]>Maximum[I]) {
                return Fail(FString::Printf(TEXT("笔刷%s的数量/密度无共同范围（%d至%d格）"),*B.Name,Minimum[I],Maximum[I]));
            }
        }
        if(B.RandomWeight==0)continue;
        if((!B.Texture && !B.Material) || !FMath::IsFinite(B.VisualSize.X+B.VisualSize.Y+B.FootFraction+B.CollisionHalfSize.X+B.CollisionHalfSize.Y+B.ScaleRange.X+B.ScaleRange.Y+B.YawRange.X+B.YawRange.Y) || B.VisualSize.X<=0 || B.VisualSize.Y<=0 || B.CollisionHalfSize.X<0 || B.CollisionHalfSize.Y<0 || B.FootFraction<0 || B.FootFraction>1 || B.ScaleRange.X<=0 || B.ScaleRange.Y<B.ScaleRange.X || B.YawRange.Y<B.YawRange.X)return Fail(FString::Printf(TEXT("笔刷%s素材/占地/脚点无效"),*B.Name));
        Pools[Layer].Add(I);Totals[Layer]+=B.RandomWeight;
    }
    if(!FMath::IsFinite(Totals[0]+Totals[1]))return Fail(TEXT("素材权重总和无效；原布局保留"));
    if((InLayerMask&1) && Pools[0].IsEmpty())return Fail(TEXT("地面池为空；旧地面保留"));
    const auto Pick=[&](int Layer,FRandomStream& Stream){float Roll=Stream.FRand()*Totals[Layer];for(int I:Pools[Layer])if((Roll-=Palette[I].RandomWeight)<=0)return I;return Pools[Layer].Last();};
    const auto PickAvailable=[&](int32 Layer,FRandomStream& Stream) {
        if (!LayerLimited[Layer]) return Pick(Layer,Stream);
        float Total=0;
        int32 Last=INDEX_NONE;
        for (const int32 I:Pools[Layer]) if (Counts[I]<Maximum[I]) {
            Total+=Palette[I].RandomWeight;
            Last=I;
        }
        if (Last==INDEX_NONE) return Last;
        float Roll=Stream.FRand()*Total;
        for (const int32 I:Pools[Layer]) if (Counts[I]<Maximum[I] && (Roll-=Palette[I].RandomWeight)<=0.f) return I;
        return Last;
    };
    TArray<AAlchemyTileCell*> Remove,Keep;TMap<FIntPoint,AAlchemyTileCell*> Ground,Objects;
    for(TActorIterator<AAlchemyTileCell> It(GetWorld());It;++It)if(It->GetOwner()==this){
        auto C=*It;const int Bit=C->bGround?1:2;
        if(C->GridX>=0 && C->GridY>=0 && (InLayerMask&Bit) && !C->bLockRandom){Remove.Add(C);continue;}
        Keep.Add(C);
        if(C->GridX>=0 && C->GridY>=0){
            if(C->GridX>=Columns || C->GridY>=Rows)return Fail(FString::Printf(TEXT("保留格%s超出新网格；未解锁"),*C->GetName()));
            auto& Map=C->bGround?Ground:Objects;const FIntPoint Key(C->GridX,C->GridY);
            if(Map.Contains(Key))return Fail(FString::Printf(TEXT("同层重复锁定格(%d,%d)"),Key.X,Key.Y));Map.Add(Key,C);
        }
    }
    for (auto* Cell:Keep) {
        if (Cell->GridX<0 || Cell->GridY<0 || !LayerLimited[Cell->bGround?0:1]) continue;
        const int32 Brush=Palette.IndexOfByPredicate([&](const auto& B) {
            if (B.bGround!=Cell->bGround) return false;
            if (!Cell->BrushName.IsEmpty()) return B.Name==Cell->BrushName;
            return (B.Material && B.Material==Cell->MaterialOverride) || (B.Texture && B.Texture==Cell->Texture);
        });
        if (Brush!=INDEX_NONE) ++Counts[Brush];
    }
    for (int32 I=0;I<Palette.Num();++I) {
        if (!LayerLimited[Palette[I].bGround?0:1]) continue;
        if (Counts[I]>Maximum[I]) {
            return Fail(FString::Printf(TEXT("笔刷%s的保留格%d超过上限%d，旧层及锁定保留"),*Palette[I].Name,Counts[I],Maximum[I]));
        }
        if (Counts[I]<Minimum[I] && Palette[I].RandomWeight==0.f) {
            return Fail(FString::Printf(TEXT("笔刷%s权重为0且保留格%d未达到下限%d"),*Palette[I].Name,Counts[I],Minimum[I]));
        }
    }
    struct FPlan{int X,Y,Brush;FVector Local;float Scale,Yaw;};TArray<FPlan> Plan;
    TMap<FIntPoint,FString> GroundNames;
    for(const auto& Item:Ground){FString Name=Item.Value->BrushName;if(Name.IsEmpty())for(const auto& B:Palette)if(B.bGround && ((B.Material && B.Material==Item.Value->MaterialOverride)||(B.Texture && B.Texture==Item.Value->Texture))){Name=B.Name;break;}GroundNames.Add(Item.Key,Name);}
    const uint32 LayoutSeed=uint32(Seed)^(bBossLayout?0x53e29b17u:0x128f42abu);
    FRandomStream GroundStream(int32(LayoutSeed^uint32(GroundSeedOffset)^0x19432edbu));
    struct FPatch{FVector2D Center;int Brush;};TArray<FPatch> Patches;
    if(InLayerMask&1){
        for(int Y=0;Y<Rows;Y+=GroundPatchSize)for(int X=0;X<Columns;X+=GroundPatchSize)Patches.Add({FVector2D(X+GroundStream.FRand()*GroundPatchSize,Y+GroundStream.FRand()*GroundPatchSize),Pick(0,GroundStream)});
        for(int Y=0;Y<Rows;Y++)for(int X=0;X<Columns;X++){
            const FIntPoint Key(X,Y);if(Ground.Contains(Key))continue;
            int Choice=0;double Best=TNumericLimits<double>::Max();for(const auto& Patch:Patches){const double D=FVector2D::DistSquared(Patch.Center,FVector2D(X+.5,Y+.5));if(D<Best){Best=D;Choice=Patch.Brush;}}
            GroundNames.Add(Key,Palette[Choice].Name);Plan.Add({X,Y,Choice,FVector((X-(Columns-1)*.5)*CellSize,(Y-(Rows-1)*.5)*CellSize,1),1,0});
            if (LayerLimited[0]) ++Counts[Choice];
        }
    }
    if (LayerLimited[0]) {
        const auto Reassign=[&](FPlan& Cell,int32 Brush) {
            --Counts[Cell.Brush];
            ++Counts[Brush];
            Cell.Brush=Brush;
            GroundNames.FindChecked(FIntPoint(Cell.X,Cell.Y))=Palette[Brush].Name;
        };
        // Satisfy minima from overfull brushes first. Each transfer then fixes both constraints.
        for (const int32 Brush:Pools[0]) {
            for (const bool ExcessOnly:{true,false}) {
                for (auto& Cell:Plan) {
                    if (Counts[Brush]>=Minimum[Brush]) break;
                    const int32 Donor=Cell.Brush;
                    if (Donor==Brush || Counts[Donor]<=(ExcessOnly?Maximum[Donor]:Minimum[Donor])) continue;
                    Reassign(Cell,Brush);
                }
            }
            if (Counts[Brush]<Minimum[Brush]) {
                return Fail(FString::Printf(TEXT("笔刷%s缺少可调整地面格，数量%d未达到下限%d"),*Palette[Brush].Name,Counts[Brush],Minimum[Brush]));
            }
        }
        for (auto& Cell:Plan) {
            if (Counts[Cell.Brush]<=Maximum[Cell.Brush]) continue;
            const int32 Choice=PickAvailable(0,GroundStream);
            if (Choice==INDEX_NONE) return Fail(TEXT("地面笔刷上限合计不足以铺满网格"));
            Reassign(Cell,Choice);
        }
    }
    if(GroundNames.Num()!=Columns*Rows)return Fail(TEXT("物件层需要完整地面；请先生成地面，旧布局保留"));
    TArray<FBox2D> Occupied,Blocking;
    const auto AddObject=[&](FVector Local,FVector2D Half,bool Block){Occupied.Add(FBox2D(FVector2D(Local)-Half,FVector2D(Local)+Half));if(Block){const FBox Box=FBox(FVector(Local.X-Half.X,Local.Y-Half.Y,0),FVector(Local.X+Half.X,Local.Y+Half.Y,0)).TransformBy(GetActorTransform());Blocking.Add(FBox2D(FVector2D(Box.Min),FVector2D(Box.Max)));}};
    for(auto C:Keep)if(!C->bGround || C->bBlocksMovement){
        const FTransform Relative=C->GetActorTransform().GetRelativeTransform(GetActorTransform());const FVector Local=Relative.GetLocation();
        const FVector2D H=C->CollisionHalfSize*FVector2D(Relative.GetScale3D().GetAbs());const double Angle=FMath::DegreesToRadians(Relative.GetRotation().Rotator().Yaw);
        const FVector2D Half(H.X*FMath::Abs(FMath::Cos(Angle))+H.Y*FMath::Abs(FMath::Sin(Angle)),H.X*FMath::Abs(FMath::Sin(Angle))+H.Y*FMath::Abs(FMath::Cos(Angle)));
        if(!PlacementAllowed(Local,Half,C->bBlocksMovement,C->bBossInterior))return Fail(FString::Printf(TEXT("保留/锁定物件%s侵入保护区或非法地面"),*C->GetName()));
        const FIntPoint Key(C->GridX,C->GridY);if(C->GridX>=0)for(const auto& B:Palette)if(B.Name==C->BrushName && !B.AllowedGrounds.IsEmpty() && !B.AllowedGrounds.Contains(GroundNames.FindRef(Key)))return Fail(FString::Printf(TEXT("保留物件%s与新地类不兼容"),*C->GetName()));
        const FBox2D Box(FVector2D(Local)-Half,FVector2D(Local)+Half);for(const auto& Other:Occupied)if(Box.ExpandBy(ObjectSpacing).Intersect(Other))return Fail(FString::Printf(TEXT("保留/锁定物件%s间距冲突"),*C->GetName()));
        AddObject(Local,Half,C->bBlocksMovement);
    }
    const auto TryPlaceObject=[&](int32 Choice,FIntPoint Key,FRandomStream& CellStream) {
        const auto& B=Palette[Choice];
        if (!B.AllowedGrounds.IsEmpty() && !B.AllowedGrounds.Contains(GroundNames.FindRef(Key))) return false;
        const float Scale=CellStream.FRandRange(B.ScaleRange.X,B.ScaleRange.Y);
        const float Yaw=CellStream.FRandRange(B.YawRange.X,B.YawRange.Y);
        const float C=FMath::Abs(FMath::Cos(FMath::DegreesToRadians(Yaw)));
        const float S=FMath::Abs(FMath::Sin(FMath::DegreesToRadians(Yaw)));
        const auto H=B.CollisionHalfSize*Scale;
        const FVector2D Half(H.X*C+H.Y*S,H.X*S+H.Y*C);
        const FVector Local((Key.X-(Columns-1)*.5+CellStream.FRandRange(-.4f,.4f))*CellSize,
                            (Key.Y-(Rows-1)*.5+CellStream.FRandRange(-.4f,.4f))*CellSize,2);
        if (!PlacementAllowed(Local,Half,B.bBlocksMovement,B.bBossInterior)) return false;
        const FBox2D Box(FVector2D(Local)-Half,FVector2D(Local)+Half);
        if (Occupied.ContainsByPredicate([&](const FBox2D& Other){return Box.ExpandBy(ObjectSpacing).Intersect(Other);})) return false;
        AddObject(Local,Half,B.bBlocksMovement);
        Plan.Add({Key.X,Key.Y,Choice,Local,Scale,Yaw});
        ++Counts[Choice];
        return true;
    };
    TSet<FIntPoint> MinimumSlots;
    if (LayerLimited[1]) {
        // Reserve required objects before the ordinary density roll, using a separate deterministic stream.
        FRandomStream MinimumStream(int32(LayoutSeed^uint32(ObjectSeedOffset)^0x39a5c7d1u));
        for (const int32 Brush:Pools[1]) {
            if (Counts[Brush]>=Minimum[Brush]) continue;
            const int32 First=MinimumStream.RandHelper(GridSlots);
            for (int32 Step=0;Step<GridSlots && Counts[Brush]<Minimum[Brush];++Step) {
                const int32 Slot=(First+Step)%GridSlots;
                const FIntPoint Key(Slot%Columns,Slot/Columns);
                if (Objects.Contains(Key) || MinimumSlots.Contains(Key)) continue;
                FRandomStream CellStream(MinimumStream.RandHelper(MAX_int32));
                for (int32 Attempt=0;Attempt<12;++Attempt) {
                    if (TryPlaceObject(Brush,Key,CellStream)) {
                        MinimumSlots.Add(Key);
                        break;
                    }
                }
            }
            if (Counts[Brush]<Minimum[Brush]) {
                return Fail(FString::Printf(TEXT("笔刷%s仅找到%d个合法物件，要求%d至%d，旧层及锁定保留"),*Palette[Brush].Name,Counts[Brush],Minimum[Brush],Maximum[Brush]));
            }
        }
    }
    FRandomStream ObjectStream(int32(LayoutSeed^uint32(ObjectSeedOffset)^0x682471cfu));
    if ((InLayerMask&2) && !Pools[1].IsEmpty()) for (int Y=0;Y<Rows;Y++) for (int X=0;X<Columns;X++) {
        // Consume per-cell entropy even under locks, so locks do not reshuffle unrelated cells.
        FRandomStream CellStream(ObjectStream.RandHelper(MAX_int32));
        const FIntPoint Key(X,Y);
        if (CellStream.FRand()>=ObjectDensity || Objects.Contains(Key) || MinimumSlots.Contains(Key)) continue;
        for (int Attempt=0;Attempt<12;Attempt++) {
            const int32 Choice=PickAvailable(1,CellStream);
            if (Choice==INDEX_NONE || TryPlaceObject(Choice,Key,CellStream)) break;
        }
    }
    if(ValidateBlockingLayout && !ValidateBlockingLayout(Blocking))return Fail(TEXT("实际通路/传送候选校验失败；所有旧层及锁定内容保留"));
    TArray<AAlchemyTileCell*> Created;
    for(const auto& Item:Plan){
        FActorSpawnParameters Params;Params.Owner=this;Params.OverrideLevel=GetLevel();Params.ObjectFlags|=Editor?RF_Transactional:RF_Transient;
        auto C=GetWorld()->SpawnActor<AAlchemyTileCell>(GetActorTransform().TransformPosition(Item.Local),GetActorRotation()+FRotator(0,Item.Yaw,0),Params);
        if(!C){for(auto Added:Created)Added->Destroy();return Fail(TEXT("生成Actor失败；旧层保留"));}
        C->SetActorScale3D(GetActorScale3D()*Item.Scale);C->AttachToActor(this,FAttachmentTransformRules::KeepWorldTransform);C->GridX=Item.X;C->GridY=Item.Y;ApplyBrush(C,Item.Brush);Created.Add(C);
    }
    for(auto C:Remove){
#if WITH_EDITOR
        if(Editor)C->Modify();
#endif
        C->Destroy();
    }
#if WITH_EDITOR
    if(Editor)MarkPackageDirty();
#endif
    RefreshCells();
    Status=FString::Printf(TEXT("双层生成成功 Seed=%d mask=%d：新建%d，保留%d；地面斑块/物件独立序列"),Seed,InLayerMask,Created.Num(),Keep.Num());
    UE_LOG(LogTemp,Display,TEXT("ALCHEMY_LAYER_GENERATE_PASS %s"),*Status);return true;
}
void AAlchemyLevelDesigner::PaintCell() {
#if WITH_EDITOR
    if(!GetWorld() || GetWorld()->IsGameWorld())return;
    if(!Palette.IsValidIndex(BrushIndex)) {Status=TEXT("BrushIndex无效");return;}
    const int32 X=FMath::RoundToInt(PaintCursor.X/CellSize+(Columns-1)*.5f),Y=FMath::RoundToInt(PaintCursor.Y/CellSize+(Rows-1)*.5f);
    if(X<0 || X>=Columns || Y<0 || Y>=Rows){Status=TEXT("光标不在网格内");return;}
    const auto& Brush=Palette[BrushIndex];AAlchemyTileCell* Previous=nullptr;
    for(TActorIterator<AAlchemyTileCell> It(GetWorld());It;++It)if(It->GetOwner()==this && It->GridX==X && It->GridY==Y){
        if(It->bGround==Brush.bGround)Previous=*It;
        else if(Brush.bGround)for(const auto& B:Palette)if(B.Name==It->BrushName && !B.AllowedGrounds.IsEmpty() && !B.AllowedGrounds.Contains(Brush.Name)){Status=TEXT("该格物件不兼容此地类；未修改任一层");return;}
    }
    if(!Brush.bGround){
        bool HasGround=false;FString GroundName;
        for(TActorIterator<AAlchemyTileCell> It(GetWorld());It;++It)if(It->GetOwner()==this && It->bGround && It->GridX==X && It->GridY==Y){HasGround=true;GroundName=It->BrushName;}
        if(!HasGround || (!Brush.AllowedGrounds.IsEmpty() && !Brush.AllowedGrounds.Contains(GroundName))){Status=TEXT("该物件需要兼容地面；未修改");return;}
    }
    FScopedTransaction Undo(NSLOCTEXT("Alchemy","PaintCell","Paint grid cell"));
    FActorSpawnParameters Params;Params.Owner=this;Params.OverrideLevel=GetLevel();Params.ObjectFlags|=RF_Transactional;
    const FVector Local((X-(Columns-1)*.5f)*CellSize,(Y-(Rows-1)*.5f)*CellSize,Brush.bGround?1:2);
    auto Cell=Previous?GetWorld()->SpawnActor<AAlchemyTileCell>(AAlchemyTileCell::StaticClass(),Previous->GetActorTransform(),Params):GetWorld()->SpawnActor<AAlchemyTileCell>(GetActorTransform().TransformPosition(Local),GetActorRotation(),Params);
    if(!Cell){Status=TEXT("新格生成失败；原格保留");return;}
    if(!Previous)Cell->SetActorScale3D(GetActorScale3D());
    Cell->AttachToActor(this,FAttachmentTransformRules::KeepWorldTransform);
    Cell->GridX=X;Cell->GridY=Y;ApplyBrush(Cell,BrushIndex);
    bool Valid=true;TArray<FBox2D> Blocks;
    if(!Brush.bGround){
        const FTransform Relative=Cell->GetActorTransform().GetRelativeTransform(GetActorTransform());const FVector P=Relative.GetLocation();
        const FVector2D H=Brush.CollisionHalfSize*FVector2D(Relative.GetScale3D().GetAbs());const double A=FMath::DegreesToRadians(Relative.GetRotation().Rotator().Yaw);
        const FVector2D Half(H.X*FMath::Abs(FMath::Cos(A))+H.Y*FMath::Abs(FMath::Sin(A)),H.X*FMath::Abs(FMath::Sin(A))+H.Y*FMath::Abs(FMath::Cos(A)));
        Valid=PlacementAllowed(P,Half,Brush.bBlocksMovement,Brush.bBossInterior);
    }
    for(TActorIterator<AAlchemyTileCell> It(GetWorld());It;++It)if(It->GetOwner()==this && *It!=Previous){
        if(It->bBlocksMovement)Blocks.Add(FBox2D(FVector2D(It->GetActorLocation())-It->WorldHalfSize(),FVector2D(It->GetActorLocation())+It->WorldHalfSize()));
        if(!Brush.bGround && *It!=Cell && (!It->bGround || It->bBlocksMovement)){
            const FBox2D Other(FVector2D(It->GetActorLocation())-It->WorldHalfSize(),FVector2D(It->GetActorLocation())+It->WorldHalfSize());
            const FBox2D Own(FVector2D(Cell->GetActorLocation())-Cell->WorldHalfSize(),FVector2D(Cell->GetActorLocation())+Cell->WorldHalfSize());
            Valid &= !Own.ExpandBy(ObjectSpacing).Intersect(Other);
        }
    }
    if(!Valid || (ValidateBlockingLayout && !ValidateBlockingLayout(Blocks))){Cell->Destroy();Status=TEXT("笔刷占地/保护区/通路冲突；原层及锁定内容保留");return;}
    if(Previous){Previous->Modify();ApplyBrush(Previous,BrushIndex);Cell->Destroy();Cell=Previous;}
    Cell->Modify();Cell->bLockRandom=true;MarkPackageDirty();
    RefreshCells();
    Status=FString::Printf(TEXT("已修改并锁定%s层(%d,%d)"),Brush.bGround?TEXT("地面"):TEXT("物件"),X,Y);
#endif
}
void AAlchemyLevelDesigner::RefreshCells() {
    if(!GetWorld())return;
    TMap<FIntPoint,AAlchemyTileCell*> Ground;
    for(TActorIterator<AAlchemyTileCell> It(GetWorld());It;++It)if(It->GetOwner()==this){
        It->ApplyAppearance();
        if(It->bGround && It->GridX>=0 && It->GridY>=0)Ground.Add(FIntPoint(It->GridX,It->GridY),*It);
    }
    if(!GroundBlendMaterial)return;
    for(const auto& Entry:Ground){
        auto Cell=Entry.Value;if(!Cell->Texture || !Cell->Image)continue;
        const FString Override=Cell->MaterialOverride?Cell->MaterialOverride->GetName():TEXT("");
        if(!Override.IsEmpty() && Override!=TEXT("M_GF_Grass") && Override!=TEXT("M_GF_Dirt") && Override!=TEXT("M_GF_Stone"))continue;
        auto Blend=UMaterialInstanceDynamic::Create(GroundBlendMaterial,Cell->Image);
        for(int Y=0;Y<3;Y++)for(int X=0;X<3;X++){
            auto Neighbor=Ground.FindRef(Entry.Key+FIntPoint(X-1,Y-1));
            Blend->SetTextureParameterValue(FName(*FString::Printf(TEXT("G%d%d"),X,Y)),Neighbor && Neighbor->Texture?Neighbor->Texture.Get():Cell->Texture.Get());
        }
        Blend->SetScalarParameterValue(TEXT("UVScale"),600.f);
        Blend->SetScalarParameterValue(TEXT("BlendWidth"),.20f);
        Cell->Image->SetMaterial(0,Blend);
    }
}
void AAlchemyLevelDesigner::SetRuntimeVisible(bool Visible) {SetActorHiddenInGame(!Visible);
    for(TActorIterator<AActor> It(GetWorld());It;++It) if(It->ActorHasTag(TEXT("AlchemyEditorPreviewLight")) && It->GetRootComponent()) It->GetRootComponent()->SetVisibility(false,true);
    for(TActorIterator<AAlchemyTileCell> It(GetWorld());It;++It) if(It->GetOwner()==this) {
        It->SetActorHiddenInGame(!Visible);
        if(Visible && It->bGround && It->Texture) {
            const FString Override=It->MaterialOverride?It->MaterialOverride->GetName():TEXT("");
            if(Override.IsEmpty() || Override==TEXT("M_Grass") || Override==TEXT("M_Dirt") || Override==TEXT("M_Stone")) {
                if(auto* Base=LoadObject<UMaterialInterface>(nullptr,TEXT("/Game/Design/M_DesignerGround.M_DesignerGround"))) {
                    auto* M=UMaterialInstanceDynamic::Create(Base,It->Image);M->SetTextureParameterValue(TEXT("Image"),It->Texture);It->Image->SetMaterial(0,M);
                }
            }
        }
    }
    // The legacy null-override fallback above can replace a blended MID when showing the layer.
    if(Visible && GroundBlendMaterial)RefreshCells();
}
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
    if(OK) for(const TCHAR* Name:{TEXT("ImportPalette"),TEXT("Randomize"),TEXT("RandomizeGround"),TEXT("RandomizeObjects"),TEXT("GenerateFromSeed"),TEXT("PaintCell"),TEXT("RefreshCells"),TEXT("OpenSkills"),TEXT("OpenRecipes"),TEXT("OpenChains"),TEXT("OpenQuality"),TEXT("ValidateDesign"),TEXT("CreateStarterTables"),TEXT("SaveDesign")}) {
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
