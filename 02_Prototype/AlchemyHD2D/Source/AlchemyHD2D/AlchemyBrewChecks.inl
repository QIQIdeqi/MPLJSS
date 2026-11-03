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
        Random.Initialize(20261102);
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
        Fresh(0);
        Check(bCombat && !TutorialActive() && BrewMode==0,TEXT("fresh_run_uses_selected_mobile_mode"));
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
