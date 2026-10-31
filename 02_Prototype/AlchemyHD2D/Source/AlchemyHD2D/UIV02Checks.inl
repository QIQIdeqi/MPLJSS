// Rendered production-path regression; UIV02Test must enable bCapture before save loading.
void AAlchemyWorld::UIV02Check(float Dt) {
    static bool UIQAOK=true;
    static int UINotePage=0,UICodexPage=0;
    static TSet<int32> UISeenSkills;
    static FBox2D UIPauseRect;
    const FString Dir=FPaths::ProjectDir()/TEXT("Evidence/UIV02_20261031");
    auto* PC=GetWorld()->GetFirstPlayerController();
    auto* HUD=PC?Cast<AAlchemyHUD>(PC->GetHUD()):nullptr;
    if(CaptureStep>0){UpdateCamera(Dt);UpdateCharacterVisual(Dt,false);}
    const auto Check=[&](bool Pass,const TCHAR* Name){UIQAOK &= Pass;UE_LOG(LogTemp,Display,TEXT("UIV02_CHECK %s %s"),Name,Pass?TEXT("PASS"):TEXT("FAIL"));};
    const auto Next=[&](int Step){CaptureStep=Step;SmokeTime=0;};
    const auto Shot=[&](const TCHAR* Name){FScreenshotRequest::RequestScreenshot(Dir/Name,true,false);};
    const auto Finish=[&](){UE_LOG(LogTemp,Display,TEXT("UIV02_%s"),UIQAOK?TEXT("PASS"):TEXT("FAIL"));FPlatformMisc::RequestExitWithStatus(false,UIQAOK?0:1);};
    const auto Onscreen=[&](const FBox2D& R){return R.bIsValid && R.Min.X>=0 && R.Min.Y>=0 && R.Max.X<=1280 && R.Max.Y<=720;};
    const auto HitAt=[&](FVector2D Logical){return HUD->GetHitBoxAtCoordinates({HUD->OX+Logical.X*HUD->S,HUD->OY+Logical.Y*HUD->S},true);};
    if(CaptureStep==0) {
        UIQAOK=true;UINotePage=UICodexPage=0;UISeenSkills.Empty();Check(bCapture,TEXT("isolated_no_player_save_IO"));if(!bCapture){Finish();return;}
        IFileManager::Get().MakeDirectory(*Dir,true);
        Progress=NewObject<UAlchemyProgress>(this);Progress->SchemaVersion=2;Progress->Talents={2,3,4,1};Progress->Coins=1234;
        Progress->RefreshUnlocked=Progress->DropRateUnlocked=true;Progress->TutorialComplete=false;Progress->Recipes={2,4};Progress->Combinations={1};
        TArray<uint8> Bytes;Check(UGameplayStatics::SaveGameToMemory(Progress,Bytes),TEXT("legacy_four_talent_save_serializes"));
        auto* Loaded=Cast<UAlchemyProgress>(UGameplayStatics::LoadGameFromMemory(Bytes));Check(Loaded && Loaded->Talents.Num()==4,TEXT("actual_legacy_save_deserializes_four_talents"));
        if(!Loaded){Finish();return;}Progress=Loaded;MigrateProgress(true);
        Check(Progress->SchemaVersion==3 && Progress->Talents.Num()==10 && Progress->Talents[0]==2 && Progress->Talents[1]==3 && Progress->Talents[2]==4,TEXT("v2_to_v3_preserves_three_purchased_attributes"));
        Check(Progress->Coins==1234 && Progress->Talents[8]==1 && Progress->Talents[9]==1 && !Progress->RefreshUnlocked && !Progress->DropRateUnlocked,TEXT("migration_preserves_coins_and_converts_one_shot_flags"));
        Check(!Progress->TutorialComplete && Progress->Recipes==TArray<int32>({2,4}) && Progress->Combinations==TArray<int32>({1}),TEXT("v2_migration_does_not_complete_tutorial_or_erase_discoveries"));
        const auto Migrated=Progress->Talents;MigrateProgress(false);Check(Progress->Talents==Migrated && Progress->Coins==1234 && !Progress->TutorialComplete,TEXT("schema3_migration_is_idempotent"));
        Bytes.Empty();const bool Saved=UGameplayStatics::SaveGameToMemory(Progress,Bytes);Loaded=Saved?Cast<UAlchemyProgress>(UGameplayStatics::LoadGameFromMemory(Bytes)):nullptr;
        Check(Loaded && Loaded->SchemaVersion==3 && Loaded->Talents==Migrated && Loaded->Coins==1234 && !Loaded->TutorialComplete,TEXT("schema3_memory_save_roundtrip_preserves_migrated_state"));
        Progress=NewObject<UAlchemyProgress>(this);MigrateProgress(true);Progress->Coins=100000;Progress->Talents.Init(0,TalentNodeCount);
        bCombat=false;bRunEnded=false;Action(TEXT("talents"));
#if WITH_EDITOR
        FAssetCompilingManager::Get().FinishAllCompilation();
        if(GShaderCompilingManager)GShaderCompilingManager->FinishAllCompilation();
#endif
        Next(10);return;
    }
    SmokeTime+=Dt;if(SmokeTime<.6f)return;
    Check(HUD!=nullptr,TEXT("native_HUD_available"));if(!HUD){Finish();return;}
    if(CaptureStep==10){if(SmokeTime<2)return;Next(1);return;} // Let completed assets reach the renderer before evidence.
    if(CaptureStep==1) {
        bool Geometry=true,Distinct=true;TArray<FBox2D> Bounds;
        for(int I=0;I<TalentNodeCount;I++){
            const auto* R=HUD->ButtonRects.Find(FString::Printf(TEXT("buy%d"),I));Geometry &= R && Onscreen(*R);
            if(R){for(const auto& B:Bounds)Distinct &= !R->Intersect(B);Bounds.Add(*R);}
        }
        Check(Bounds.Num()==10 && Geometry,TEXT("all_ten_enabled_upgrade_buttons_inside_safe_frame"));Check(Distinct,TEXT("upgrade_purchase_hitboxes_do_not_overlap"));
        Check(Panel==TEXT("talents") && HUD->UIV02DrawnText.Contains(TEXT("永久强化")),TEXT("upgrade_capture_matches_rendered_panel_title_and_ten_buttons"));
        Shot(TEXT("01-ten-upgrades.png"));Next(11);return;
    }
    if(CaptureStep==11) {
        if(FScreenshotRequest::IsScreenshotRequested())return; // Never mutate the UI while the asynchronous capture is pending.
        Check(Panel==TEXT("talents") && HUD->UIV02DrawnText.Contains(TEXT("永久强化")) && HUD->ButtonRects.Contains(TEXT("buy9")),TEXT("upgrade_panel_stays_rendered_until_capture_completes"));
        bool Purchased=true;
        for(int I=0;I<TalentNodeCount;I++){
            const int Before=Progress->Coins;HUD->Activate(FString::Printf(TEXT("buy%d"),I));
            Purchased &= Panel==TEXT("confirmbuy") && PendingTalent==I;HUD->Activate(TEXT("confirmbuy"));
            Purchased &= Progress->Talents[I]==1 && Progress->Coins==Before-TalentCosts[I][0] && Panel==TEXT("talents");
        }
        Check(Purchased,TEXT("Activate_and_confirm_purchase_all_ten_real_nodes"));
        StartRun();for(auto& E:Enemies){if(IsValid(E.Body))E.Body->Destroy();if(IsValid(E.Shadow))E.Shadow->Destroy();}Enemies.Empty();
        Progress->TutorialComplete=true;Progress->Combinations={0,1,2,3,4,5,6};Inventory={10,10,10,0,0,0};Selected={0,0,0,0,0,0};
        SpawnCD=NextElite=NextMerchantTime=10000;Action(TEXT("alchemy"));Next(2);return;
    }
    if(CaptureStep==2) {
        const auto* Fill=HUD->ButtonRects.Find(TEXT("fill0"));Check(Fill && Onscreen(*Fill),TEXT("known_recipe_fill_button_is_drawn_and_in_bounds"));
        bool Distinct=true;if(Fill)for(const TCHAR* Id:{TEXT("craft"),TEXT("clear")})if(const auto* R=HUD->ButtonRects.Find(Id))Distinct &= !Fill->Intersect(*R);
        Check(Distinct,TEXT("first_recipe_fill_hitbox_clear_of_action_buttons"));
        HUD->Activate(TEXT("fill0"));int Total=0;int ActualMask=0;for(int I=0;I<3;I++){Total+=Selected[I];if(Selected[I])ActualMask|=1<<I;}
        Check(Panel==TEXT("alchemy") && Total==3 && ActualMask==RuntimeRecipes[0].Mask,TEXT("alchemy_notes_fill_routes_to_real_action_and_selects_recipe"));
        Shot(TEXT("02-alchemy-notes.png"));Next(6);return;
    }
    if(CaptureStep==6) {
        bool PageOK=true;
        for(int C=UINotePage*3;C<FMath::Min(7,(UINotePage+1)*3);C++){
            const auto* R=HUD->ButtonRects.Find(FString::Printf(TEXT("fill%d"),C));PageOK &= R && Onscreen(*R);
            for(const TCHAR* Id:{TEXT("craft"),TEXT("clear")})if(const auto* ActionRect=HUD->ButtonRects.Find(Id))if(R)PageOK &= !R->Intersect(*ActionRect);
            HUD->Activate(FString::Printf(TEXT("fill%d"),C));int Total=0,Mask=0;for(int I=0;I<3;I++){Total+=Selected[I];if(Selected[I])Mask|=1<<I;}
            PageOK &= Total==3 && Mask==RuntimeRecipes[C].Mask;
        }
        Check(PageOK,TEXT("notes_page_real_fill_actions_visible_nonoverlapping_and_correct"));
        if(++UINotePage<3){HUD->Activate(TEXT("notenext"));Next(6);return;}
        for(int C=0;C<7;C++)for(int Q=0;Q<3;Q++)Progress->Recipes.AddUnique(CombinationSkill(C,Q));
        CodexPage=0;Action(TEXT("codex"));Next(7);return;
    }
    if(CaptureStep==7) {
        for(int C=0;C<7;C++)for(int Q=0;Q<3;Q++){
            const int K=CombinationSkill(C,Q);const FString Name=SkillName(K);
            if(HUD->UIV02DrawnText.ContainsByPredicate([&](const FString& T){return T==Name;}))UISeenSkills.Add(K);
        }
        if(++UICodexPage<4){HUD->Activate(TEXT("detailnext"));Next(7);return;}
        bool HighID=false;for(int K:UISeenSkills)HighID |= K>20;
        Check(UISeenSkills.Num()==21 && HighID,TEXT("all_7x3_actual_normal_skill_IDs_including_high_IDs_reachable_in_codex"));
        Shot(TEXT("04-codex-high-IDs.png"));Next(3);return;
    }
    if(CaptureStep==3) {
        Action(TEXT("clear"));Panel.Empty();Message(TEXT("UIV02 提示可见性验证"));Next(4);return;
    }
    if(CaptureStep==4) {
        Check(HUD->UIV02DrawnText.ContainsByPredicate([](const FString& T){return T.Contains(TEXT("Q")) && T.Contains(TEXT("炼金"));}),TEXT("battle_Q_alchemy_hint_actually_drawn"));
        Check(HUD->UIV02DrawnText.Contains(TEXT("UIV02 提示可见性验证")),TEXT("production_Message_toast_actually_drawn"));
        Shot(TEXT("03-battle-guidance-toast.png"));Next(5);return;
    }
    if(CaptureStep==5) {
        for(const TCHAR* Name:{TEXT("01-ten-upgrades.png"),TEXT("02-alchemy-notes.png"),TEXT("03-battle-guidance-toast.png"),TEXT("04-codex-high-IDs.png")})Check(IFileManager::Get().FileSize(*(Dir/Name))>0,TEXT("native_screenshot_written"));
        Progress->Monsters.Remove(10);RunCoins=37;const int CoinsBeforeVictory=Progress->Coins;
        FAlchemyEnemy BossDiscovery;BossDiscovery.Type=10;BossDiscovery.Definition=10;DiscoverEnemy(BossDiscovery);
        EndRun(true);
        Check(bRunEnded && bWon && Panel==TEXT("victory") && Progress->Monsters.Contains(10),TEXT("actual_victory_settlement_discovers_Boss"));
        Check(Progress->Coins==CoinsBeforeVictory+37 && ResultCoins==37 && RunCoins==0,TEXT("actual_victory_settlement_transfers_coins_once"));
        TArray<uint8> VictoryBytes;const bool VictorySaved=UGameplayStatics::SaveGameToMemory(Progress,VictoryBytes);
        const auto* VictoryLoaded=VictorySaved?Cast<UAlchemyProgress>(UGameplayStatics::LoadGameFromMemory(VictoryBytes)):nullptr;
        Check(VictoryLoaded && VictoryLoaded->Monsters.Contains(10) && VictoryLoaded->Coins==CoinsBeforeVictory+37,TEXT("Boss_discovery_and_settlement_survive_memory_save_roundtrip"));
        const auto DiscoveredMonsters=Progress->Monsters;EndRun(true);
        Check(Progress->Coins==CoinsBeforeVictory+37 && ResultCoins==37 && RunCoins==0 && Progress->Monsters==DiscoveredMonsters,TEXT("repeated_victory_does_not_repeat_coins_or_discovery"));
        StartRun();for(auto& E:Enemies){if(IsValid(E.Body))E.Body->Destroy();if(IsValid(E.Shadow))E.Shadow->Destroy();}Enemies.Empty();
        Progress->TutorialComplete=true;SpawnCD=NextElite=NextMerchantTime=10000;for(float& CD:SkillCD)CD=10000;Panel.Empty();ToastTime=0;
        Next(20);return;
    }
    if(CaptureStep==20){
        const auto* R=HUD->ButtonRects.Find(TEXT("pausebtn"));Check(BattleWidget && R,TEXT("real_widget_battle_exposes_pause_text_hitbox"));
        if(!R){Finish();return;}UIPauseRect=*R;
        int VX=0,VY=0;PC->GetViewportSize(VX,VY);
        Check(HUD->OX+R->Min.X*HUD->S>=0 && HUD->OY+R->Min.Y*HUD->S>=0 && HUD->OX+R->Max.X*HUD->S<=VX && HUD->OY+R->Max.Y*HUD->S<=VY,TEXT("pause_text_hitbox_inside_actual_viewport"));
        const FVector2D Center=R->GetCenter();const auto* Hit=HitAt(Center);
        Check(Hit && Hit->GetName()==FName(TEXT("pausebtn")),TEXT("native_AHUD_hit_query_resolves_pause_text"));
        const float HintX=R->Min.X-HUD->Measure(TEXT("Q 炼金 · B 技能 · "),16);
        const auto* QHit=HitAt({HintX+HUD->Measure(TEXT("Q 炼金"),16)*.5f,Center.Y});
        const auto* BHit=HitAt({HintX+HUD->Measure(TEXT("Q 炼金 · "),16)+HUD->Measure(TEXT("B 技能"),16)*.5f,Center.Y});
        Check((!BHit || BHit->GetName()!=FName(TEXT("pausebtn"))) && (!QHit || QHit->GetName()!=FName(TEXT("pausebtn"))),TEXT("pause_text_hitbox_does_not_capture_adjacent_Q_B_hints"));
        if(Hit)HUD->NotifyHitBoxClick(Hit->GetName());Check(Panel==TEXT("pause"),TEXT("native_hitbox_click_callback_opens_pause_action"));Next(21);return;
    }
    if(CaptureStep==21){
        Check(Panel==TEXT("pause") && HUD->UIV02DrawnText.Contains(TEXT("暂停")) && HUD->ButtonRects.Contains(TEXT("close")),TEXT("pause_menu_title_and_resume_button_actually_drawn"));
        const auto* Header=HUD->ButtonRects.Find(TEXT("modalclose"));const auto* Resume=HUD->ButtonRects.Find(TEXT("close"));
        Check(Header && Resume && !Header->Intersect(*Resume),TEXT("header_return_and_pause_resume_have_distinct_nonoverlapping_hitboxes"));
        Shot(TEXT("05-pause-menu.png"));Next(22);return;
    }
    if(CaptureStep==22){
        if(FScreenshotRequest::IsScreenshotRequested())return;
        const auto* Header=HUD->ButtonRects.Find(TEXT("modalclose"));const auto* HeaderHit=Header?HitAt(Header->GetCenter()):nullptr;
        Check(HeaderHit && HeaderHit->GetName()==FName(TEXT("modalclose")),TEXT("native_AHUD_hit_query_resolves_distinct_header_return"));
        const FName HeaderName=HeaderHit?HeaderHit->GetName():NAME_None;
        const auto* R=HUD->ButtonRects.Find(TEXT("close"));const auto* Hit=R?HitAt(R->GetCenter()):nullptr;
        Check(Hit && Hit->GetName()==FName(TEXT("close")),TEXT("native_AHUD_hit_query_resolves_resume_button"));
        if(Hit)HUD->NotifyHitBoxClick(Hit->GetName());Check(Panel.IsEmpty(),TEXT("native_resume_click_callback_closes_pause"));
        HUD->NotifyHitBoxClick(FName(TEXT("pausebtn")));Check(Panel==TEXT("pause"),TEXT("pause_callback_reopens_after_resume"));
        if(!HeaderName.IsNone())HUD->NotifyHitBoxClick(HeaderName);Check(Panel.IsEmpty(),TEXT("queried_header_return_callback_also_closes_pause"));
        PendingResultSkill=CombinationSkill(6,0);PendingResultCombination=6;PendingResultTotal=3;PendingIsNuclear=false;PendingRefreshed=false;Panel=TEXT("result");Next(23);return;
    }
    if(CaptureStep==23){
        const int Staged=PendingResultSkill;const auto* OldHit=HitAt(UIPauseRect.GetCenter());
        Check(!HUD->ButtonRects.Contains(TEXT("pausebtn")) && (!OldHit || OldHit->GetName()!=FName(TEXT("pausebtn"))),TEXT("pending_result_has_no_stale_pause_hitbox"));
        HUD->NotifyHitBoxClick(FName(TEXT("pausebtn")));Check(Panel==TEXT("result") && PendingResultSkill==Staged,TEXT("stale_pause_callback_cannot_override_pending_result"));
        AcceptPendingResult();Levels.Init(0,NumSkills());Levels[0]=1;Equipped={0};Bag.Empty();Inventory={10,10,10,0,0,0};Selected={1,1,1,0,0,0};Action(TEXT("alchemy"));Next(24);return;
    }
    if(CaptureStep==24){
        Check(QualityWeight(0,0)==70 && QualityWeight(0,1)==20 && QualityWeight(0,2)==10,TEXT("three_material_runtime_weights_remain_unchanged"));
        const FString Drawn=FString::Join(HUD->UIV02DrawnText,TEXT(" "));
        Check(Drawn.Contains(TEXT("70.00%")) && Drawn.Contains(TEXT("20.00%")) && Drawn.Contains(TEXT("10.00%")),TEXT("all_three_quality_percentages_draw_two_decimal_places"));
        Levels[CombinationSkill(6,0)]=5;Next(25);return;
    }
    if(CaptureStep==25){
        const FString Drawn=FString::Join(HUD->UIV02DrawnText,TEXT(" "));
        Check(Drawn.Contains(TEXT("低 0.00%")) && Drawn.Contains(TEXT("中 66.67%")) && Drawn.Contains(TEXT("高 33.33%")),TEXT("actual_filtered_probabilities_draw_zero_and_rounded_two_decimals"));
        Shot(TEXT("06-filtered-probabilities.png"));Next(26);return;
    }
    if(CaptureStep==26){
        if(FScreenshotRequest::IsScreenshotRequested())return;
        for(const TCHAR* Name:{TEXT("05-pause-menu.png"),TEXT("06-filtered-probabilities.png")})Check(IFileManager::Get().FileSize(*(Dir/Name))>0,TEXT("new_native_screenshot_written"));
        Selected={4,3,3,0,0,0};Next(27);return;
    }
    if(CaptureStep==27){
        const TArray<int32> Baseline={4,3,3,0,0,0};const auto BeforeInventory=Inventory;
        bool Geometry=true,Names=true,Returns=true;TArray<FBox2D> Slots;
        for(int Slot=0;Slot<10;Slot++){
            Selected=Baseline;const int M=Slot<4?0:Slot<7?1:2;
            const FString ID=FString::Printf(TEXT("furnace%d_%d"),M,Slot);const auto* R=HUD->ButtonRects.Find(ID);
            Geometry &= R && Onscreen(*R);
            if(!R){Names=false;Returns=false;continue;}
            for(const auto& Other:Slots)Geometry &= !R->Intersect(Other);Slots.Add(*R);
            const auto* Hit=HitAt(R->GetCenter());Names &= Hit && Hit->GetName()==FName(*ID);
            if(Hit)HUD->NotifyHitBoxClick(Hit->GetName());
            for(int I=0;I<Baseline.Num();I++)Returns &= Selected[I]==Baseline[I]-(I==M?1:0);
            Returns &= Inventory==BeforeInventory;
        }
        Selected=Baseline;
        Check(Slots.Num()==10 && Geometry,TEXT("ten_furnace_slots_have_in_bounds_nonoverlapping_rectangles"));
        Check(Names,TEXT("all_ten_native_furnace_hit_queries_resolve_unique_slot_names"));
        Check(Returns,TEXT("each_native_furnace_click_returns_only_its_material_without_changing_inventory"));
        Finish();return;
    }
}
