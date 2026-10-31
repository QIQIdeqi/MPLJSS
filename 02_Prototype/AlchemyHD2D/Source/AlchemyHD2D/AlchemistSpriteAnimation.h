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
    UPROPERTY() TArray<TObjectPtr<UTexture2D>> RoseMotionAtlases;
    bool RoseMage=false;
    int32 Facing=1,Frame=0,Row=0;
    float Time=0;
    bool Mirror=false,Throwing=false,Moving=false,Hurting=false,Dead=false;
    bool Initialize(UObject* Owner,UStaticMeshComponent* Mesh);
    bool InitializeRoseMage(UObject* Owner,UStaticMeshComponent* Mesh);
    bool HasRoseMotion() const {return RoseMage && RoseMotionAtlases.Num()==3;}
    float SheetWorldSize() const {return RoseMage?288.f:220.f;}
    float FootOffset() const {return SheetWorldSize()*(RoseMage?232.f/512:104.f/256);}
    void Face(FVector2D Direction);
    float ReleaseTime() const {return RoseMage?.4f:.25f;}
    bool Throw(FVector2D Direction);
    void Hit();
    void Die();
    void Reset();
    bool DeathFinished() const {return Dead && Time>=.75f;}
    bool Advance(float Delta,FVector2D Direction,bool IsMoving);
    void Apply();
};
