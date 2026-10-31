#pragma once
#include "CoreMinimal.h"
#include "Camera/CameraActor.h"
#include "Camera/CameraComponent.h"
#include "Engine/Scene.h"
#include "GameFramework/Actor.h"
#include "GameFramework/GameModeBase.h"
#include "GameFramework/HUD.h"
#include "GameFramework/SaveGame.h"
#include "AlchemyDesignTools.h"
#include "AlchemyEnemyDefinitions.h"
#include "AlchemistSpriteAnimation.h"
#include "GreyfordReferenceRegion.h"
#include "AlchemyWorld.generated.h"

// Native off-axis frustum follows the subject without disturbing registered scenery layers.
UCLASS()
class UAlchemyCameraComponent : public UCameraComponent {
    GENERATED_BODY()
public:
    FVector2D ProjectionOffset=FVector2D::ZeroVector;
    virtual void GetCameraView(float Dt,FMinimalViewInfo& Out) override {
        Super::GetCameraView(Dt,Out);Out.OffCenterProjectionOffset=ProjectionOffset;
    }
};
UCLASS()
class AAlchemyCamera : public ACameraActor {
    GENERATED_BODY()
public:
    AAlchemyCamera(const FObjectInitializer& Init):Super(Init.SetDefaultSubobjectClass<UAlchemyCameraComponent>(TEXT("CameraComponent"))){}
};

class AStaticMeshActor;
class ULevel;
class ACameraActor;
class UMaterialInterface;
class UNiagaraSystem;
class UNiagaraComponent;
class USoundBase;
class UBattleReferenceWidget;
struct FMerchantCoinEffect {
    FVector2D From,To;
    float Born=0;
    int32 Delta=0;
};

UCLASS()
class UAlchemyProgress : public USaveGame {
    GENERATED_BODY()
public:
    UPROPERTY() int32 Coins=0;
    // 10 independent upgrades (system UI V0.2): indexes 0..9 per TalentNames[].
    UPROPERTY() TArray<int32> Talents={0,0,0,0,0,0,0,0,0,0};
    UPROPERTY() TArray<int32> Recipes;
    UPROPERTY() TArray<int32> Chains;
    UPROPERTY() int32 SchemaVersion=0;
    UPROPERTY() bool TutorialComplete=false;
    UPROPERTY() TArray<int32> Combinations;
    UPROPERTY() TArray<int32> ChainsV2;
    // Codex: permanently discovered monsters and materials (new categories).
    UPROPERTY() TArray<int32> Monsters;
    UPROPERTY() TArray<int32> Materials;
    UPROPERTY() float UITextScale=1;
    UPROPERTY() float MediumTextScale=.9f;
    UPROPERTY() float LargeTextScale=.72f;
    // TALENT-002 one-shot flags are now represented by Talents[8] and Talents[9] (0/1).
    // Kept for save migration only; not authoritative at runtime.
    UPROPERTY() bool RefreshUnlocked=false;
    UPROPERTY() bool DropRateUnlocked=false;
    UPROPERTY() bool StartMaterialUnlocked=false;
    float FontSize(float Size) const { return Size*(Size<=18?1.f:Size<26?MediumTextScale:LargeTextScale); }
};

struct FAlchemyEnemy {
    AStaticMeshActor* Body=nullptr;
    AStaticMeshActor* Shadow=nullptr;
    FVector Pos=FVector::ZeroVector;
    int32 Type=0, Definition=-1;
    float HP=1, MaxHP=1, Speed=1, Contact=0, AttackCD=1, Windup=0, Slow=0, Transition=0;
    FVector Aim=FVector::ZeroVector;
    bool Phase2=false;
    int32 BossAttack=0, BossSequence=0;
    float BossActive=0;
    int32 PlannedState=0;
    float PlannedTime=0, PlannedDistance=0;
    bool PlannedLocked=false;
    bool BossDashHit=false;
    FVector DashDirection=FVector::ZeroVector;
    TArray<FVector> Path;
    float RepathCD=0;
    float SlowFactor=0.65f;
    float HitFlash=0;
};
struct FAlchemyShot {
    AStaticMeshActor* Body=nullptr;
    FVector Pos=FVector::ZeroVector, Velocity=FVector::ZeroVector;
    float Life=4, Damage=0;
    bool Hostile=false, Potion=false, NewPotion=false;
    float ReleaseDelay=0, Age=0;
    int32 BossWave=-1;
    float FadeRemaining=-1,SpawnDelay=0;
    FLinearColor Color=FLinearColor::White;
    TWeakObjectPtr<UNiagaraComponent> Trail;
    TWeakObjectPtr<UNiagaraSystem> HitEffect;
    float Slow=0,SlowFactor=1,EffectScale=1,HitLife=.7f;
};
struct FAlchemyDrop {
    AStaticMeshActor* Body=nullptr;
    FVector Pos=FVector::ZeroVector;
    int32 Kind=0, Count=1; // -1 currency, 0..5 materials, 6..8 elite chests
};
struct FAlchemyFX { AStaticMeshActor* Body=nullptr; float Life=0, Total=0; float Radius=0; bool PotionBreak=false,New=true; };
struct FAlchemyObstacle { FVector2D Center; FVector2D Half; };
struct FAlchemyDamageNumber {FVector Position; float Value=0,Life=.85f; int32 Lane=0;};
USTRUCT()
struct FAlchemyNiagaraFX {
    GENERATED_BODY()
    UPROPERTY() TObjectPtr<UNiagaraComponent> Component;
    float Life=0;
};

UCLASS()
class AAlchemyWorld : public AActor {
    GENERATED_BODY()
public:
    AAlchemyWorld();
    virtual void BeginPlay() override;
    virtual void Tick(float Delta) override;
    virtual void EndPlay(const EEndPlayReason::Type Reason) override;
    UPROPERTY(EditAnywhere, Category="HD2D") float CameraPitch=60;
    UPROPERTY(EditAnywhere, Category="HD2D") float CameraFOV=50;
    UPROPERTY(EditAnywhere, Category="HD2D") float ViewWidth=2844;
    UPROPERTY(EditAnywhere, Category="HD2D") bool bPerspective=true;
    UPROPERTY(EditAnywhere, Category="HD2D") bool bLitSprites=false;
    UPROPERTY(EditAnywhere, Category="HD2D") bool bUprightSprites=false;
    UPROPERTY(EditAnywhere, Category="HD2D") bool bDepthOfField=false;
    // Reuse combat in the authored Greyford map with temporary progress.
    UPROPERTY(EditAnywhere, Category="HD2D") bool bGreyfordScene=false;
    UPROPERTY(EditAnywhere, Category="HD2D") bool bGreyfordFlow=false;
    UPROPERTY() TObjectPtr<ULevel> GreyfordActiveLevel;
    int32 GreyfordStage=0;
    bool bGreyfordReference=false;
    int32 ReferencePreviousAA=-1;
    UPROPERTY(EditAnywhere,Category="Reference") float ReferenceZoom=2.41153846f;
    UPROPERTY(EditAnywhere,Category="Reference") float ReferencePlayerRadius=30;
    UPROPERTY() TArray<TObjectPtr<AStaticMeshActor>> ReferencePerspectiveCards;
    UPROPERTY() TArray<TObjectPtr<UMaterialInstanceDynamic>> ReferencePerspectiveMaterials;
    TArray<FTransform> ReferencePerspectiveTransforms;
    void UpdateVillagePerspectiveCards(bool Perspective);
    bool VillagePerspectiveCheck(float Delta);
    bool VillagePresentationCheck(float Delta);
    FVector VillageVisualPoint(FVector Logical) const;
    float VillageVisualScale(FVector Logical) const;
    FVector ReferenceCameraFocus=FVector::ZeroVector;
    bool ReferenceCameraReady=false;
    void GreyfordAmbientCheck(float Dt);
    void GreyfordSpatialCheck(float Dt);
    int32 SpatialCase=-1;float SpatialTime=0;bool SpatialOK=true;
    FString SpatialDir;TArray<FVector> SpatialPoints;TArray<FString> SpatialNames;
    float AmbientTime=0,AmbientPause=2,AmbientCaptureTime=0;
    int32 AmbientWaypoint=0,AmbientFrame=0;
    bool AmbientOK=true;
    TArray<FVector> AmbientPath;
    FString AmbientCSV;
    UPROPERTY() TArray<TObjectPtr<AGreyfordReferenceRegion>> ReferenceRegions;
    UPROPERTY() TObjectPtr<UBattleReferenceWidget> BattleWidget;
    bool bBattleReference=false;
    UPROPERTY() TArray<TObjectPtr<AGreyfordReferenceRegion>> BattleRegions;
    UPROPERTY() TArray<TObjectPtr<AActor>> BattleCards;
    TArray<TWeakObjectPtr<AActor>> BattleHiddenActors;
    TArray<FVector2D> BattleSpawnPixels;
    float BattlePreviousReferenceRadius=30;
    FPostProcessSettings BattlePreviousCameraPostProcess;
    bool BattleSavedCameraPostProcess=false;
    bool BuildBattleReferenceScene();
    void ClearBattleReferenceScene();
    FVector BattleReferencePoint(FVector2D Pixel) const;
    FVector2D BattleReferencePixel(FVector P) const;
    bool BattleOffscreen(FVector P,float Radius) const;
    bool BattleFindSpawn(int DefinitionID,FVector& P);
    void UpdateBattleReferenceCamera(float Delta=0);
    bool BuildBossReferenceScene();
    bool UnifiedPresentationCheck(float Delta);
    void UIV02Check(float Delta);
    bool EnemyCodexCheck(float Delta);
    bool bReferenceBossScene=false,CombatCameraReady=false;
    FVector2D CombatCameraSourceFocus=FVector2D(836,470.5);
    double CombatCameraTangent=.466307658;
    FVector BattlePlayerPoint(FVector Point) const;
    TArray<FVector> ReferenceNodes;
    TArray<TPair<FVector,FVector>> ReferenceBoundary;
    void BuildReferenceBoundary();
    bool ReferenceSweep(FVector A,FVector B,float Radius) const;
    bool ReferenceWalkable(FVector P,float Radius) const;
    static FVector ReferencePoint(float X,float Y){return FVector((836-X)*(180.f/52),(470.5f-Y)*(180.f/52)/FMath::Sin(FMath::DegreesToRadians(48.f)),0);}
    bool GreyfordPortalReady=false;
    FVector GreyfordPortalPos=FVector::ZeroVector;
    float GreyfordPortalRetry=300;
    UPROPERTY() TObjectPtr<AActor> GreyfordPortal;
    class APixelFXActor* SpawnPixelFX(uint8 Kind,FVector Position,float Scale=1);
    TArray<TWeakObjectPtr<class APixelFXActor>> PixelFXActors;
    void ClearPixelFX();
    void PixelFXCheck(float Delta);
    float PixelFXCheckTime=0,PixelFXCaptureTime=0;
    int32 PixelFXCheckSection=-1,PixelFXFrame=0,PixelFXHitCount=0;
    bool PixelFXCheckOK=true;
    TWeakObjectPtr<class APixelFXActor> PixelFXPreview;
    TArray<FVector> GreyfordFacilities={FVector(1800,0,0),FVector(-1200,0,0),FVector(-6300,-600,0)};
    bool SwitchGreyfordStage(int32 Stage);
    void UpdateGreyfordPortal();
    bool EnterGreyfordBoss();
    FVector FacilityPosition(int32 Index) const;
    float GreyfordSurfaceHeight(FVector Position) const;
    bool GreyfordFlowAction(const FString& Id);
    void GreyfordFlowCheck(float Delta);
    int32 GreyfordFlowTestStep=0;
    int32 GreyfordFlowExpectedCoins=0;
    float GreyfordFlowTestTime=0;
    float GreyfordPausedTime=0;
    float GreyfordBossPreparation=0, GreyfordBossStartFlash=0, GreyfordPausedPreparation=0;
    int32 GreyfordBossWarmupFrames=0, GreyfordCountdownCapture=-1;
    bool GreyfordFlowTestOK=true;
    bool GreyfordReviewActive=false, GreyfordReviewDodge=false, GreyfordReviewOK=true;
    int32 GreyfordWaypoint=1, GreyfordDodges=0, GreyfordPeakEnemies=0, GreyfordAttackFrames=0;
    float GreyfordReviewTime=0, GreyfordSegmentTime=0, GreyfordMinHP=120;
    TArray<FVector> GreyfordRoute, GreyfordPath;
    FString GreyfordReviewCSV;
    void BuildGreyfordScene();
    void StartGreyfordReview();
    FVector UpdateGreyfordReview(float Delta,FVector ManualDirection);
    void FinishGreyfordReview();
    UPROPERTY(EditAnywhere, Category="Tuning") bool bTune001B=true;
    UPROPERTY(EditAnywhere, Category="Tuning") bool bDrop001=true;
    bool bCombat=false, bBossSpawned=false, bSmoke=false, bRunEnded=false, bWon=false, bCapture=false;
    FString Panel, Toast;
    float ToastTime=0, RunTime=0, HP=120, MaxHP=120, DodgeCD=0, DodgeTime=0, HurtInv=0, DodgeInv=0;
    int32 Kills=0, RunCoins=0, CraftCount=0, ChainCount=0, ResultCoins=0, PendingTalent=-1, SelectedBag=-1;
    TArray<int32> Inventory={0,0,0,0,0,0}, Selected={0,0,0,0,0,0};
    TArray<int32> Levels, Equipped={0}, Bag;
    // RESULT-001: pending craft result before accept, plus one-shot reroll state.
    int32 PendingResultSkill=-1, PendingResultCombination=-1, PendingResultTotal=0;
    bool PendingIsNuclear=false, PendingRefreshed=false;
    // ALCH-003: nuclear special result only kills normal enemies, then shows a dedicated result page.
    // EXP-001: run-local level/xp and the seven in-run attribute stacks.
    int32 RunLevel=1; float RunXP=0; int32 RunAttrs[7]={0,0,0,0,0,0,0};
    int32 LevelupChoices[3]={-1,-1,-1};
    int32 PendingLevelUps=0;
    // TALENT-002 start material: chosen once per run before entering combat.
    int32 StartMaterialChoice=-1;
    bool bTutorialSupplyDone=false;
    int32 TutorialSkill=-1, CodexPage=0;
    bool TutorialActive() const;
    void MigrateProgress(bool HasPlayed);
    void TutorialSupply(FVector Position);
    void TutorialHit(int32 Skill,int32 Hits);
    void AddMaterial(int32 Index);
    bool CraftOptions(TArray<int32>& Skills,TArray<float>& Weights,FString& Reason,int32& Combination,bool Nuclear=false) const;
    float ResultQualityWeight(int32 Total,int32 Quality,bool Nuclear) const;
    FVector PlayerPos=FVector::ZeroVector;
    FVector LastDirection=FVector(0,1,0), DodgeDirection=FVector(0,1,0);
    TArray<FAlchemyEnemy> Enemies;
    TArray<FAlchemyShot> Shots;
    TArray<FAlchemyDrop> Drops;
    TArray<FAlchemyFX> Effects;
    TArray<FAlchemyDamageNumber> DamageNumbers;
    UPROPERTY() TArray<FAlchemyNiagaraFX> NiagaraFX;
    UPROPERTY() TObjectPtr<UNiagaraSystem> ImpactFX;
    UPROPERTY() TObjectPtr<UNiagaraSystem> BlastFX;
    UPROPERTY() TObjectPtr<UNiagaraSystem> TrailFX;
    UPROPERTY() TObjectPtr<UMaterialInterface> ParticleMaterial;
    int32 HitFXThisFrame=0, DamageSerial=0, VFXSpawnCount=0;
    TArray<FAlchemyObstacle> Obstacles;
    UPROPERTY() TObjectPtr<UAlchemyProgress> Progress;
    UPROPERTY() TMap<FString,TObjectPtr<UMaterialInterface>> Mats;
    UPROPERTY() TObjectPtr<UFont> UIFont;
    UPROPERTY() TObjectPtr<UTexture2D> BattlePortrait;
    UPROPERTY() TObjectPtr<UDataTable> EnemyTable;
    UPROPERTY() TArray<FAlchemyEnemyRow> RuntimeEnemies;
    const FAlchemyEnemyRow& EnemyDefinition(int32 ID) const {return RuntimeEnemies[ID];}
    const FAlchemyEnemyRow& EnemyDefinition(const FAlchemyEnemy& E) const;
    bool DiscoverEnemy(const FAlchemyEnemy& E);
    FString EnemyCodexDescription(int32 ID) const;
    float EnemyRadius(int32 DefinitionID) const;
    float EnemyRadius(const FAlchemyEnemy& E) const;
    void UpdateEnemyVisual(FAlchemyEnemy& E,bool Mirror=false);
    int32 ChooseEliteDefinition();
    bool BattlePresentationCheck(float Delta);
    bool Reference60Check(float Delta);
    UPROPERTY() TObjectPtr<AAlchemyLevelDesigner> Designer;
    UPROPERTY() TObjectPtr<UDataTable> SkillTable;
    UPROPERTY() TObjectPtr<UDataTable> RecipeTable;
    UPROPERTY() TObjectPtr<UDataTable> ChainTable;
    UPROPERTY() TObjectPtr<UDataTable> QualityTable;
    UPROPERTY() TArray<FAlchemySkillRow> RuntimeSkills;
    UPROPERTY() TArray<FAlchemyRecipeRow> RuntimeRecipes;
    UPROPERTY() TArray<FAlchemyChainRow> RuntimeChains;
    UPROPERTY() TArray<FAlchemyQualityRow> RuntimeQuality;
    bool LoadDesignConfig();
    static bool CreateDesignTables();
    const FAlchemySkillRow& SkillConfig(int32 I) const {return RuntimeSkills[I];}
    const FAlchemyChainRow& ChainConfig(int32 I) const {return RuntimeChains[I];}
    const TCHAR* SkillName(int32 I) const {return RuntimeSkills.IsValidIndex(I)?*RuntimeSkills[I].Name:TEXT("无效技能");}
    const TCHAR* CombinationName(int32 I) const {return *RuntimeRecipes[I].Name;}
    int32 CombinationSkill(int32 I,int32 Q) const {const auto& R=RuntimeRecipes[I];return Q==0?R.LowSkill:Q==1?R.MidSkill:R.HighSkill;}
    float QualityWeight(int32 I,int32 Q) const {const auto& R=RuntimeQuality[I];return Q==0?R.Low:Q==1?R.Mid:R.High;}
    int32 RecipeCost(int32 Skill,int32 Material) const;
    int32 NumSkills() const {return RuntimeSkills.Num();}
    int32 NumChains() const {return RuntimeChains.Num();}
    FVector2D CombatHalfSize=FVector2D(7060,5330);
    ACameraActor* Camera=nullptr;
    AStaticMeshActor* Player=nullptr;
    UPROPERTY() FAlchemistSpriteAnimation CharacterAnimation;
    void UpdateCharacterVisual(float Delta,bool Moving);
    void CharacterSmoke(float Delta);
    void CharacterV3Smoke(float Delta);
    void SpawnPotionBreak(FVector Position);
    UPROPERTY() TObjectPtr<UTexture2D> PotionBreakAtlas;
    int32 PotionBreakCount=0;
    bool CharacterWalks[3]={false,false,false}, CharacterPending=false, CharacterReleased=false, CharacterHit=false, CharacterDodge=false;
    float CharacterInitialHP=0;
    AStaticMeshActor* PlayerShadow=nullptr;
    UPROPERTY() TArray<TObjectPtr<AActor>> Scene;
    float SpawnCD=2.6f, NextElite=90, ContactCD=0, VisualTime=0;
    bool bBossArenaActive=false, bCollectBossRewards=false;
    FVector BossArenaCenter=FVector::ZeroVector;
    float BossArenaRadius=1450;
    int32 BossClearCount=0, BossAttackCounts[3]={0,0,0};
    UPROPERTY() TObjectPtr<AStaticMeshActor> BossArenaRing;
    UPROPERTY() TObjectPtr<AStaticMeshActor> BossTelegraph;
    UPROPERTY() TArray<TObjectPtr<AStaticMeshActor>> BossFanTelegraphs;
    bool bMerchantActive=false, MerchantEliteUnlocked[3]={false,false,false};
    FVector MerchantPos=FVector::ZeroVector;
    float MerchantRemaining=0,NextMerchantTime=80,MerchantArrivalAge=0;
    float MerchantAnimClock=0,MerchantWaveTime=-1,MerchantGreetingCD=0;
    int32 MerchantAnimationFrame=0,MerchantCapturedWaveFrames=0,MerchantCapturedIdleFrames=0;
    bool bMerchantAnimationLit=false;
    bool bMerchantLeaving=false;
    bool bMerchantCapturedBuyCoins=false,bMerchantCapturedSellCoins=false;
    float MerchantDepartureTime=0,MerchantBubbleUntil=0;
    FString MerchantBubble;
    int32 MerchantTradeSerial=0,MerchantSoundEvents=0;
    TArray<FMerchantCoinEffect> MerchantCoinEffects;
    UPROPERTY() TObjectPtr<USoundBase> MerchantBuySound;
    UPROPERTY() TObjectPtr<USoundBase> MerchantSellSound;
    UPROPERTY() TObjectPtr<UTexture2D> MerchantCoinTexture;
    int32 MerchantVisit=0,MerchantRerolls=0,MerchantStock[3]={0,1,2};
    bool MerchantSoldOut[3]={false,false,false};
    int32 MerchantSellKind=-1,MerchantSellCount=0;
    FRandomStream MerchantRandom{1177};
    UPROPERTY() TObjectPtr<AStaticMeshActor> MerchantBody;
    UPROPERTY() TObjectPtr<AStaticMeshActor> MerchantShadow;
    UPROPERTY() TObjectPtr<AStaticMeshActor> MerchantMarker;
    UPROPERTY() TArray<TObjectPtr<AStaticMeshActor>> MerchantArrivalParts;
    UPROPERTY() TObjectPtr<UNiagaraComponent> MerchantArrivalFX;
    UPROPERTY() TObjectPtr<UMaterialInstanceDynamic> MerchantAnimationMaterial;
    TArray<float> SkillCD,ChainCD;
    int32 EliteIndex=0, SmokeStep=0, CaptureStep=0;
    float SmokeTime=0;
    FRandomStream Random{77};
    void BuildScene(bool Combat);
    AStaticMeshActor* Mesh(const FString& Shape, FVector Pos, FVector Scale, FLinearColor Tint, bool Solid=false);
    AStaticMeshActor* Sprite(const FString& Name, FVector Pos, float Width, float Height);
    AStaticMeshActor* Sheet(const FString& Name, FVector Pos, float Width, float Height);
    UMaterialInterface* Material(const FString& Name);
    void UpdateSprite(AStaticMeshActor* Body, const FString& Name, FVector Pos, float Width, float Height, bool Flip=false, UMaterialInterface* OverrideMaterial=nullptr);
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
    void TogglePanel(const FString& Id);
    void ProducerRegression();
    void Message(FString Text);
    bool SaveProgress();
    bool Craft();
    void TriggerNuclear();
    void AcceptPendingResult();
    void RerollPendingResult();
    int32 RequiredXP(int32 Level) const;
    void GrantXP(float Amount);
    void RollLevelupChoices();
    void ApplyRunAttr(int32 AttrIndex);
    bool TalentNodeUnlocked(int32 Node) const;
    bool TalentNodeDone(int32 Node) const;
    void BuyTalentNode(int32 Node);
    FString ChainHintFor(int32 Skill) const;
    float MaterialDropChance() const;
    void SpawnEnemy(int32 Type);
    bool StartBossEncounter();
    void UpdateBoss(FAlchemyEnemy& Enemy,float Delta);
    void UpdatePlannedBoss(FAlchemyEnemy& Enemy,float Delta);
    void UpdateShots(float Delta);
    void UpdatePlannedShot(FAlchemyShot& Shot,float Delta);
    FVector BossStraightMove(FVector From,FVector Delta,float Radius) const;
    FVector PlannedPlayerMove(FVector ManualDelta,float Delta);
    void ShowPlannedBossLines(FAlchemyEnemy& Enemy,bool Dash,bool Locked);
    void FirePlannedBossWave(FAlchemyEnemy& Enemy,float FrameOffset);
    void BossLockCue();
    void PlannedBossCheck(float Delta);
    void PlannedBossCapture();
    void SpawnTutorialEncounter();
    bool TutorialEncounterPending=false;
    float TutorialEncounterRetry=0;
    UPROPERTY(EditAnywhere,Category="Level|Unconfirmed Test Defaults",meta=(ClampMin="1",ClampMax="12")) int32 TutorialEncounterCount=6;
    UPROPERTY(EditAnywhere,Category="Boss|Unconfirmed Test Defaults",meta=(ClampMin="0.01")) float PlannedWaveFade=.15f;
    UPROPERTY(EditAnywhere,Category="Boss|Unconfirmed Test Defaults",meta=(ClampMin="0.35")) float PlannedFanWindup=1.25f;
    UPROPERTY(EditAnywhere,Category="Boss|Unconfirmed Test Defaults",meta=(ClampMin="0.1")) float PlannedFanRecovery=1;
    UPROPERTY(EditAnywhere,Category="Boss|Unconfirmed Test Defaults",meta=(ClampMin="0.1")) float PlannedFanLifetime=5;
    UPROPERTY() TObjectPtr<USoundBase> BossLockSound;
    UPROPERTY() TArray<TObjectPtr<AStaticMeshActor>> PlannedBossLines;
    TSet<int32> SpentBossWaves;
    int32 PlannedBossWaveSerial=0,PlannedBossWavesFired=0,PlannedBossLockSounds=0;
    float BossKnockRemaining=0;
    FVector BossKnockDirection=FVector::ZeroVector;
    void UpdateBossVisual(FAlchemyEnemy& Enemy);
    void EndBossArena();
    void ClearBossTelegraphs();
    void RewardEnemy(const FAlchemyEnemy& Enemy);
    void CollectDrop(int32 Kind,int32 Count,bool BossTransfer=false);
    void BossSmoke(float Delta);
    void BossPresentationCapture(float Delta);
    void ResetMerchant();
    void RollMerchantStock();
    bool SpawnMerchant();
    void CloseMerchant();
    bool OpenMerchant();
    bool CanTrade() const;
    int32 MerchantBuyPrice(int32 Kind) const;
    int32 MerchantSellPrice(int32 Kind) const;
    int32 MerchantRefreshPrice() const;
    bool BuyMerchant(int32 Slot);
    bool RefreshMerchant();
    bool SellMerchant(int32 Kind,bool All=false);
    bool ConfirmMerchantSale();
    void UpdateMerchant(float Delta);
    void UpdateMerchantVisual(float Delta);
    void StartMerchantEffect();
    void BeginMerchantDeparture();
    void MerchantSay(const FString& Line,float Seconds=3);
    void MerchantTradeFeedback(int32 Delta,FVector2D From,FVector2D To,const FString& Line);
    void UpdateMerchantFeedback();
    void MerchantSmoke(float Delta);
    void MerchantCapture(float Delta);
    bool FindSpawnPoint(int32 Type,FVector& Position);
    void SpawnWave();
    int32 Nearest(FVector Pos,float Range,const TArray<int32>& Exclude={}) const;
    void Fire(FVector From,FVector Target,float Damage,FLinearColor Color,bool Hostile=false,float Speed=1000,UNiagaraSystem* TrailSystem=nullptr,UNiagaraSystem* HitSystem=nullptr,float Lifetime=4,float EffectScale=1,float HitLife=.7f,bool Potion=false);
    void DamageEnemy(int32 Index,float Damage,FLinearColor Color=FLinearColor(1,.8f,.3f),UNiagaraSystem* HitSystem=nullptr,float EffectScale=1,float HitLife=.7f);
    void SlowEnemy(int32 Index,float Duration,float Factor);
    UNiagaraComponent* SpawnVFX(UNiagaraSystem* System,FVector Position,FLinearColor Color,float Scale,float Life);
    void UpdateFeedback(float Delta);
    int32 Area(FVector Pos,float Radius,float Damage,FLinearColor Color,float Slow=0,float SlowFactor=0.65f,UNiagaraSystem* CastSystem=nullptr,UNiagaraSystem* HitSystem=nullptr,float EffectScale=1,float CastLife=1.25f,float HitLife=.7f);
    void Hurt(float Damage);
    void Drop(FVector Pos,int32 Kind,int32 Count=1);
    void CastSkills(float Delta);
    void SmokeCheck(float Delta);
    void AlchemyCheck();
    int32 FeedbackParticles() const;
    float FeedbackAge() const;
    bool CaptureFeedback(float Delta);
    bool CheckDesignRuntime();
    void CaptureTools(float Delta);
    int32 RenderedEliteBars=0,RenderedBossBarY=-1;
    int32 FeedbackPeak=0;
    float FeedbackPauseAge=0;
};

UCLASS()
class AAlchemyHUD : public AHUD {
    GENERATED_BODY()
public:
    virtual void DrawHUD() override;
    virtual void NotifyHitBoxClick(FName BoxName) override;
    int32 DragMaterial=-1;
    AAlchemyWorld* World=nullptr;
    float S=1, OX=0, OY=0;
    int32 FocusIndex=0, DetailPage=0;
    FString LastPanel;
    TArray<FString> FocusOrder;
    TArray<FString> UIV02DrawnText;
    TMap<FString,FBox2D> ButtonRects;
    FBox2D DragSource, Furnace;
    float Measure(const FString& Value,float Size) const;
    void Activate(const FString& Id);
    void Text(const FString& Value,float X,float Y,float Size=20,FLinearColor Color=FLinearColor::White);
    void Paragraph(const FString& Value,float X,float Y,float Width,float Size=18,FLinearColor Color=FLinearColor::White);
    void Box(float X,float Y,float W,float H,FLinearColor Color);
    void Button(const FString& Id,const FString& Label,float X,float Y,float W=180,bool Enabled=true,float Height=48);
    void DrawMerchant();
    void DrawGreyfordFlow();
    void DrawMerchantFeedback();
};

UCLASS()
class AAlchemyMode : public AGameModeBase {
    GENERATED_BODY()
public:
    AAlchemyMode();
    virtual void StartPlay() override;
};
