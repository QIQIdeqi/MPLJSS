#pragma once
#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "GameFramework/GameModeBase.h"
#include "GameFramework/HUD.h"
#include "GameFramework/SaveGame.h"
#include "AlchemyWorld.generated.h"

class AStaticMeshActor;
class ACameraActor;
class UMaterialInterface;

UCLASS()
class UAlchemyProgress : public USaveGame {
    GENERATED_BODY()
public:
    UPROPERTY() int32 Coins=0;
    UPROPERTY() TArray<int32> Talents={0,0,0,0};
    UPROPERTY() TArray<int32> Recipes;
    UPROPERTY() TArray<int32> Chains;
};

struct FAlchemyEnemy {
    AStaticMeshActor* Body=nullptr;
    AStaticMeshActor* Shadow=nullptr;
    FVector Pos=FVector::ZeroVector;
    int32 Type=0;
    float HP=1, MaxHP=1, Speed=1, Contact=0, AttackCD=1, Windup=0, Slow=0, Transition=0;
    FVector Aim=FVector::ZeroVector;
    bool Phase2=false;
    TArray<FVector> Path;
    float RepathCD=0;
};
struct FAlchemyShot {
    AStaticMeshActor* Body=nullptr;
    FVector Pos=FVector::ZeroVector, Velocity=FVector::ZeroVector;
    float Life=4, Damage=0;
    bool Hostile=false;
};
struct FAlchemyDrop {
    AStaticMeshActor* Body=nullptr;
    FVector Pos=FVector::ZeroVector;
    int32 Kind=0, Count=1; // -1 currency, 0..5 materials, 6..8 elite chests
};
struct FAlchemyFX { AStaticMeshActor* Body=nullptr; float Life=0, Total=0; float Radius=0; };
struct FAlchemyObstacle { FVector2D Center; FVector2D Half; };

UCLASS()
class AAlchemyWorld : public AActor {
    GENERATED_BODY()
public:
    AAlchemyWorld();
    virtual void BeginPlay() override;
    virtual void Tick(float Delta) override;
    UPROPERTY(EditAnywhere, Category="HD2D") float CameraPitch=48;
    UPROPERTY(EditAnywhere, Category="HD2D") float ViewWidth=2844;
    UPROPERTY(EditAnywhere, Category="HD2D") bool bPerspective=false;
    UPROPERTY(EditAnywhere, Category="HD2D") bool bLitSprites=false;
    UPROPERTY(EditAnywhere, Category="HD2D") bool bUprightSprites=false;
    UPROPERTY(EditAnywhere, Category="HD2D") bool bDepthOfField=false;
    UPROPERTY(EditAnywhere, Category="Tuning") bool bTune001B=true;
    UPROPERTY(EditAnywhere, Category="Tuning") bool bDrop001=true;
    bool bCombat=false, bBossSpawned=false, bSmoke=false, bRunEnded=false, bWon=false, bCapture=false;
    FString Panel, Toast;
    float ToastTime=0, RunTime=0, HP=120, MaxHP=120, DodgeCD=0, DodgeTime=0, HurtInv=0, DodgeInv=0;
    int32 Kills=0, RunCoins=0, CraftCount=0, ChainCount=0, ResultCoins=0, PendingTalent=-1, SelectedBag=-1;
    TArray<int32> Inventory={0,0,0,0,0,0}, Selected={0,0,0,0,0,0};
    TArray<int32> Levels={1,0,0,0,0,0,0,0,0,0}, Equipped={0}, Bag;
    FVector PlayerPos=FVector::ZeroVector;
    FVector LastDirection=FVector(0,1,0), DodgeDirection=FVector(0,1,0);
    TArray<FAlchemyEnemy> Enemies;
    TArray<FAlchemyShot> Shots;
    TArray<FAlchemyDrop> Drops;
    TArray<FAlchemyFX> Effects;
    TArray<FAlchemyObstacle> Obstacles;
    UPROPERTY() TObjectPtr<UAlchemyProgress> Progress;
    UPROPERTY() TMap<FString,TObjectPtr<UMaterialInterface>> Mats;
    UPROPERTY() TObjectPtr<UFont> UIFont;
    ACameraActor* Camera=nullptr;
    AStaticMeshActor* Player=nullptr;
    AStaticMeshActor* PlayerShadow=nullptr;
    UPROPERTY() TArray<TObjectPtr<AActor>> Scene;
    float SpawnCD=2.6f, NextElite=90, SkillCD[10]={}, ChainCD[2]={12,10}, ContactCD=0, VisualTime=0;
    int32 EliteIndex=0, SmokeStep=0, CaptureStep=0;
    float SmokeTime=0;
    FRandomStream Random{77};
    void BuildScene(bool Combat);
    AStaticMeshActor* Mesh(const FString& Shape, FVector Pos, FVector Scale, FLinearColor Tint, bool Solid=false);
    AStaticMeshActor* Sprite(const FString& Name, FVector Pos, float Width, float Height);
    AStaticMeshActor* Sheet(const FString& Name, FVector Pos, float Width, float Height);
    UMaterialInterface* Material(const FString& Name);
    void UpdateSprite(AStaticMeshActor* Body, const FString& Name, FVector Pos, float Width, float Height, bool Flip=false);
    void Tree(FVector Pos, float Size, bool Solid=true);
    void House(FVector Pos, FLinearColor Roof);
    void Ring(FVector Pos,float Radius,FLinearColor Color,float Duration=0.35);
    bool Walkable(FVector Pos, float Radius=45) const;
    FVector Move(FVector Pos,FVector Delta,float Radius=45) const;
    bool SegmentClear(FVector From,FVector To,float Radius) const;
    bool FindPath(FVector From,FVector To,float Radius,TArray<FVector>& Path) const;
    void Chase(FAlchemyEnemy& Enemy,float Delta);
    void LayoutCheck();
    void UpdateCamera(float Delta);
    void StartRun();
    void EndRun(bool Won);
    void Action(FString Id);
    void Message(FString Text);
    bool SaveProgress();
    bool Craft();
    void SpawnEnemy(int32 Type);
    bool FindSpawnPoint(int32 Type,FVector& Position);
    void SpawnWave();
    int32 Nearest(FVector Pos,float Range,const TArray<int32>& Exclude={}) const;
    void Fire(FVector From,FVector Target,float Damage,FLinearColor Color,bool Hostile=false,float Speed=1000);
    void DamageEnemy(int32 Index,float Damage);
    void Area(FVector Pos,float Radius,float Damage,FLinearColor Color,float Slow=0);
    void Hurt(float Damage);
    void Drop(FVector Pos,int32 Kind,int32 Count=1);
    void CastSkills(float Delta);
    void SmokeCheck(float Delta);
};

UCLASS()
class AAlchemyHUD : public AHUD {
    GENERATED_BODY()
public:
    virtual void DrawHUD() override;
    virtual void NotifyHitBoxClick(FName BoxName) override;
    AAlchemyWorld* World=nullptr;
    float S=1;
    void Text(const FString& Value,float X,float Y,float Size=16,FLinearColor Color=FLinearColor::White);
    void Box(float X,float Y,float W,float H,FLinearColor Color);
    void Button(const FString& Id,const FString& Label,float X,float Y,float W=180,bool Enabled=true);
};

UCLASS()
class AAlchemyMode : public AGameModeBase {
    GENERATED_BODY()
public:
    AAlchemyMode();
    virtual void StartPlay() override;
};
