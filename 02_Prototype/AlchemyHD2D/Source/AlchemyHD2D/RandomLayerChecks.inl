// Native Flow fixture. The capture entry returns before production simulation and saving.
bool AAlchemyWorld::RandomLayerCheck(float Dt) {
    static int Phase=0,Sample=0;static float Wait=0;static bool OK=true;
    static TArray<FString> FieldGround,FieldObjects,BossObjects;
    const int Seed=77+Sample;
    const bool RecoveryTrial=FParse::Param(FCommandLine::Get(),TEXT("AlchemyRecoveryTrial"));
    const FString Dir=FPaths::ProjectDir()/(RecoveryTrial?TEXT("Evidence/RandomLayers_20261106/RecoveryTrial"):TEXT("Evidence/RandomLayers_20261104/Native"));
    const auto Check=[&](bool Good,const TCHAR* Name){OK &= Good;UE_LOG(LogTemp,Display,TEXT("RANDOM_LAYERS_CHECK %s %s seed=%d"),Name,Good?TEXT("PASS"):TEXT("FAIL"),Seed);};
    const auto Signature=[&](bool Ground){TArray<FString> Rows;
        for(TActorIterator<AAlchemyTileCell> It(GetWorld());It;++It)if(It->GetOwner()==Designer && It->bGround==Ground)
            Rows.Add(FString::Printf(TEXT("%s|%s|%s|%s|%d"),*It->BrushName,*It->GetActorLocation().ToString(),*It->GetActorScale3D().ToString(),*It->GetActorRotation().ToString(),It->bBlocksMovement));
        Rows.Sort();return FString::Join(Rows,TEXT("\n"));};
    const auto VerifyLayers=[&](){int Ground=0,Props=0;TSet<FString> Terrain;
        for(TActorIterator<AAlchemyTileCell> It(GetWorld());It;++It)if(It->GetOwner()==Designer){
            if(It->bGround){++Ground;Terrain.Add(It->BrushName);}else ++Props;}
        Check(bRandomBattleScene && IsValid(Designer) && Designer->ActorHasTag(TEXT("AlchemyRandomStage")),TEXT("runtime_random_designer"));
        Check(Ground>0 && Props>0,TEXT("both_layers_nonempty"));Check(Terrain.Num()>1,TEXT("terrain_varied"));};
    const auto Shot=[&](const TCHAR* Stage){IFileManager::Get().MakeDirectory(*Dir,true);
        UpdateCamera(0);UpdateCharacterVisual(0,false);
        auto PC=GetWorld()->GetFirstPlayerController();int W=0,H=0;if(PC)PC->GetViewportSize(W,H);
        Check(Camera && Camera->GetCameraComponent()->ProjectionMode==ECameraProjectionMode::Perspective && FMath::IsNearlyEqual(Camera->GetActorRotation().Pitch,-60.,.01),TEXT("capture_perspective_pitch60"));
        const auto Measure=[&](AActor* Body,const TCHAR* Scope){bool Inside=IsValid(Body) && PC && W>0 && H>0;FBox2D Pixels(ForceInit);
            if(Inside){const FBox B=Body->GetComponentsBoundingBox(true);for(int I=0;I<8;++I){FVector2D P;
                const FVector Corner(I&1?B.Max.X:B.Min.X,I&2?B.Max.Y:B.Min.Y,I&4?B.Max.Z:B.Min.Z);
                if(!PC->ProjectWorldLocationToScreen(Corner,P)){Inside=false;continue;}Pixels+=P;Inside &= P.X>=0 && P.X<=W && P.Y>=0 && P.Y<=H;}}
            UE_LOG(LogTemp,Display,TEXT("RANDOM_LAYERS_PROJECTION seed=%d stage=%s scope=%s source=actual_actor_component_bounds viewport=%dx%d min=%s max=%s"),Seed,Stage,Scope,W,H,*Pixels.Min.ToString(),*Pixels.Max.ToString());
            Check(Inside,Scope);
            const double Fit=FMath::Min(double(W)/1672,double(H)/940),Top=(H-940*Fit)*.5;
            double SafeTop=Top+50*Fit,SafeBottom=Top+804*Fit;
            if(BattleWidget)for(const TCHAR* Name:{TEXT("TimerText"),TEXT("SkillGroup")})if(auto Widget=BattleWidget->GetWidgetFromName(Name)){
                const auto G=Widget->GetCachedGeometry();if(G.GetLocalSize().GetMin()<=0)continue;
                FVector2D Pixel,Unused;const bool Timer=FCString::Strcmp(Name,TEXT("TimerText"))==0;
                USlateBlueprintLibrary::LocalToViewport(this,G,Timer?G.GetLocalSize():FVector2D::ZeroVector,Pixel,Unused);
                if(Timer)SafeTop=Pixel.Y;else SafeBottom=Pixel.Y;
            }
            Check(Pixels.bIsValid && Pixels.Min.Y>=SafeTop+4 && Pixels.Max.Y<=SafeBottom-4,TEXT("full_actor_canvas_clear_of_actual_HUD_vertical_band"));};
        Measure(Player,TEXT("player_full_canvas_in_viewport"));if(GreyfordStage==2)Measure(Enemies.IsEmpty()?nullptr:Enemies[0].Body,TEXT("boss_full_canvas_in_viewport"));
        FScreenshotRequest::RequestScreenshot(Dir/FString::Printf(TEXT("seed_%d_%s.png"),Seed,Stage),true,false);};
#if WITH_EDITOR
    if(GShaderCompilingManager && GShaderCompilingManager->IsCompiling()){GShaderCompilingManager->FinishAllCompilation();Wait=0;return true;}
#endif
    Wait+=Dt;if(Wait<.3f)return true;Wait=0;
    if(Phase==0){
        if(Sample==0){
            AAlchemyLevelDesigner* FieldLayout=nullptr;
            for(auto Stream:GetWorld()->GetStreamingLevels())if(Stream->GetWorldAssetPackageName().EndsWith(TEXT("Outskirts_Blockout")))
                if(auto Level=Stream->GetLoadedLevel())for(AActor* Actor:Level->Actors)
                    if(auto Candidate=Cast<AAlchemyLevelDesigner>(Actor);Candidate && Candidate->ActorHasTag(TEXT("AlchemyRandomStage"))){FieldLayout=Candidate;break;}
            Check(IsValid(FieldLayout),TEXT("field_failure_fixture_preset_found"));
            if(FieldLayout){const auto SavedPalette=FieldLayout->Palette;const auto Coins=Progress->Coins;const bool Intro=Progress->BrewV02Introduced;
                for(auto& B:FieldLayout->Palette)if(B.bGround)B.RandomWeight=0;
                StartRun();FieldLayout->Palette=SavedPalette;
                Check(bStageBuildFailed && !bCombat && GreyfordStage==0 && !bRunEnded && Progress->Coins==Coins && Progress->BrewV02Introduced==Intro && IsValid(Player),TEXT("failed_field_start_returns_village_without_settlement_or_intro_consumption"));
            }
        }
        StartRun();RandomMapSeed=Seed;
        const bool Built=SwitchGreyfordStage(1);Check(Built,TEXT("field_build"));
        if(Built){VerifyLayers();const FString G=Signature(true),P=Signature(false);FieldGround.Add(G);FieldObjects.Add(P);
            IFileManager::Get().MakeDirectory(*Dir,true);
            FFileHelper::SaveStringToFile(G,*FPaths::Combine(Dir,FString::Printf(TEXT("seed_%d_ground.txt"),Seed)));
            FFileHelper::SaveStringToFile(P,*FPaths::Combine(Dir,FString::Printf(TEXT("seed_%d_props.txt"),Seed)));
            TWeakObjectPtr<AAlchemyTileCell> PreviewGround,PreviewObject;
            for(TActorIterator<AAlchemyTileCell> It(GetWorld());It;++It) if(It->GetOwner()==Designer) {
                auto& Preview=It->bGround?PreviewGround:PreviewObject;
                if(!Preview.IsValid()) { Preview=*It;It->bLockRandom=true; }
            }
            Check(PreviewGround.IsValid() && PreviewObject.IsValid(),TEXT("preview_lock_fixture_both_layers"));
            Check(SwitchGreyfordStage(1),TEXT("same_seed_rebuild"));
            Check(!PreviewGround.IsValid() && !PreviewObject.IsValid(),TEXT("runtime_replaces_locked_preview_cells"));
            Check(G==Signature(true) && P==Signature(false),TEXT("same_seed_reproduces_both_layers"));
            if(Sample==0){
                const float Density=Designer->ObjectDensity;Designer->ObjectDensity=0;
                Check(SwitchGreyfordStage(1) && Signature(false).IsEmpty() && G==Signature(true),TEXT("zero_object_density_is_valid_production_layout"));
                Designer->ObjectDensity=Density;
                Check(SwitchGreyfordStage(1) && G==Signature(true) && P==Signature(false),TEXT("restore_density_reproduces_layout"));
                if(!RecoveryTrial) {
                    const auto SavedPalette=Designer->Palette;
                    const int32 GridSlots=Designer->Columns*Designer->Rows;
                    for(auto& Brush:Designer->Palette) {
                        if(Brush.bGround) {
                            const int32 Count=Brush.Name==TEXT("Grass")?GridSlots-1:Brush.Name==TEXT("Stone")?1:0;
                            Brush.CountRange=FIntPoint(Count,Count);
                        } else if(Brush.Name==TEXT("Oak")) {
                            Brush.CountRange=FIntPoint(2,2);
                            Brush.DensityRange=FVector2D(2./GridSlots,2./GridSlots);
                        }
                    }
                    const auto CheckConfigured=[&](int32 TrialSeed,FVector& Stone){
                        RandomMapSeed=TrialSeed;
                        if(!SwitchGreyfordStage(1)) return false;
                        int32 Grass=0,Stones=0,Oak=0;
                        for(TActorIterator<AAlchemyTileCell> It(GetWorld());It;++It) if(It->GetOwner()==Designer) {
                            Grass+=It->bGround && It->BrushName==TEXT("Grass");
                            Oak+=!It->bGround && It->BrushName==TEXT("Oak");
                            if(It->bGround && It->BrushName==TEXT("Stone")) { ++Stones;Stone=It->GetActorLocation(); }
                        }
                        return Grass==GridSlots-1 && Stones==1 && Oak==2;
                    };
                    FVector FirstStone=FVector::ZeroVector,SecondStone=FVector::ZeroVector;
                    const bool First=CheckConfigured(Seed,FirstStone);
                    const bool Second=CheckConfigured(Seed+1,SecondStone);
                    Check(First && Second && FirstStone!=SecondStone,TEXT("configured_counts_and_density_hold_across_seeds_with_random_terrain_location"));
                    Designer->Palette=SavedPalette;
                    RandomMapSeed=Seed;
                    Check(SwitchGreyfordStage(1) && G==Signature(true) && P==Signature(false),TEXT("restore_palette_reproduces_layout"));
                }
            }
            Check(Walkable(FVector::ZeroVector,45),TEXT("field_origin_clear"));
            int Routes=0;bool Reachable=true;
            if(Designer)for(FVector2D Local:Designer->ProtectedPoints)if(!Local.IsNearlyZero() && Routes<4){TArray<FVector> Path;
                const FVector Target=Designer->GetActorTransform().TransformPosition(FVector(Local,0));
                Reachable &= Walkable(Target,45) && FindPath(FVector::ZeroVector,Target,45,Path);++Routes;}
            Check(Routes==4 && Reachable,TEXT("four_representative_routes"));
            bool Solid=false,Decor=false;
            for(TActorIterator<AAlchemyTileCell> It(GetWorld());It;++It)if(It->GetOwner()==Designer && !It->bGround){
                const FVector C(It->GetActorLocation().X,It->GetActorLocation().Y,0);
                if(!It->bBlocksMovement && !Decor && Walkable(C,45)){
                    const FVector A=C-FVector(70,0,0),B=C+FVector(70,0,0);
                    if(Walkable(A,45) && Walkable(B,45))Decor=Move(A,B-A,45).Equals(B,1);}
                if(It->bBlocksMovement && !Solid){const FVector2D H=It->WorldHalfSize();
                    for(int Axis=0;Axis<2 && !Solid;++Axis){const FVector D=Axis?FVector(0,H.Y+100,0):FVector(H.X+100,0,0);
                        const FVector A=C-D,B=C+D;TArray<FVector> Path;
                        if(!Walkable(A,45) || !Walkable(B,45))continue;
                        Solid=!Walkable(C,45) && !Move(A,B-A,45).Equals(B,1) && FindPath(A,B,45,Path) && Path.Num()>1;}}
            }
            Check(Solid,TEXT("solid_blocks_move_and_path_goes_around"));Check(Decor,TEXT("decoration_is_traversable"));
            RunTime=300;UpdateGreyfordPortal();TArray<FVector> Path;
            Check(GreyfordPortalReady && Walkable(GreyfordPortalPos,240) && FindPath(PlayerPos,GreyfordPortalPos,45,Path),TEXT("portal_real_candidate_clear_and_reachable"));
            if(Sample==0 && !RecoveryTrial) {
                FAlchemyEnemy Enemy;
                Enemy.Type=0;
                Enemy.Pos=PlayerPos+FVector(250,160,0);
                const auto SavedRandom=Random;
                Random.Initialize(0);
                RewardEnemy(Enemy);
                Random=SavedRandom;
                const auto* XP=Drops.FindByPredicate([](const auto& D){return D.Kind==-2;});
                const auto* Coin=Drops.FindByPredicate([](const auto& D){return D.Kind==-1;});
                Check(XP && Coin && IsValid(XP->Body) && IsValid(Coin->Body) && !XP->Pos.Equals(Coin->Pos)
                    && XP->Body->GetStaticMeshComponent()->GetMaterial(0)->GetMaterial()!=Coin->Body->GetStaticMeshComponent()->GetMaterial(0)->GetMaterial(),
                    TEXT("normal_reward_distinct_coin_and_experience_orb"));
                if(XP && Coin) {
                    const float PreviousXP=RunXP;
                    const int32 PreviousCoins=RunCoins;
                    CollectDrop(XP->Kind,XP->Count);
                    CollectDrop(Coin->Kind,Coin->Count);
                    Check(RunXP==PreviousXP+1 && RunCoins==PreviousCoins+1,TEXT("experience_and_coin_reward_values"));
                    RunXP=PreviousXP;
                    RunCoins=PreviousCoins;
                }
            }
            if(RecoveryTrial) {
                TArray<const AAlchemyTileCell*> Fences,Crates;
                for(TActorIterator<AAlchemyTileCell> It(GetWorld());It;++It) if(It->GetOwner()==Designer && !It->bGround) {
                    if(It->BrushName==TEXT("Fence")) Fences.Add(*It);
                    if(It->BrushName==TEXT("Crates")) Crates.Add(*It);
                }
                const AAlchemyTileCell* Landmark=nullptr;
                for(const auto* Fence:Fences) for(const auto* Crate:Crates) {
                    const auto Delta=Crate->GetActorLocation()-Fence->GetActorLocation();
                    if(FMath::IsNearlyEqual(FMath::Abs(Delta.X),Designer->CellSize,.1) && FMath::IsNearlyZero(Delta.Y,.1))
                        Landmark=Fence;
                }
                if(Landmark) {
                    const FVector Center=Landmark->GetActorLocation();
                    const FVector2D Half=Landmark->WorldHalfSize();
                    const FVector Front=Center+FVector(0,-Half.Y-145,0);
                    const FVector Back=Center+FVector(0,Half.Y+145,0);
                    TArray<FVector> Approach;
                    Check(FindPath(PlayerPos,Front,45,Approach),TEXT("recovery_front_reachable"));
                    for(int32 Side:{-1,1}) {
                        const FVector End(Side*(Half.X+85),0,0);
                        const auto Step=[&](FVector A,FVector B){return Walkable(A,45) && FVector::DistSquared2D(Move(A,B-A,45),B)<1.;};
                        Check(Step(Front,Front+End) && Step(Front+End,Back+End) && Step(Back+End,Back),
                            Side<0?TEXT("recovery_left_route_walkable"):TEXT("recovery_right_route_walkable"));
                    }
                }
            }
        }
        Phase=1;return true;
    }
    if(Phase==1){Shot(TEXT("field"));Phase=2;return true;}
    if(Phase==2){
        PlayerPos=GreyfordPortalPos;const float BeforeHP=HP;
        AAlchemyLevelDesigner* BossLayout=nullptr;
        // Loaded invisible levels are not necessarily attached to the world's actor iterator.
        for(auto Stream:GetWorld()->GetStreamingLevels())if(Stream->GetWorldAssetPackageName().EndsWith(TEXT("Greyford_Boss")))
            if(auto Level=Stream->GetLoadedLevel())for(AActor* Actor:Level->Actors)
                if(auto Candidate=Cast<AAlchemyLevelDesigner>(Actor);Candidate && Candidate->ActorHasTag(TEXT("AlchemyRandomStage"))){BossLayout=Candidate;break;}
        Check(IsValid(BossLayout),TEXT("boss_failure_fixture_preset_found"));
        if(BossLayout){
            if(Enemies.IsEmpty())SpawnEnemyAt(0,FVector::ZeroVector);if(Drops.IsEmpty())Drop(FVector::ZeroVector,0,1);
            Check(!Enemies.IsEmpty() && !Drops.IsEmpty(),TEXT("boss_failure_fixture_has_live_enemy_and_drop"));
            const auto BeforeInventory=Inventory;const auto BeforeEnemies=Enemies;const auto BeforeDrops=Drops;const auto SavedPalette=BossLayout->Palette;
            const int BeforeCoins=Progress->Coins;const bool BeforeEnded=bRunEnded;const FVector BeforePosition=PlayerPos;
            for(auto& Brush:BossLayout->Palette)if(Brush.bGround)Brush.RandomWeight=0;
            const bool Rejected=!EnterGreyfordBoss();BossLayout->Palette=SavedPalette;
            bool Preserved=Enemies.Num()==BeforeEnemies.Num() && Drops.Num()==BeforeDrops.Num();
            for(int I=0;I<Enemies.Num() && I<BeforeEnemies.Num();++I){const auto& A=Enemies[I];const auto& B=BeforeEnemies[I];Preserved &= A.Body==B.Body && IsValid(A.Body) && A.Pos==B.Pos && A.HP==B.HP && A.Type==B.Type && A.Definition==B.Definition;}
            for(int I=0;I<Drops.Num() && I<BeforeDrops.Num();++I){const auto& A=Drops[I];const auto& B=BeforeDrops[I];Preserved &= A.Body==B.Body && IsValid(A.Body) && A.Pos==B.Pos && A.Kind==B.Kind && A.Count==B.Count;}
            Check(Rejected && GreyfordStage==1 && GreyfordPortalReady && PlayerPos==BeforePosition && HP==BeforeHP && Inventory==BeforeInventory && Progress->Coins==BeforeCoins && bRunEnded==BeforeEnded && Preserved,TEXT("failed_boss_build_preserves_live_run_and_retry"));
        }
        const bool Entered=EnterGreyfordBoss();Check(Entered,TEXT("real_boss_entry"));
        if(Entered){VerifyLayers();const FString G=Signature(true),P=Signature(false);BossObjects.Add(P);
            Check(HP==BeforeHP && Enemies.Num()==1 && Enemies[0].Type==10,TEXT("boss_identity_and_hp_preserved"));
            Check(PlayerPos.Equals(FVector(0,-500,0),1) && !Enemies.IsEmpty() && Enemies[0].Pos.Equals(FVector(0,500,0),1),TEXT("boss_fixed_positions_1000cm"));
            Check(FMath::IsNearlyEqual(GreyfordBossPreparation,2.f),TEXT("boss_two_second_preparation"));
            Check(CombatHalfSize.Equals(FVector2D(1600,1300),.1) && Walkable(FVector::ZeroVector,45) && Walkable(FVector(0,-500,0),45) && Walkable(FVector(0,500,0),45)
                && !Walkable(FVector(1600,0,0),45) && !Walkable(FVector(0,1300,0),45),TEXT("boss_ellipse_and_central_clearance"));
            bool Safe=true;for(TActorIterator<AAlchemyTileCell> It(GetWorld());It;++It)if(It->GetOwner()==Designer && !It->bGround){
                const FVector C=It->GetActorLocation();const bool Interior=FMath::Square(C.X/1600)+FMath::Square(C.Y/1300)<1;
                if(Interior)Safe &= !It->bBlocksMovement && It->bBossInterior;}
            Check(Safe,TEXT("boss_interior_only_permitted_low_decoration"));
            Check(SwitchGreyfordStage(2),TEXT("boss_same_seed_rebuild"));
            Check(G==Signature(true) && P==Signature(false),TEXT("boss_same_seed_reproduces_layers"));
        }
        Phase=3;return true;
    }
    if(Phase==3){Shot(TEXT("boss"));Phase=4;return true;}
    if(++Sample<3){Phase=0;return true;}
    Check(FieldGround.Num()==3 && FieldGround[0]!=FieldGround[1] && FieldGround[1]!=FieldGround[2],TEXT("different_seeds_change_terrain"));
    Check(FieldObjects.Num()==3 && FieldObjects[0]!=FieldObjects[1] && FieldObjects[1]!=FieldObjects[2],TEXT("different_seeds_change_field_props"));
    Check(BossObjects.Num()==3 && BossObjects[0]!=BossObjects[1] && BossObjects[1]!=BossObjects[2],TEXT("different_seeds_change_boss_props"));
    UE_LOG(LogTemp,Display,TEXT("RANDOM_LAYERS_%s"),OK?TEXT("PASS"):TEXT("FAIL"));FPlatformMisc::RequestExitWithStatus(false,OK?0:1);return true;
}
