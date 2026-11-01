#include "Engine/GameViewportClient.h"
#include "GameFramework/PlayerInput.h"
#include "Components/ProgressBar.h"
#include "Input/HittestGrid.h"
#include "Layout/ArrangedWidget.h"
#include "Widgets/SWindow.h"
#include "Widgets/SToolTip.h"

// -UIV02Test -UIAccessTest: production Tick is frozen; Slate/UMG/DrawHUD stay live.
void AAlchemyWorld::UIAccessCheck(float Dt) {
    static bool OK=true;
    static int BossHintCase=0;
    static TWeakPtr<IToolTip> DodgeTip, XPTip, SkillTip;
    auto PC=GetWorld()->GetFirstPlayerController();auto HUD=PC?Cast<AAlchemyHUD>(PC->GetHUD()):nullptr;
    if(!PC || !HUD)return;
    const FString Dir=FPaths::ProjectDir()/TEXT("Evidence/UIAccess_20261101");
    const auto Check=[&](bool Pass,const TCHAR* Name){OK &= Pass;UE_LOG(LogTemp,Display,TEXT("UIACCESS_CHECK %s %s"),Name,Pass?TEXT("PASS"):TEXT("FAIL"));};
    const auto Next=[&](int Step){CaptureStep=Step;SmokeTime=0;};
    const auto Key=[&](EInputEvent Event){PC->InputKey(FInputKeyParams(EKeys::Enter,Event,Event==IE_Pressed?1.0:0.0,false));};
    const auto FocusedMaterial=[&](){return HUD->FocusOrder.IsValidIndex(HUD->FocusIndex) && HUD->FocusOrder[HUD->FocusIndex]==TEXT("material0");};
    const auto Bar=[&](const TCHAR* Name){return BattleWidget?Cast<UProgressBar>(BattleWidget->GetWidgetFromName(Name)):nullptr;};
    const auto Tip=[&](UWidget* Target)->TSharedPtr<IToolTip>{return Target && Target->GetCachedWidget().IsValid()?Target->GetCachedWidget()->GetToolTip():nullptr;};
    const auto TipText=[&](const TSharedPtr<IToolTip>& Value){
        if(!Value.IsValid())return FString();
        const auto Widget=Value->AsWidget(); // UE5.8 wraps the real SToolTip in SDeferredToolTipText.
        if(Widget->GetType()!=FName(TEXT("SToolTip")))return FString();
        return StaticCastSharedRef<SToolTip>(Widget)->GetTextTooltip().ToString();
    };
    const auto Hit=[&](UProgressBar* Target){
        const auto Viewport=GetWorld()->GetGameViewport();const auto Window=Viewport?Viewport->GetWindow():nullptr;
        if(!Target || !Window.IsValid() || !Target->GetCachedWidget().IsValid())return false;
        const FGeometry& G=Target->GetCachedGeometry();if(G.GetLocalSize().X<=0 || G.GetLocalSize().Y<=0)return false;
        const auto Path=Window->GetHittestGrid().GetBubblePath(G.LocalToAbsolute(G.GetLocalSize()*.5f),0.f,false);
        for(const auto& Entry:Path)if(Entry.GetWidgetPtr()==Target->GetCachedWidget().Get())return true;
        return false;
    };
    const auto Finish=[&](){Key(IE_Released);UE_LOG(LogTemp,Display,TEXT("UIACCESS_%s"),OK?TEXT("PASS"):TEXT("FAIL"));FPlatformMisc::RequestExitWithStatus(false,OK?0:1);};
    const int BossStates[]={0,0,1,2,3,4,5};
    const TCHAR* BossHints[]={TEXT("准备阶段 · 观察站位，倒计时结束后开战"),TEXT("保持移动 · 等待Boss出招"),TEXT("冲刺蓄力 · 方向锁定后向侧面躲开"),TEXT("冲刺中 · 避开橙色路线"),TEXT("收招停顿 · 调整站位并输出"),TEXT("两波弹幕 · 观察青色弹道间隙"),TEXT("两波弹幕 · 观察青色弹道间隙")};
    SmokeTime+=Dt;
    if(CaptureStep==0){
        OK=true;BossHintCase=0;Check(bCapture,TEXT("isolated_capture_prevents_player_save_IO"));if(!bCapture){Finish();return;}
        IFileManager::Get().MakeDirectory(*Dir,true);Key(IE_Released);
        Progress=NewObject<UAlchemyProgress>(this);MigrateProgress(true);Progress->TutorialComplete=true;StartRun();
        Inventory={5,0,0,0,0,0};Selected={0,0,0,0,0,0};Progress->Combinations.Empty();
        RunXP=RequiredXP(RunLevel)/2.f;DodgeCD=1;Panel.Empty();ToastTime=0;Next(1);return;
    }
    if(CaptureStep==1){
        if(SmokeTime<.6f)return;
        Check(BattleWidget && BattleWidget->GetClass()->GetPathName().Contains(TEXT("/Game/UI/Reference/WBP_BattleReference.")),TEXT("real_editable_reference_WBP_instance_loaded"));
        auto Dodge=Bar(TEXT("DodgeBar"));auto XP=Bar(TEXT("XPBar"));
        Check(Dodge && XP && Dodge->GetCachedGeometry().GetLocalSize().X>0 && XP->GetCachedGeometry().GetLocalSize().X>0,TEXT("rendered_progress_bars_have_real_cached_geometry"));
        auto CurrentDodgeTip=Tip(Dodge);auto CurrentXPTip=Tip(XP);DodgeTip=CurrentDodgeTip;XPTip=CurrentXPTip;
        SkillTip=Tip(BattleWidget?BattleWidget->GetWidgetFromName(TEXT("SkillArt0")):nullptr);
        Check(SkillTip.IsValid(),TEXT("actual_equipped_skill0_has_Slate_tooltip"));
        Check(TipText(CurrentDodgeTip)==TEXT("Space · 闪避 1.0s"),TEXT("actual_Slate_Dodge_tooltip_binds_current_cooldown"));
        Check(TipText(CurrentXPTip)==FString::Printf(TEXT("经验 %.0f / %d"),RunXP,RequiredXP(RunLevel)),TEXT("actual_Slate_XP_tooltip_binds_current_and_required_experience"));
        Check(Hit(Dodge) && Hit(XP),TEXT("actual_Slate_hittest_paths_include_both_tooltip_bars"));
        DodgeCD=0;Next(2);return;
    }
    if(CaptureStep==2){
        if(SmokeTime<.3f)return;
        const auto CurrentDodgeTip=Tip(Bar(TEXT("DodgeBar")));const auto CurrentXPTip=Tip(Bar(TEXT("XPBar")));
        Check(DodgeTip.IsValid() && XPTip.IsValid() && DodgeTip.Pin()==CurrentDodgeTip && XPTip.Pin()==CurrentXPTip,TEXT("both_Slate_tooltip_instances_persist_across_frames_and_state_update"));
        Check(SkillTip.IsValid() && SkillTip.Pin()==Tip(BattleWidget?BattleWidget->GetWidgetFromName(TEXT("SkillArt0")):nullptr),TEXT("unchanged_equipped_skill_Slate_tooltip_instance_persists_across_frames"));
        Check(TipText(CurrentDodgeTip)==TEXT("Space · 闪避就绪"),TEXT("actual_Slate_Dodge_tooltip_updates_to_ready_state"));
        Action(TEXT("pausebtn"));Check(Panel==TEXT("pause"),TEXT("production_pause_action_opens_modal"));Next(3);return;
    }
    if(CaptureStep==3){
        if(SmokeTime<.3f)return;
        Check(!Hit(Bar(TEXT("DodgeBar"))) && !Hit(Bar(TEXT("XPBar"))),TEXT("paused_modal_removes_both_HUD_bars_from_Slate_hittest_paths"));
        Action(TEXT("close"));Check(Panel.IsEmpty(),TEXT("production_close_action_restores_battle"));Next(4);return;
    }
    if(CaptureStep==4){
        if(SmokeTime<.3f)return;
        Check(Hit(Bar(TEXT("DodgeBar"))) && Hit(Bar(TEXT("XPBar"))),TEXT("resumed_HUD_restores_both_tooltip_hittest_paths"));
        TogglePanel(TEXT("alchemy"));Next(5);return;
    }
    if(CaptureStep==5){
        if(SmokeTime<.6f)return;
        Check(Panel==TEXT("alchemy") && FocusedMaterial() && Selected[0]==0,TEXT("empty_furnace_initial_keyboard_focus_is_material0"));
        Key(IE_Pressed);Next(6);return;
    }
    if(CaptureStep==6){
        if(SmokeTime<.3f)return;
        Check(Selected[0]==1 && Inventory[0]==5,TEXT("first_real_Enter_press_selects_exactly_one_material_without_spending_inventory"));
        Check(FocusedMaterial(),TEXT("dynamic_furnace_insertion_preserves_material_keyboard_focus_by_ID"));
        FScreenshotRequest::RequestScreenshot(Dir/TEXT("01-keyboard-focus.png"),true,false);Next(7);return;
    }
    if(CaptureStep==7){
        if(SmokeTime<.3f || FScreenshotRequest::IsScreenshotRequested())return;
        Check(IFileManager::Get().FileSize(*(Dir/TEXT("01-keyboard-focus.png")))>0,TEXT("native_first_material_focus_frame_written"));
        Key(IE_Released);Next(8);return;
    }
    if(CaptureStep==8){
        if(SmokeTime<.2f)return;
        Check(!PC->IsInputKeyDown(EKeys::Enter),TEXT("first_Enter_released_before_second_press"));
        Key(IE_Pressed);Next(9);return;
    }
    if(CaptureStep==9){
        if(SmokeTime<.3f)return;
        Check(Selected[0]==2 && Inventory[0]==5 && Selected[1]==0 && Selected[2]==0,TEXT("second_real_Enter_press_adds_second_material_instead_of_removing_first"));
        Check(FocusedMaterial(),TEXT("second_furnace_insertion_keeps_material_keyboard_focus"));Key(IE_Released);Next(10);return;
    }
    if(CaptureStep==10){
        if(SmokeTime<.2f || FScreenshotRequest::IsScreenshotRequested())return;
        Check(!PC->IsInputKeyDown(EKeys::Enter),TEXT("fixture_finishes_with_Enter_released"));Action(TEXT("close"));
        StartRun();GreyfordPortalReady=true;GreyfordPortalPos=PlayerPos;Check(EnterGreyfordBoss() && Enemies.Num()==1,TEXT("actual_Boss_entry_available_for_HUD_state_checks"));Next(13);return;
    }
    if(CaptureStep==13){
        if(Enemies.IsEmpty()){Finish();return;}
        GreyfordBossPreparation=BossHintCase==0?2:0;Enemies[0].PlannedState=BossStates[BossHintCase];Next(14);return;
    }
    if(CaptureStep==14){
        if(SmokeTime<.3f)return;
        UE_LOG(LogTemp,Display,TEXT("UIACCESS_BOSS_HINT case=%d preparation=%.1f state=%d"),BossHintCase,GreyfordBossPreparation,Enemies[0].PlannedState);
        Check(HUD->UIV02DrawnText.Contains(BossHints[BossHintCase]),TEXT("rendered_Boss_hint_matches_preparation_or_actual_planned_state"));
        if(BossHintCase<2)FScreenshotRequest::RequestScreenshot(Dir/(BossHintCase==0?TEXT("03-boss-preparation.png"):TEXT("04-boss-idle.png")),true,false);
        Next(15);return;
    }
    if(CaptureStep==15){
        if(SmokeTime<.3f || FScreenshotRequest::IsScreenshotRequested())return;
        if(++BossHintCase<UE_ARRAY_COUNT(BossStates)){Next(13);return;}
        Finish();return;
    }
    Check(false,TEXT("bounded_fixture_stage"));Finish();
}
