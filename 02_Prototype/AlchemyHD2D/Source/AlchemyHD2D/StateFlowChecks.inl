#include "GameFramework/PlayerInput.h"

// -StateFlowTest owns temporary progress. false runs the real production Tick below the hook.
bool AAlchemyWorld::StateFlowCheck(float Dt) {
    static bool OK=true;
    static int32 Choices[3]={-1,-1,-1},ExpectedBank=0;
    static float Clock=0;
    auto PC=GetWorld()->GetFirstPlayerController();auto HUD=PC?Cast<AAlchemyHUD>(PC->GetHUD()):nullptr;
    if(!PC || !HUD)return true;
    const FString Dir=FPaths::ProjectDir()/TEXT("Evidence/StateFlow_20261101");
    const auto Check=[&](bool Pass,const TCHAR* Name){OK &= Pass;UE_LOG(LogTemp,Display,TEXT("STATE_FLOW_CHECK %s %s"),Name,Pass?TEXT("PASS"):TEXT("FAIL"));};
    const auto Next=[&](int Step){CaptureStep=Step;SmokeTime=0;};
    const auto SendEscape=[&](EInputEvent Event){PC->InputKey(FInputKeyParams(EKeys::Escape,Event,Event==IE_Pressed?1.0:0.0,false));};
    const auto QuietRun=[&](){
        for(auto& E:Enemies){if(IsValid(E.Body))E.Body->Destroy();if(IsValid(E.Shadow))E.Shadow->Destroy();}Enemies.Empty();
        for(auto& S:Shots){if(IsValid(S.Body))S.Body->Destroy();if(S.Trail.IsValid())S.Trail->DestroyComponent();}Shots.Empty();
        for(auto& D:Drops)if(IsValid(D.Body))D.Body->Destroy();Drops.Empty();
        ClearEliteWarning();Equipped.Empty();SpawnCD=NextElite=NextMerchantTime=10000;
    };
    const auto Die=[&](int32 Coins){RunCoins=Coins;HP=1;HurtInv=DodgeInv=0;Hurt(10000);};
    const auto Finish=[&](){SendEscape(IE_Released);UE_LOG(LogTemp,Display,TEXT("STATE_FLOW_%s"),OK?TEXT("PASS"):TEXT("FAIL"));FPlatformMisc::RequestExitWithStatus(false,OK?0:1);};
    SmokeTime+=Dt;
    if(CaptureStep==0){
        OK=true;Check(bCapture,TEXT("isolated_capture_prevents_real_player_save_IO"));if(!bCapture){Finish();return true;}
        IFileManager::Get().MakeDirectory(*Dir,true);SendEscape(IE_Released);
        Progress=NewObject<UAlchemyProgress>(this);MigrateProgress(true);Progress->TutorialComplete=true;StartRun();QuietRun();
        GrantXP(RequiredXP(RunLevel));Clock=RunTime;for(int I=0;I<3;I++)Choices[I]=LevelupChoices[I];
        Check(Panel==TEXT("levelup") && PendingLevelUps==1 && Choices[0]>=0,TEXT("actual_XP_grant_creates_required_upgrade_choices"));
        Action(TEXT("textsize"));Check(Panel==TEXT("fonts"),TEXT("actual_textsize_action_opens_fonts_from_upgrade"));
        Action(TEXT("close"));Check(Panel.IsEmpty(),TEXT("actual_fonts_close_leaves_pending_choice_for_Tick"));Next(1);return false;
    }
    if(CaptureStep==1){
        bool Same=true;for(int I=0;I<3;I++)Same &= Choices[I]==LevelupChoices[I];
        Check(Panel==TEXT("levelup") && PendingLevelUps==1 && Same && FMath::IsNearlyEqual(RunTime,Clock),TEXT("real_Tick_restores_identical_upgrade_before_battle_clock_advances"));
        const int Attr=Choices[0];const int Old=Attr>=0 && Attr<7?RunAttrs[Attr]:0;
        Action(FString::Printf(TEXT("pick%d"),Attr));
        Check(Attr>=0 && Attr<7 && RunAttrs[Attr]==Old+1 && PendingLevelUps==0 && Panel.IsEmpty(),TEXT("production_pick_resolves_required_upgrade_once"));Next(2);return true;
    }
    if(CaptureStep==2){
        ExpectedBank=Progress->Coins+23;Die(23);
        Check(bRunEnded && Panel==TEXT("defeat") && CharacterAnimation.Dead && !CharacterAnimation.DeathFinished(),TEXT("actual_lethal_Hurt_starts_death_before_settlement_controls"));
        Check(Progress->Coins==ExpectedBank && ResultCoins==23 && RunCoins==0,TEXT("death_banks_23_coins_exactly_once"));
        SendEscape(IE_Pressed);Next(3);return false;
    }
    if(CaptureStep==3){
        if(SmokeTime<.08f)return false;
        const bool Stayed=bRunEnded && Panel==TEXT("defeat") && GreyfordStage==1 && bCombat && CharacterAnimation.Dead && !CharacterAnimation.DeathFinished();
        Check(Stayed,TEXT("real_early_Esc_does_not_skip_unfinished_death_or_return_to_village"));
        Check(Progress->Coins==ExpectedBank,TEXT("early_Esc_does_not_bank_coins_again"));SendEscape(IE_Released);
        if(!Stayed){
            UE_LOG(LogTemp,Display,TEXT("STATE_FLOW_BASELINE_RECOVERY restarting_isolated_run_then_lethal_Hurt_with_zero_coins"));
            StartRun();QuietRun();Die(0);
        }
        Next(4);return false;
    }
    if(CaptureStep==4){
        if(!CharacterAnimation.DeathFinished() && SmokeTime<2)return false;
        Check(bRunEnded && Panel==TEXT("defeat") && CharacterAnimation.Dead && CharacterAnimation.DeathFinished(),TEXT("natural_production_Tick_completes_death_within_two_seconds"));
        const int LastFrame=CharacterAnimation.RoseMage && !CharacterAnimation.HasRoseMotion()?0:5;
        Check(CharacterAnimation.Row==4 && CharacterAnimation.Frame==LastFrame,TEXT("actual_character_material_pose_is_death_last_frame"));
        Check(HUD->ButtonRects.Contains(TEXT("village")),TEXT("rendered_HUD_exposes_settlement_return_only_after_death_finishes"));
        Check(Progress->Coins==ExpectedBank,TEXT("natural_death_completion_does_not_repeat_bank_credit"));Next(5);return true;
    }
    if(CaptureStep==5){
        if(SmokeTime<.6f)return true;
        FScreenshotRequest::RequestScreenshot(Dir/TEXT("01-death-settlement.png"),true,false);Next(6);return true;
    }
    if(CaptureStep==6){
        if(SmokeTime<.3f || FScreenshotRequest::IsScreenshotRequested())return true;
        Check(IFileManager::Get().FileSize(*(Dir/TEXT("01-death-settlement.png")))>0,TEXT("native_completed_death_and_settlement_frame_written"));
        SendEscape(IE_Pressed);Next(7);return false;
    }
    if(CaptureStep==7){
        if(SmokeTime<.2f)return false;
        Check(GreyfordStage==0 && !bCombat && !bRunEnded && Panel.IsEmpty(),TEXT("real_Esc_after_death_completion_returns_to_village"));
        Check(!CharacterAnimation.Dead && !CharacterAnimation.Hurting && !CharacterAnimation.Throwing && CharacterAnimation.Row==0,TEXT("return_to_village_resets_death_and_attack_pose"));
        Check(Progress->Coins==ExpectedBank,TEXT("completed_settlement_return_does_not_credit_coins_twice"));SendEscape(IE_Released);Next(8);return true;
    }
    if(CaptureStep==8){
        if(SmokeTime<.2f || FScreenshotRequest::IsScreenshotRequested())return true;
        Check(!PC->IsInputKeyDown(EKeys::Escape),TEXT("fixture_finishes_with_Esc_released"));Finish();return true;
    }
    Check(false,TEXT("bounded_fixture_stage"));Finish();return true;
}
