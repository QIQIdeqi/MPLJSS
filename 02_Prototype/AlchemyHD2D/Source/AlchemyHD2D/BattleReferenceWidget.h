#pragma once
#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "BattleReferenceWidget.generated.h"

class AAlchemyWorld;
class UCanvasPanel;
class UImage;
class UProgressBar;
class UTextBlock;
class UWidgetTree;

UCLASS()
class ALCHEMYHD2D_API UBattleReferenceWidget : public UUserWidget {
    GENERATED_BODY()
public:
    UFUNCTION(BlueprintCallable,Category="Battle HUD") void InitializeForWorld(AAlchemyWorld* InWorld);
    UFUNCTION(BlueprintCallable,Category="Battle HUD|Editor") static bool CreateEditableBlueprint();
protected:
    virtual void NativeOnInitialized() override;
    virtual void NativeTick(const FGeometry& MyGeometry,float InDeltaTime) override;
    virtual int32 NativePaint(const FPaintArgs& Args,const FGeometry& Geometry,const FSlateRect& CullingRect,FSlateWindowElementList& Elements,int32 LayerId,const FWidgetStyle& Style,bool ParentEnabled) const override;
private:
    static void BuildReferenceTree(UWidgetTree* Tree);
    void BindControls();
    UFUNCTION() void OpenSkills();
    UPROPERTY() TObjectPtr<AAlchemyWorld> BattleWorld;
    UPROPERTY(meta=(BindWidgetOptional)) TObjectPtr<UProgressBar> HPBar;
    UPROPERTY(meta=(BindWidgetOptional)) TObjectPtr<UProgressBar> DodgeBar;
    UPROPERTY(meta=(BindWidgetOptional)) TObjectPtr<UProgressBar> XPBar;
    UPROPERTY(meta=(BindWidgetOptional)) TObjectPtr<UTextBlock> LevelText;
    UPROPERTY(meta=(BindWidgetOptional)) TObjectPtr<UTextBlock> HPText;
    UPROPERTY(meta=(BindWidgetOptional)) TObjectPtr<UTextBlock> TimerText;
    UPROPERTY(meta=(BindWidgetOptional)) TObjectPtr<UTextBlock> KillText;
    UPROPERTY(meta=(BindWidgetOptional)) TObjectPtr<UTextBlock> CoinText;
    UPROPERTY(meta=(BindWidgetOptional)) TObjectPtr<UTextBlock> DodgeText;
    UPROPERTY(meta=(BindWidgetOptional)) TObjectPtr<UCanvasPanel> SkillGroup;
    UPROPERTY(meta=(BindWidgetOptional)) TObjectPtr<UCanvasPanel> Minimap;
    int32 MapStage=-1;
    FVector2D MapHalf=FVector2D::ZeroVector;
    FVector MapRight=FVector::ZeroVector,MapUp=FVector::ZeroVector;
    float MapRX=1,MapRY=1;
    TArray<FVector2D> WalkCells;
};
