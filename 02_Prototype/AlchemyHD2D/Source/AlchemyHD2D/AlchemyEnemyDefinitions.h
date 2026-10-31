#pragma once
#include "CoreMinimal.h"
#include "Engine/DataTable.h"
#include "GameFramework/Actor.h"
#include "AlchemyEnemyDefinitions.generated.h"

class UMaterialInterface;

UENUM(BlueprintType)
enum class EAlchemyEnemyBehavior : uint8 {
    Contact UMETA(DisplayName="追逐接触"),
    Ranged UMETA(DisplayName="远程保持距离"),
    Area UMETA(DisplayName="范围预警攻击"),
    Hybrid UMETA(DisplayName="远程与范围攻击"),
    Boss UMETA(DisplayName="现有Boss招式")
};

USTRUCT(BlueprintType)
struct ALCHEMYHD2D_API FAlchemyEnemyRow : public FTableRowBase {
    GENERATED_BODY()
    UPROPERTY(EditAnywhere, BlueprintReadWrite) FString Name;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0",ClampMax="10",ToolTip="稳定兼容模板：0–6普通、7–9对应三种精英奖励、10现有Boss。不是本行ID。")) int32 Archetype=0;
    UPROPERTY(EditAnywhere, BlueprintReadWrite) EAlchemyEnemyBehavior Behavior=EAlchemyEnemyBehavior::Contact;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="1")) float HP=16;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0",Units="cm/s")) float Speed=320;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0")) float ContactDamage=6;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="-1",ToolTip="调参B模式生命；-1跟随HP")) float TunedHP=-1;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="-1",ToolTip="调参B模式接触伤害；-1跟随ContactDamage")) float TunedContactDamage=-1;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="-1",ToolTip="调参B模式范围伤害；-1跟随AreaDamage")) float TunedAreaDamage=-1;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="-1",ToolTip="调参B模式远程伤害；-1跟随RangedDamage")) float TunedRangedDamage=-1;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0")) float HPPerMinute=.12f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0")) float SpeedPerMinute=.025f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0")) int32 HPMinuteCap=6;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0")) int32 SpeedMinuteCap=4;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="1",Units="cm")) float CollisionRadius=35;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(Units="cm")) FVector2D VisualSize=FVector2D(100,100);
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ToolTip="现有Art材质名的素材键，例如Enemy0；材质覆盖为空时使用。")) FString SpriteKey=TEXT("Enemy0");
    UPROPERTY(EditAnywhere, BlueprintReadWrite) TObjectPtr<UMaterialInterface> MaterialOverride;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(EditFixedSize,ToolTip="普通怪六个分钟阶段的相对权重；全0表示不加入自然波次。")) TArray<float> SpawnWeights={0,0,0,0,0,0};
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0",ToolTip="仅7–9精英模板使用；0不加入精英轮换。")) float EliteWeight=0;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0",Units="cm")) float AreaTrigger=200;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="1",Units="cm")) float AreaRadius=160;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0")) float AreaDamage=14;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0.01",Units="s")) float AreaWindup=.55f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0.01",Units="s")) float AreaCD=2.8f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite) bool AreaAimAtPlayer=false;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0",Units="cm")) float RangedMin=200;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="1",Units="cm")) float RangedMax=750;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0",Units="cm")) float RangedKeepDistance=550;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0")) float RangedDamage=10;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="1",Units="cm/s")) float RangedSpeed=650;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0.01",Units="s")) float RangedCD=2.8f;
};

namespace AlchemyDesign {
    ALCHEMYHD2D_API bool ReadEnemyDefinitions(UDataTable* Table,TArray<FAlchemyEnemyRow>& Rows,FString& Error);
}

UCLASS(BlueprintType)
class ALCHEMYHD2D_API AAlchemyEnemyDesigner : public AActor {
    GENERATED_BODY()
public:
    AAlchemyEnemyDesigner();
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="怪物配置") TObjectPtr<UDataTable> EnemyTable;
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category="操作结果") FString Status;
    UFUNCTION(CallInEditor, BlueprintCallable, Category="怪物工具",meta=(DisplayName="打开怪物数据表")) void OpenEnemies();
    UFUNCTION(BlueprintCallable, Category="怪物工具") bool ValidateEnemies();
    UFUNCTION(CallInEditor, Category="怪物工具",meta=(DisplayName="校验怪物配置")) void ValidateEnemyDesign(){ValidateEnemies();}
    UFUNCTION(BlueprintCallable, Category="怪物工具") bool CreateStarterTable();
    UFUNCTION(CallInEditor, Category="怪物工具",meta=(DisplayName="创建缺失的默认怪物表（不覆盖已有）")) void CreateEnemyStarterTable(){CreateStarterTable();}
};
