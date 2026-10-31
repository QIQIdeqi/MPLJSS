// Isolated -CombatFeedbackTest fixture. A/B exercise production methods; C uses real Tick.
bool AAlchemyWorld::CombatFeedbackCheck(float Dt) {
    static bool OK=true;
    static int AreaID=-1;
    static FVector Origin,Travel;
    static TWeakObjectPtr<AStaticMeshActor> Warning;
    static float BeforeHP=0,PausedWindup=0,PausedLife=0,PausedClock=0;
    const FString Dir=FPaths::ProjectDir()/TEXT("Evidence/CombatFeedback_20261101");
    const auto Check=[&](bool Pass,const TCHAR* Name){OK &= Pass;UE_LOG(LogTemp,Display,TEXT("COMBAT_FEEDBACK_CHECK %s %s"),Name,Pass?TEXT("PASS"):TEXT("FAIL"));};
    const auto Next=[&](int Step){CaptureStep=Step;SmokeTime=0;};
    const auto Finish=[&](){UE_LOG(LogTemp,Display,TEXT("COMBAT_FEEDBACK_%s"),OK?TEXT("PASS"):TEXT("FAIL"));FPlatformMisc::RequestExitWithStatus(false,OK?0:1);};
    const auto ClearShots=[&](){
        for(auto& S:Shots){if(IsValid(S.Body))S.Body->Destroy();if(S.Trail.IsValid())S.Trail->DestroyComponent();}Shots.Empty();
        for(auto& F:NiagaraFX)if(IsValid(F.Component))F.Component->DestroyComponent();NiagaraFX.Empty();
    };
    const auto ClearEnemies=[&](){for(auto& E:Enemies){if(IsValid(E.Body))E.Body->Destroy();if(IsValid(E.Shadow))E.Shadow->Destroy();}Enemies.Empty();};
    const auto ClearEffects=[&](){for(auto& F:Effects)if(IsValid(F.Body))F.Body->Destroy();Effects.Empty();DamageNumbers.Empty();ClearPixelFX();};
    const auto WarningLife=[&](){for(const auto& F:Effects)if(F.Body==Warning.Get())return F.Life;return -1.f;};
    const auto Potion=[&](float Lifetime,float Speed){CharacterAnimation.Reset();Fire(Origin,Origin+Travel*500,7,FLinearColor::White,false,Speed,nullptr,nullptr,Lifetime,1,.7f,true);};
    SmokeTime+=Dt;
    if(CaptureStep==0){
        OK=true;IFileManager::Get().MakeDirectory(*Dir,true);
        Progress=NewObject<UAlchemyProgress>(this);MigrateProgress(true);Progress->TutorialComplete=true;StartRun();
        ClearEnemies();ClearShots();ClearEffects();Equipped.Empty();Bag.Empty();
        SpawnCD=NextElite=NextMerchantTime=10000;HurtInv=DodgeInv=0;for(int32& A:RunAttrs)A=0;HP=MaxHP=1000;Panel.Empty();
        Origin=bBattleReference?BattleReferencePoint({570,350}):PlayerPos;PlayerPos=Origin;UpdateCamera(0);
        Travel=FVector::ZeroVector;
        for(int I=0;I<32;I++){
            const float Angle=I*2*PI/32;const FVector D(FMath::Cos(Angle),FMath::Sin(Angle),0);
            if(SegmentClear(Origin,Origin+D*320,45)){Travel=D;break;}
        }
        Check(!Travel.IsNearlyZero() && Walkable(Origin,45),TEXT("fixture_has_legal_clear_ground_segment"));
        Check(CharacterAnimation.RoseMage && !bSmoke,TEXT("fixture_uses_real_Rose_and_enabled_Niagara"));
        if(Travel.IsNearlyZero()){Finish();return true;}
        // A: exact remaining post-release time, including the zero-flight boundary.
        for(float Step:{1.f/60,1.f/30,.1f})for(float Fraction:{.5f,1.f}){
            ClearShots();Potion(2,1000);auto& S=Shots.Last();S.NewPotion=false;S.ReleaseDelay=Step*Fraction;
            UpdateShots(Step);const float Expected=Step*(1-Fraction);
            const bool Pass=Shots.Num()==1 && FMath::IsNearlyEqual(Shots[0].Age,Expected,.0001f)
                && FMath::IsNearlyEqual(Shots[0].Life,2-Expected,.0001f)
                && FMath::IsNearlyEqual(FVector::Dist2D(Shots[0].Pos,Origin),1000*Expected,.02f);
            const FString Name=FString::Printf(TEXT("release_boundary_dt_%.5f_fraction_%.1f_uses_only_remaining_time"),Step,Fraction);Check(Pass,*Name);
        }
        ClearShots();SpawnEnemyAt(0,Origin+Travel*150);
        Check(Enemies.Num()==1,TEXT("release_collision_fixture_has_real_target_at_150"));
        if(Enemies.Num()==1){
            Enemies[0].HP=Enemies[0].MaxHP=1000;Potion(2,1000);Shots.Last().NewPotion=false;Shots.Last().ReleaseDelay=.05f;UpdateShots(.1f);
            Check(Enemies[0].HP==1000 && Shots.Num()==1 && FMath::IsNearlyEqual(FVector::Dist2D(Shots[0].Pos,Origin),50.f,.02f),TEXT("partial_release_tick_does_not_hit_150_target_early"));
        }
        ClearEnemies();ClearShots();ClearEffects();
        // B: manager/component lifetime, not proof of visible particle pixels.
        Potion(.6f,100);Check(Shots.Num()==1 && Shots[0].Trail.IsValid(),TEXT("Rose_potion_has_actual_Niagara_trail_component"));
        UpdateShots(0); // Production creation tick consumes NewPotion without advancing flight or delay.
        const float Release=CharacterAnimation.ReleaseTime();
        for(float Remaining=Release+.6f-.04f;Remaining>.00001f;){const float Step=FMath::Min(1.f/60,Remaining);UpdateFeedback(Step);UpdateShots(Step);Remaining-=Step;}
        Check(Shots.Num()==1 && IsValid(Shots[0].Body) && Shots[0].Life>0 && Shots[0].Trail.IsValid(),TEXT("Rose_trail_manager_survives_until_last_flight_frames"));
        for(int I=0;I<60 && !Shots.IsEmpty();I++){UpdateFeedback(1.f/60);UpdateShots(1.f/60);}
        Check(Shots.IsEmpty(),TEXT("Rose_potion_eventually_expires_and_removes_body"));ClearShots();ClearEffects();
        const bool WasRose=CharacterAnimation.RoseMage;CharacterAnimation.RoseMage=false;Potion(.6f,100);
        float ManagedLife=-1;for(const auto& F:NiagaraFX)if(F.Component==Shots.Last().Trail.Get())ManagedLife=F.Life;
        Check(FMath::IsNearlyEqual(Shots.Last().ReleaseDelay,.25f) && FMath::IsNearlyEqual(ManagedLife,.95f,.0001f),TEXT("legacy_quarter_second_release_keeps_point_35_trail_allowance"));
        CharacterAnimation.RoseMage=WasRose;ClearShots();ClearEffects();CharacterAnimation.Reset();
        AreaID=-1;for(int I=0;I<RuntimeEnemies.Num();I++){
            const auto& K=RuntimeEnemies[I];
            if(K.Archetype<7 && (K.Behavior==EAlchemyEnemyBehavior::Area || K.Behavior==EAlchemyEnemyBehavior::Hybrid)){AreaID=I;break;}
        }
        Check(AreaID>=0,TEXT("actual_runtime_table_has_normal_Area_or_Hybrid_row"));
        if(AreaID<0){Finish();return true;}
        const auto& K=RuntimeEnemies[AreaID];const float Offset=FMath::Min(75.f,FMath::Min(K.AreaTrigger,K.AreaRadius)*.5f);
        SpawnEnemyAt(AreaID,Origin+Travel*Offset);
        Check(Enemies.Num()==1,TEXT("real_normal_area_attacker_spawned"));if(Enemies.IsEmpty()){Finish();return true;}
        Enemies[0].Speed=0;Enemies[0].Contact=0;Enemies[0].AttackCD=0;Enemies[0].HP=Enemies[0].MaxHP=10000;
        BeforeHP=HP;ToastTime=0;Next(1);return false;
    }
    if(CaptureStep==1){
        if(Enemies.IsEmpty()){Check(false,TEXT("area_attacker_survives_fixture"));Finish();return true;}
        if(Enemies[0].Windup<=0 && SmokeTime<1)return false;
        Warning.Reset();for(const auto& F:Effects)if(FMath::IsNearlyEqual(F.Total,EnemyDefinition(Enemies[0]).AreaWindup) && FMath::IsNearlyEqual(F.Radius,EnemyDefinition(Enemies[0]).AreaRadius))Warning=F.Body;
        Check(Enemies[0].Windup>0 && Warning.IsValid() && FMath::IsNearlyEqual(WarningLife(),Enemies[0].Windup,.0001f),TEXT("birth_frame_warning_life_matches_actual_enemy_windup"));
        Check(HP==BeforeHP,TEXT("area_birth_frame_has_no_early_damage"));Next(2);return false;
    }
    if(CaptureStep==2){
        if(Enemies.IsEmpty()){Check(false,TEXT("area_attacker_exists_before_impact"));Finish();return true;}
        const float Left=Enemies[0].Windup;
        if(Left>Dt+.0001f && SmokeTime<2)return false;
        Check(Left>0 && HP==BeforeHP && Warning.IsValid() && WarningLife()>0 && FMath::IsNearlyEqual(WarningLife(),Left,.0001f),TEXT("last_positive_windup_tick_still_has_matching_warning_and_no_damage"));
        UpdateCamera(0);UpdateCharacterVisual(0,false);Next(3);return true;
    }
    if(CaptureStep==3){
        if(SmokeTime<.6f)return true;
        FScreenshotRequest::RequestScreenshot(Dir/TEXT("01-last-windup-warning.png"),true,false);Next(4);return true;
    }
    if(CaptureStep==4){
        if(SmokeTime<.3f || FScreenshotRequest::IsScreenshotRequested())return true;
        Check(IFileManager::Get().FileSize(*(Dir/TEXT("01-last-windup-warning.png")))>0,TEXT("native_last_positive_windup_frame_written"));
        PausedWindup=Enemies[0].Windup;PausedLife=WarningLife();PausedClock=RunTime;Panel=TEXT("pause");Next(5);return false;
    }
    if(CaptureStep==5){
        if(SmokeTime<.3f)return false;
        Check(Warning.IsValid() && FMath::IsNearlyEqual(WarningLife(),PausedLife) && FMath::IsNearlyEqual(Enemies[0].Windup,PausedWindup)
            && HP==BeforeHP && FMath::IsNearlyEqual(RunTime,PausedClock),TEXT("actual_pause_Tick_freezes_warning_windup_HP_and_battle_clock"));
        Action(TEXT("close"));Check(Panel.IsEmpty(),TEXT("production_close_resumes_combat"));Next(6);return false;
    }
    if(CaptureStep==6){
        if(HP==BeforeHP && SmokeTime<.3f)return false;
        const auto& K=EnemyDefinition(Enemies[0]);const float Expected=FMath::Max(1.f,FMath::RoundToFloat(bTune001B && K.TunedAreaDamage>=0?K.TunedAreaDamage:K.AreaDamage));
        Check(Expected>0 && FMath::IsNearlyEqual(BeforeHP-HP,Expected,.001f) && Enemies[0].Windup<=0 && !Warning.IsValid(),TEXT("resumed_real_Tick_applies_area_damage_then_retires_warning"));
        ClearShots();ClearEnemies();ClearEffects();Finish();return true;
    }
    Check(false,TEXT("bounded_fixture_stage"));Finish();return true;
}
