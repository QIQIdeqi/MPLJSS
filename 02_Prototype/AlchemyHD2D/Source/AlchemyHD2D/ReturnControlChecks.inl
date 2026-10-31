#include "GameFramework/PlayerInput.h"

// Isolated -ReturnControlTest: false allows the actual movement/death/settlement Tick.
bool AAlchemyWorld::ReturnControlCheck(float Dt) {
    static bool OK=true,SawHidden=false;
    static int32 ExpectedBank=0;
    static FVector CorridorDirection,VillageStart;
    static float MaxVillageMovement=0;
    auto PC=GetWorld()->GetFirstPlayerController();if(!PC || !Player)return true;
    const FString Dir=FPaths::ProjectDir()/TEXT("Evidence/ReturnControl_20261101");
    const auto Check=[&](bool Pass,const TCHAR* Name){OK &= Pass;UE_LOG(LogTemp,Display,TEXT("RETURN_CONTROL_CHECK %s %s"),Name,Pass?TEXT("PASS"):TEXT("FAIL"));};
    const auto Next=[&](int Step){CaptureStep=Step;SmokeTime=0;};
    const auto Space=[&](EInputEvent Event){PC->InputKey(FInputKeyParams(EKeys::SpaceBar,Event,Event==IE_Pressed?1.0:0.0,false));};
    const auto TimersClear=[&](){return DodgeCD==0 && DodgeTime==0 && HurtInv==0 && DodgeInv==0;};
    const auto QuietRun=[&](){
        for(auto& E:Enemies){if(IsValid(E.Body))E.Body->Destroy();if(IsValid(E.Shadow))E.Shadow->Destroy();}Enemies.Empty();
        for(auto& S:Shots){if(IsValid(S.Body))S.Body->Destroy();if(S.Trail.IsValid())S.Trail->DestroyComponent();}Shots.Empty();
        for(auto& D:Drops)if(IsValid(D.Body))D.Body->Destroy();Drops.Empty();
        ClearEliteWarning();Equipped.Empty();SpawnCD=NextElite=NextMerchantTime=10000;
    };
    const auto Observe=[&](){SawHidden |= Player->IsHidden();MaxVillageMovement=FMath::Max(MaxVillageMovement,float(FVector::Dist2D(VillageStart,PlayerPos)));};
    const auto BeginVillage=[&](){VillageStart=PlayerPos;SawHidden=Player->IsHidden();MaxVillageMovement=0;};
    const auto Finish=[&](){Space(IE_Released);UE_LOG(LogTemp,Display,TEXT("RETURN_CONTROL_%s"),OK?TEXT("PASS"):TEXT("FAIL"));FPlatformMisc::RequestExitWithStatus(false,OK?0:1);};
    SmokeTime+=Dt;
    if(CaptureStep==0){
        OK=true;Check(bCapture,TEXT("isolated_capture_prevents_real_player_save_IO"));if(!bCapture){Finish();return true;}
        IFileManager::Get().MakeDirectory(*Dir,true);Space(IE_Released);
        Check(GreyfordStage==0 && !bCombat,TEXT("fixture_begins_in_actual_village"));CorridorDirection=FVector::ZeroVector;
        for(int I=0;I<32;I++){const float A=I*2*PI/32;const FVector D(FMath::Cos(A),FMath::Sin(A),0);if(SegmentClear(PlayerPos,PlayerPos+D*350,45)){CorridorDirection=D;break;}}
        Check(!CorridorDirection.IsNearlyZero(),TEXT("village_has_350cm_free_corridor_for_residual_dash_observation"));
        if(CorridorDirection.IsNearlyZero()){Finish();return true;}
        Progress=NewObject<UAlchemyProgress>(this);MigrateProgress(true);Progress->TutorialComplete=true;StartRun();QuietRun();
        GreyfordPortalReady=true;GreyfordPortalPos=PlayerPos;Check(EnterGreyfordBoss(),TEXT("win_real_Boss_entry_succeeds"));
        // Fixed-position fixture skips only the preparation countdown; boss death remains production-driven.
        GreyfordBossPreparation=0;GreyfordBossWarmupFrames=0;Equipped.Empty();LastDirection=CorridorDirection;
        RunCoins=17;ExpectedBank=Progress->Coins+17;Space(IE_Pressed);Next(1);return false;
    }
    if(CaptureStep==1){
        if(DodgeTime<=0 && SmokeTime<.5f)return false;
        Check(DodgeTime>0 && DodgeInv>0 && DodgeCD>0,TEXT("win_real_Space_input_starts_dash_invulnerability_and_cooldown"));
        Check(Enemies.Num()==1 && Enemies[0].Type==10,TEXT("win_fixture_contains_actual_Boss"));
        if(Enemies.IsEmpty()){Finish();return true;}
        DamageEnemy(0,Enemies[0].HP+1);Next(2);return false;
    }
    if(CaptureStep==2){
        if(!bRunEnded && SmokeTime<.3f)return false;
        Check(bRunEnded && bWon && Panel==TEXT("victory") && GreyfordStage==2,TEXT("win_real_Tick_processes_Boss_death_and_victory"));
        Check(DodgeTime>0 && DodgeInv>0 && DodgeCD>0,TEXT("win_settlement_fixture_preserves_active_dash_before_return"));
        Check(Progress->Coins==ExpectedBank && ResultCoins==17 && RunCoins==0,TEXT("win_Boss_settlement_banks_17_once"));Space(IE_Released);
        Action(TEXT("village"));Check(GreyfordStage==0 && !bCombat && !bRunEnded && Panel.IsEmpty(),TEXT("win_production_action_returns_to_village"));
        Check(TimersClear(),TEXT("win_village_entry_clears_dash_hurt_and_invulnerability_timers"));
        Check(SegmentClear(PlayerPos,PlayerPos+CorridorDirection*350,45),TEXT("win_return_spawn_retains_free_corridor_so_collision_cannot_hide_dash_bug"));
        BeginVillage();Next(3);return false;
    }
    if(CaptureStep==3){
        Observe();if(SmokeTime<.35f)return false;
        Check(MaxVillageMovement<.01f,TEXT("win_actual_village_Tick_without_WASD_does_not_continue_dash"));
        Check(!SawHidden,TEXT("win_actual_village_Ticks_never_blink_or_hide_player"));
        Check(Progress->Coins==ExpectedBank,TEXT("win_village_Ticks_do_not_credit_bank_again"));Next(4);return true;
    }
    if(CaptureStep==4){
        if(SmokeTime<.6f)return true;
        FScreenshotRequest::RequestScreenshot(Dir/TEXT("01-victory-return.png"),true,false);Next(5);return true;
    }
    if(CaptureStep==5){
        if(SmokeTime<.3f || FScreenshotRequest::IsScreenshotRequested())return true;
        Check(IFileManager::Get().FileSize(*(Dir/TEXT("01-victory-return.png")))>0,TEXT("win_native_return_screenshot_written"));
        StartRun();QuietRun();ExpectedBank+=5;RunCoins=5;HP=1;HurtInv=DodgeInv=0;Hurt(10000);
        Check(bRunEnded && !bWon && Panel==TEXT("defeat") && CharacterAnimation.Dead && HurtInv>0,TEXT("loss_actual_lethal_Hurt_starts_death_with_hurt_invulnerability"));
        Check(Progress->Coins==ExpectedBank && ResultCoins==5 && RunCoins==0,TEXT("loss_death_settlement_banks_5_once"));Next(6);return false;
    }
    if(CaptureStep==6){
        if(!CharacterAnimation.DeathFinished() && SmokeTime<2)return false;
        Check(CharacterAnimation.Dead && CharacterAnimation.DeathFinished() && bRunEnded,TEXT("loss_natural_Tick_finishes_death_before_return"));
        Action(TEXT("village"));Check(GreyfordStage==0 && !bCombat && !bRunEnded && Panel.IsEmpty(),TEXT("loss_production_action_returns_to_village"));
        Check(TimersClear(),TEXT("loss_village_entry_clears_dash_hurt_and_invulnerability_timers"));BeginVillage();Next(7);return false;
    }
    if(CaptureStep==7){
        Observe();if(SmokeTime<.35f)return false;
        Check(MaxVillageMovement<.01f,TEXT("loss_actual_village_Tick_without_WASD_does_not_move_player"));
        Check(!SawHidden,TEXT("loss_actual_village_Ticks_do_not_inherit_death_hurt_blink"));
        Check(Progress->Coins==ExpectedBank,TEXT("loss_village_Ticks_do_not_credit_bank_again"));Next(8);return true;
    }
    if(CaptureStep==8){
        if(SmokeTime<.6f)return true;
        FScreenshotRequest::RequestScreenshot(Dir/TEXT("02-defeat-return.png"),true,false);Next(9);return true;
    }
    if(CaptureStep==9){
        if(SmokeTime<.3f || FScreenshotRequest::IsScreenshotRequested())return true;
        Check(IFileManager::Get().FileSize(*(Dir/TEXT("02-defeat-return.png")))>0,TEXT("loss_native_return_screenshot_written"));
        Check(!PC->IsInputKeyDown(EKeys::SpaceBar),TEXT("fixture_finishes_with_Space_released"));Finish();return true;
    }
    Check(false,TEXT("bounded_fixture_stage"));Finish();return true;
}
