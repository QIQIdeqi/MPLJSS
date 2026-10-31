// Isolated, bounded checks of production actions. -ProducerRegression never loads or writes player saves.
void AAlchemyWorld::ProducerRegression() {
    const bool Visual=FParse::Param(FCommandLine::Get(),TEXT("ProducerVisual"));
    const FString Dir=FPaths::ProjectDir()/TEXT("Evidence/ProducerRegression");
    const auto Finish=[&](bool OK){UE_LOG(LogTemp,Display,TEXT("PRODUCER_REGRESSION_%s"),OK?TEXT("PASS"):TEXT("FAIL"));FPlatformMisc::RequestExitWithStatus(false,OK?0:1);};
    if(SmokeStep>0) {
        SmokeTime+=GetWorld()->GetDeltaSeconds();
        if(SmokeTime<1)return;SmokeTime=0;
        if(SmokeStep==1){FScreenshotRequest::RequestScreenshot(Dir/TEXT("nuclear-result.png"),false,false);SmokeStep=2;return;}
        if(SmokeStep==2){
            Action(TEXT("acceptresult"));Progress->TutorialComplete=false;TutorialSkill=CombinationSkill(6,0);
            Action(TEXT("alchemy"));Inventory={10,10,10,1,1,1};Selected={3,0,0,0,0,0};SmokeStep=3;return;
        }
        if(SmokeStep==3){FScreenshotRequest::RequestScreenshot(Dir/TEXT("unfinished-tutorial-boss-alchemy.png"),false,false);SmokeStep=4;return;}
        Finish(true);return;
    }
    bool OK=true;
    const auto Check=[&](bool Pass,const TCHAR* Name){OK &= Pass;UE_LOG(LogTemp,Display,TEXT("PRODUCER_CHECK %s %s"),Name,Pass?TEXT("PASS"):TEXT("FAIL"));};
    const auto ClearEnemies=[&](){for(auto& E:Enemies){if(IsValid(E.Body))E.Body->Destroy();if(IsValid(E.Shadow))E.Shadow->Destroy();}Enemies.Empty();};
    const auto SeedFor=[&](bool Nuclear,int Total){
        for(int Seed=1;Seed<=10000;Seed++)if((FRandomStream(Seed).FRand()*100<SpecialProcChance[Total-3])==Nuclear){Random.Initialize(Seed);return;}
        Check(false,TEXT("bounded_seed_search"));
    };
    const auto Fresh=[&](){Progress=NewObject<UAlchemyProgress>(this);MigrateProgress(true);Progress->Talents[8]=1;StartRun();ClearEnemies();Inventory={10,10,10,1,1,1};Selected={1,1,1,0,0,0};};
    Fresh();SeedFor(false,3);Check(Craft(),TEXT("ordinary_result_staged"));
    const int First=PendingResultSkill;const auto Paid=Inventory;const int Crafts=CraftCount;
    bool Panels=First>=0;
    for(const TCHAR* Id:{TEXT("alchemy"),TEXT("codex"),TEXT("skills"),TEXT("fonts"),TEXT("research")}){
        TogglePanel(Id);Panels &= Panel==TEXT("result") && PendingResultSkill==First;
    }
    for(const TCHAR* Id:{TEXT("close"),TEXT("alchemy"),TEXT("codex"),TEXT("skills"),TEXT("talents"),TEXT("level"),TEXT("research"),TEXT("fonts"),TEXT("textsize"),TEXT("return"),TEXT("village"),TEXT("start"),TEXT("enterboss"),TEXT("craft")}){
        Action(Id);Panels &= Panel==TEXT("result") && PendingResultSkill==First && Inventory==Paid && CraftCount==Crafts;
    }
    Check(Panels,TEXT("Tab_C_B_F7_F6_Esc_and_UI_actions_preserve_result"));
    Selected={1,1,1,0,0,0};Check(!Craft() && Inventory==Paid && PendingResultSkill==First,TEXT("direct_second_craft_has_no_cost_or_overwrite"));
    GrantXP(RequiredXP(RunLevel));Check(Panel==TEXT("result") && PendingLevelUps>0,TEXT("queued_levelup_does_not_replace_result"));
    const int PriorLevel=First>=0?Levels[First]:0;Action(TEXT("acceptresult"));Action(TEXT("acceptresult"));
    Check(First>=0 && Levels[First]==PriorLevel+1 && Inventory==Paid && PendingResultSkill<0 && !PendingIsNuclear,TEXT("receive_exactly_once_after_navigation"));
    RollLevelupChoices();Check(Panel==TEXT("levelup"),TEXT("queued_levelup_available_after_receive"));

    Fresh();TArray<int32> Options;TArray<float> W;FString Reason;int C;
    bool WeightsOK=true;
    for(int Total=3;Total<=10;Total++)for(int Q=0;Q<3;Q++){
        const float Expected=Q==0?QualityWeight(Total-3,0)+(QualityWeight(Total-3,1)+QualityWeight(Total-3,2))*.5f:QualityWeight(Total-3,Q)*.5f;
        WeightsOK &= FMath::IsNearlyEqual(ResultQualityWeight(Total,Q,true),Expected) && ResultQualityWeight(Total,Q,false)==QualityWeight(Total-3,Q);
    }
    Check(WeightsOK && ResultQualityWeight(3,0,true)==85 && ResultQualityWeight(10,0,true)==65,TEXT("all_8_nuclear_rows_lower_mid_high_without_changing_base"));
    const int Low=CombinationSkill(6,0),Mid=CombinationSkill(6,1),High=CombinationSkill(6,2);
    Levels[Low]=5;
    Check(CraftOptions(Options,W,Reason,C,true) && Options.Num()==2 && FMath::IsNearlyEqual(W[0],200.f/3,.001f) && FMath::IsNearlyEqual(W[1],100.f/3,.001f),TEXT("nuclear_weights_lower_before_maxlevel_filter_normalize"));
    Levels[Mid]=Levels[High]=5;const auto BlockedInventory=Inventory;
    Check(!Craft() && Inventory==BlockedInventory,TEXT("all_candidates_blocked_no_material_cost"));
    Fresh();Equipped={0,1,2,3,5,6};Bag={7,8,9,10,11,12};Levels[Low]=1;
    Check(CraftOptions(Options,W,Reason,C,true) && Options.Num()==1 && Options[0]==Low && W[0]==100,TEXT("nuclear_capacity_filter_allows_existing_upgrade"));

    Fresh();SpawnEnemy(0);SpawnEnemy(7);SpawnEnemy(10);
    const float EliteHP=Enemies[1].HP,BossHP=Enemies[2].HP;const auto BeforeClear=Inventory;const int KillsBefore=Kills;
    SeedFor(true,3);Check(Craft() && PendingIsNuclear && PendingResultSkill>=0,TEXT("nuclear_still_stages_receivable_skill"));
    Check(Enemies.Num()==2 && Enemies[0].Type>=7 && Enemies[1].Type>=7 && Kills==KillsBefore+1,TEXT("nuclear_clears_normal_once"));
    bool SpecialHP=true;for(const auto& E:Enemies)SpecialHP &= E.HP==(E.Type==7?EliteHP:BossHP);
    Check(SpecialHP && Inventory[0]==BeforeClear[0]-1 && Inventory[1]==BeforeClear[1]-1 && Inventory[2]==BeforeClear[2]-1 && CraftCount==1,TEXT("nuclear_elite_boss_unchanged_single_cost"));
    const int Original=PendingResultSkill,ClearKills=Kills,DropCount=Drops.Num();const auto NuclearPaid=Inventory;
    Progress->Talents[8]=0;RerollPendingResult();Check(PendingResultSkill==Original && !PendingRefreshed,TEXT("locked_refresh_no_change"));Progress->Talents[8]=1;
    // With low as the sole alternative, verify filters, receive, and no second clearing deterministically.
    for(int Q=0;Q<3;Q++)Levels[CombinationSkill(6,Q)]=CombinationSkill(6,Q)==Original?0:5;
    RerollPendingResult();Check(PendingResultSkill==Original && !PendingRefreshed,TEXT("no_alternative_refresh_keeps_result"));
    Levels[Low]=Levels[Mid]=Levels[High]=0;
    RerollPendingResult();const int Refreshed=PendingResultSkill;
    Check(PendingRefreshed && PendingIsNuclear && Refreshed>=0 && Refreshed!=Original && Kills==ClearKills && Drops.Num()==DropCount && Inventory==NuclearPaid,TEXT("nuclear_refresh_once_same_craft_no_second_clear_or_cost"));
    RerollPendingResult();Check(PendingResultSkill==Refreshed,TEXT("second_refresh_rejected"));
    const int RefreshedLevel=Refreshed>=0?Levels[Refreshed]:0;AcceptPendingResult();
    Check(Refreshed>=0 && Levels[Refreshed]==RefreshedLevel+1 && Progress->Recipes.Contains(Refreshed) && Progress->Combinations.Contains(6) && !PendingIsNuclear,TEXT("nuclear_receive_grants_skill_and_discovery"));
    Selected={1,1,1,0,0,0};SeedFor(false,3);Check(Craft() && !PendingIsNuclear,TEXT("following_ordinary_craft_has_no_nuclear_flag"));AcceptPendingResult();
    Selected={1,0,1,1,0,0};SeedFor(true,3);Check(Craft() && !PendingIsNuclear && PendingResultSkill==7,TEXT("elite_recipe_never_nuclear"));AcceptPendingResult();

    for(bool HasTutorialSkill:{false,true}){
        Fresh();Progress->TutorialComplete=false;TutorialSkill=HasTutorialSkill?Low:-1;
        GreyfordPortalReady=true;GreyfordPortalPos=PlayerPos;Check(EnterGreyfordBoss(),TEXT("unfinished_tutorial_freely_enters_boss"));
        Check(GreyfordStage==2 && !TutorialActive() && !Progress->TutorialComplete && Enemies.Num()==1 && Enemies[0].Type==10,TEXT("boss_temporarily_lifts_tutorial_without_extra_enemies"));
        Inventory={10,10,10,1,1,1};Selected={0,0,0,0,0,0};AddMaterial(0);AddMaterial(0);AddMaterial(0);
        Check(Selected[0]==3 && CraftOptions(Options,W,Reason,C),TEXT("boss_allows_free_pour_before_tutorial_complete"));
        SeedFor(false,3);Check(Craft(),TEXT("boss_unfinished_tutorial_can_craft"));AcceptPendingResult();
        Levels[7]=1;Bag={7};SelectedBag=0;Action(TEXT("equip1"));
        TutorialHit(TutorialSkill,2);
        Check(Equipped.Contains(7) && !Progress->TutorialComplete,TEXT("boss_can_equip_without_faking_tutorial_completion"));
        // Exercise both defeat and victory transitions, then the next real field start.
        EndRun(HasTutorialSkill);Action(TEXT("village"));Action(TEXT("start"));
        Check(GreyfordStage==1 && TutorialActive() && TutorialSkill<0 && !Progress->TutorialComplete,TEXT("next_field_run_resumes_unfinished_tutorial"));
    }
    // Reproduce the reported resource loss in the actual single-Boss stage, including a new player.
    Fresh();Progress->TutorialComplete=false;
    GreyfordPortalReady=true;GreyfordPortalPos=PlayerPos;
    Check(EnterGreyfordBoss(),TEXT("boss_only_nuclear_scenario_enters_freely"));
    Inventory={3,0,0,0,0,0};Selected={3,0,0,0,0,0};
    const float BossOnlyHP=Enemies.IsEmpty()?0:Enemies[0].HP;
    SeedFor(true,3);
    Check(Craft() && PendingIsNuclear && PendingResultSkill>=0 && Inventory[0]==0 && CraftCount==1,TEXT("boss_only_nuclear_costs_once_and_gives_skill"));
    Check(Enemies.Num()==1 && Enemies[0].Type==10 && Enemies[0].HP==BossOnlyHP && Drops.IsEmpty(),TEXT("boss_only_nuclear_keeps_boss_hp_and_creates_no_materials"));
    const int BossNuclearSkill=PendingResultSkill;
    Action(TEXT("acceptresult"));
    Check(BossNuclearSkill>=0 && Levels[BossNuclearSkill]==1 && !Progress->TutorialComplete && PendingResultSkill<0,TEXT("boss_only_nuclear_skill_received_without_completing_tutorial"));
    // Direct transition callers must also preserve a staged result and its refresh opportunity.
    Fresh();SeedFor(true,3);Check(Craft(),TEXT("pending_nuclear_before_direct_boss_entry"));
    const int BeforeEntrySkill=PendingResultSkill;const auto BeforeEntryInventory=Inventory;
    GreyfordPortalReady=true;GreyfordPortalPos=PlayerPos;Check(EnterGreyfordBoss(),TEXT("direct_boss_entry_with_pending_result"));
    Check(Panel==TEXT("result") && PendingResultSkill==BeforeEntrySkill && PendingIsNuclear && Inventory==BeforeEntryInventory,TEXT("boss_entry_preserves_result_without_auto_receive"));
    if(!OK || !Visual){Finish(OK);return;}
    IFileManager::Get().MakeDirectory(*Dir,true);SmokeStep=1;SmokeTime=0;
}
