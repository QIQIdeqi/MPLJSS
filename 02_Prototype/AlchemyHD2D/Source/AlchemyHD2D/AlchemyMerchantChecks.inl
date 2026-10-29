void AAlchemyWorld::MerchantSmoke(float Dt) {
    if(VisualTime<.5f || CaptureStep) return;CaptureStep=1;bool OK=true;int Checks=0;
    auto Check=[&](bool Pass,const TCHAR* Name){OK&=Pass;Checks++;UE_LOG(LogTemp,Display,TEXT("MERCHANT_CHECK %s %s"),Name,Pass?TEXT("PASS"):TEXT("FAIL"));};
    Progress->TutorialComplete=true;Progress->Coins=123;StartRun();MerchantRandom.Initialize(1177);RunTime=80;NextMerchantTime=80;
    UpdateMerchant(.01f);Check(bMerchantActive && MerchantVisit==1 && MerchantRemaining==35,TEXT("scheduled_first_visit"));
    Check(FVector::Dist2D(PlayerPos,MerchantPos)>=500 && FVector::Dist2D(PlayerPos,MerchantPos)<=900 && Walkable(MerchantPos,60),TEXT("legal_nearby_spawn"));
    Check(IsValid(MerchantAnimationMaterial) && MerchantAnimationMaterial->Parent->GetName().Contains(TEXT("MerchantAnimated")) && IsValid(MerchantShadow),TEXT("dedicated_merchant_art_replaces_prototypes"));
    Check(MerchantArrivalParts.Num()==14 && MerchantArrivalAge==0,TEXT("arrival_starts_once_with_two_rings_twelve_sparks"));
    Check(IsValid(MerchantBuySound) && IsValid(MerchantSellSound) && IsValid(MerchantCoinTexture),TEXT("trade_audio_and_coin_assets_loaded"));
    Check(!MerchantBubble.IsEmpty() && MerchantBubbleUntil>VisualTime,TEXT("spawn_dialogue_bubble_ready"));
    const int Bank=Progress->Coins;RunCoins=0;
    Check(!OpenMerchant() && !BuyMerchant(0),TEXT("out_of_range_transactions_rejected"));
    PlayerPos=MerchantPos+Camera->GetActorRightVector().GetSafeNormal2D()*100;Selected={1,0,0,0,0,0};
    Check(OpenMerchant() && Selected[0]==0,TEXT("open_releases_furnace_selection"));
    const float Left=MerchantRemaining,Clock=RunTime;UpdateMerchant(10);
    Check(MerchantRemaining==Left && RunTime==Clock,TEXT("shop_pauses_event_clock"));
    UpdateMerchantVisual(10);Check(MerchantArrivalAge==0 && MerchantArrivalParts.Num()==14,TEXT("arrival_pauses_with_shop"));
    Panel.Empty();UpdateMerchantVisual(1.5f);Panel=TEXT("merchant");
    Check(MerchantArrivalParts.IsEmpty() && !IsValid(MerchantArrivalFX) && (MerchantBody->GetActorLocation()-MerchantPos).Equals(Camera->GetActorUpVector()*(208.f/448*260),.01f),TEXT("arrival_cleans_up_and_feet_settle_on_baseline"));
    Check(MerchantWaveTime==0 && MerchantAnimationFrame==6,TEXT("arrival_triggers_greeting_once"));
    Panel.Empty();const FVector Standing=MerchantBody->GetActorLocation();auto* AnimationMID=MerchantAnimationMaterial.Get();
    bool WaveFrames=true;for(int I=1;I<6;I++){UpdateMerchantVisual(1.f/6+.0001f);WaveFrames&=MerchantAnimationFrame==6+I && MerchantBody->GetActorLocation().Equals(Standing,.01f);}
    Check(WaveFrames,TEXT("wave_advances_six_frames_without_root_motion"));
    const float WaveClock=MerchantWaveTime;Panel=TEXT("merchant");UpdateMerchantVisual(2);
    Check(MerchantWaveTime==WaveClock && MerchantAnimationFrame==11,TEXT("wave_pauses_in_shop"));
    Panel.Empty();UpdateMerchantVisual(.2f);Check(MerchantWaveTime<0 && MerchantAnimationFrame==0,TEXT("greeting_returns_to_idle"));
    bool IdleFrames=true;for(int I=1;I<=4;I++){UpdateMerchantVisual(.2501f);IdleFrames&=MerchantAnimationFrame==I%4 && MerchantBody->GetActorLocation().Equals(Standing,.01f);}
    Check(IdleFrames && MerchantAnimationMaterial==AnimationMID,TEXT("idle_loops_four_frames_with_cached_material"));
    const int IdleFrame=MerchantAnimationFrame;const float IdleClock=MerchantAnimClock;Panel=TEXT("merchant");UpdateMerchantVisual(3);
    Check(MerchantAnimationFrame==IdleFrame && MerchantAnimClock==IdleClock,TEXT("idle_pauses_in_shop"));
    Panel.Empty();MerchantGreetingCD=0;PlayerPos=MerchantPos+FVector(800,0,0);UpdateMerchantVisual(.1f);
    Check(MerchantWaveTime<0,TEXT("far_player_does_not_trigger_repeated_greeting"));
    PlayerPos=MerchantPos+Camera->GetActorRightVector().GetSafeNormal2D()*100;UpdateMerchantVisual(.1f);
    Check(MerchantWaveTime==0 && MerchantAnimationFrame==6,TEXT("near_player_triggers_greeting_after_cooldown"));
    Panel=TEXT("merchant");
    Check(!BuyMerchant(0) && !RefreshMerchant() && RunCoins==0 && MerchantRerolls==0,TEXT("insufficient_funds_costs_nothing"));
    MerchantStock[0]=0;MerchantStock[1]=MerchantStock[2]=1;for(bool& S:MerchantSoldOut) S=false;
    RunCoins=80;Inventory={0,0,0,0,0,0};Action(TEXT("merchantbuy0"));
    Check(RunCoins==72 && Inventory[0]==1 && MerchantSoldOut[0],TEXT("purchase_deducts_once"));
    const int TradeSerial=MerchantTradeSerial,SoundSerial=MerchantSoundEvents;
    Check(MerchantCoinEffects.Num()>0 && MerchantCoinEffects.Last().Delta==-8 && SoundSerial>0,TEXT("buy_emits_outgoing_coins_and_sound"));
    Action(TEXT("merchantbuy0"));Check(RunCoins==72 && Inventory[0]==1,TEXT("sold_out_blocks_repeat_purchase"));
    Check(MerchantTradeSerial==TradeSerial && MerchantSoundEvents==SoundSerial,TEXT("failed_purchase_has_no_feedback_or_sound"));
    Inventory[1]=10;Check(!BuyMerchant(1) && RunCoins==72,TEXT("capacity_rejects_without_charge"));
    MerchantRerolls=2;Action(TEXT("close"));Check(OpenMerchant() && MerchantRerolls==2 && MerchantSoldOut[0] && MerchantStock[0]==0,TEXT("reopen_preserves_stock_and_fee"));
    RunCoins=1000;MerchantRerolls=0;bool Fees=true;
    for(int I=0;I<6;I++){const int Fee=I<4?5+5*I:25,Before=RunCoins;Fees&=MerchantRefreshPrice()==Fee && RefreshMerchant() && RunCoins==Before-Fee;}
    Check(Fees && RunCoins==900,TEXT("refresh_fees_5_10_15_20_25_25"));
    bool Diversity=true,Duplicates=false,Locked=true,Unlocked=false;
    for(int Phase=0;Phase<2;Phase++) {
        MerchantEliteUnlocked[0]=Phase==1;MerchantEliteUnlocked[1]=MerchantEliteUnlocked[2]=false;
        for(int I=0;I<2000;I++) {
            RollMerchantStock();Diversity&=MerchantStock[0]!=MerchantStock[1] || MerchantStock[1]!=MerchantStock[2];
            Duplicates|=MerchantStock[0]==MerchantStock[1] || MerchantStock[1]==MerchantStock[2] || MerchantStock[0]==MerchantStock[2];
            for(int K:MerchantStock) {Locked&=K>=0 && K<=(Phase?3:2);Unlocked|=K==3;}
        }
    }
    Check(Diversity && Duplicates,TEXT("4000_rolls_at_least_two_kinds_duplicates_allowed"));
    Check(Locked && Unlocked,TEXT("elite_material_pool_unlocks_only_earned_kind"));
    Inventory[0]=4;const int BeforeSell=RunCoins;Action(TEXT("merchantsell0"));
    Check(Inventory[0]==3 && RunCoins==BeforeSell+2,TEXT("sell_one"));
    Check(MerchantCoinEffects.Last().Delta==2 && MerchantCoinEffects.Last().To.Equals(FVector2D(270,196)),TEXT("sale_coins_fly_into_wallet"));
    Action(TEXT("merchantsellall0"));Check(Panel==TEXT("merchantconfirm") && Inventory[0]==3,TEXT("sell_all_requires_confirmation"));
    Action(TEXT("close"));Check(Panel==TEXT("merchant") && Inventory[0]==3 && RunCoins==BeforeSell+2,TEXT("cancel_sale_costs_nothing"));
    Action(TEXT("merchantsellall0"));Action(TEXT("merchantconfirm"));Action(TEXT("merchantconfirm"));
    Check(Inventory[0]==0 && RunCoins==BeforeSell+8,TEXT("confirmed_sale_exactly_once"));
    Check(!SellMerchant(0),TEXT("empty_inventory_rejected"));
    Inventory[0]=3;SellMerchant(0,true);Inventory[0]=2;const int BeforeStale=RunCoins;
    Check(!ConfirmMerchantSale() && Inventory[0]==2 && RunCoins==BeforeStale,TEXT("stale_sale_snapshot_rejected"));
    Inventory[0]=14;MerchantStock[0]=0;MerchantSoldOut[0]=false;
    Check(!BuyMerchant(0) && SellMerchant(0),TEXT("boss_overflow_can_sell_but_cannot_buy_more"));
    CollectDrop(0,1);Check(Inventory[0]==13,TEXT("boss_overflow_not_truncated"));
    Check(Progress->Coins==Bank,TEXT("bank_currency_untouched_during_trade"));
    const int WalletBeforeFX=RunCoins;VisualTime+=2;UpdateMerchantFeedback();
    Check(MerchantCoinEffects.IsEmpty() && RunCoins==WalletBeforeFX,TEXT("ui_effects_expire_without_changing_balance"));
    Panel.Empty();UpdateMerchant(36);const int AfterExpiry=RunCoins;
    Check(bMerchantLeaving && !CanTrade() && !BuyMerchant(0) && RunCoins==AfterExpiry,TEXT("expiry_disables_hidden_actions"));
    Check(MerchantArrivalParts.Num()==14 && MerchantAnimationFrame>=0 && !MerchantBubble.IsEmpty(),TEXT("departure_starts_goodbye_and_portal"));
    UpdateMerchant(.6f);Check(bMerchantActive && bMerchantLeaving && MerchantAnimationFrame>=6,TEXT("departure_plays_goodbye_wave"));
    UpdateMerchant(.7f);Check(MerchantBody->GetActorScale3D().Y<2.6f,TEXT("departure_shrinks_into_portal"));
    UpdateMerchant(.4f);Check(!bMerchantActive && MerchantArrivalParts.IsEmpty() && !IsValid(MerchantAnimationMaterial) && MerchantBubble.IsEmpty(),TEXT("departure_cleans_actor_effects_and_dialogue"));
    RunTime=NextMerchantTime;UpdateMerchant(.01f);Check(bMerchantActive && MerchantVisit==2 && MerchantRerolls==0,TEXT("next_visit_resets_fee"));
    const auto ArrivalActors=MerchantArrivalParts;CloseMerchant();
    Check(MerchantArrivalParts.IsEmpty() && !IsValid(MerchantArrivalFX) && !ArrivalActors.ContainsByPredicate([](const TObjectPtr<AStaticMeshActor>& A){return IsValid(A);}),TEXT("leaving_mid_arrival_cancels_all_parts"));
    MerchantVisit=0;RunTime=80;NextMerchantTime=80;Progress->TutorialComplete=false;UpdateMerchant(.1f);
    Check(!bMerchantActive,TEXT("tutorial_defers_merchant"));Progress->TutorialComplete=true;UpdateMerchant(.1f);
    Check(bMerchantActive,TEXT("merchant_resumes_after_tutorial"));
    RunTime=300;UpdateMerchant(.01f);Check(bMerchantLeaving && !CanTrade() && !SpawnMerchant(),TEXT("boss_warning_ends_trading"));UpdateMerchant(1.7f);
    RunTime=80;MerchantVisit=0;NextMerchantTime=80;UpdateMerchant(.01f);
    Check(bMerchantActive && StartBossEncounter() && !bMerchantActive && !SpawnMerchant(),TEXT("boss_entry_closes_and_blocks_merchant"));
    const int Deposit=RunCoins;EndRun(false);Check(Progress->Coins==Bank+Deposit && RunCoins==0 && !bMerchantActive,TEXT("remaining_wallet_banked_once_at_run_end"));
    const FString Folder=FPaths::ProjectDir()/TEXT("Evidence/Merchant20261029");IFileManager::Get().MakeDirectory(*Folder,true);
    FFileHelper::SaveStringToFile(FString::Printf(TEXT("{\"result\":\"%s\",\"checks\":%d,\"stock_rolls\":4000}\n"),OK?TEXT("PASS"):TEXT("FAIL"),Checks),*(Folder/TEXT("verification.json")));
    UE_LOG(LogTemp,Display,TEXT("ALCHEMY_MERCHANT_%s"),OK?TEXT("PASS"):TEXT("FAIL"));FPlatformMisc::RequestExitWithStatus(false,OK?0:1);
}
void AAlchemyWorld::MerchantCapture(float Dt) {
    const float T=VisualTime-4;
    auto Shot=[&](const TCHAR* Name){
        int X=0,Y=0;GetWorld()->GetFirstPlayerController()->GetViewportSize(X,Y);
        const FString Folder=FPaths::ProjectDir()/FString::Printf(TEXT("Evidence/Merchant20261029/%dx%d"),X,Y);
        IFileManager::Get().MakeDirectory(*Folder,true);FScreenshotRequest::RequestScreenshot(Folder/Name,false,false);
        UE_LOG(LogTemp,Display,TEXT("MERCHANT_FRAME %s time=%.3f ttl=%.3f coins=%d arrival=%.3f parts=%d anim=%d"),Name,RunTime,MerchantRemaining,RunCoins,MerchantArrivalAge,MerchantArrivalParts.Num(),MerchantAnimationFrame);
    };
    if(bMerchantActive && MerchantWaveTime>=0 && MerchantCapturedWaveFrames<6 && MerchantAnimationFrame==6+MerchantCapturedWaveFrames) {
        Shot(*FString::Printf(TEXT("10_Wave%d.png"),MerchantCapturedWaveFrames));MerchantCapturedWaveFrames++;return;
    }
    if(bMerchantActive && MerchantCapturedWaveFrames==6 && MerchantWaveTime<0 && MerchantCapturedIdleFrames<4 && MerchantAnimationFrame==MerchantCapturedIdleFrames) {
        Shot(*FString::Printf(TEXT("11_Idle%d.png"),MerchantCapturedIdleFrames));MerchantCapturedIdleFrames++;return;
    }
    if(CaptureStep==0 && T>.5f) {
        Progress->TutorialComplete=true;StartRun();RunTime=80;NextMerchantTime=80;RunCoins=80;Inventory={3,4,2,1,0,0};
        MerchantCapturedWaveFrames=MerchantCapturedIdleFrames=0;bMerchantCapturedBuyCoins=bMerchantCapturedSellCoins=false;
        if(FParse::Param(FCommandLine::Get(),TEXT("AlchemyRecordMerchantAudio"))) {FApp::SetUnfocusedVolumeMultiplier(1);UAudioMixerBlueprintLibrary::StartRecordingOutput(this,12);}
        for(auto& E:Enemies){E.Body->Destroy();E.Shadow->Destroy();}Enemies.Empty();SpawnCD=10000;
        if(!SpawnMerchant()){FPlatformMisc::RequestExitWithStatus(false,1);return;}
        PlayerPos=MerchantPos+Camera->GetActorRightVector().GetSafeNormal2D()*220;UpdateCamera(0);UpdateCharacterVisual(0,false);
        MerchantStock[0]=0;MerchantStock[1]=1;MerchantStock[2]=2;ToastTime=0;CaptureStep=1;
    } else if(CaptureStep==1 && T>.68f){Shot(TEXT("00_ArrivalStart.png"));CaptureStep=2;}
    else if(CaptureStep==2 && T>1.2f){Shot(TEXT("00_ArrivalGather.png"));CaptureStep=3;}
    else if(CaptureStep==3 && T>2.1f){Shot(TEXT("00_ArrivalSettled.png"));CaptureStep=4;}
    else if(CaptureStep==4 && T>3.1f){OpenMerchant();Shot(TEXT("01_Shop.png"));CaptureStep=5;}
    else if(CaptureStep==5 && T>4){Action(TEXT("merchantbuy0"));Shot(TEXT("02_Purchased.png"));CaptureStep=6;}
    else if(CaptureStep==6 && T>4.35f && !bMerchantCapturedBuyCoins){Shot(TEXT("12_BuyCoins.png"));bMerchantCapturedBuyCoins=true;}
    else if(CaptureStep==6 && T>4.9f){Action(TEXT("merchantrefresh"));Shot(TEXT("03_Refreshed.png"));CaptureStep=7;}
    else if(CaptureStep==7 && T>5.9f){Action(TEXT("merchantsellall0"));Shot(TEXT("04_ConfirmSale.png"));CaptureStep=8;}
    else if(CaptureStep==8 && T>7.1f){Action(TEXT("merchantconfirm"));Shot(TEXT("05_Sold.png"));CaptureStep=9;}
    else if(CaptureStep==9 && T>7.45f && !bMerchantCapturedSellCoins){Shot(TEXT("12_SellCoins.png"));bMerchantCapturedSellCoins=true;}
    else if(CaptureStep==9 && T>8){Action(TEXT("close"));Shot(TEXT("06_MerchantWorld.png"));CaptureStep=10;}
    else if(CaptureStep==10 && T>9.2f){
        if(FParse::Param(FCommandLine::Get(),TEXT("AlchemyRecordMerchantAudio"))) UAudioMixerBlueprintLibrary::StopRecordingOutput(this,EAudioRecordingExportType::WavFile,TEXT("MerchantTradeMix"),FPaths::ConvertRelativePathToFull(FPaths::ProjectDir()/TEXT("Evidence/Merchant20261029")));
        BeginMerchantDeparture();CaptureStep=11;
    }
    else if(CaptureStep==11 && T>9.65f){Shot(TEXT("13_Goodbye.png"));CaptureStep=12;}
    else if(CaptureStep==12 && T>10.5f){Shot(TEXT("14_DeparturePortal.png"));CaptureStep=13;}
    else if(CaptureStep==13 && T>11.05f){Shot(TEXT("15_Left.png"));CaptureStep=14;}
    else if(CaptureStep==14 && T>12){const bool Complete=MerchantCapturedWaveFrames==6 && MerchantCapturedIdleFrames==4 && bMerchantCapturedBuyCoins && bMerchantCapturedSellCoins && !bMerchantActive && MerchantArrivalParts.IsEmpty();UE_LOG(LogTemp,Display,TEXT("ALCHEMY_MERCHANT_CAPTURE_%s"),Complete?TEXT("PASS"):TEXT("FAIL"));FPlatformMisc::RequestExitWithStatus(false,Complete?0:1);CaptureStep=15;}
}
