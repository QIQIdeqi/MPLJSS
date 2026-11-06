#pragma once

#include "CoreMinimal.h"
#include "Containers/ArrayView.h"
#include "Engine/EngineTypes.h"
#include "GreyfordTOD.generated.h"

class ADirectionalLight;
class ASkyLight;
class AStaticMeshActor;
class UMaterialInstanceDynamic;
class UMaterialInterface;
class UStaticMesh;
class UTexture2D;
class UWorld;

USTRUCT(BlueprintType)
struct FGreyfordTODSettings {
    GENERATED_BODY()

    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="1", Units="s")) float CycleSeconds=480.f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0", ClampMax="24")) float StartHour=13.f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(Units="deg")) float SunAzimuthOffset=45.f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="1", ClampMax="89", Units="deg")) float MinSunElevation=7.f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="1", ClampMax="89", Units="deg")) float MaxSunElevation=65.f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0", ClampMax="1")) float ShadowOpacity=.56f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="1", Units="cm")) float MinShadowLength=48.f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="1", Units="cm")) float MaxShadowLength=700.f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0", Units="cm")) float GroundLift=1.f;
};

struct FGreyfordTODCaster {
    FVector Foot=FVector::ZeroVector;
    float Width=80.f;
    float Height=180.f;
    float Strength=1.f;
    TWeakObjectPtr<UTexture2D> Texture;
    float FootFraction=.96f;
    FVector WidthAxis=FVector::RightVector;
};

// Scene presentation only. The caller supplies the same run clock in both combat stages.
class FGreyfordTOD {
public:
    void BindLights(ADirectionalLight* InSun, ASkyLight* InSky);
    void Update(float RunTime, const FGreyfordTODSettings& Settings);
    void UpdateShadows(UWorld* World, UMaterialInterface* Material, TConstArrayView<FGreyfordTODCaster> Casters);
    void Clear();

    float GetHour() const { return Hour; }
    float GetSunElevation() const { return SunElevation; }
    FVector GetShadowDirection() const { return ShadowDirection; }
    const FLinearColor& GetSceneTint() const { return SceneTint; }
    int32 GetShadowCount() const { return ActiveShadows; }

private:
    struct FLightState {
        float Intensity=0.f;
        FLinearColor Color=FLinearColor::White;
        EComponentMobility::Type Mobility=EComponentMobility::Movable;
    };
    struct FShadow {
        TWeakObjectPtr<AStaticMeshActor> Actor;
        TWeakObjectPtr<UMaterialInstanceDynamic> Material;
    };

    void RestoreLights();
    void ClearShadows();
    TWeakObjectPtr<ADirectionalLight> Sun;
    TWeakObjectPtr<ASkyLight> Sky;
    FRotator SavedSunRotation=FRotator::ZeroRotator;
    FLightState SavedSun, SavedSky;
    TWeakObjectPtr<UStaticMesh> Plane;
    TWeakObjectPtr<UMaterialInterface> ShadowParent;
    TArray<FShadow> Shadows;
    int32 ActiveShadows=0;
    float Hour=13.f;
    float SunElevation=65.f;
    FVector ShadowDirection=FVector::ForwardVector;
    FLinearColor SceneTint=FLinearColor::White;
    FLinearColor ShadowColor=FLinearColor::Black;
    float ShadowOpacity=.56f;
    float MinShadowLength=48.f;
    float MaxShadowLength=700.f;
    float GroundLift=1.f;
};
