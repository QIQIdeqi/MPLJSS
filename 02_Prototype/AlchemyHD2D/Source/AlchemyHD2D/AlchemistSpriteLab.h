#pragma once
#include "CoreMinimal.h"
#include "GameFramework/Pawn.h"
#include "GameFramework/GameModeBase.h"
#include "GameFramework/HUD.h"
#include "AlchemistSpriteAnimation.h"
#include "AlchemistSpriteLab.generated.h"

class UStaticMeshComponent;
class UCameraComponent;
class UMaterialInterface;
class UMaterialInstanceDynamic;
class UTexture2D;

UCLASS()
class ALCHEMYHD2D_API AAlchemistSpriteLabPawn : public APawn {
    GENERATED_BODY()
public:
    AAlchemistSpriteLabPawn();
    virtual void BeginPlay() override;
    virtual void Tick(float DeltaSeconds) override;
    int32 AnimationRow() const {return Playback.Row;}
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly) TObjectPtr<UStaticMeshComponent> Sprite;
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly) TObjectPtr<UCameraComponent> Camera;
    // Side, front, back. Atlas rows: idle (4), walk (6), potion throw (6).
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Sprite Lab") TArray<TObjectPtr<UTexture2D>> Atlases;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Sprite Lab") TObjectPtr<UMaterialInterface> SpriteMaterial;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Sprite Lab") float MoveSpeed=280;
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category="Sprite Lab") int32 Facing=1;
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category="Sprite Lab") int32 Frame=0;
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category="Sprite Lab") bool bAttacking=false;
    UFUNCTION(BlueprintCallable, Category="Sprite Lab") void SetFacing(int32 Direction, bool Mirror=false);
    UFUNCTION(BlueprintCallable, Category="Sprite Lab") void Attack();
private:
    UPROPERTY() TObjectPtr<UMaterialInstanceDynamic> Material;
    UPROPERTY() FAlchemistSpriteAnimation Playback;
    float TestTime=0;
    int32 TestStep=0;
    FVector TestStart;
    bool bMirror=false, bSmoke=false;
    void UpdateFrame();
    void Smoke(float DeltaSeconds);
};

UCLASS()
class ALCHEMYHD2D_API AAlchemistSpriteLabHUD : public AHUD {
    GENERATED_BODY()
    virtual void DrawHUD() override;
};

UCLASS()
class ALCHEMYHD2D_API AAlchemistSpriteLabMode : public AGameModeBase {
    GENERATED_BODY()
public:
    AAlchemistSpriteLabMode();
};
