#pragma once
#include "CoreMinimal.h"
#include "GameFramework/Pawn.h"
#include "GameFramework/GameModeBase.h"
#include "GreyfordBlockout.generated.h"

class USphereComponent;
class UFloatingPawnMovement;
class UCameraComponent;

// Separate map-only inspection pawn; it does not create the production world or load saves.
UCLASS()
class ALCHEMYHD2D_API AGreyfordBlockoutPawn : public APawn {
    GENERATED_BODY()
public:
    AGreyfordBlockoutPawn();
    virtual void BeginPlay() override;
    virtual void Tick(float DeltaSeconds) override;
private:
    UPROPERTY() TObjectPtr<USphereComponent> Body;
    UPROPERTY() TObjectPtr<UFloatingPawnMovement> Movement;
    UPROPERTY() TObjectPtr<UCameraComponent> Camera;
    bool Overview=false, Capture=false;
    int32 CaptureStage=0;
    float Elapsed=0;
    void SetOverview(bool Value);
    bool VerifyCollision();
    TArray<FVector> WalkRoute;
    int32 WalkIndex=0;
    bool Walking=false, WalkAutoExit=false;
    float WalkSeconds=0, SegmentSeconds=0, SegmentLimit=0;
    FString WalkLog;
    void StartWalk();
    void UpdateWalk(float DeltaSeconds);
    void FinishWalk(bool OK);
};

UCLASS()
class ALCHEMYHD2D_API AGreyfordBlockoutMode : public AGameModeBase {
    GENERATED_BODY()
public:
    AGreyfordBlockoutMode();
};

UCLASS()
class ALCHEMYHD2D_API AGreyfordCombatMode : public AGameModeBase {
    GENERATED_BODY()
public:
    AGreyfordCombatMode();
    virtual void StartPlay() override;
};

UCLASS()
class ALCHEMYHD2D_API AGreyfordFlowMode : public AGreyfordCombatMode {
    GENERATED_BODY()
public:
    virtual void StartPlay() override;
};
