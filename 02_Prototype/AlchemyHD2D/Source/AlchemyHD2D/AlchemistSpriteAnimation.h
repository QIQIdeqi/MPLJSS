#pragma once
#include "CoreMinimal.h"
#include "AlchemistSpriteAnimation.generated.h"
class UStaticMeshComponent;
class UTexture2D;
class UMaterialInstanceDynamic;

// Shared playback for the lab pawn and the existing combat-world controller.
USTRUCT()
struct FAlchemistSpriteAnimation {
    GENERATED_BODY()
    UPROPERTY() TObjectPtr<UMaterialInstanceDynamic> Material;
    UPROPERTY() TArray<TObjectPtr<UTexture2D>> Atlases;
    int32 Facing=1,Frame=0,Row=0;
    float Time=0;
    bool Mirror=false,Throwing=false,Moving=false,Hurting=false,Dead=false;
    bool Initialize(UObject* Owner,UStaticMeshComponent* Mesh);
    void Face(FVector2D Direction);
    bool Throw(FVector2D Direction);
    void Hit();
    void Die();
    void Reset();
    bool DeathFinished() const {return Dead && Time>=.75f;}
    bool Advance(float Delta,FVector2D Direction,bool IsMoving);
    void Apply();
};
