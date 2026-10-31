#pragma once
#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "PixelFXActor.generated.h"

class UStaticMeshComponent;
class UMaterialInstanceDynamic;
class AAlchemyWorld;

UENUM(BlueprintType)
enum class EPixelFX : uint8 { Hit, Poison, Portal };

// A foot-anchored PixelFX card with independently depth-tested back/front color and light.
UCLASS(Blueprintable)
class ALCHEMYHD2D_API APixelFXActor : public AActor {
    GENERATED_BODY()
public:
    APixelFXActor();
    virtual void OnConstruction(const FTransform& Transform) override;
    virtual void BeginPlay() override;
    virtual void Tick(float Delta) override;
    UPROPERTY(EditAnywhere,BlueprintReadWrite,Category="PixelFX") EPixelFX Effect=EPixelFX::Poison;
    UPROPERTY(EditAnywhere,BlueprintReadWrite,Category="PixelFX",meta=(ClampMin="0.05")) float PixelScale=1;
    UPROPERTY(EditAnywhere,BlueprintReadWrite,Category="PixelFX",meta=(ClampMin="0",ClampMax="1")) float Opacity=1;
    UPROPERTY(EditAnywhere,BlueprintReadWrite,Category="PixelFX",meta=(ClampMin="0")) float GlowStrength=.65f;
    UPROPERTY(EditAnywhere,BlueprintReadWrite,Category="PixelFX") bool Mirror=false;
    // Zero uses the preset: 0.5 seconds for hit; indefinitely looping poison and portal.
    UPROPERTY(EditAnywhere,BlueprintReadWrite,Category="PixelFX",meta=(ClampMin="0")) float Lifetime=0;
    UPROPERTY(VisibleAnywhere,Category="PixelFX") TArray<TObjectPtr<UStaticMeshComponent>> Cards;
    bool IsReady() const;
    void SetPlaybackTime(float Seconds);
private:
    void UpdateCards();
    UPROPERTY(Transient) TArray<TObjectPtr<UMaterialInstanceDynamic>> Materials;
    TWeakObjectPtr<AAlchemyWorld> Alchemy;
    float Age=0;
};
