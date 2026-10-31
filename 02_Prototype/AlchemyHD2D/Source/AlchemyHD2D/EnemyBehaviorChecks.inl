#include "Engine/DataTable.h"
#include "UObject/ObjectKey.h"

// Synthetic, no-save AI fixture: fixed legal placement, real production enemy/projectile Tick.
bool AAlchemyWorld::EnemyBehaviorCheck(float Dt) {
    static bool OK=true,SawWindup=false,SawDamage=false,SawInvulnerability=false,SawReaction=false;
    static int Case=0,DefinitionID=-1;static float BeforeHP=0,FirstFireCD=-1,FirstFireClock=-1;
    static FVector Origin=FVector::ZeroVector;static TArray<FAlchemyEnemyRow> Original;
    static TSet<FObjectKey> FiredBodies;
    const TCHAR* Names[]={TEXT("base_contact_zero"),TEXT("tuned_contact_zero"),TEXT("base_area_zero"),TEXT("tuned_area_zero"),TEXT("base_ranged_zero"),TEXT("tuned_ranged_zero"),TEXT("ranged_keep_equals_min"),TEXT("ranged_keep_equals_max"),TEXT("ranged_below_min"),TEXT("ranged_above_max")};
    const auto Check=[&](bool Pass,const TCHAR* Name){OK &= Pass;UE_LOG(LogTemp,Display,TEXT("ENEMY_BEHAVIOR_CHECK case=%s %s %s"),Names[Case],Name,Pass?TEXT("PASS"):TEXT("FAIL"));};
    const auto Next=[&](int Step){CaptureStep=Step;SmokeTime=0;};
    const auto Clear=[&](){
        for(auto& E:Enemies){if(IsValid(E.Body))E.Body->Destroy();if(IsValid(E.Shadow))E.Shadow->Destroy();}Enemies.Empty();
        for(auto& S:Shots){if(IsValid(S.Body))S.Body->Destroy();if(S.Trail.IsValid())S.Trail->DestroyComponent();}Shots.Empty();
        for(auto& D:Drops)if(IsValid(D.Body))D.Body->Destroy();Drops.Empty();
        for(auto& F:NiagaraFX)if(IsValid(F.Component))F.Component->DestroyComponent();NiagaraFX.Empty();
        for(auto& F:Effects)if(IsValid(F.Body))F.Body->Destroy();Effects.Empty();DamageNumbers.Empty();ClearPixelFX();
    };
    const auto Finish=[&](){Clear();if(!Original.IsEmpty())RuntimeEnemies=Original;UE_LOG(LogTemp,Display,TEXT("ENEMY_BEHAVIOR_%s"),OK?TEXT("PASS"):TEXT("FAIL"));FPlatformMisc::RequestExitWithStatus(false,OK?0:1);};
    SmokeTime+=Dt;
    if(CaptureStep==0){
        OK=true;Case=0;Check(bCapture,TEXT("isolated_capture_prevents_player_save_IO"));if(!bCapture){Finish();return true;}
        Original=RuntimeEnemies;Check(Original.Num()>=11,TEXT("actual_runtime_table_has_original_compatible_rows"));if(Original.Num()<11){Finish();return true;}
        Progress=NewObject<UAlchemyProgress>(this);MigrateProgress(false);StartRun();Clear();
        Equipped.Empty();SpawnCD=NextElite=NextMerchantTime=10000;ClearEliteWarning();
        bool Found=false;const FVector2D Points[]={{1000,400},{820,540},{570,350},{1140,620},{700,700}};
        for(const auto Pixel:Points){const FVector P=bBattleReference?BattleReferencePoint(Pixel):PlayerPos;
            const FVector Rounded(FMath::RoundToInt(P.X),FMath::RoundToInt(P.Y),0);
            if(Walkable(Rounded,45) && SegmentClear(Rounded,Rounded+FVector(750,0,0),45)){Origin=Rounded;Found=true;break;}}
        Check(Found,TEXT("integer_axis_aligned_750cm_fixture_corridor_is_legal"));if(!Found){Finish();return true;}
        PlayerPos=Origin;UpdateCamera(0);UpdateCharacterVisual(0,false);Next(1);return true;
    }
    if(CaptureStep==1){
        Clear();PlayerPos=Origin;HP=MaxHP;HurtInv=DodgeInv=DodgeCD=DodgeTime=0;CharacterAnimation.Reset();Panel.Empty();
        SawWindup=SawDamage=SawInvulnerability=SawReaction=false;FiredBodies.Empty();FirstFireCD=FirstFireClock=-1;
        FAlchemyEnemyRow Row=Original[0];Row.Name=FString::Printf(TEXT("QA_%s"),Names[Case]);Row.Archetype=0;Row.Speed=0;Row.HP=10000;Row.TunedHP=-1;
        Row.ContactDamage=Row.AreaDamage=Row.RangedDamage=0;Row.TunedContactDamage=Row.TunedAreaDamage=Row.TunedRangedDamage=-1;
        Row.SpawnWeights.Init(0,6);Row.EliteWeight=0;Row.AreaTrigger=200;Row.AreaRadius=160;Row.AreaWindup=.55f;Row.AreaCD=2.8f;
        Row.RangedMin=200;Row.RangedMax=750;Row.RangedKeepDistance=550;Row.RangedSpeed=1000;Row.RangedCD=2.8f;
        Row.Behavior=Case<2?EAlchemyEnemyBehavior::Contact:Case<4?EAlchemyEnemyBehavior::Area:EAlchemyEnemyBehavior::Ranged;
        bTune001B=Case==1 || Case==3 || Case==5;
        if(Case==1){Row.ContactDamage=9;Row.TunedContactDamage=0;}
        if(Case==3){Row.AreaDamage=9;Row.TunedAreaDamage=0;}
        if(Case==5){Row.RangedDamage=9;Row.TunedRangedDamage=0;}
        float Distance=Case<2?50:Case<4?100:500;
        if(Case==6 || Case==8){Row.RangedKeepDistance=Row.RangedMin;Distance=Case==6?200:199;}
        if(Case==7 || Case==9){Row.RangedKeepDistance=Row.RangedMax;Distance=Case==7?750:751;}
        auto Table=NewObject<UDataTable>(this);Table->RowStruct=FAlchemyEnemyRow::StaticStruct();
        for(int I=0;I<Original.Num();I++)Table->AddRow(FName(*FString::FromInt(I)),Original[I]);DefinitionID=Original.Num();Table->AddRow(FName(*FString::FromInt(DefinitionID)),Row);
        TArray<FAlchemyEnemyRow> Parsed;FString Error;const bool Valid=AlchemyDesign::ReadEnemyDefinitions(Table,Parsed,Error);
        Check(Valid,TEXT("in_memory_appended_row_passes_real_ReadEnemyDefinitions"));if(!Valid){UE_LOG(LogTemp,Error,TEXT("ENEMY_BEHAVIOR_CONFIG %s"),*Error);Finish();return true;}
        RuntimeEnemies=MoveTemp(Parsed);SpawnEnemyAt(DefinitionID,Origin+FVector(Distance,0,0));
        Check(Enemies.Num()==1,TEXT("actual_configured_enemy_spawned"));if(Enemies.IsEmpty()){Finish();return true;}
        Enemies[0].AttackCD=0;BeforeHP=HP;const float ActualDistance=(PlayerPos-Enemies[0].Pos).Size2D();
        Check(ActualDistance==Distance,TEXT("actual_AI_distance_equals_exact_integer_fixture_distance"));
        UE_LOG(LogTemp,Display,TEXT("ENEMY_BEHAVIOR_CONFIG case=%s definition=%d tuned=%d distance=%.9f min=%.1f keep=%.1f max=%.1f"),Names[Case],DefinitionID,bTune001B,ActualDistance,Row.RangedMin,Row.RangedKeepDistance,Row.RangedMax);
        Next(2);return false;
    }
    if(CaptureStep==2){
        if(Enemies.Num()!=1){Check(false,TEXT("bounded_case_retains_actual_enemy"));Finish();return true;}
        auto& E=Enemies[0];SawWindup |= E.Windup>0;SawDamage |= HP<BeforeHP;SawInvulnerability |= HurtInv>0;SawReaction |= CharacterAnimation.Hurting;
        for(const auto& S:Shots)if(S.Hostile && IsValid(S.Body))FiredBodies.Add(FObjectKey(S.Body));
        if(E.AttackCD>0 && FirstFireCD<0 && Case>=4){FirstFireCD=E.AttackCD;FirstFireClock=RunTime;}
        bool Done=false;
        if(Case<2)Done=E.AttackCD>0;
        else if(Case<4)Done=SawWindup && E.Windup<=0 && E.AttackCD>0;
        else if(Case<6)Done=FiredBodies.Num()>0 && Shots.IsEmpty();
        else if(Case<8)Done=FirstFireCD>=0 && RunTime-FirstFireClock>=.3f;
        else Done=SmokeTime>=.4f;
        if(!Done && SmokeTime<1.8f)return false;
        Check(Done,TEXT("production_AI_case_completes_within_bounded_time"));
        if(Case<6){
            Check(!SawDamage && HP==BeforeHP,TEXT("zero_damage_AI_does_not_reduce_HP"));
            Check(!SawInvulnerability && HurtInv==0,TEXT("zero_damage_AI_does_not_grant_hurt_invulnerability"));
            Check(!SawReaction && !CharacterAnimation.Hurting,TEXT("zero_damage_AI_does_not_start_hurt_animation"));
            // Direct positive control, explicitly separate from the real AI activation above.
            const float PriorHP=HP;Hurt(.1f);const bool PositiveHit=FMath::IsNearlyEqual(PriorHP-HP,1.f);Check(PositiveHit,TEXT("direct_tiny_positive_Hurt_after_zero_AI_still_deals_minimum_one"));
            const float AfterPositive=HP;Hurt(8);Check(PositiveHit && HP==AfterPositive,TEXT("direct_positive_Hurt_respects_normal_protection_after_real_hit"));
        }else if(Case<8){
            Check(FiredBodies.Num()==1 && FirstFireCD>0,TEXT("accepted_keep_distance_endpoint_fires_once"));
            Check(E.AttackCD>0 && E.AttackCD<FirstFireCD,TEXT("ranged_cooldown_counts_down_without_refiring_early"));
        }else Check(FiredBodies.IsEmpty() && FirstFireCD<0 && E.AttackCD<=0,TEXT("outside_min_max_does_not_fire_or_consume_attack_cooldown"));
        if(++Case<10){Next(1);return true;}Case=9;Finish();return true;
    }
    Check(false,TEXT("bounded_fixture_stage"));Finish();return true;
}
