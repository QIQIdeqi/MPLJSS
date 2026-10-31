// Isolated native placement/clock checks; not a natural-duration or real-AoE teaching playthrough.
bool AAlchemyWorld::TutorialPlacementCheck(float Dt) {
    static bool OK=true,CenterWarning=false,NoEarlyEnemies=true;
    static int Case=0,StrictCases=0,WarningCases=0,Skipped=0;
    static float SavedClock=0,SavedDeadline=0;
    static FVector Origin;
    static TArray<FVector> SavedPositions;
    static TWeakObjectPtr<AStaticMeshActor> SavedMarker;
    static FString WarningShot;
    const FVector2D Pixels[]={FVector2D(570,350),FVector2D(820,540)};
    auto* PC=GetWorld()->GetFirstPlayerController();int VX=0,VY=0;PC->GetViewportSize(VX,VY);
    const bool Wide=VY>0 && double(VX)/VY>2.2;
    const auto Check=[&](bool Pass,const TCHAR* Name){OK &= Pass;UE_LOG(LogTemp,Display,TEXT("TUTORIAL_PLACEMENT_CHECK case=%d %s %s"),Case,Name,Pass?TEXT("PASS"):TEXT("FAIL"));};
    const auto Next=[&](int Phase){CaptureStep=Phase;SmokeTime=0;};
    const auto Finish=[&](){
        UE_LOG(LogTemp,Display,TEXT("TUTORIAL_PLACEMENT_SUMMARY strict_cases=%d warning_cases=%d cleanup_skips=%d"),StrictCases,WarningCases,Skipped);
        UE_LOG(LogTemp,Display,TEXT("TUTORIAL_PLACEMENT_%s"),OK?TEXT("PASS"):TEXT("FAIL"));
        CaptureStep=99;FPlatformMisc::RequestExitWithStatus(false,OK?0:1);
    };
    const auto Done=[&](){if(++Case<5)Next(1);else Finish();};
    const auto ClearEnemies=[&](){for(auto& E:Enemies){if(IsValid(E.Body))E.Body->Destroy();if(IsValid(E.Shadow))E.Shadow->Destroy();}Enemies.Empty();};
    const auto SpriteCorners=[&](FVector P,const FAlchemyEnemyRow& K){
        TArray<FVector> Corners;
        for(int X:{-1,1})for(int Y:{-1,1})Corners.Add(P+Camera->GetActorUpVector()*(K.VisualSize.Y*.46)+Camera->GetActorRightVector()*(X*K.VisualSize.X*.5)+(bUprightSprites?FVector::UpVector:Camera->GetActorUpVector())*(Y*K.VisualSize.Y*.5));
        return Corners;
    };
    const auto LogState=[&](const TCHAR* Label,const TArray<FVector>& Points){
        const auto Eye=Camera->GetActorLocation();const auto Rotation=Camera->GetActorRotation();const auto C=CastChecked<UAlchemyCameraComponent>(Camera->GetCameraComponent());
        const auto PlayerPixel=BattleReferencePixel(PlayerPos);
        UE_LOG(LogTemp,Display,TEXT("TUTORIAL_PLACEMENT_STATE case=%d phase=%s viewport=%dx%d player_source=(%.3f,%.3f) camera=(%.3f,%.3f,%.3f) pitch=%.3f yaw=%.3f fov=%.6f offset=(%.6f,%.6f) clock=%.6f deadline=%.6f actual_count=%d pending=%d marker=%d reserved=%d"),Case,Label,VX,VY,PlayerPixel.X,PlayerPixel.Y,Eye.X,Eye.Y,Eye.Z,Rotation.Pitch,Rotation.Yaw,CameraFOV,C->ProjectionOffset.X,C->ProjectionOffset.Y,RunTime,TutorialEncounterRetry,Enemies.Num(),TutorialEncounterPending,TutorialEncounterMarker.IsValid(),TutorialEncounterPositions.Num());
        for(int I=0;I<Points.Num();I++){
            const auto P=Points[I];const auto Pixel=BattleReferencePixel(P);
            UE_LOG(LogTemp,Display,TEXT("TUTORIAL_PLACEMENT_POSITION case=%d phase=%s index=%d world=(%.3f,%.3f,%.3f) source=(%.3f,%.3f)"),Case,Label,I,P.X,P.Y,P.Z,Pixel.X,Pixel.Y);
        }
    };
    const auto ValidateReserved=[&](){
        bool Ground=SavedPositions.Num()==6,Safe=Ground,Inside=Ground;double Diameter=0;
        const float Speed=500*(1+.03f*Progress->Talents[2]+.05f*RunAttrs[2]);
        for(int I=0;I<SavedPositions.Num();I++){
            const auto& K=EnemyDefinition(I%2);const FVector P=SavedPositions[I];TArray<FVector> Path;
            Ground &= Walkable(P,45) && FindPath(PlayerPos,P,45,Path);
            Safe &= FVector::Dist2D(P,PlayerPos)+.01>=FMath::Max(900.f,K.CollisionRadius+45+Speed*1.5f+280);
            for(FVector Corner:SpriteCorners(P,K)){
                FVector2D Screen;const bool Projected=PC->ProjectWorldLocationToScreen(Corner,Screen);
                Inside &= Projected && Screen.X>=VX*.08-.01 && Screen.X<=VX*.92+.01 && Screen.Y>=VY*.22-.01 && Screen.Y<=VY*.78+.01;
            }
            for(int J=0;J<I;J++)Diameter=FMath::Max(Diameter,FVector::Dist2D(P,SavedPositions[J]));
        }
        Check(Ground,TEXT("six_reserved_points_have_real_radius45_ground_and_native_paths"));
        Check(Safe,TEXT("all_reserved_points_include_actual_player_speed_warning_and_dodge_clearance"));
        Check(Inside,TEXT("complete_future_sprites_stay_inside_actual_viewport_HUD_safe_rectangle"));
        Check(SavedPositions.Num()==6 && Diameter<=330.01,TEXT("six_reserved_positions_remain_one_compact_cluster"));
    };
    const auto ValidatePack=[&](bool Strict){
        bool IDs=Enemies.Num()==6,Ground=IDs,Outside=IDs,Safe=IDs,Same=IDs;double Diameter=0;
        const float Speed=500*(1+.03f*Progress->Talents[2]+.05f*RunAttrs[2]);TArray<FVector> Points;
        for(int I=0;I<Enemies.Num();I++){
            const auto& E=Enemies[I];const auto& K=EnemyDefinition(E);TArray<FVector> Path;Points.Add(E.Pos);
            IDs &= E.Type==I%2 && E.Definition==I%2;
            Ground &= Walkable(E.Pos,45) && FindPath(PlayerPos,E.Pos,45,Path);
            if(Strict)Outside &= BattleOffscreen(E.Pos,45) && BattleProjectedOutside(PC,SpriteCorners(E.Pos,K));
            else {
                Safe &= FVector::Dist2D(E.Pos,PlayerPos)+.01>=FMath::Max(450.f,K.CollisionRadius+45+Speed*.5f);
                Same &= SavedPositions.IsValidIndex(I) && FVector::Dist2D(E.Pos,SavedPositions[I])<=E.Speed*.11+1;
            }
            for(int J=0;J<I;J++)Diameter=FMath::Max(Diameter,FVector::Dist2D(E.Pos,Enemies[J].Pos));
        }
        Check(IDs,TEXT("spawned_pack_has_exactly_six_alternating_actual_definitions_zero_and_one"));
        Check(Ground,TEXT("all_six_actual_positions_are_Walkable_and_native_FindPath_radius45_reachable"));
        Check(Enemies.Num()==6 && Diameter<=330.01,TEXT("all_six_actual_enemies_remain_one_compact_cluster_at_most_330cm"));
        if(Strict)Check(Outside,TEXT("strict_branch_keeps_all_six_collision_and_actual_sprite_bounds_fully_offscreen"));
        else {Check(Safe,TEXT("materialized_pack_passes_current_player_speed_materialization_clearance"));Check(Same,TEXT("actual_pack_uses_reserved_positions_with_at_most_one_production_tick_of_chase"));}
        Check(!TutorialEncounterPending && !TutorialEncounterMarker.IsValid() && TutorialEncounterPositions.IsEmpty(),TEXT("completed_pack_resolves_pending_marker_and_reserved_positions"));
        LogState(Strict?TEXT("strict_pack"):TEXT("materialized_pack"),Points);
    };
    SmokeTime+=Dt;
    if(CaptureStep==0){
        OK=true;Case=StrictCases=WarningCases=Skipped=0;CenterWarning=false;
        Check(bCapture,TEXT("isolated_capture_prevents_real_player_save_IO"));if(!bCapture){Finish();return true;}
        Next(1);
    }
    if(CaptureStep==1){
        if(Case>=2 && !CenterWarning){
            ++Skipped;UE_LOG(LogTemp,Display,TEXT("TUTORIAL_PLACEMENT_SKIP case=%d reason=no_stable_ultrawide_center_warning_branch"),Case);Done();return true;
        }
        Progress=NewObject<UAlchemyProgress>(this);MigrateProgress(false);Progress->TutorialComplete=false;StartRun();ClearEnemies();
        PlayerPos=BattleReferencePoint(Pixels[Case==0?0:1]);Origin=PlayerPos;UpdateCamera(0);UpdateCharacterVisual(0,false);
        SpawnCD=NextElite=NextMerchantTime=10000;Inventory={1,1,1,0,0,0};Selected=Inventory;Random.Initialize(3401);
        Check(bBattleReference && GreyfordStage==1 && TutorialActive() && Walkable(PlayerPos,45),TEXT("real_incomplete_tutorial_and_player_ground_are_valid"));
        Check(TutorialEncounterCount==6,TEXT("configured_encounter_still_contains_six_monsters"));
        const bool Made=Craft();Check(Made && PendingResultSkill>=0 && !PendingIsNuclear,TEXT("production_first_three_material_Craft_stages_non_nuclear_skill"));
        if(Made)AcceptPendingResult();
        Check(TutorialSkill>=0 && TutorialEncounterPending && PendingResultSkill<0 && !Progress->TutorialComplete,TEXT("production_Accept_queues_encounter_without_completing_tutorial"));
        Equipped.Empty();for(float& CD:SkillCD)CD=10000;Panel.Empty();ToastTime=0;NoEarlyEnemies=true;
        SavedPositions.Empty();SavedMarker.Reset();WarningShot.Empty();
#if WITH_EDITOR
        FAssetCompilingManager::Get().FinishAllCompilation();if(GShaderCompilingManager)GShaderCompilingManager->FinishAllCompilation();
#endif
        Next(2);return true;
    }
    if(CaptureStep==2){
        if(SmokeTime<.6f)return true;
        UpdateCamera(0);UpdateCharacterVisual(0,false);SpawnTutorialEncounter();
        const bool Warning=TutorialEncounterMarker.IsValid();
        UE_LOG(LogTemp,Display,TEXT("TUTORIAL_PLACEMENT_BRANCH case=%d branch=%s"),Case,Warning?TEXT("visible_warning"):Enemies.Num()==6?TEXT("strict_offscreen"):TEXT("unresolved"));
        if(Case==1)CenterWarning=Wide && Warning;
        if(!Warning){
            if(Case<2){if(Enemies.Num()==6)++StrictCases;ValidatePack(true);}else Check(false,TEXT("cleanup_case_reproduces_stable_ultrawide_warning"));
            Done();return true;
        }
        ++WarningCases;SavedPositions=TutorialEncounterPositions;SavedMarker=TutorialEncounterMarker;SavedClock=RunTime;SavedDeadline=TutorialEncounterRetry;
        Check(Enemies.IsEmpty() && TutorialEncounterPending && SavedPositions.Num()==6,TEXT("visible_warning_reserves_six_without_creating_targetable_enemies"));
        Check(FMath::IsNearlyEqual(SavedDeadline-SavedClock,1.5f,.001f),TEXT("reservation_starts_a_full_one_point_five_seconds_of_combat_time"));
        ValidateReserved();LogState(TEXT("warning_reserved"),SavedPositions);
        if(Case==2){
            GreyfordPortalReady=true;GreyfordPortalPos=PlayerPos;
            Check(EnterGreyfordBoss() && GreyfordStage==2 && !TutorialActive() && !Progress->TutorialComplete,TEXT("real_Boss_entry_remains_free_for_unfinished_tutorial"));
            Check(!SavedMarker.IsValid() && !TutorialEncounterMarker.IsValid() && TutorialEncounterPositions.IsEmpty() && !TutorialEncounterPending && Enemies.Num()==1 && Enemies[0].Type==10,TEXT("real_Boss_transition_clears_warning_and_does_not_materialize_tutorial_pack"));
            Done();return true;
        }
        if(Case==3){
            // Direct production completion hook, explicitly not a real combat AoE hit assertion.
            TutorialHit(TutorialSkill,2);
            Check(Progress->TutorialComplete && !TutorialActive(),TEXT("production_TutorialHit_completion_hook_records_completion_not_a_real_AoE_test"));
            Check(!SavedMarker.IsValid() && !TutorialEncounterMarker.IsValid() && TutorialEncounterPositions.IsEmpty() && !TutorialEncounterPending && Enemies.IsEmpty(),TEXT("tutorial_completion_clears_warning_without_spawning_pending_pack"));
            Done();return true;
        }
        if(Case==4){
            if(SavedPositions.IsEmpty()){Done();return true;}
            PlayerPos=SavedPositions[0];UpdateCamera(0);UpdateCharacterVisual(0,false);Next(7);return false;
        }
        Next(3);return true;
    }
    if(CaptureStep==3){
        if(SmokeTime<.3f)return true;
        if(Case==1){
#if WITH_EDITOR
            FAssetCompilingManager::Get().FinishAllCompilation();
            if(GShaderCompilingManager)GShaderCompilingManager->FinishAllCompilation();
#endif
            const FString Dir=FPaths::ProjectDir()/TEXT("Evidence/TutorialPlacement_20261101");IFileManager::Get().MakeDirectory(*Dir,true);
            WarningShot=Dir/FString::Printf(TEXT("01-warning_%dx%d.png"),VX,VY);
            FScreenshotRequest::RequestScreenshot(WarningShot,true,false);Next(4);return true;
        }
        Next(4);return true;
    }
    if(CaptureStep==4){
        if(FScreenshotRequest::IsScreenshotRequested() && SmokeTime<2)return true;
        if(!WarningShot.IsEmpty() && IFileManager::Get().FileSize(*WarningShot)<=0 && SmokeTime<1)return true;
        if(!WarningShot.IsEmpty())Check(IFileManager::Get().FileSize(*WarningShot)>0,TEXT("native_warning_screenshot_includes_UI_and_is_written"));
        Panel=TEXT("pause");SavedClock=RunTime;SavedDeadline=TutorialEncounterRetry;Next(5);return false;
    }
    if(CaptureStep==5){
        if(SmokeTime<.3f)return false;
        Check(Panel==TEXT("pause") && FMath::IsNearlyEqual(RunTime,SavedClock,.001f) && FMath::IsNearlyEqual(TutorialEncounterRetry,SavedDeadline,.001f) && TutorialEncounterMarker==SavedMarker && TutorialEncounterPositions==SavedPositions && Enemies.IsEmpty(),TEXT("real_menu_Tick_freezes_clock_deadline_marker_reserved_positions_and_enemy_count"));
        Action(TEXT("close"));Check(Panel.IsEmpty(),TEXT("existing_close_action_resumes_from_warning_pause"));Next(6);return false;
    }
    if(CaptureStep==6){
        if(RunTime<SavedDeadline-.001f)NoEarlyEnemies &= Enemies.IsEmpty();
        if(!Enemies.IsEmpty()){
            Check(NoEarlyEnemies && RunTime>=SavedDeadline-.001f,TEXT("real_production_ticks_never_materialize_before_absolute_warning_deadline"));
            ValidatePack(false);Done();return true;
        }
        if(SmokeTime<3)return false;
        Check(false,TEXT("real_production_ticks_materialize_six_within_three_second_bound"));Done();return true;
    }
    if(CaptureStep==7){
        NoEarlyEnemies &= Enemies.IsEmpty();
        if(SavedMarker.IsValid() && SmokeTime<2.5f)return false;
        Check(NoEarlyEnemies && RunTime>=SavedDeadline-.001f && !SavedMarker.IsValid() && !TutorialEncounterMarker.IsValid() && TutorialEncounterPending && TutorialEncounterPositions.IsEmpty() && TutorialEncounterRetry>=RunTime+.99f,TEXT("approaching_reserved_point_cancels_old_marker_at_deadline_and_schedules_one_second_retry_without_enemies"));
        SavedDeadline=TutorialEncounterRetry;
        PlayerPos=Origin;UpdateCamera(0);UpdateCharacterVisual(0,false);Next(8);return false;
    }
    if(CaptureStep==8){
        if(TutorialEncounterMarker.IsValid()){
            UE_LOG(LogTemp,Display,TEXT("TUTORIAL_PLACEMENT_BRANCH case=%d branch=retry_visible_warning"),Case);
            Check(NoEarlyEnemies && Enemies.IsEmpty() && TutorialEncounterMarker!=SavedMarker && TutorialEncounterPending && TutorialEncounterPositions.Num()==6 && TutorialEncounterRetry>=RunTime+1.47f,TEXT("real_retry_creates_a_new_marker_with_full_warning_and_no_same_frame_spawn"));
            SavedPositions=TutorialEncounterPositions;ValidateReserved();LogState(TEXT("restarted_warning"),SavedPositions);
        }else if(!Enemies.IsEmpty()){
            Check(NoEarlyEnemies && RunTime>=SavedDeadline-.001f,TEXT("real_retry_can_use_newly_available_strict_space_after_retry_deadline"));
            UE_LOG(LogTemp,Display,TEXT("TUTORIAL_PLACEMENT_BRANCH case=%d branch=retry_strict_offscreen"),Case);ValidatePack(true);
        }else if(SmokeTime<3)return false;
        else Check(false,TEXT("real_retry_produces_strict_pack_or_new_full_warning_within_bound"));
        const auto RestartedMarker=TutorialEncounterMarker;EndRun(false);
        Check(bRunEnded && !RestartedMarker.IsValid() && !TutorialEncounterMarker.IsValid() && TutorialEncounterPositions.IsEmpty() && !TutorialEncounterPending,TEXT("real_EndRun_clears_retry_warning_and_reserved_pack"));
        Done();return true;
    }
    if(CaptureStep==99)return true;
    Check(false,TEXT("bounded_fixture_stage"));Finish();return true;
}
