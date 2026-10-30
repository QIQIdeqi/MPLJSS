// Explicit opt-in, no-save checks call the same combat functions as normal play.
void AAlchemyWorld::PlannedBossCapture() {
    if(Enemies.IsEmpty())return;
    auto& E=Enemies[0];
    const auto Shot=[&](const TCHAR* Name){
        const FString Dir=FPaths::ProjectDir()/TEXT("Evidence/BossPlan/Visual");IFileManager::Get().MakeDirectory(*Dir,true);
        FScreenshotRequest::RequestScreenshot(Dir/Name,false,false);
        UE_LOG(LogTemp,Display,TEXT("PLANNED_BOSS_FRAME %s state=%d time=%.3f waves=%d hp=%.1f"),Name,E.PlannedState,E.PlannedTime,PlannedBossWavesFired,HP);
    };
    if(CaptureStep==0 && GreyfordBossPreparation>0 && GreyfordBossPreparation<1.5f){Shot(TEXT("01-preparation.png"));CaptureStep=1;}
    else if(CaptureStep==1 && E.PlannedState==1 && E.PlannedTime>.35f){Shot(TEXT("02-dash-aiming.png"));CaptureStep=2;}
    else if(CaptureStep==2 && E.PlannedState==1 && E.PlannedTime>.75f){PlayerPos=FVector(550,-500,0);Shot(TEXT("03-dash-locked.png"));CaptureStep=3;}
    else if(CaptureStep==3 && E.PlannedState==4 && E.PlannedTime>PlannedFanWindup-.15f){Shot(TEXT("04-first-fan.png"));CaptureStep=4;}
    else if(CaptureStep==4 && E.PlannedState==5 && E.PlannedTime>.1f){PlayerPos=FVector(-600,0,0);CaptureStep=5;}
    else if(CaptureStep==5 && E.PlannedState==5 && E.PlannedTime>.6f){Shot(TEXT("05-second-wave-lock.png"));CaptureStep=6;}
    else if(CaptureStep==6 && E.PlannedState==3 && E.BossAttack==1 && E.PlannedTime>.05f){Shot(TEXT("06-two-wave-flight.png"));CaptureStep=7;}
    else if(CaptureStep==7){Panel=TEXT("skills");SmokeTime=VisualTime;GreyfordPausedTime=E.PlannedTime;CaptureStep=8;}
    else if(CaptureStep==8 && VisualTime>SmokeTime+.5f){
        if(E.PlannedTime!=GreyfordPausedTime){FPlatformMisc::RequestExitWithStatus(false,1);return;}
        Shot(TEXT("07-paused-config.png"));Panel.Empty();CaptureStep=9;
    } else if(CaptureStep==9 && VisualTime>SmokeTime+1){UE_LOG(LogTemp,Display,TEXT("PLANNED_BOSS_CAPTURE_PASS"));FPlatformMisc::RequestExitWithStatus(false,0);CaptureStep=10;}
}

void AAlchemyWorld::PlannedBossCheck(float Dt) {
    if(VisualTime<1 || CaptureStep)return;CaptureStep=1;
    bool OK=true;
    const auto Check=[&](bool Pass,const TCHAR* Name){OK&=Pass;UE_LOG(LogTemp,Display,TEXT("PLANNED_BOSS_CHECK %s %s"),Name,Pass?TEXT("PASS"):TEXT("FAIL"));};
    const auto ClearShots=[&](){for(auto& S:Shots){if(IsValid(S.Body))S.Body->Destroy();if(S.Trail.IsValid())S.Trail->DestroyComponent();}Shots.Empty();};
    const auto Advance=[&](FAlchemyEnemy& E,float Seconds){for(int I=0;I<FMath::RoundToInt(Seconds/.005f);I++)UpdateBoss(E,.005f);};
    Progress->TutorialComplete=true;StartRun();Panel.Empty();
    Progress->TutorialComplete=false;RunTime=40;
    Drop(FVector(99999,0,0),0);TutorialSupply(PlayerPos);
    Check(Drops.ContainsByPredicate([&](const FAlchemyDrop& D){return D.Kind==0 && D.Pos.Equals(PlayerPos,.1f);}),TEXT("tutorial_floor_ignores_unreachable_material"));
    const int MobsBefore=Enemies.Num();PendingResultSkill=23;PendingResultCombination=6;AcceptPendingResult();
    Check(TutorialEncounterPending,TEXT("first_aoe_accept_queues_melee_encounter"));SpawnTutorialEncounter();
    bool LegalPack=Enemies.Num()==MobsBefore+TutorialEncounterCount;
    for(int I=MobsBefore;I<Enemies.Num();I++)LegalPack&=Enemies[I].Type<2 && Walkable(Enemies[I].Pos,45);
    Check(LegalPack && !TutorialEncounterPending,TEXT("first_aoe_melee_pack_legal_spawn"));
    Progress->TutorialComplete=true;RunTime=0;HP=73;
    SkillCD[0]=2.7f;Inventory={9,0,0,0,0,0};Drop(PlayerPos,0,4);Drop(PlayerPos,1,2);
    const int Coins=RunCoins;
    GreyfordPortalReady=true;GreyfordPortalPos=PlayerPos;
    Check(EnterGreyfordBoss(),TEXT("enters_separate_scene"));
    if(Enemies.IsEmpty()){FPlatformMisc::RequestExitWithStatus(false,1);return;}
    auto& E=Enemies[0];
    Check(HP==73 && SkillCD[0]==2.7f && Inventory[0]==10 && Inventory[1]==2 && RunCoins==Coins,TEXT("hp_cooldowns_capped_existing_materials_inherited"));
    Check(FVector::Dist2D(PlayerPos,E.Pos)==1000 && CombatHalfSize==FVector2D(1600,1300),TEXT("ten_meter_spacing_32x26_bound"));
    UpdateBoss(E,1);Check(E.PlannedState==0,TEXT("preparation_prevents_early_attacks"));GreyfordBossPreparation=0;
    bool Dash=false,Fan=false;
    for(int Seed=0;Seed<40;Seed++){Random.Initialize(Seed);E.BossSequence=0;E.PlannedState=0;UpdateBoss(E,.005f);Dash|=E.BossAttack==0;Fan|=E.BossAttack==1;}
    Check(Dash && Fan,TEXT("first_attack_random_uses_both_two_entry_pool"));
    E.Pos=FVector(-500,0,0);PlayerPos=FVector::ZeroVector;E.PlannedState=1;E.PlannedTime=0;E.PlannedLocked=false;
    const int SoundBefore=PlannedBossLockSounds;
    Advance(E,.6f);const FVector Locked=E.DashDirection;const float Clock=E.PlannedTime;
    Check(E.PlannedLocked && PlannedBossLockSounds==SoundBefore+1,TEXT("dash_locks_at_point_six_with_one_cue"));
    Panel=TEXT("alchemy");UpdateBoss(E,.7f);Check(E.PlannedTime==Clock,TEXT("menu_freezes_boss_clock"));Panel.Empty();
    PlayerPos=FVector(0,300,0);Advance(E,.4f);
    Check(E.PlannedState==2 && E.DashDirection.Equals(Locked) && PlannedBossLockSounds==SoundBefore+1,TEXT("dash_direction_fixed_last_point_four"));
    E.PlannedDistance=0;E.Pos=FVector(-500,0,0);E.DashDirection=FVector(1,0,0);E.BossDashHit=false;
    PlayerPos=FVector::ZeroVector;HP=120;HurtInv=DodgeInv=0;
    for(int I=0;I<120;I++){HurtInv=0;UpdateBoss(E,.005f);}
    Check(FMath::IsNearlyEqual(E.Pos.X,700.f,.1f) && HP==96 && E.BossDashHit && E.PlannedState==3,TEXT("dash_12m_point_six_24_damage_once_continues_after_hit"));
    Advance(E,.99f);Check(E.PlannedState==3,TEXT("one_second_stationary_recovery"));
    E.PlannedState=2;E.PlannedTime=E.PlannedDistance=0;E.Pos=FVector(1300,0,0);PlayerPos=FVector(-500,0,0);E.BossDashHit=false;
    for(int I=0;I<120 && E.PlannedState==2;I++)UpdateBoss(E,.005f);
    Check(E.PlannedState==3 && E.PlannedDistance<1200 && Walkable(E.Pos,EnemyRadius(10)),TEXT("boundary_stops_without_sliding_or_distance_repayment"));
    BossKnockRemaining=.15f;BossKnockDirection=FVector(1,0,0);PlayerPos=FVector::ZeroVector;
    for(int I=0;I<3;I++)PlayerPos=PlannedPlayerMove(FVector(25,0,0),.05f);
    Check(FMath::IsNearlyEqual(PlayerPos.X,100.f,.01f),TEXT("knockback_one_meter_point_fifteen_suppresses_walking"));
    PlayerPos=PlannedPlayerMove(FVector(0,25,0),.05f);
    Check(FMath::IsNearlyEqual(PlayerPos.Y,25.f,.01f),TEXT("latest_input_resumes_without_release"));
    PlayerPos=FVector(1554,0,0);BossKnockRemaining=.15f;
    PlayerPos=PlannedPlayerMove(FVector(-25,0,0),.05f);
    Check(BossKnockRemaining==0 && Walkable(PlayerPos) && PlayerPos.X<1554,TEXT("blocked_knock_ends_early_resumes_current_input"));
    ClearShots();SpentBossWaves.Empty();BossKnockRemaining=0;
    E.Pos=FVector::ZeroVector;PlayerPos=FVector(0,-900,0);E.BossAttack=1;E.PlannedState=4;E.PlannedTime=0;E.PlannedLocked=false;
    Advance(E,PlannedFanWindup);Check(Shots.Num()==5 && E.PlannedState==5,TEXT("first_fan_wave_five_projectiles"));
    PlayerPos=FVector(900,0,0);Advance(E,.5f);const FVector SecondAim=E.DashDirection;
    Check(E.PlannedLocked && SecondAim.Equals(FVector(1,0,0),.01f),TEXT("second_wave_reaim_at_point_five"));
    PlayerPos=FVector(-900,0,0);Advance(E,.3f);
    Check(Shots.Num()==10 && E.PlannedState==3 && E.DashDirection.Equals(SecondAim),TEXT("two_waves_point_eight_interval_final_point_three_locked"));
    bool Pattern=true;
    for(int I=0;I<5;I++)Pattern&=Shots[5+I].Velocity.Equals(SecondAim.RotateAngleAxis(-30.f+15*I,FVector::UpVector)*800,.1f) && Shots[I].Damage==18 && Shots[I].BossWave!=Shots[5+I].BossWave;
    Check(Pattern,TEXT("sixty_degree_equal_fifteen_speed_eight_damage_eighteen_independent_wave_ids"));
    ClearShots();SpentBossWaves.Empty();PlayerPos=FVector::ZeroVector;E.DashDirection=FVector(1,0,0);HP=120;HurtInv=DodgeInv=0;
    FirePlannedBossWave(E,0);UpdateShots(.01f);
    Check(HP==102 && SpentBossWaves.Num()==1 && Shots.Num()==4,TEXT("same_frame_multi_bullet_one_hit_remaining_fade"));
    const int OldWave=PlannedBossWaveSerial;
    const float Fade=Shots[0].FadeRemaining;
    Panel=TEXT("skills");UpdateShots(.1f);Check(Shots[0].FadeRemaining==Fade,TEXT("pause_freezes_fade"));Panel.Empty();
    HurtInv=0;FirePlannedBossWave(E,0);UpdateShots(.01f);
    Check(HP==84 && SpentBossWaves.Contains(OldWave) && SpentBossWaves.Num()==2,TEXT("two_wave_hit_cap_36_old_wave_not_reset"));
    UpdateShots(PlannedWaveFade+.01f);Check(Shots.IsEmpty(),TEXT("capped_wave_fade_recycles_without_extra_hits"));
    SpentBossWaves.Empty();HP=120;HurtInv=1;FirePlannedBossWave(E,0);UpdateShots(.01f);
    Check(HP==120 && Shots.Num()==5 && SpentBossWaves.IsEmpty(),TEXT("invulnerable_contact_keeps_projectile_and_wave_eligibility"));
    HurtInv=0;RunAttrs[4]=5;UpdateShots(.01f);
    Check(HP==106 && SpentBossWaves.Num()==1,TEXT("mitigation_rounds_eighteen_to_fourteen"));
    Check(IsValid(BossLockSound) && Material(TEXT("M_PlannedBossBolt"))!=nullptr,TEXT("lock_audio_and_fade_material_loaded"));
    ClearShots();RunAttrs[4]=0;
    const FString Dir=FPaths::ProjectDir()/TEXT("Evidence/BossPlan");IFileManager::Get().MakeDirectory(*Dir,true);
    FFileHelper::SaveStringToFile(FString::Printf(TEXT("{\"result\":\"%s\",\"method\":\"opt-in production simulation checks; not human balance acceptance\",\"unconfirmed_fade_seconds\":%.3f}\n"),OK?TEXT("PASS"):TEXT("FAIL"),PlannedWaveFade),*(Dir/TEXT("verification.json")));
    UE_LOG(LogTemp,Display,TEXT("PLANNED_BOSS_%s"),OK?TEXT("PASS"):TEXT("FAIL"));FPlatformMisc::RequestExitWithStatus(false,OK?0:1);
}
