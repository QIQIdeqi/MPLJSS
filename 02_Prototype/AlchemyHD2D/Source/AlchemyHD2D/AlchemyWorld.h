#pragma once
#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "GameFramework/GameModeBase.h"
#include "GameFramework/HUD.h"
#include "GameFramework/SaveGame.h"
#include "AlchemyDesignTools.h"
#include "AlchemistSpriteAnimation.h"
#include "AlchemyWorld.generated.h"

class AStaticMeshActor;
class ACameraActor;
class UMaterialInterface;
class UNiagaraSystem;
class UNiagaraComponent;

UCLASS()
class UAlchemyProgress : public USaveGame {
    GENERATED_BODY()
public:
    UPROPERTY() int32 Coins=0;
    UPROPERTY() TArray<int32> Talents={0,0,0,0};
    UPROPERTY() TArray<int32> Recipes;
    UPROPERTY() TArray<int32> Chains;
    UPROPERTY() int32 SchemaVersion=0;
    UPROPERTY() bool TutorialComplete=false;
    UPROPERTY() TArray<int32> Combinations;
    UPROPERTY() TArray<int32> ChainsV2;
    UPROPERTY() float UITextScale=1;
    UPROPERTY() float MediumTextScale=.9f;
    UPROPERTY() float LargeTextScale=.72f;
    // TALENT-002: three one-shot unlock nodes (no levels).
    UPROPERTY() bool RefreshUnlocked=false;
    UPROPERTY() bool DropRateUnlocked=false;
    UPROPERTY() bool StartMaterialUnlocked=false;
    float FontSize(float Size) const { return Size*(Size<=18?1.f:Size<26?MediumTextScale:LargeTextScale); }
};

struct FAlchemyEnemy {
    AStaticMeshActor* Body=nullptr;
    AStaticMeshActor* Shadow=nullptr;
    FVector Pos=FVector::ZeroVector;
    int32 Type=0;
    float HP=1, MaxHP=1, Speed=1, Contact=0, AttackCD=1, Windup=0, Slow=0, Transition=0;
    FVector Aim=FVector::ZeroVector;
    bool Phase2=false;
    int32 BossAttack=0, BossSequence=0;
    float BossActive=0;
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
    bool CraftOptions(TArray<int32>& Skills,TArray<float>& Weights,FString& Reason,int32& Combination) const;
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
    float MerchantRemaining=0,NextMerchantTime=80;
    int32 MerchantVisit=0,MerchantRerolls=0,MerchantStock[3]={0,1,2};
    bool MerchantSoldOut[3]={false,false,false};
    int32 MerchantSellKind=-1,MerchantSellCount=0;
    FRandomStream MerchantRandom{1177};
    UPROPERTY() TObjectPtr<AStaticMeshActor> MerchantBody;
    UPROPERTY() TObjectPtr<AStaticMeshActor> MerchantStall;
    UPROPERTY() TObjectPtr<AStaticMeshActor> MerchantMarker;
    TArray<float> SkillCD,ChainCD;
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
    TMap<FString,FBox2D> ButtonRects;
    FBox2D DragSource, Furnace;
    float Measure(const FString& Value,float Size) const;
    void Activate(const FString& Id);
    void Text(const FString& Value,float X,float Y,float Size=20,FLinearColor Color=FLinearColor::White);
    void Paragraph(const FString& Value,float X,float Y,float Width,float Size=18,FLinearColor Color=FLinearColor::White);
    void Box(float X,float Y,float W,float H,FLinearColor Color);
    void Button(const FString& Id,const FString& Label,float X,float Y,float W=180,bool Enabled=true,float Height=48);
    void DrawMerchant();
};

UCLASS()
class AAlchemyMode : public AGameModeBase {
    GENERATED_BODY()
public:
    AAlchemyMode();
    virtual void StartPlay() override;
};
