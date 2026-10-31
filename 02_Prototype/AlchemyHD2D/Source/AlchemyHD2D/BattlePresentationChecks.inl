bool AAlchemyWorld::BattlePresentationCheck(float Dt) {
    const bool Visual=FParse::Param(FCommandLine::Get(),TEXT("BattlePresentationCapture"));
    const FString Dir=FPaths::ProjectDir()/TEXT("Evidence/BattlePresentation_20261031");
    const auto ClearEnemies=[&](){for(auto& E:Enemies){E.Body->Destroy();E.Shadow->Destroy();}Enemies.Empty();};
    if(Visual && FParse::Param(FCommandLine::Get(),TEXT("RoseAttackCapture")) && CaptureStep>=20){
        static bool RoseOK=true,RoseVisible=false;static int RoseView=0;
        static float RoseInitialHP=0,RoseHitHP=0,RoseDamage=0,RoseDelay=0,RoseTime=0,RoseRunTime=0,RoseCastClock=0;
        const FString RoseDir=FPaths::ProjectDir()/TEXT("Evidence/RoseMageAttack_20261101");
        const auto Check=[&](bool Pass,const TCHAR* Name){RoseOK &= Pass;UE_LOG(LogTemp,Display,TEXT("BATTLE_CHECK %s %s"),Name,Pass?TEXT("PASS"):TEXT("FAIL"));};
        const auto Next=[&](int Step){CaptureStep=Step;SmokeTime=0;};
        const auto Finish=[&](){UE_LOG(LogTemp,Display,TEXT("ROSE_ATTACK_%s"),RoseOK?TEXT("PASS"):TEXT("FAIL"));UE_LOG(LogTemp,Display,TEXT("BATTLE_PRESENTATION_%s"),RoseOK?TEXT("PASS"):TEXT("FAIL"));FPlatformMisc::RequestExitWithStatus(false,RoseOK?0:1);};
        SmokeTime+=Dt;
        if(CaptureStep==20){
            RoseOK=true;RoseVisible=false;RoseView=0;IFileManager::Get().MakeDirectory(*RoseDir,true);
            Progress=NewObject<UAlchemyProgress>(this);MigrateProgress(true);StartRun();ClearEnemies();
            Check(CharacterAnimation.HasRoseAttack(),TEXT("real_Rose_three_direction_attack_pack_active"));
            PlayerPos=BattleReferencePoint({570,350});UpdateCamera(0);CharacterAnimation.Reset();UpdateCharacterVisual(0,false);
            FVector Target=PlayerPos;for(int I=0;I<8;I++){const double A=I*PI/4;const FVector P=PlayerPos+FVector(FMath::Cos(A),FMath::Sin(A),0)*350;if(Walkable(P,EnemyRadius(0))){Target=P;break;}}
            Check(FVector::Dist2D(Target,PlayerPos)>300,TEXT("stationary_hit_target_has_legal_nearby_ground"));
            SpawnEnemyAt(0,Target);Check(Enemies.Num()==1,TEXT("production_target_spawned"));if(Enemies.IsEmpty()){Finish();return true;}
            Enemies[0].Speed=0;Enemies[0].Contact=0;Enemies[0].HP=Enemies[0].MaxHP=10000;UpdateEnemyVisual(Enemies[0]);RoseInitialHP=Enemies[0].HP;
            Equipped={0};Levels[0]=1;SkillCD[0]=0;SpawnCD=NextElite=NextMerchantTime=10000;HP=MaxHP;HurtInv=10000;Panel.Empty();ToastTime=0;
            RoseDamage=FMath::RoundToFloat(SkillConfig(0).Damage);RoseCastClock=RunTime;CastSkills(.01f);SkillCD[0]=10000;
            Check(Shots.Num()==1 && Shots[0].Potion && Shots[0].Body->IsHidden() && CharacterAnimation.Throwing,TEXT("real_CastSkills_stages_hidden_Rose_potion_and_attack_pose"));
            Next(21);return false;
        }
        if(CaptureStep==21){
            if(SmokeTime<.15f)return false;
            Check(Shots.Num()==1 && Shots[0].ReleaseDelay>0 && Shots[0].Body->IsHidden() && Enemies[0].HP==RoseInitialHP,TEXT("production_windup_has_hidden_projectile_and_no_early_damage"));
            if(Shots.IsEmpty()){Finish();return true;}RoseDelay=Shots[0].ReleaseDelay;RoseTime=CharacterAnimation.Time;RoseRunTime=RunTime;Panel=TEXT("pause");Next(22);return false;
        }
        if(CaptureStep==22){
            if(SmokeTime<.3f)return false;
            Check(Shots.Num()==1 && FMath::IsNearlyEqual(Shots[0].ReleaseDelay,RoseDelay) && FMath::IsNearlyEqual(CharacterAnimation.Time,RoseTime) && FMath::IsNearlyEqual(RunTime,RoseRunTime) && Enemies[0].HP==RoseInitialHP,TEXT("actual_pause_Tick_freezes_release_animation_clock_and_damage"));
            Action(TEXT("close"));Next(23);return false;
        }
        if(CaptureStep==23){
            for(const auto& S:Shots)if(S.Potion && S.ReleaseDelay<=0 && !S.Body->IsHidden()){
                if(!RoseVisible)Check(RunTime-RoseCastClock>=.4f-.001f,TEXT("real_projectile_visibility_waits_for_point_four_battle_seconds"));RoseVisible=true;
            }
            if(!Enemies.IsEmpty() && Enemies[0].HP<RoseInitialHP){
                RoseHitHP=Enemies[0].HP;Check(RoseVisible && FMath::IsNearlyEqual(RoseInitialHP-RoseHitHP,RoseDamage) && Shots.IsEmpty(),TEXT("resumed_production_potion_becomes_visible_and_hits_once_for_expected_damage"));Next(24);return false;
            }
            if(SmokeTime<2)return false;Check(false,TEXT("bounded_production_potion_hit_after_resume"));Finish();return true;
        }
        if(CaptureStep==24){
            if(SmokeTime<.25f)return false;
            Check(!Enemies.IsEmpty() && Enemies[0].HP==RoseHitHP && Shots.IsEmpty(),TEXT("no_duplicate_projectile_or_hit_after_release"));ClearEnemies();Next(30);return true;
        }
        const TCHAR* Names[]={TEXT("01-side-attack.png"),TEXT("02-front-attack.png"),TEXT("03-back-attack.png"),TEXT("04-left-attack.png")};
        const FVector2D Directions[]={FVector2D(1,0),FVector2D(0,-1),FVector2D(0,1),FVector2D(-1,0)};
        if(CaptureStep==30){
            CharacterAnimation.Reset();CharacterAnimation.Throw(Directions[RoseView]);CharacterAnimation.Time=.45f;CharacterAnimation.Apply();UpdateCharacterVisual(0,false);Next(31);return true;
        }
        if(CaptureStep==31){
            UpdateCharacterVisual(0,false);if(SmokeTime<.6f)return true;
            Check(CharacterAnimation.Row==2 && CharacterAnimation.Frame==4 && CharacterAnimation.Facing==(RoseView==3?0:RoseView) && CharacterAnimation.Mirror==(RoseView==3),TEXT("rendered_attack_release_frame_and_facing_match_capture"));
            FScreenshotRequest::RequestScreenshot(RoseDir/Names[RoseView],true,false);Next(32);return true;
        }
        if(CaptureStep==32){
            UpdateCharacterVisual(0,false);if(SmokeTime<.3f || FScreenshotRequest::IsScreenshotRequested())return true;
            Check(IFileManager::Get().FileSize(*(RoseDir/Names[RoseView]))>0,TEXT("native_Rose_attack_screenshot_written"));
            if(++RoseView<4){Next(30);return true;}Finish();return true;
        }
        return true;
    }
    if(CaptureStep==0){
        bool OK=true;const auto Check=[&](bool Pass,const TCHAR* Name){OK &= Pass;UE_LOG(LogTemp,Display,TEXT("BATTLE_CHECK %s %s"),Name,Pass?TEXT("PASS"):TEXT("FAIL"));};
        Progress=NewObject<UAlchemyProgress>(this);MigrateProgress(true);StartRun();ClearEnemies();
        Check(RuntimeEnemies.Num()>=11 && EnemyTable,TEXT("authored_enemy_table_loaded"));
        Check(CharacterAnimation.RoseMage && BattlePortrait && CharacterAnimation.Atlases.Num()==4,TEXT("previous_rose_mage_and_portrait_loaded"));
        Check(FMath::IsNearlyEqual(CharacterAnimation.SheetWorldSize()*320.f/512,180),TEXT("hero_visible_height_180cm"));
        const auto Original=RuntimeEnemies;
        auto Variant=RuntimeEnemies[0];Variant.Name=TEXT("Regression variant");Variant.HP=77;Variant.TunedHP=-1;Variant.VisualSize=FVector2D(140,130);Variant.CollisionRadius=42;Variant.SpriteKey.Empty();Variant.MaterialOverride=Material(TEXT("M_Enemy0_Lit"));
        RuntimeEnemies.Add(Variant);const int ID=RuntimeEnemies.Num()-1;
        SpawnEnemy(ID);
        Check(Enemies.Num()==1 && Enemies[0].Definition==ID && Enemies[0].Type==0 && Enemies[0].HP==77 && EnemyRadius(Enemies[0])==42,TEXT("appended_row_keeps_normal_identity_and_own_stats"));
        if(!Enemies.IsEmpty()){
            Enemies[0].Pos=PlayerPos+FVector(300,0,0);UpdateEnemyVisual(Enemies[0]);
            Check(FMath::IsNearlyEqual(float(Enemies[0].Body->GetActorScale3D().X),1.4f) && Enemies[0].Body->GetStaticMeshComponent()->GetMaterial(0)==Variant.MaterialOverride,TEXT("configured_visual_size_applied"));
            const FVector BeforeMove=Enemies[0].Pos;Chase(Enemies[0],.1f);
            Check(Walkable(Enemies[0].Pos,EnemyRadius(Enemies[0])) && FVector::Dist2D(Enemies[0].Pos,PlayerPos)<FVector::Dist2D(BeforeMove,PlayerPos),TEXT("appended_normal_uses_existing_navigation"));
            const int BeforeKills=Kills;TriggerNuclear();Check(Enemies.IsEmpty() && Kills==BeforeKills+1,TEXT("appended_normal_not_misclassified_as_elite"));
        }
        for(auto& K:RuntimeEnemies)K.SpawnWeights={0,0,0,0,0,0};RuntimeEnemies[ID].SpawnWeights={100,100,100,100,100,100};SpawnWave();
        bool Spawned=!Enemies.IsEmpty();for(const auto& E:Enemies)Spawned &= E.Definition==ID;
        Check(Spawned,TEXT("appended_row_participates_in_configured_waves"));ClearEnemies();
        for(auto& K:RuntimeEnemies)K.EliteWeight=0;
        Check(ChooseEliteDefinition()==-1,TEXT("zero_elite_weights_disable_selection"));
        auto Elite=Original[7];Elite.Name=TEXT("Regression elite variant");Elite.EliteWeight=1;
        RuntimeEnemies.Add(Elite);const int EliteID=RuntimeEnemies.Num()-1;
        Check(ChooseEliteDefinition()==EliteID,TEXT("appended_elite_participates_in_weighted_selection"));
        if(bBattleReference){
            const FVector RewardPoint=BattleReferencePoint({570,350});
            const bool Legal=Walkable(RewardPoint,EnemyRadius(EliteID));
            Check(Legal,TEXT("elite_reward_fixture_uses_authored_legal_ground"));
            if(Legal)SpawnEnemyAt(EliteID,RewardPoint);
        }else SpawnEnemy(EliteID);
        const int BeforeDrops=Drops.Num();
        if(!Enemies.IsEmpty())RewardEnemy(Enemies.Last());
        Check(!Enemies.IsEmpty() && Enemies.Last().Type==7 && MerchantEliteUnlocked[0] && Drops.Num()==BeforeDrops+2 && Drops[BeforeDrops].Kind==6,TEXT("appended_elite_preserves_valid_chest_and_unlock"));ClearEnemies();
        auto* InvalidTable=NewObject<UDataTable>(this);InvalidTable->RowStruct=FAlchemyEnemyRow::StaticStruct();
        for(int I=0;I<Original.Num();I++)InvalidTable->AddRow(FName(*FString::FromInt(I)),Original[I]);
        auto InvalidRow=Original[0];InvalidRow.SpawnWeights={1};InvalidTable->AddRow(FName(TEXT("0")),InvalidRow);
        TArray<FAlchemyEnemyRow> InvalidRows;FString InvalidReason;
        Check(!AlchemyDesign::ReadEnemyDefinitions(InvalidTable,InvalidRows,InvalidReason) && InvalidRows.IsEmpty(),TEXT("invalid_authored_weights_are_rejected"));
        FAlchemistSpriteAnimation ReleaseProbe;ReleaseProbe.RoseMage=true;ReleaseProbe.Throw(FVector2D(1,0));
        const bool EarlyRelease=ReleaseProbe.Advance(.39f,FVector2D(1,0),false);
        Check(!EarlyRelease && ReleaseProbe.Advance(.02f,FVector2D(1,0),false),TEXT("rose_attack_releases_at_authored_swing"));
        Check(CharacterAnimation.HasRoseAttack(),TEXT("authored_side_front_back_attack_atlases_loaded"));
        if(CharacterAnimation.HasRoseAttack()){
            auto AttackProbe=CharacterAnimation;bool Views=true,Frames=true;
            const FVector2D Directions[]={FVector2D(1,0),FVector2D(0,-1),FVector2D(0,1)};
            for(int View=0;View<3;View++){
                AttackProbe.Reset();const bool Started=AttackProbe.Throw(Directions[View]);
                Views &= Started && AttackProbe.Facing==View && !AttackProbe.Mirror && AttackProbe.Material->K2_GetTextureParameterValue(TEXT("SpriteSheet"))==AttackProbe.RoseAttackAtlases[View];
                Views &= AttackProbe.RoseAttackAtlases[View]->GetSizeX()==4096 && AttackProbe.RoseAttackAtlases[View]->GetSizeY()==512;
                const auto UV=AttackProbe.Material->K2_GetVectorParameterValue(TEXT("UVScale"));Views &= FMath::IsNearlyEqual(UV.R,.125f) && UV.G==1;
                for(int Frame=0;Frame<8;Frame++){
                    AttackProbe.Reset();AttackProbe.Throw(Directions[View]);AttackProbe.Advance(Frame*.1f+.05f,Directions[View],false);
                    Frames &= AttackProbe.Row==2 && AttackProbe.Frame==Frame && AttackProbe.Material->K2_GetTextureParameterValue(TEXT("SpriteSheet"))==AttackProbe.RoseAttackAtlases[View];
                }
                AttackProbe.Reset();AttackProbe.Throw(Directions[View]);
                const bool Before=AttackProbe.Advance(.39f,Directions[View],false),At=AttackProbe.Advance(.02f,Directions[View],false),After=AttackProbe.Advance(.01f,Directions[View],false);
                Frames &= !Before && At && !After;
            }
            Check(Views,TEXT("each_attack_facing_selects_real_material_texture_and_eight_cell_layout"));
            Check(Frames,TEXT("all_three_attack_views_play_eight_frames_and_release_once_at_point_four"));
            AttackProbe.Reset();AttackProbe.Throw({-1,0});
            Check(AttackProbe.Facing==0 && AttackProbe.Mirror && AttackProbe.Material->K2_GetTextureParameterValue(TEXT("SpriteSheet"))==AttackProbe.RoseAttackAtlases[0],TEXT("left_attack_mirrors_same_side_atlas"));
            AttackProbe.Reset();AttackProbe.Advance(.1f,{1,0},true);const bool MovingThrow=AttackProbe.Throw({0,1});
            Check(!MovingThrow && AttackProbe.Moving && !AttackProbe.Throwing && AttackProbe.Row==1,TEXT("moving_keeps_existing_gait_instead_of_starting_attack"));
            AttackProbe.Reset();AttackProbe.Throw({1,0});AttackProbe.Advance(.1f,{0,1},true);
            Check(!AttackProbe.Throwing && AttackProbe.Moving && AttackProbe.Row==1,TEXT("starting_movement_still_cancels_attack_pose"));
            AttackProbe.Reset();AttackProbe.Throw({0,1});AttackProbe.Hit();
            Check(AttackProbe.Hurting && !AttackProbe.Throwing && AttackProbe.Row==3 && !AttackProbe.Throw({1,0}),TEXT("hurt_overrides_attack_and_blocks_new_attack_pose"));
            AttackProbe.Die();AttackProbe.Hit();AttackProbe.Advance(.8f,{1,0},true);
            Check(AttackProbe.Dead && !AttackProbe.Hurting && !AttackProbe.Throwing && AttackProbe.Row==4 && AttackProbe.Frame==5 && !AttackProbe.Throw({1,0}),TEXT("death_overrides_hurt_movement_and_attack_and_holds_last_frame"));
            AttackProbe.RoseAttackAtlases.Empty();AttackProbe.Reset();AttackProbe.Throw({0,1});
            Check(!AttackProbe.HasRoseAttack() && AttackProbe.Row==2 && AttackProbe.Material->K2_GetTextureParameterValue(TEXT("SpriteSheet"))==AttackProbe.Atlases[3],TEXT("missing_directional_attack_pack_falls_back_to_original_attack"));
            auto LegacyProbe=CharacterAnimation;auto* LegacyMesh=NewObject<UStaticMeshComponent>(this);
            Check(LegacyProbe.Initialize(this,LegacyMesh) && !LegacyProbe.RoseMage && LegacyProbe.RoseAttackAtlases.IsEmpty() && LegacyProbe.RoseMotionAtlases.IsEmpty(),TEXT("legacy_initialization_clears_all_rose_motion_and_attack_state"));
            CharacterAnimation.Apply();
        }
        RuntimeEnemies=Original;
        for(bool Tuned:{false,true}){
            bTune001B=Tuned;RunTime=0;SpawnEnemy(0);const auto& K=RuntimeEnemies[0];
            Check(!Enemies.IsEmpty() && Enemies.Last().HP==(Tuned?K.TunedHP:K.HP) && Enemies.Last().Contact==(Tuned?K.TunedContactDamage:K.ContactDamage),Tuned?TEXT("tuned_profile_preserved"):TEXT("baseline_profile_preserved"));ClearEnemies();
        }
        bTune001B=true;StartRun();ClearEnemies();Progress->TutorialComplete=true;
        if(!OK || !Visual){UE_LOG(LogTemp,Display,TEXT("BATTLE_PRESENTATION_%s"),OK?TEXT("PASS"):TEXT("FAIL"));FPlatformMisc::RequestExitWithStatus(false,OK?0:1);return true;}
        IFileManager::Get().MakeDirectory(*Dir,true);
        RunTime=120;SpawnCD=1000;NextElite=10000;HP=MaxHP;RunCoins=124;Kills=32;
        CloseMerchant();NextMerchantTime=10000;
        if(Walkable(FVector::ZeroVector,45))PlayerPos=FVector::ZeroVector;
        UpdateCamera(0);UpdateCharacterVisual(0,false);
        Equipped={0,1,2,3,4,5};for(int S:Equipped)Levels[S]=2;
        for(int I=0;I<30;I++){
            const int Count=Enemies.Num();SpawnEnemy(I%7);if(Enemies.Num()==Count)continue;
            const float A=I*2.39996f,R=430+(I%5)*125;
            const FVector P=PlayerPos+Camera->GetActorRightVector().GetSafeNormal2D()*FMath::Cos(A)*R+Camera->GetActorForwardVector().GetSafeNormal2D()*FMath::Sin(A)*R;
            if(Walkable(P,EnemyRadius(Enemies.Last()))){Enemies.Last().Pos=P;UpdateEnemyVisual(Enemies.Last());}
        }
        for(int I=0;I<8;I++)Drop(PlayerPos+FVector((I-4)*110,240,0),I%3);
        ToastTime=0;SmokeTime=0;CaptureStep=1;
    }
    SmokeTime+=Dt;
    if(CaptureStep==1 && SmokeTime>1.1f){FScreenshotRequest::RequestScreenshot(Dir/TEXT("01-field.png"),false,false);CaptureStep=2;}
    else if(CaptureStep==2 && SmokeTime>2.0f){
        GreyfordPortalReady=true;GreyfordPortalPos=PlayerPos;EnterGreyfordBoss();ToastTime=0;CaptureStep=3;
    }else if(CaptureStep==3 && SmokeTime>2.5f){FScreenshotRequest::RequestScreenshot(Dir/TEXT("02-boss-preparation.png"),false,false);CaptureStep=4;}
    else if(CaptureStep==4 && SmokeTime>4.6f){
        if(FParse::Param(FCommandLine::Get(),TEXT("RoseAttackCapture"))){CaptureStep=20;SmokeTime=0;return true;}
        UE_LOG(LogTemp,Display,TEXT("BATTLE_PRESENTATION_PASS"));FPlatformMisc::RequestExitWithStatus(false,0);return true;
    }
    return false;
}
