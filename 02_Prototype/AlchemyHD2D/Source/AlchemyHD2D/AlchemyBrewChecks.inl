// Isolated -BrewV02Test fixture. It exercises production brewing without player save I/O.
bool AAlchemyWorld::BrewV02Check(float Delta) {
    static bool OK=true;
    static int32 Stage=0;
    static float PauseClock=0,PausedProgress=0;
    const auto Check=[&](bool Pass,const TCHAR* Name) {
        OK &= Pass;
        UE_LOG(LogTemp,Display,TEXT("BREW_V02_CHECK %s %s"),Name,Pass?TEXT("PASS"):TEXT("FAIL"));
    };
    const auto Finish=[&]() {
        UE_LOG(LogTemp,Display,TEXT("BREW_V02_%s"),OK?TEXT("PASS"):TEXT("FAIL"));
        FPlatformMisc::RequestExitWithStatus(false,OK?0:1);
        Stage=3;
    };
    const auto ClearEnemies=[&]() {
        for(auto& Enemy:Enemies) {
            if(IsValid(Enemy.Body)) Enemy.Body->Destroy();
            if(IsValid(Enemy.Shadow)) Enemy.Shadow->Destroy();
        }
        Enemies.Empty();
    };
    const auto Fresh=[&](int32 Mode) {
        Progress=NewObject<UAlchemyProgress>(this);
        MigrateProgress(true);
        Progress->TutorialComplete=true;
        Progress->AlchemyMode=Mode;
        StartRun();
        ClearEnemies();
        SpawnCD=NextElite=NextMerchantTime=10000;
        Inventory={8,8,8,0,0,0};
        for(int32& Stock:BrewOnlyStock) Stock=0; // Fixture stock is acquired normally.
        Random.Initialize(20261102);
        MaterialRandom.Initialize(20261102 ^ 0x4D41544C);
        BrewRandom.Initialize(20261102 ^ 0x42524557);
        Panel.Empty();
    };
    const auto Resolve=[&](int32 Operation,int32 Target,int32 Main,int32 Support,int32 MainCount,int32 SupportCount) {
        BrewOperation=Operation;BrewTarget=Target;BrewMain=Main;BrewSupport=Support;
        BrewMainCount=MainCount;BrewSupportCount=SupportCount;
        if(!BeginBrew()) return false;
        UpdateBrew(BrewDuration+.01f);
        return bV02Pending && PendingResultSkill>=0;
    };

    if(Stage==0) {
        OK=true;
        Check(bCapture,TEXT("fixture_isolated_from_player_save_IO"));
        if(!bCapture) {Finish();return true;}
        Progress=NewObject<UAlchemyProgress>(this);
        MigrateProgress(true);
        Progress->TutorialComplete=true;
        Progress->AlchemyMode=0;
        StartRun();ClearEnemies();
        Check(Progress->BrewV02Introduced && Inventory[0]==1 && Inventory[1]==1 && Inventory[2]==1 &&
              BrewOnlyStock[0]==1 && BrewOnlyStock[1]==1 && BrewOnlyStock[2]==1 &&
              !bOpeningSupplyEligible && !bOpeningSupplyGranted,
              TEXT("first_intro_gift_is_once_and_disables_kill_supply_this_run"));
        bMerchantActive=true;bMerchantLeaving=false;MerchantRemaining=35;MerchantPos=PlayerPos;
        RunTime=80;Panel=TEXT("merchant");RunCoins=20;
        const int32 GiftCoins=RunCoins;
        bool GiftSaleBlocked=true;
        for(int32 I=0;I<3;I++) GiftSaleBlocked &= !SellMerchant(I) && !SellMerchant(I,true) && Inventory[I]==1;
        Check(GiftSaleBlocked && RunCoins==GiftCoins && Panel==TEXT("merchant"),
              TEXT("intro_gift_cannot_be_sold_one_or_all"));
        GrantFragment(0,PlayerPos);GrantFragment(0,PlayerPos);GrantFragment(0,PlayerPos);
        Check(Inventory[0]==2 && BrewOnlyStock[0]==1 && MerchantSellableCount(0)==1 &&
              SellMerchant(0) && Inventory[0]==1 && BrewOnlyStock[0]==1 && MerchantSellableCount(0)==0,
              TEXT("natural_extra_is_sellable_while_intro_gift_remains_protected"));
        MerchantStock[0]=0;MerchantSoldOut[0]=false;
        Check(BuyMerchant(0) && Inventory[0]==2 && BrewOnlyStock[0]==1 && MerchantSellableCount(0)==1,
              TEXT("purchased_extra_is_sellable_while_intro_gift_remains_protected"));
        GrantFragment(0,PlayerPos);GrantFragment(0,PlayerPos);GrantFragment(0,PlayerPos);
        const int32 CoinsBeforeAll=RunCoins;
        Check(SellMerchant(0,true) && Panel==TEXT("merchantconfirm") && MerchantSellCount==2 &&
              ConfirmMerchantSale() && Inventory[0]==1 && BrewOnlyStock[0]==1 &&
              MerchantSellableCount(0)==0 && RunCoins==CoinsBeforeAll+4,
              TEXT("sell_all_sells_only_natural_and_purchased_extra"));
        GrantFragment(0,PlayerPos);GrantFragment(0,PlayerPos);GrantFragment(0,PlayerPos);
        Panel.Empty();BrewOperation=0;BrewTarget=-1;BrewMain=0;BrewMainCount=1;
        BrewSupport=-1;BrewSupportCount=0;
        Check(BeginBrew() && Inventory[0]==1 && BrewOnlyStock[0]==0 && MerchantSellableCount(0)==1,
              TEXT("brew_spends_protected_gift_before_sellable_material"));
        UpdateBrew(BrewDuration+.01f);RejectPendingResult();
        Check(Inventory[0]==1 && BrewOnlyStock[0]==0,
              TEXT("rejecting_brew_keeps_gift_spent_without_touching_natural_extra"));
        StartRun();ClearEnemies();
        Check(Inventory[0]==0 && Inventory[1]==0 && Inventory[2]==0 &&
              BrewOnlyStock[0]==0 && BrewOnlyStock[1]==0 && BrewOnlyStock[2]==0 &&
              bOpeningSupplyEligible && OpeningSupplyNormalDeaths==0 && !bOpeningSupplyGranted,
              TEXT("zero_kill_restart_does_not_repeat_intro_gift"));
        const auto AddDeadEnemy=[&](int32 Type) {
            FAlchemyEnemy Enemy;Enemy.Type=Type;Enemy.Definition=Type;Enemy.Pos=PlayerPos+FVector(400,0,0);Enemy.HP=0;
            Enemy.Body=Sprite(TEXT("Enemy0"),Enemy.Pos,100,100);
            Enemy.Shadow=Sprite(TEXT("Enemy0"),Enemy.Pos,100,20);
            Enemies.Add(Enemy);
        };
        FAlchemyEnemy DirectReward;DirectReward.Type=0;DirectReward.Definition=0;DirectReward.Pos=PlayerPos+FVector(400,0,0);
        RewardEnemy(DirectReward);
        Check(OpeningSupplyNormalDeaths==0 && !bOpeningSupplyGranted,
              TEXT("direct_reward_call_does_not_count_as_real_death"));
        AddDeadEnemy(7);ProcessDeadEnemies();
        Check(OpeningSupplyNormalDeaths==0 && !bOpeningSupplyGranted,
              TEXT("elite_death_does_not_count_for_opening_supply"));
        Inventory={4,0,0,0,0,0};FragmentCount[0]=1;FragmentCount[1]=2;FragmentCount[2]=0;
        int32 NoFragmentSeed=1;
        for(;NoFragmentSeed<10000;NoFragmentSeed++) {
            FRandomStream Probe(NoFragmentSeed);bool bNoFragments=true;
            for(int32 I=0;I<9;I++) if(Probe.FRand()<MaterialDropChance()) {bNoFragments=false;break;}
            if(bNoFragments) break;
        }
        Check(NoFragmentSeed<10000,TEXT("opening_supply_fixture_found_no_fragment_seed"));
        MaterialRandom.Initialize(NoFragmentSeed);
        for(int32 I=0;I<7;I++) AddDeadEnemy(0);
        ProcessDeadEnemies();
        Check(OpeningSupplyNormalDeaths==7 && !bOpeningSupplyGranted &&
              Inventory[0]==4 && Inventory[1]==0 && Inventory[2]==0 &&
              FragmentCount[0]==1 && FragmentCount[1]==2 && FragmentCount[2]==0,
              TEXT("seven_actual_normal_deaths_do_not_grant_opening_supply"));
        AddDeadEnemy(0);ProcessDeadEnemies();
        Check(OpeningSupplyNormalDeaths==8 && bOpeningSupplyGranted &&
              Inventory[0]==4 && Inventory[1]==1 && Inventory[2]==1 &&
              BrewOnlyStock[0]==0 && BrewOnlyStock[1]==1 && BrewOnlyStock[2]==1 &&
              FragmentCount[0]==1 && FragmentCount[1]==2 && FragmentCount[2]==0 &&
              Toast.Contains(TEXT("首测补给")),
              TEXT("eighth_actual_normal_death_tops_each_material_to_one_once"));
        bMerchantActive=true;bMerchantLeaving=false;MerchantRemaining=35;MerchantPos=PlayerPos;
        RunTime=80;Panel=TEXT("merchant");
        const int32 SupplyCoins=RunCoins;
        Check(!SellMerchant(1) && !SellMerchant(1,true) && !SellMerchant(2) &&
              MerchantSellableCount(0)==4 && MerchantSellableCount(1)==0 && MerchantSellableCount(2)==0 &&
              RunCoins==SupplyCoins,TEXT("eighth_kill_supply_cannot_be_sold_but_existing_stock_can"));
        Panel.Empty();
        BrewOperation=0;BrewTarget=-1;BrewMain=1;BrewMainCount=1;BrewSupport=2;BrewSupportCount=1;
        Check(BeginBrew() && Inventory[1]==0 && Inventory[2]==0 &&
              BrewOnlyStock[1]==0 && BrewOnlyStock[2]==0,
              TEXT("brew_spends_protected_main_and_support_first"));
        UpdateBrew(BrewDuration+.01f);RejectPendingResult();
        Check(Inventory[1]==0 && Inventory[2]==0 && BrewOnlyStock[1]==0 && BrewOnlyStock[2]==0,
              TEXT("rejecting_brew_does_not_refund_protected_supply"));
        AddDeadEnemy(0);ProcessDeadEnemies();
        Check(OpeningSupplyNormalDeaths==8 && bOpeningSupplyGranted && Inventory[1]==0 && BrewOnlyStock[1]==0,
              TEXT("opening_supply_does_not_repeat_after_material_is_spent"));
        StartRun();ClearEnemies();
        Check(OpeningSupplyNormalDeaths==0 && !bOpeningSupplyGranted && bOpeningSupplyEligible &&
              Inventory[0]==0 && Inventory[1]==0 && Inventory[2]==0 &&
              BrewOnlyStock[0]==0 && BrewOnlyStock[1]==0 && BrewOnlyStock[2]==0,
              TEXT("opening_supply_resets_only_after_new_run_and_gives_no_zero_kill_stock"));
        for(auto& DropItem:Drops) if(IsValid(DropItem.Body)) DropItem.Body->Destroy();
        Drops.Empty();
        Fresh(0);
        BrewOperation=0;BrewTarget=-1;BrewMain=1;BrewMainCount=2;
        BrewSupport=1;BrewSupportCount=2;
        int32 CostPreview[6];BuildBrewCost(CostPreview);
        Check(CostPreview[0]==0 && CostPreview[1]==4 && CostPreview[2]==0 && CostPreview[4]==0,
              TEXT("same_color_main_support_preview_combines_to_one_cost"));
        Inventory[1]=3;
        FString ShortageReason;
        const TArray<int32> ShortageStock=Inventory;
        Check(!CanStartBrew(ShortageReason) && !ShortageReason.IsEmpty() && !BeginBrew() &&
              Inventory==ShortageStock && CraftCount==0,
              TEXT("same_color_combined_shortage_disables_brew_without_cost"));
        Inventory[1]=4;
        Check(CanStartBrew(ShortageReason) && BeginBrew() && Inventory[1]==0 && CraftCount==1,
              TEXT("same_color_brew_deducts_exact_combined_cost_once"));
        UpdateBrew(BrewDuration+.01f);RejectPendingResult();
        Check(Inventory[1]==0,TEXT("same_color_rejected_result_does_not_refund_combined_cost"));
        Fresh(0);
        BrewOperation=0;BrewMain=1;BrewMainCount=2;BrewSupport=2;BrewSupportCount=1;
        BuildBrewCost(CostPreview);
        Check(CostPreview[0]==0 && CostPreview[1]==2 && CostPreview[2]==1 && CostPreview[4]==0,
              TEXT("different_color_preview_has_separate_main_and_support_costs"));
        bBrewConvertTrait=true;Inventory[4]=0;BuildBrewCost(CostPreview);
        const TArray<int32> NoCrystalStock=Inventory;
        Check(CostPreview[4]==1 && !CanStartBrew(ShortageReason) && !BeginBrew() &&
              Inventory==NoCrystalStock && CraftCount==0,
              TEXT("void_crystal_extra_cost_is_previewed_and_blocks_unpaid_brew"));
        Fresh(0);
        Check(bCombat && !TutorialActive() && BrewMode==0,TEXT("fresh_run_uses_selected_mobile_mode"));
        const TArray<int32> StockBeforeStreams=Inventory;
        const int32 FragmentsBeforeStreams[3]={FragmentCount[0],FragmentCount[1],FragmentCount[2]};
        const int32 CraftsBeforeStreams=CraftCount;
        const int32 DropsBeforeStreams=Drops.Num();
        const auto MaterialTrace=[&](int32 Seed,int32 CombatDraws) {
            Inventory={0,0,0,0,0,0};FragmentCount[0]=FragmentCount[1]=FragmentCount[2]=0;
            MaterialRandom.Initialize(Seed);
            FString Trace;
            for(int32 I=0;I<120;I++) {
                for(int32 J=0;J<CombatDraws;J++) Random.FRand();
                TryGrantNormalFragment(PlayerPos);
                Trace+=FString::Printf(TEXT("%d%d%d:%d%d%d|"),Inventory[0],Inventory[1],Inventory[2],FragmentCount[0],FragmentCount[1],FragmentCount[2]);
            }
            return Trace;
        };
        const FString MaterialA=MaterialTrace(20261103,0);
        const FString MaterialReplay=MaterialTrace(20261103,5);
        const FString MaterialOther=MaterialTrace(20261104,0);
        Check(MaterialA==MaterialReplay && Drops.Num()==DropsBeforeStreams,
              TEXT("material_sequence_replays_despite_extra_combat_random_calls"));
        Check(MaterialA!=MaterialOther,TEXT("different_material_seed_changes_fragment_sequence"));
        Inventory=StockBeforeStreams;
        for(int32 I=0;I<3;I++) FragmentCount[I]=FragmentsBeforeStreams[I];
        MaterialRandom.Initialize(20261102 ^ 0x4D41544C);
        Random.Initialize(20261102);
        struct FBrewSample {bool bDone=false;int32 Skill=-1,Trait=-1,Quality=-1;};
        const auto SampleBrew=[&](int32 Seed,int32 CombatDraws) {
            Inventory=StockBeforeStreams;
            BrewRandom.Initialize(Seed);
            for(int32 I=0;I<CombatDraws;I++) Random.FRand();
            FBrewSample Sample;
            Sample.bDone=Resolve(0,-1,0,1,1,1);
            if(Sample.bDone) {
                Sample.Skill=PendingResultSkill;Sample.Trait=PendingTrait;Sample.Quality=PendingQuality;
                RejectPendingResult();
            }
            return Sample;
        };
        const FBrewSample BrewA=SampleBrew(20261103,0);
        const FBrewSample BrewReplay=SampleBrew(20261103,97);
        Check(BrewA.bDone && BrewReplay.bDone && BrewA.Skill==BrewReplay.Skill &&
              BrewA.Trait==BrewReplay.Trait && BrewA.Quality==BrewReplay.Quality,
              TEXT("production_brew_replays_despite_extra_combat_random_calls"));
        BrewRandom.Initialize(20261103);const float BrewFirstRoll=BrewRandom.FRand();
        BrewRandom.Initialize(20261104);const float BrewOtherRoll=BrewRandom.FRand();
        Check(BrewFirstRoll!=BrewOtherRoll,TEXT("different_brew_seed_changes_roll_sequence"));
        Inventory=StockBeforeStreams;CraftCount=CraftsBeforeStreams;
        BrewRandom.Initialize(20261102 ^ 0x42524557);
        Random.Initialize(20261102);
        TArray<int32> BodyOne,BodyThree;TArray<float> WeightOne,WeightThree;
        BuildBrewBodyOptions(0,1,-1,BodyOne,WeightOne);
        BuildBrewBodyOptions(0,3,-1,BodyThree,WeightThree);
        float SumOne=0,SumThree=0;
        for(float Weight:WeightOne) SumOne+=Weight;
        for(float Weight:WeightThree) SumThree+=Weight;
        Check(BodyOne.Num()==5 && BodyOne==BodyThree && WeightOne.Num()==5 && WeightThree.Num()==5 &&
              SumOne>0 && SumThree>0 && WeightThree.Last()/SumThree>WeightOne.Last()/SumOne &&
              WeightThree[0]/SumThree<WeightOne[0]/SumOne,
              TEXT("extra_main_changes_body_odds_without_removing_other_results"));
        const float ExpectedOne[5]={6,5,4,3,2},ExpectedThree[5]={6,7,8,9,10};
        bool ExactBody=WeightOne.Num()==5 && WeightThree.Num()==5;
        if(ExactBody) for(int32 I=0;I<5;I++)
            ExactBody &= FMath::IsNearlyEqual(WeightOne[I],ExpectedOne[I]) && FMath::IsNearlyEqual(WeightThree[I],ExpectedThree[I]);
        Check(ExactBody && FMath::IsNearlyEqual(SumOne,20.f) && FMath::IsNearlyEqual(SumThree,40.f) &&
              FMath::IsNearlyEqual(WeightOne[0]/SumOne,.3f) && FMath::IsNearlyEqual(WeightThree[4]/SumThree,.25f),
              TEXT("body_preview_uses_exact_normalized_prototype_weights"));
        float TraitOne[3],TraitThree[3];
        BuildBrewTraitWeights(1,1,TraitOne);
        BuildBrewTraitWeights(1,3,TraitThree);
        const float TraitSumOne=TraitOne[0]+TraitOne[1]+TraitOne[2];
        const float TraitSumThree=TraitThree[0]+TraitThree[1]+TraitThree[2];
        Check(TraitSumOne>0 && TraitSumThree>0 && TraitThree[1]/TraitSumThree>TraitOne[1]/TraitSumOne &&
              TraitThree[0]>0 && TraitThree[2]>0,
              TEXT("extra_support_improves_chosen_trait_odds_but_preserves_randomness"));
        Check(FMath::IsNearlyEqual(TraitOne[0],20.f) && FMath::IsNearlyEqual(TraitOne[1],60.f) &&
              FMath::IsNearlyEqual(TraitOne[2],20.f) && FMath::IsNearlyEqual(TraitSumOne,100.f) &&
              FMath::IsNearlyEqual(TraitThree[0],20.f) && FMath::IsNearlyEqual(TraitThree[1],90.f) &&
              FMath::IsNearlyEqual(TraitThree[2],20.f) && FMath::IsNearlyEqual(TraitSumThree,130.f) &&
              FMath::IsNearlyEqual(TraitThree[1]/TraitSumThree,9.f/13.f),
              TEXT("trait_preview_uses_exact_normalized_prototype_weights"));
        float FirstRolls[4],RepeatedRolls[4],OtherRolls[4];
        BrewRandom.Initialize(20261103);for(float& Roll:FirstRolls) Roll=BrewRandom.FRand();
        BrewRandom.Initialize(20261103);for(float& Roll:RepeatedRolls) Roll=BrewRandom.FRand();
        BrewRandom.Initialize(20261104);for(float& Roll:OtherRolls) Roll=BrewRandom.FRand();
        bool Repeated=true,Changed=false;
        for(int32 I=0;I<4;I++) {Repeated &= FirstRolls[I]==RepeatedRolls[I];Changed |= FirstRolls[I]!=OtherRolls[I];}
        Check(Repeated && Changed,TEXT("same_seed_replays_rolls_and_different_seed_varies"));
        BrewRandom.Initialize(20261102 ^ 0x42524557); // Preserve the production-brew fixture sequence.
        for(int32 I=0;I<4;I++) Levels[AlchemyBrewPrototype::Pool[0][I]]=1;
        TArray<int32> Filtered;TArray<float> FilteredWeights;
        BuildBrewBodyOptions(0,2,-1,Filtered,FilteredWeights);
        BrewOperation=0;BrewTarget=-1;BrewMain=0;BrewSupport=-1;BrewMainCount=2;BrewSupportCount=0;
        FString OneCandidateReason;
        const TArray<int32> BeforeOneCandidate=Inventory;
        Check(Filtered.Num()==1 && FilteredWeights.Num()==1 &&
              !CanStartBrew(OneCandidateReason) && !OneCandidateReason.IsEmpty() &&
              !BeginBrew() && Inventory==BeforeOneCandidate,
              TEXT("single_remaining_body_rejects_wasted_extra_main_without_cost"));
        for(int32 I=0;I<4;I++) Levels[AlchemyBrewPrototype::Pool[0][I]]=0;
        const int32 DropsBeforeFragments=Drops.Num();
        GrantFragment(0,PlayerPos);GrantFragment(0,PlayerPos);
        Check(Inventory[0]==8 && FragmentCount[0]==2 && Drops.Num()==DropsBeforeFragments,
              TEXT("ordinary_fragments_accumulate_without_floor_pickup"));
        GrantFragment(0,PlayerPos);
        Check(Inventory[0]==9 && FragmentCount[0]==0 && Drops.Num()==DropsBeforeFragments,
              TEXT("third_fragment_converts_to_one_material"));
        Inventory[0]=8;
        BrewOperation=0;BrewTarget=-1;BrewMain=0;BrewSupport=1;
        BrewMainCount=1;BrewSupportCount=1;
        FString Reason;
        Check(CanStartBrew(Reason),TEXT("legal_main_and_support_can_start"));
        const TArray<int32> Before=Inventory;
        if(!BeginBrew()) {Check(false,TEXT("legal_begin_succeeds"));Finish();return true;}
        const TArray<int32> Paid=Inventory;
        const int32 CraftsAfterBegin=CraftCount;
        Check(bBrewActive && Paid[0]==Before[0]-1 && Paid[1]==Before[1]-1 &&
              Paid[2]==Before[2] && CraftsAfterBegin==1,TEXT("begin_deducts_each_ingredient_once"));
        Check(!BeginBrew() && Inventory==Paid && CraftCount==CraftsAfterBegin,
              TEXT("duplicate_begin_does_not_pay_twice"));
        const float MobileDuration=BrewDuration;
        PlayerPos=BrewOrigin+FVector(400,0,0);
        UpdateBrew(.2f);
        Check(bBrewActive && BrewProgress>=.19f,TEXT("mobile_mode_progresses_while_moving"));
        UpdateBrew(MobileDuration);
        Check(!bBrewActive && bV02Pending && PendingResultSkill>=0 &&
              Inventory==Paid,TEXT("completion_stages_one_result_without_extra_cost"));
        const int32 First=PendingResultSkill;
        if(!Levels.IsValidIndex(First) || !PillStates.IsValidIndex(First)) {
            Check(false,TEXT("new_pill_result_has_valid_skill_ID"));Finish();return true;
        }
        const int32 FirstTrait=PendingTrait;
        const int32 FirstQuality=PendingQuality;
        Check(PendingOldSkill<0 && PendingMain==0 && FirstTrait>=0 && FirstTrait<3 &&
              Levels[First]==0 && !Equipped.Contains(First),
              TEXT("new_pill_is_staged_before_equipping"));
        CompleteBrew();
        Check(PendingResultSkill==First && PendingTrait==FirstTrait &&
              PendingQuality==FirstQuality && Inventory==Paid && CraftCount==CraftsAfterBegin,
              TEXT("duplicate_complete_keeps_the_same_paid_result"));
        AcceptPendingResult();
        Check(!bV02Pending && PendingResultSkill<0 && Levels[First]==1 &&
              Equipped.Contains(First) && PillStates[First].Main==0 &&
              PillStates[First].Trait==FirstTrait,TEXT("accepted_new_pill_becomes_a_skill"));

        // Stable same-recipe growth keeps the body and effect before changing either layer.
        if(!Resolve(1,First,0,-1,1,0)) {
            Check(false,TEXT("same_recipe_enhancement_completes"));Finish();return true;
        }
        Check(PendingResultSkill==First && PendingTrait==FirstTrait &&
              Equipped.Contains(First),TEXT("enhancement_keeps_original_pill_active_until_accept"));
        AcceptPendingResult();
        const int32 Growth=Levels[First];
        Check(Growth==2 && PillStates[First].Trait==FirstTrait,
              TEXT("same_recipe_enhancement_increases_growth_without_rerolling_trait"));

        // New main material changes the skill body; existing trait and growth survive.
        const FAlchemyPillState BeforeMain=PillStates[First];
        SkillCD[First]=1.75f;
        if(!Resolve(2,First,1,-1,1,0)) {
            Check(false,TEXT("main_material_reforge_completes"));Finish();return true;
        }
        const int32 Second=PendingResultSkill;
        Check(Second!=First && Levels.IsValidIndex(Second) && PillStates.IsValidIndex(Second) &&
              PendingOldSkill==First && PendingMain==1 &&
              PendingTrait==BeforeMain.Trait && PendingTraitLevel==BeforeMain.TraitLevel &&
              Levels[First]==Growth && Equipped.Contains(First) &&
              PillStates[First].Main==BeforeMain.Main && PillStates[First].Trait==BeforeMain.Trait,
              TEXT("main_reforge_stages_new_body_without_touching_old_pill"));
        if(!Levels.IsValidIndex(Second) || !PillStates.IsValidIndex(Second)) {
            Check(false,TEXT("main_reforge_result_has_valid_skill_ID"));Finish();return true;
        }
        AcceptPendingResult();
        Check(Levels[Second]==Growth && Levels[First]==0 && Equipped.Contains(Second) &&
              !Equipped.Contains(First) && PillStates[Second].Main==1 &&
              PillStates[Second].Trait==BeforeMain.Trait &&
              PillStates[Second].TraitLevel==BeforeMain.TraitLevel &&
              FMath::IsNearlyEqual(SkillCD[Second],1.75f,.001f),
              TEXT("accepted_main_reforge_inherits_growth_trait_and_cooldown"));

        // Auxiliary material may reroll the effect; it must not replace the skill body.
        const FAlchemyPillState BeforeSupport=PillStates[Second];
        const int32 SupportGrowth=Levels[Second];
        if(!Resolve(3,Second,1,2,1,2)) {
            Check(false,TEXT("support_material_reforge_completes"));Finish();return true;
        }
        const int32 NewTrait=PendingTrait;
        Check(PendingResultSkill==Second && PendingOldSkill==Second &&
              PendingMain==BeforeSupport.Main && PendingTraitLevel==1 &&
              NewTrait>=0 && NewTrait<3 && Levels[Second]==SupportGrowth &&
              PillStates[Second].Trait==BeforeSupport.Trait,
              TEXT("support_reforge_stages_effect_only"));
        AcceptPendingResult();
        Check(Levels[Second]==SupportGrowth && PillStates[Second].Main==BeforeSupport.Main &&
              PillStates[Second].Trait==NewTrait && Equipped.Contains(Second),
              TEXT("accepted_support_reforge_keeps_body_and_growth"));

        // Void crystal is a declared conversion material, not a free probability boost.
        bBrewConvertTrait=true;
        BrewOperation=3;BrewTarget=Second;BrewSupport=0;BrewSupportCount=1;
        Inventory[4]=0;
        Reason.Empty();
        const TArray<int32> WithoutCrystal=Inventory;
        const int32 CraftsBeforeCrystal=CraftCount;
        Check(!CanStartBrew(Reason) && !Reason.IsEmpty() && !BeginBrew() &&
              Inventory==WithoutCrystal && CraftCount==CraftsBeforeCrystal && !bBrewActive,
              TEXT("conversion_without_void_crystal_does_not_spend_support"));
        Inventory[4]=1;
        BrewOperation=3;BrewSupport=0;BrewSupportCount=2;
        const TArray<int32> BeforeRedundantSupport=Inventory;
        Check(!BeginBrew() && Inventory==BeforeRedundantSupport && !bBrewActive,
              TEXT("void_conversion_rejects_wasted_extra_support_without_cost"));
        BrewSupportCount=1;
        BrewOperation=1;BrewMain=1;BrewSupport=-1;BrewSupportCount=0;
        const TArray<int32> InvalidConversionStock=Inventory;
        Check(!BeginBrew() && Inventory==InvalidConversionStock && !bBrewActive,
              TEXT("conversion_on_enhancement_is_invalid_and_free"));
        const FAlchemyPillState BeforeConvert=PillStates[Second];
        const int32 ConvertGrowth=Levels[Second];
        const TArray<int32> ConvertStock=Inventory;
        if(!Resolve(3,Second,1,0,1,1)) {
            Check(false,TEXT("void_crystal_support_conversion_completes"));Finish();return true;
        }
        Check(Inventory[0]==ConvertStock[0]-1 && Inventory[4]==ConvertStock[4]-1 &&
              PendingResultSkill==Second && PendingTrait==0 && bPendingTraitConverted &&
              PillStates[Second].Trait==BeforeConvert.Trait,
              TEXT("void_crystal_pays_once_and_deterministically_stages_chosen_trait"));
        AcceptPendingResult();
        Check(PillStates[Second].Main==BeforeConvert.Main && PillStates[Second].Trait==0 &&
              Levels[Second]==ConvertGrowth && !bPendingTraitConverted,
              TEXT("accepted_conversion_changes_only_declared_trait_layer"));
        bBrewConvertTrait=false;

        // Invalid requests must fail before spending material or creating a new furnace.
        Inventory={0,0,0,0,0,0};
        BrewOperation=0;BrewTarget=-1;BrewMain=0;BrewSupport=-1;
        BrewMainCount=1;BrewSupportCount=0;
        Reason.Empty();
        const TArray<int32> EmptyStock=Inventory;
        const int32 CraftsBeforeInvalid=CraftCount;
        Check(!CanStartBrew(Reason) && !Reason.IsEmpty() && !BeginBrew() &&
              Inventory==EmptyStock && CraftCount==CraftsBeforeInvalid &&
              !bBrewActive && !bV02Pending,TEXT("missing_material_rejected_without_cost"));
        Inventory={8,8,8,0,0,0};
        BrewOperation=3;BrewTarget=-1;BrewSupport=0;BrewSupportCount=1;
        const TArray<int32> BeforeInvalidTarget=Inventory;
        Check(!BeginBrew() && Inventory==BeforeInvalidTarget && !bBrewActive,
              TEXT("invalid_target_rejected_without_cost"));

        // Rejected results keep the old pill and the committed material cost.
        const FAlchemyPillState BeforeReject=PillStates[Second];
        const int32 RejectGrowth=Levels[Second];
        if(!Resolve(3,Second,1,0,1,1)) {
            Check(false,TEXT("rejectable_reforge_completes"));Finish();return true;
        }
        const TArray<int32> RejectPaid=Inventory;
        RejectPendingResult();
        Check(!bV02Pending && PendingResultSkill<0 && Inventory==RejectPaid &&
              Levels[Second]==RejectGrowth && Equipped.Contains(Second) &&
              PillStates[Second].Main==BeforeReject.Main &&
              PillStates[Second].Trait==BeforeReject.Trait &&
              PillStates[Second].TraitLevel==BeforeReject.TraitLevel,
              TEXT("reject_keeps_old_pill_but_does_not_refund_ingredients"));
        RejectPendingResult();
        Check(Inventory==RejectPaid && !bV02Pending,TEXT("duplicate_reject_is_inert"));

        // Two selected modes have different timings and movement requirements.
        Fresh(1);
        BrewOperation=0;BrewTarget=-1;BrewMain=0;BrewSupport=2;
        BrewMainCount=1;BrewSupportCount=1;bBrewConvertTrait=true;Inventory[4]=1;
        if(!BeginBrew()) {Check(false,TEXT("stationary_mode_begin_succeeds"));Finish();return true;}
        Check(BrewMode==1 && BrewDuration>0 && BrewDuration<MobileDuration && Inventory[4]==0,
              TEXT("stationary_mode_has_distinct_shorter_duration"));
        const FVector Station=BrewOrigin;
        PlayerPos=Station+FVector(121,0,0);
        UpdateBrew(.4f);
        Check(FMath::IsNearlyZero(BrewProgress) && bBrewActive,
              TEXT("stationary_mode_pauses_when_player_leaves_station"));
        PlayerPos=Station;
        UpdateBrew(.2f);
        Check(BrewProgress>=.19f && bBrewActive,
              TEXT("stationary_mode_resumes_near_station"));
        Panel=TEXT("pause");
        PausedProgress=BrewProgress;
        PauseClock=0;
        Stage=1;
        return false; // Let the production Tick prove that an open system UI freezes brewing.
    }
    if(Stage==1) {
        PauseClock+=Delta;
        if(PauseClock<.3f) return false;
        Check(bBrewActive && !bV02Pending &&
              FMath::IsNearlyEqual(BrewProgress,PausedProgress,.0001f),
              TEXT("system_pause_freezes_brew_progress_across_real_ticks"));
        Panel.Empty();
        Stage=2;
        return false; // The resumed production Tick advances UpdateBrew once.
    }
    if(Stage==2) {
        Check(bBrewActive && BrewProgress>PausedProgress,
              TEXT("closing_system_UI_resumes_brew_progress"));
        UpdateBrew(BrewDuration);
        const int32 ConvertedSkill=PendingResultSkill;
        Check(bV02Pending && Levels.IsValidIndex(ConvertedSkill) &&
              bPendingTraitConverted && PendingTrait==2 && PendingMain==0,
              TEXT("new_pill_void_crystal_conversion_uses_selected_support_trait"));
        if(Levels.IsValidIndex(ConvertedSkill) && PillStates.IsValidIndex(ConvertedSkill)) {
            AcceptPendingResult();
            Check(Levels[ConvertedSkill]==1 && PillStates[ConvertedSkill].Trait==2,
                  TEXT("accepted_new_pill_preserves_deterministic_conversion"));
        }
        Finish();
        return true;
    }
    return true;
}
