bool AAlchemyWorld::BattlePresentationCheck(float Dt) {
    const bool Visual=FParse::Param(FCommandLine::Get(),TEXT("BattlePresentationCapture"));
    const FString Dir=FPaths::ProjectDir()/TEXT("Evidence/BattlePresentation_20261031");
    const auto ClearEnemies=[&](){for(auto& E:Enemies){E.Body->Destroy();E.Shadow->Destroy();}Enemies.Empty();};
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
        SpawnEnemy(EliteID);const int BeforeDrops=Drops.Num();
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
    else if(CaptureStep==4 && SmokeTime>4.6f){UE_LOG(LogTemp,Display,TEXT("BATTLE_PRESENTATION_PASS"));FPlatformMisc::RequestExitWithStatus(false,0);return true;}
    return false;
}
