#pragma once
#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "Components/SplineComponent.h"
#include "GreyfordReferenceRegion.generated.h"

// Editable polygons in the fixed-camera village's ground coordinates.
UCLASS()
class AGreyfordReferenceRegion : public AActor {
    GENERATED_BODY()
public:
    AGreyfordReferenceRegion();
    // Legacy/import data. Once initialized, the editable spline is authoritative.
    UPROPERTY() TArray<FVector> Vertices;
    UPROPERTY(VisibleAnywhere,BlueprintReadOnly,Category="Collision Layout") TObjectPtr<USplineComponent> Outline;
    UPROPERTY(EditAnywhere,Category="Collision Layout",meta=(DisplayName="阻挡区域",ToolTip="红色为禁止通行；取消勾选后绿色为允许通行区域。")) bool bBlocked=false;
    UPROPERTY(EditAnywhere,Category="Collision Layout",meta=(DisplayName="显示碰撞轮廓")) bool bShowOutline=true;
    UPROPERTY(VisibleAnywhere,Category="Collision Layout",meta=(DisplayName="数据保存状态")) FString EditorStatus;
    virtual void PostLoad() override;
    virtual void OnConstruction(const FTransform& Transform) override;
    virtual void Tick(float DeltaSeconds) override;
    virtual bool ShouldTickIfViewportsOnly() const override {return true;}
    UFUNCTION(BlueprintCallable,Category="Collision Layout") void InitializeOutline();
    UFUNCTION(BlueprintCallable,Category="Collision Layout") TArray<FVector> GetWorldVertices() const;
    UFUNCTION(CallInEditor,BlueprintCallable,Category="Collision Layout",meta=(DisplayName="对齐原图编辑视角")) void AlignReferenceView();
    UFUNCTION(CallInEditor,BlueprintCallable,Category="Collision Layout",meta=(DisplayName="保存本关卡碰撞到源数据",ToolTip="导出本关卡全部红绿区域到 GreyfordReference.json；Ctrl+S 另行保存关卡。")) void SaveCollisionLayout();
    bool Contains(FVector P) const;
private:
#if WITH_EDITOR
    TArray<FVector> LastEditorPoints;
    bool bEditorPointsKnown=false;
#endif
};
