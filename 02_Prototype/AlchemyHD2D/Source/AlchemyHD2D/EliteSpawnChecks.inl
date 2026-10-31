// Rendered isolated fixture. false permits production Tick for pause and natural-schedule checks.
bool AAlchemyWorld::EliteSpawnCheck(float Dt) {
    static bool ESOK=true,ESWarning=false,ESNoEarly=true,ESSawWarning=false;static int ESPause=0,ESCoins=0,ESKills=0,ESIndex=0;
    static float ESNext=0,ESRemaining=0,ESRetry=0,ESTime=0;static FVector ESOrigin;
    static TWeakObjectPtr<AStaticMeshActor> ESMarker;
    const FString Dir=FPaths::ProjectDir()/TEXT("Evidence/EliteSpawn_20261101");
    const auto Check=[&](bool Pass,const TCHAR* Name){ESOK &= Pass;UE_LOG(LogTemp,Display,TEXT("ELITESPAWN_CHECK %s %s"),Name,Pass?TEXT("PASS"):TEXT("FAIL"));};
    const auto Clear=[&](){for(auto& E:Enemies){if(IsValid(E.Body))E.Body->Destroy();if(IsValid(E.Shadow))E.Shadow->Destroy();}Enemies.Empty();};
    const auto Next=[&](int Step){CaptureStep=Step;SmokeTime=0;};
    const auto Shot=[&](const TCHAR* Name){
#if WITH_EDITOR
        FAssetCompilingManager::Get().FinishAllCompilation();if(GShaderCompilingManager)GShaderCompilingManager->FinishAllCompilation();
#endif
        FScreenshotRequest::RequestScreenshot(Dir/Name,true,false);
    };
    const auto Finish=[&](){UE_LOG(LogTemp,Display,TEXT("ELITESPAWN_%s"),ESOK?TEXT("PASS"):TEXT("FAIL"));FPlatformMisc::RequestExitWithStatus(false,ESOK?0:1);};
    if(CaptureStep==0){
        ESOK=true;ESPause=0;Check(bCapture,TEXT("isolated_fixture_never_uses_real_player_save"));if(!bCapture){Finish();return true;}
        IFileManager::Get().MakeDirectory(*Dir,true);Progress=NewObject<UAlchemyProgress>(this);MigrateProgress(true);StartRun();Clear();ClearEliteWarning();
        ESOrigin=BattleReferencePoint({820,540});PlayerPos=ESOrigin;CombatCameraReady=false;UpdateCamera(0);UpdateCharacterVisual(0,false);
        Progress->TutorialComplete=true;SpawnCD=NextMerchantTime=10000;for(float& CD:SkillCD)CD=10000;Panel.Empty();
        for(auto& Row:RuntimeEnemies)Row.EliteWeight=0;RuntimeEnemies[7].EliteWeight=1;
        RunTime=88.5f;NextElite=90;EliteIndex=0;ESCoins=RunCoins;ESKills=Kills;Progress->Monsters.Empty();ToastTime=0;
#if WITH_EDITOR
        FAssetCompilingManager::Get().FinishAllCompilation();if(GShaderCompilingManager)GShaderCompilingManager->FinishAllCompilation();
#endif
        Next(1);return true;
    }
    UpdateCamera(Dt);UpdateCharacterVisual(Dt,false);SmokeTime+=Dt;
    if(CaptureStep==5){
        if(SmokeTime<.2f)return false;
        Check(FMath::IsNearlyEqual(RunTime,ESTime) && FMath::IsNearlyEqual(EliteWarning.Remaining,ESRemaining) && FMath::IsNearlyEqual(EliteWarning.Retry,ESRetry) && EliteWarning.Marker==ESMarker,TEXT("actual_menu_tick_freezes_warning_and_run_clock"));
        if(++ESPause<6){const TCHAR* Panels[]={TEXT("pause"),TEXT("alchemy"),TEXT("skills"),TEXT("result"),TEXT("levelup"),TEXT("bossportal")};Panel=Panels[ESPause];ESTime=RunTime;ESRemaining=EliteWarning.Remaining;ESRetry=EliteWarning.Retry;ESMarker=EliteWarning.Marker;Next(5);return false;}
        Panel.Empty();Next(6);return true;
    }
    if(CaptureStep==11){
        ESSawWarning |= EliteWarning.Marker.IsValid();
        if(RunTime<90)ESNoEarly &= Enemies.IsEmpty() && NextElite==90 && EliteIndex==0;
        if(SmokeTime<2)return false;
        Check(ESNoEarly,TEXT("actual_natural_tick_does_not_spawn_or_advance_before_ninety"));
        Check(RunTime>=90 && Enemies.Num()==1 && Enemies[0].Definition==7 && NextElite==180 && EliteIndex==1 && EliteWarning.Definition<0,TEXT("actual_natural_tick_generates_one_elite_and_advances_once"));
        if(ESWarning)Check(ESSawWarning,TEXT("actual_ultrawide_natural_tick_renders_warning_before_materialization"));
        Next(12);return true;
    }
    if(SmokeTime<.7f)return true;
    // Give new primitives and their streaming resources real render frames before observation.
    if(CaptureStep==8){
        if(auto* M=EliteWarning.Marker.Get())UE_LOG(LogTemp,Display,TEXT("ELITESPAWN_VISUAL warning_material=%s hidden=%d visible=%d"),*GetPathNameSafe(M->GetStaticMeshComponent()->GetMaterial(0)),M->IsHidden(),M->GetStaticMeshComponent()->IsVisible());
        Shot(TEXT("01-pre-spawn-state.png"));Next(2);return true;
    }
    if(CaptureStep==9){
        if(!Enemies.IsEmpty())UE_LOG(LogTemp,Display,TEXT("ELITESPAWN_VISUAL enemy_material=%s hidden=%d visible=%d"),*GetPathNameSafe(Enemies[0].Body->GetStaticMeshComponent()->GetMaterial(0)),Enemies[0].Body->IsHidden(),Enemies[0].Body->GetStaticMeshComponent()->IsVisible());
        Shot(TEXT("03-actual-elite.png"));Next(7);return true;
    }
    if(CaptureStep==10){Shot(TEXT("02-reposition-or-recheck.png"));Next(3);return true;}
    if(CaptureStep==1){
        if(SmokeTime<2)return true;FVector StrictPoint;const bool Strict=FindSpawnPoint(7,StrictPoint);
        int VX=0,VY=0;GetWorld()->GetFirstPlayerController()->GetViewportSize(VX,VY);
        if(VY>0 && double(VX)/VY>2.2)Check(!Strict,TEXT("ultrawide_center_reproduces_no_complete_offscreen_elite_point"));
        UpdateEliteSpawning(0);ESWarning=EliteWarning.Marker.IsValid();
        Check(Enemies.IsEmpty() && RunTime<NextElite && EliteWarning.Definition==7,TEXT("precheck_reserves_elite_without_early_enemy"));
        Check(NextElite==90 && EliteIndex==0 && RunCoins==ESCoins && Kills==ESKills && Progress->Monsters.IsEmpty(),TEXT("warning_has_no_early_schedule_rewards_or_discovery"));
        if(!Strict)Check(ESWarning && FMath::IsNearlyEqual(EliteWarning.Remaining,1.5f,.001f),TEXT("no_offscreen_point_starts_full_visible_warning"));
        else Check(!ESWarning,TEXT("strict_offscreen_available_does_not_show_visible_warning"));
        Next(8);return true;
    }
    if(CaptureStep==2){
        if(FScreenshotRequest::IsScreenshotRequested())return true;
        if(ESWarning){
            const float Speed=500*(1+.03f*Progress->Talents[2]+.05f*RunAttrs[2]);const float Distance=FMath::Max(900.f,EnemyRadius(7)+45+Speed*1.5f+280);
            Check(EliteWarningPointSafe(7,EliteWarning.Position,Distance),TEXT("warning_point_passes_real_radius_path_and_speed_dash_safety"));
            const FVector PendingPoint=EliteWarning.Position;const int PendingID=EliteWarning.Definition;ESMarker=EliteWarning.Marker;
            // Pending records are outside Enemies: production damage/casts/nuclear cannot target them.
            Area(PendingPoint,120,100000,FLinearColor::Red);TriggerNuclear();
            ToastTime=0;
            Check(Enemies.IsEmpty() && EliteWarning.Definition==PendingID && EliteWarning.Marker==ESMarker && RunCoins==ESCoins && Kills==ESKills && Progress->Monsters.IsEmpty(),TEXT("pending_warning_cannot_be_hit_killed_rewarded_or_cleared_by_nuclear"));
            // Damage-probe feedback is not part of the spawn cue; the fixture freezes its normal lifetime.
            for(auto& FX:Effects)if(IsValid(FX.Body)){Scene.Remove(FX.Body);FX.Body->Destroy();}Effects.Empty();
            PlayerPos=PendingPoint;UpdateCamera(0);RunTime=90;UpdateEliteSpawning(EliteWarning.Remaining+.1f);
            Check(Enemies.IsEmpty() && EliteWarning.Definition==7 && !EliteWarning.Marker.IsValid() && EliteWarning.Retry>=.99f && EliteWarning.Remaining==0 && !ESMarker.IsValid(),TEXT("approaching_landing_cancels_marker_preserves_ID_and_retries_one_second"));
            PlayerPos=ESOrigin;UpdateCamera(0);UpdateEliteSpawning(1.01f);if(!EliteWarning.Marker.IsValid())UpdateEliteSpawning(0);
            Check(EliteWarning.Marker.IsValid() && EliteWarning.Remaining>=1.49f && Enemies.IsEmpty(),TEXT("retry_selects_safe_point_and_restarts_entire_warning"));
            Next(10);return true;
        }
        // A different actual viewport can have strict space: recheck the moved camera at the scheduled time.
        PlayerPos=BattleReferencePoint({570,350});UpdateCamera(0);RunTime=89.9f;UpdateEliteSpawning(1.4f);
        Check(Enemies.IsEmpty() && NextElite==90,TEXT("strict_branch_does_not_spawn_before_scheduled_ninety_seconds"));
        Next(10);return true;
    }
    if(CaptureStep==3){
        if(FScreenshotRequest::IsScreenshotRequested())return true;
        Panel=TEXT("pause");ESTime=RunTime;ESRemaining=EliteWarning.Remaining;ESRetry=EliteWarning.Retry;ESMarker=EliteWarning.Marker;Next(5);return false;
    }
    if(CaptureStep==6){
        ESIndex=EliteIndex;ESNext=NextElite;
        if(ESWarning){RunTime=90;UpdateEliteSpawning(.5f);Check(Enemies.IsEmpty(),TEXT("full_restarted_warning_cannot_complete_after_only_half_second"));UpdateEliteSpawning(1.01f);}
        else{RunTime=90;UpdateEliteSpawning(.11f);}
        if(Enemies.IsEmpty() && EliteWarning.Marker.IsValid()){RunTime=FMath::Max(RunTime,NextElite);UpdateEliteSpawning(1.51f);}
        Check(Enemies.Num()==1 && Enemies[0].Definition==7 && NextElite==ESNext+90 && EliteIndex==ESIndex+1,TEXT("actual_generation_happens_once_and_advances_schedule_once"));
        Check(!EliteWarning.Marker.IsValid() && EliteWarning.Definition<0,TEXT("successful_generation_clears_pending_marker_and_ID"));
        const int Generated=Enemies.Num();UpdateEliteSpawning(.1f);Check(Enemies.Num()==Generated && NextElite==ESNext+90,TEXT("subsequent_tick_does_not_duplicate_elite"));
        if(!Enemies.IsEmpty())UpdateEnemyVisual(Enemies[0]);
        Next(9);return true;
    }
    if(CaptureStep==7){
        if(FScreenshotRequest::IsScreenshotRequested())return true;Clear();ClearEliteWarning();
        PlayerPos=ESOrigin;UpdateCamera(0);RunTime=88.49f;NextElite=90;EliteIndex=0;ESNoEarly=true;ESSawWarning=false;
        SpawnCD=NextMerchantTime=10000;for(float& CD:SkillCD)CD=10000;HP=MaxHP;HurtInv=100;
        Next(11);return false;
    }
    if(CaptureStep==12){
        Clear();
        SpawnEnemyAt(0,PlayerPos+FVector(350,0,0));Check(Enemies.Num()==1 && Enemies[0].Type==0,TEXT("normal_SpawnEnemyAt_remains_immediate"));Clear();
        SpawnEnemy(10);Check(Enemies.Num()==1 && Enemies[0].Type==10 && EliteWarning.Definition<0,TEXT("Boss_SpawnEnemy_remains_immediate_without_elite_warning"));Clear();
        // Recreate pending state through the real scheduling helper before cancellation checks.
        PlayerPos=ESOrigin;UpdateCamera(0);NextElite=RunTime+1.5f;UpdateEliteSpawning(0);
        Check(EliteWarning.Definition==7,TEXT("next_scheduled_elite_can_be_reserved"));EndRun(false);
        Check(EliteWarning.Definition<0 && !EliteWarning.Marker.IsValid(),TEXT("EndRun_cancels_pending_elite"));
        StartRun();Clear();NextElite=RunTime+1.5f;UpdateEliteSpawning(0);
        Check(EliteWarning.Definition==7,TEXT("live_pending_exists_before_direct_restart"));
        StartRun();Check(EliteWarning.Definition<0 && !EliteWarning.Marker.IsValid() && NextElite==90 && EliteIndex==0,TEXT("new_run_clears_live_old_warning_and_resets_schedule"));Clear();
        NextElite=RunTime+1.5f;UpdateEliteSpawning(0);ClearEliteWarning();Check(EliteWarning.Definition<0 && !EliteWarning.Marker.IsValid(),TEXT("explicit_stage_cleanup_cancels_pending_elite"));
        NextElite=RunTime+1.5f;UpdateEliteSpawning(0);GreyfordPortalReady=true;GreyfordPortalPos=PlayerPos;
        Check(EnterGreyfordBoss() && GreyfordStage==2 && EliteWarning.Definition<0 && !EliteWarning.Marker.IsValid(),TEXT("real_Boss_stage_transition_cancels_pending_warning"));
        for(const TCHAR* Name:{TEXT("01-pre-spawn-state.png"),TEXT("02-reposition-or-recheck.png"),TEXT("03-actual-elite.png")})Check(IFileManager::Get().FileSize(*(Dir/Name))>0,TEXT("native_screenshot_written"));
        Finish();return true;
    }
    return true;
}
