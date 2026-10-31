// true freezes the fixture; false lets production Tick process the staged Boss death.
bool AAlchemyWorld::EnemyCodexCheck(float Dt) {
    static bool ECOK=true;static int ECCoins=0;
    const FString Dir=FPaths::ProjectDir()/TEXT("Evidence/EnemyCodex_20261101");
    auto* PC=GetWorld()->GetFirstPlayerController();auto* HUD=PC?Cast<AAlchemyHUD>(PC->GetHUD()):nullptr;
    const auto Check=[&](bool Pass,const TCHAR* Name){ECOK &= Pass;UE_LOG(LogTemp,Display,TEXT("ENEMYC_CHECK %s %s"),Name,Pass?TEXT("PASS"):TEXT("FAIL"));};
    const auto Clear=[&](){for(auto& E:Enemies){if(IsValid(E.Body))E.Body->Destroy();if(IsValid(E.Shadow))E.Shadow->Destroy();}Enemies.Empty();};
    const auto Next=[&](int Step){CaptureStep=Step;SmokeTime=0;};
    const auto Shot=[&](const TCHAR* Name){FScreenshotRequest::RequestScreenshot(Dir/Name,true,false);};
    const auto Finish=[&](){UE_LOG(LogTemp,Display,TEXT("ENEMYC_%s"),ECOK?TEXT("PASS"):TEXT("FAIL"));FPlatformMisc::RequestExitWithStatus(false,ECOK?0:1);};
    const auto Drawn=[&](const FString& Text){return HUD && FString::Join(HUD->UIV02DrawnText,TEXT("")).Contains(Text);};
    if(CaptureStep==0){
        ECOK=true;Check(bCapture,TEXT("isolated_fixture_no_real_save_IO"));if(!bCapture){Finish();return true;}
        IFileManager::Get().MakeDirectory(*Dir,true);Progress=NewObject<UAlchemyProgress>(this);MigrateProgress(true);StartRun();Clear();
        auto* TestTable=NewObject<UDataTable>(this);TestTable->RowStruct=FAlchemyEnemyRow::StaticStruct();
        for(int I=0;I<11;I++)TestTable->AddRow(FName(*FString::FromInt(I)),RuntimeEnemies[I]);
        auto Normal=RuntimeEnemies[0];Normal.Name=TEXT("回归普通新行");Normal.CodexDescription=TEXT("");
        auto Elite=RuntimeEnemies[7];Elite.Name=TEXT("回归精英新行");Elite.Behavior=EAlchemyEnemyBehavior::Ranged;Elite.CodexDescription=TEXT("");
        auto Boss=RuntimeEnemies[10];Boss.Name=TEXT("回归Boss新行");Boss.CodexDescription=TEXT("");
        auto Long=Normal;Long.Name=TEXT("回归长名称材料守卫测试行这是为了实际字体测量下也超过一栏宽度而保留的回归名称");Long.CodexDescription=TEXT("自填说明：这段文字用于检查真实怪物图鉴的长文案省略，描述只来自运行数据表，不根据素材外观或兼容模板擅自增加怪物身份，也不影响伤害、掉落、行为和碰撞。");
        TestTable->AddRow(FName(TEXT("11")),Normal);TestTable->AddRow(FName(TEXT("12")),Elite);TestTable->AddRow(FName(TEXT("13")),Boss);TestTable->AddRow(FName(TEXT("14")),Long);
        TArray<FAlchemyEnemyRow> ReadRows;FString Error;Check(AlchemyDesign::ReadEnemyDefinitions(TestTable,ReadRows,Error) && ReadRows.Num()==15,TEXT("actual_table_reader_accepts_contiguous_appended_variants"));
        if(ReadRows.Num()!=15){Finish();return true;}EnemyTable=TestTable;RuntimeEnemies=ReadRows;
        // A wide center view may legitimately leave no complete offscreen elite space.
        // Exercise actual spawning at the authored upper-meadow point, retaining every production query.
        PlayerPos=BattleReferencePoint(FVector2D(570,350));
        Check(Walkable(PlayerPos,70),TEXT("authored_meadow_test_position_accepts_elite_radius"));
        UpdateCamera(0);Next(11);return true;
    }
    UpdateCamera(Dt);UpdateCharacterVisual(Dt,false);SmokeTime+=Dt;
    if(CaptureStep==9){
        if(!bRunEnded){if(SmokeTime<2)return false;Check(false,TEXT("production_tick_processed_dead_Boss_within_bound"));Finish();return true;}
        Check(bWon && Progress->Monsters.Contains(13) && !Progress->Monsters.Contains(10),TEXT("real_Boss_death_discovers_13_without_unlocking_10"));
        Check(Progress->Coins==ECCoins+29 && ResultCoins==29,TEXT("real_Boss_victory_settles_run_coins"));
        const auto Discovered=Progress->Monsters;EndRun(true);Check(Progress->Coins==ECCoins+29 && ResultCoins==29 && Progress->Monsters==Discovered,TEXT("repeat_victory_does_not_duplicate_coins_or_discovery"));
        TArray<uint8> Bytes;const bool Saved=UGameplayStatics::SaveGameToMemory(Progress,Bytes);auto* Loaded=Saved?Cast<UAlchemyProgress>(UGameplayStatics::LoadGameFromMemory(Bytes)):nullptr;
        Check(Loaded && Loaded->Monsters.Contains(13) && !Loaded->Monsters.Contains(10) && Loaded->Coins==ECCoins+29,TEXT("new_Boss_discovery_and_coins_survive_memory_save"));
        Shot(TEXT("04-new-Boss-victory.png"));Next(10);return true;
    }
    if(SmokeTime<.7f)return true;
    Check(HUD!=nullptr,TEXT("native_HUD_available"));if(!HUD){Finish();return true;}
    // StartRun changes the camera; wait for an actual rendered projection before offscreen spawns.
    if(CaptureStep==11){
        Progress->Monsters={0,7,10};TArray<uint8> LegacyBytes;const bool Saved=UGameplayStatics::SaveGameToMemory(Progress,LegacyBytes);
        auto* Loaded=Saved?Cast<UAlchemyProgress>(UGameplayStatics::LoadGameFromMemory(LegacyBytes)):nullptr;
        Check(Loaded && Loaded->Monsters==TArray<int32>({0,7,10}),TEXT("legacy_0_7_10_discovery_save_roundtrip_unchanged"));
        Progress->Monsters.Empty();SpawnEnemy(11);Check(Enemies.Num()==1 && Enemies[0].Type==0 && Enemies[0].Definition==11,TEXT("new_normal_uses_own_definition_and_old_reward_template"));
        if(!Enemies.IsEmpty())RewardEnemy(Enemies.Last());Check(Progress->Monsters==TArray<int32>({11}),TEXT("normal_reward_discovers_11_without_unlocking_0"));Clear();
        SpawnEnemy(12);const int BeforeDrops=Drops.Num();if(!Enemies.IsEmpty())RewardEnemy(Enemies.Last());
        Check(Progress->Monsters.Contains(12) && !Progress->Monsters.Contains(7) && MerchantEliteUnlocked[0] && Drops.Num()==BeforeDrops+2 && Drops[BeforeDrops].Kind==6,TEXT("new_elite_discovery_independent_reward_template_preserved"));Clear();
        Progress->Monsters.Empty();SpawnEnemy(11);SpawnEnemy(11);const int BeforeKills=Kills;TriggerNuclear();
        Check(Enemies.IsEmpty() && Kills==BeforeKills+2 && Progress->Monsters==TArray<int32>({11}),TEXT("nuclear_first_discovery_records_new_definition_once"));
        const int NuclearKills=Kills;TriggerNuclear();Check(Kills==NuclearKills && Progress->Monsters==TArray<int32>({11}),TEXT("empty_repeated_nuclear_has_no_duplicate_discovery_or_kills"));
        SpawnCD=NextElite=NextMerchantTime=10000;for(float& CD:SkillCD)CD=10000;Progress->TutorialComplete=true;
        CodexPage=1;Action(TEXT("codex"));
#if WITH_EDITOR
        FAssetCompilingManager::Get().FinishAllCompilation();if(GShaderCompilingManager)GShaderCompilingManager->FinishAllCompilation();
#endif
        Next(1);return true;
    }
    if(CaptureStep==1){if(SmokeTime<2)return true;HUD->Activate(TEXT("detailnext"));HUD->Activate(TEXT("detailnext"));Next(2);return true;}
    if(CaptureStep==2){Check(HUD->DetailPage==2 && Drawn(TEXT("3 / 3")) && Drawn(TEXT("???")),TEXT("third_codex_page_exists_and_unknown_definitions_are_masked"));Shot(TEXT("01-third-page-unknown.png"));Next(3);return true;}
    if(CaptureStep==3){
        if(FScreenshotRequest::IsScreenshotRequested())return true;
        for(int ID:{12,14}){FAlchemyEnemy E;E.Type=RuntimeEnemies[ID].Archetype;E.Definition=ID;E.Pos=PlayerPos;RewardEnemy(E);}
        Next(4);return true;
    }
    if(CaptureStep==4){
        Check(Drawn(RuntimeEnemies[12].Name) && Drawn(TEXT("回归长名称")),TEXT("third_page_names_read_actual_runtime_rows"));
        Check(HUD->UIV02DrawnText.ContainsByPredicate([](const FString& T){return T.StartsWith(TEXT("回归长名称")) && T.EndsWith(TEXT("…"));}),TEXT("long_authored_name_is_explicitly_ellipsized"));
        Check(!EnemyCodexDescription(12).IsEmpty() && Drawn(EnemyCodexDescription(12)),TEXT("empty_authored_description_uses_drawn_behavior_fallback"));
        Check(EnemyCodexDescription(14)==RuntimeEnemies[14].CodexDescription && Drawn(TEXT("自填说明")),TEXT("authored_description_overrides_behavior_and_is_drawn"));
        Check(!Drawn(RuntimeEnemies[13].Name) && Drawn(TEXT("???")),TEXT("unbeaten_Boss_name_stays_hidden"));
        Shot(TEXT("02-third-page-known-long-text.png"));Next(5);return true;
    }
    if(CaptureStep==5){if(FScreenshotRequest::IsScreenshotRequested())return true;HUD->Activate(TEXT("detailprev"));Next(6);return true;}
    if(CaptureStep==6){Check(HUD->DetailPage==1 && Drawn(RuntimeEnemies[11].Name) && !Drawn(RuntimeEnemies[0].Name),TEXT("new_normal_name_on_second_page_not_old_archetype_name"));Shot(TEXT("03-new-normal-second-page.png"));Next(8);return true;}
    if(CaptureStep==8){
        if(FScreenshotRequest::IsScreenshotRequested())return true;Panel.Empty();Clear();Progress->Monsters.Remove(10);Progress->Monsters.Remove(13);
        SpawnEnemy(13);Check(Enemies.Num()==1 && Enemies[0].Definition==13 && Enemies[0].Type==10,TEXT("appended_Boss_instantiated_with_own_definition"));
        if(Enemies.IsEmpty()){Finish();return true;}Enemies[0].HP=0;bBossSpawned=true;HP=MaxHP;HurtInv=100;RunCoins=29;ECCoins=Progress->Coins;Next(9);return false;
    }
    if(CaptureStep==10){for(const TCHAR* Name:{TEXT("01-third-page-unknown.png"),TEXT("02-third-page-known-long-text.png"),TEXT("03-new-normal-second-page.png"),TEXT("04-new-Boss-victory.png")})Check(IFileManager::Get().FileSize(*(Dir/Name))>0,TEXT("native_screenshot_written"));Finish();return true;}
    return true;
}
