#pragma once
#include "CoreMinimal.h"
#include "Engine/DataTable.h"
#include "GameFramework/Actor.h"
#include "AlchemyDesignTools.generated.h"

class UNiagaraSystem;
class UTexture2D;
class UMaterialInterface;
class UStaticMeshComponent;

UENUM(BlueprintType)
enum class EAlchemyCast : uint8 { Bolt UMETA(DisplayName="弹丸"), Direct UMETA(DisplayName="直接命中"), SelfArea UMETA(DisplayName="自身范围"), TargetArea UMETA(DisplayName="目标范围"), Bounce UMETA(DisplayName="跳跃命中") };

USTRUCT(BlueprintType)
struct FAlchemySkillRow : public FTableRowBase {
    GENERATED_BODY()
    UPROPERTY(EditAnywhere, BlueprintReadWrite) FString Name;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0")) float Damage=18;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0.01")) float CD=1;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="1",Units="cm")) float Range=900;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0",Units="cm")) float Radius=0;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0",Units="s")) float Slow=0;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0.05",ClampMax="1")) float Factor=1;
    UPROPERTY(EditAnywhere, BlueprintReadWrite) EAlchemyCast Cast=EAlchemyCast::Bolt;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="1")) int32 Targets=1;
    UPROPERTY(EditAnywhere, BlueprintReadWrite) FLinearColor Color=FLinearColor(.65f,.3f,1);
    UPROPERTY(EditAnywhere, BlueprintReadWrite) TObjectPtr<UNiagaraSystem> HitEffect;
    UPROPERTY(EditAnywhere, BlueprintReadWrite) TObjectPtr<UNiagaraSystem> CastEffect;
    UPROPERTY(EditAnywhere, BlueprintReadWrite) TObjectPtr<UNiagaraSystem> TrailEffect;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0",ToolTip="本行Niagara效果的整体缩放倍率；0关闭Niagara")) float EffectScale=1;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0.05",Units="s")) float CastLife=1.25f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0.05",Units="s")) float HitLife=.7f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="1",Units="cm/s")) float ProjectileSpeed=1000;
    UPROPERTY(EditAnywhere, BlueprintReadWrite) FString Notes;
};

USTRUCT(BlueprintType)
struct FAlchemyChainRow : public FTableRowBase {
    GENERATED_BODY()
    UPROPERTY(EditAnywhere, BlueprintReadWrite) FString Name;
    UPROPERTY(EditAnywhere, BlueprintReadWrite) int32 A=0;
    UPROPERTY(EditAnywhere, BlueprintReadWrite) int32 B=1;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0.01")) float CD=12;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="1",Units="cm")) float Range=1000;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0")) float Damage=30;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0",Units="cm")) float Radius=240;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0",Units="s")) float Slow=0;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0.05",ClampMax="1")) float Factor=1;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0")) int32 Targets=0;
    UPROPERTY(EditAnywhere, BlueprintReadWrite) FLinearColor Color=FLinearColor(.82f,.58f,.25f);
    UPROPERTY(EditAnywhere, BlueprintReadWrite) TObjectPtr<UNiagaraSystem> CastEffect;
    UPROPERTY(EditAnywhere, BlueprintReadWrite) TObjectPtr<UNiagaraSystem> HitEffect;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0",ToolTip="本行Niagara效果的整体缩放倍率；0关闭Niagara")) float EffectScale=1;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0.05",Units="s")) float CastLife=1.25f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0.05",Units="s")) float HitLife=.7f;
};

USTRUCT(BlueprintType)
struct FAlchemyRecipeRow : public FTableRowBase {
    GENERATED_BODY()
    UPROPERTY(EditAnywhere, BlueprintReadWrite) FString Name;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ToolTip="普通组合：火=1，露=2，魔=4，组合相加")) int32 Mask=1;
    UPROPERTY(EditAnywhere, BlueprintReadWrite) int32 LowSkill=0;
    UPROPERTY(EditAnywhere, BlueprintReadWrite) int32 MidSkill=1;
    UPROPERTY(EditAnywhere, BlueprintReadWrite) int32 HighSkill=2;
    UPROPERTY(EditAnywhere, BlueprintReadWrite) bool bElite=false;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(EditFixedSize,ToolTip="精英固定配方，顺序：火粉、露水、魔法碎片、兽核、虚空晶、根须心")) TArray<int32> Costs={0,0,0,0,0,0};
};

USTRUCT(BlueprintType)
struct FAlchemyQualityRow : public FTableRowBase {
    GENERATED_BODY()
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0")) float Low=70;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0")) float Mid=20;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0")) float High=10;
};

USTRUCT(BlueprintType)
struct FAlchemyTileBrush {
    GENERATED_BODY()
    UPROPERTY(EditAnywhere, BlueprintReadWrite) FString Name;
    UPROPERTY(EditAnywhere, BlueprintReadWrite) TObjectPtr<UTexture2D> Texture;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ToolTip="优先使用此材质；留空时用Texture生成显示材质")) TObjectPtr<UMaterialInterface> Material;
    UPROPERTY(EditAnywhere, BlueprintReadWrite) bool bGround=true;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0")) float RandomWeight=0;
    UPROPERTY(EditAnywhere, BlueprintReadWrite) FVector2D VisualSize=FVector2D(240,320);
};

UCLASS(BlueprintType)
class ALCHEMYHD2D_API AAlchemyTileCell : public AActor {
    GENERATED_BODY()
public:
    AAlchemyTileCell();
    UPROPERTY(VisibleAnywhere) TObjectPtr<UStaticMeshComponent> Image;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="格子") int32 GridX=-1;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="格子") int32 GridY=-1;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="格子") bool bLockRandom=false;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="外观") TObjectPtr<UTexture2D> Texture;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="外观") TObjectPtr<UMaterialInterface> MaterialOverride;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="外观") bool bGround=true;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="外观") FVector2D VisualSize=FVector2D(600,600);
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="碰撞") bool bBlocksMovement=false;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="碰撞") FVector2D CollisionHalfSize=FVector2D(100,100);
    virtual void OnConstruction(const FTransform& Transform) override;
    virtual void PostRegisterAllComponents() override;
    virtual void BeginPlay() override;
    void ApplyAppearance();
    FVector2D WorldHalfSize() const;
};

UCLASS(BlueprintType)
class ALCHEMYHD2D_API AAlchemyLevelDesigner : public AActor {
    GENERATED_BODY()
public:
    AAlchemyLevelDesigner();
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="关卡",meta=(ClampMin="1",ClampMax="64")) int32 Columns=24;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="关卡",meta=(ClampMin="1",ClampMax="64")) int32 Rows=18;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="关卡",meta=(ClampMin="100",Units="cm")) float CellSize=600;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="关卡") int32 Seed=77;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="关卡") FVector2D PlayHalfSize=FVector2D(7060,5330);
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="关卡") bool bUseInGame=true;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="素材",meta=(TitleProperty="Name")) TArray<FAlchemyTileBrush> Palette;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="微调") int32 BrushIndex=0;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="微调",meta=(MakeEditWidget)) FVector PaintCursor=FVector::ZeroVector;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="技能表") TObjectPtr<UDataTable> SkillTable;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="技能表") TObjectPtr<UDataTable> RecipeTable;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="技能表") TObjectPtr<UDataTable> ChainTable;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="技能表") TObjectPtr<UDataTable> QualityTable;
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category="操作结果") FString Status;
    UFUNCTION(CallInEditor, BlueprintCallable, Category="关卡工具",meta=(DisplayName="1 读取全部图片素材")) void ImportPalette();
    UFUNCTION(CallInEditor, BlueprintCallable, Category="关卡工具",meta=(DisplayName="2 一键随机生成（保留锁定格）")) void Randomize();
    UFUNCTION(CallInEditor, BlueprintCallable, Category="关卡工具",meta=(DisplayName="3 在光标格子应用笔刷并锁定")) void PaintCell();
    UFUNCTION(CallInEditor, BlueprintCallable, Category="关卡工具",meta=(DisplayName="4 刷新全部格子显示")) void RefreshCells();
    UFUNCTION(CallInEditor, BlueprintCallable, Category="技能工具",meta=(DisplayName="打开技能与特效表")) void OpenSkills();
    UFUNCTION(CallInEditor, BlueprintCallable, Category="技能工具",meta=(DisplayName="打开炼金配方表")) void OpenRecipes();
    UFUNCTION(CallInEditor, BlueprintCallable, Category="技能工具",meta=(DisplayName="打开连锁表")) void OpenChains();
    UFUNCTION(CallInEditor, BlueprintCallable, Category="技能工具",meta=(DisplayName="打开品质权重表")) void OpenQuality();
    UFUNCTION(BlueprintCallable, Category="技能工具") bool ValidateLibrary();
    UFUNCTION(CallInEditor, BlueprintCallable, Category="技能工具",meta=(DisplayName="校验技能与配方")) void ValidateDesign() {ValidateLibrary();}
    UFUNCTION(CallInEditor, BlueprintCallable, Category="技能工具",meta=(DisplayName="创建缺失的默认技能表（不覆盖已有）")) void CreateStarterTables();
    UFUNCTION(CallInEditor, BlueprintCallable, Category="关卡工具",meta=(DisplayName="保存当前关卡和技能表")) void SaveDesign();
    void SetRuntimeVisible(bool bVisible);
private:
    void ApplyBrush(AAlchemyTileCell* Cell,int32 Index);
    void OpenTable(UDataTable* Table);
};

namespace AlchemyDesign {
    bool ReadTables(UDataTable* Skills,UDataTable* Recipes,UDataTable* Chains,UDataTable* Quality,TArray<FAlchemySkillRow>& OutSkills,TArray<FAlchemyRecipeRow>& OutRecipes,TArray<FAlchemyChainRow>& OutChains,TArray<FAlchemyQualityRow>& OutQuality,FString& Error);
}
