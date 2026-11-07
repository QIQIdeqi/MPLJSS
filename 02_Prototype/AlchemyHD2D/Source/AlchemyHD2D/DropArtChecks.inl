void AAlchemyWorld::DropArtCheck(float Dt) {
    static int32 Phase=0;
    static float Wait=0.f;
    static bool OK=true;
    static TWeakObjectPtr<AStaticMeshActor> CoinBody, OrbBody;
    static TWeakObjectPtr<UNiagaraComponent> Motes;
    static FVector CoinStart, OrbStart, PickupPoint, CoinMoved, OrbMoved;
    static double CoinTravel=0.,OrbTravel=0.;
    static bool CapturedBaseline=false;
    static int32 PeakParticles=0;
    const auto Check=[&](bool Good,const TCHAR* Name) {
        OK &= Good;
        UE_LOG(LogTemp,Display,TEXT("DROP_ART_CHECK %s %s"),Name,Good?TEXT("PASS"):TEXT("FAIL"));
    };
#if WITH_EDITOR
    if(GShaderCompilingManager && GShaderCompilingManager->IsCompiling()) {
        GShaderCompilingManager->FinishAllCompilation();
        return;
    }
#endif
    Wait+=Dt;
    if(Phase==0) {
        Progress->TutorialComplete=true;
        StartRun();
        Check(bRandomBattleScene && GreyfordStage==1,TEXT("first_level_started"));
        for(auto& Enemy:Enemies) {Enemy.Body->Destroy();Enemy.Shadow->Destroy();}
        Enemies.Empty();
        ToastTime=0;
        const auto SavedRandom=Random;
        Random.Initialize(0);
        FAlchemyEnemy Enemy;
        Enemy.Pos=PlayerPos+FVector(300,150,0);
        RewardEnemy(Enemy);
        Random=SavedRandom;
        auto* Coin=Drops.FindByPredicate([](const auto& D){return D.Kind==-1;});
        auto* Orb=Drops.FindByPredicate([](const auto& D){return D.Kind==-2;});
        Check(Coin && Orb && !Coin->Pos.Equals(Orb->Pos),TEXT("real_reward_pair_distinct"));
        if(!Coin || !Orb) {FPlatformMisc::RequestExitWithStatus(false,1);return;}
        CoinBody=Coin->Body;
        OrbBody=Orb->Body;
        PickupPoint=Orb->Pos;
        UpdateDropVisuals();
        CoinStart=Coin->Body->GetActorLocation();
        OrbStart=Orb->Body->GetActorLocation();
        Motes=Orb->Motes;
        Check(Coin->Body->GetStaticMeshComponent()->GetMaterial(0)->GetMaterial()->GetName()==TEXT("M_DropCoin")
            && Orb->Body->GetStaticMeshComponent()->GetMaterial(0)->GetMaterial()->GetName()==TEXT("M_DropXP"),TEXT("approved_sprite_materials"));
        Check(Motes.IsValid() && Motes->GetOwner()==OrbBody.Get() && Motes->GetAsset()==XPDropFX
            && Camera->GetCameraComponent()->PostProcessSettings.BloomIntensity>0,TEXT("owned_upward_niagara_and_bloom"));
        Phase=1;
        Wait=0;
        return;
    }
    if(Phase==1) {
        RunTime+=Dt;
        UpdateDropVisuals();
        UpdateCamera(Dt);
        const FString Dir=FPaths::ProjectDir()/TEXT("Evidence/DropArt");
        CoinTravel=FMath::Max(CoinTravel,FMath::Abs(CoinBody->GetActorLocation().Z-CoinStart.Z));
        OrbTravel=FMath::Max(OrbTravel,FMath::Abs(OrbBody->GetActorLocation().Z-OrbStart.Z));
        if(auto* Component=Motes.Get()) {
            const auto Controller=Component->GetSystemInstanceController();
            if(Controller.IsValid()) if(auto* Instance=Controller->GetSystemInstance_Unsafe()) {
                int32 Alive=0;
                for(const auto& Emitter:Instance->GetEmitters()) Alive+=Emitter->GetNumParticles();
                PeakParticles=FMath::Max(PeakParticles,Alive);
            }
        }
        if(Wait<.70f) return;
        IFileManager::Get().MakeDirectory(*Dir,true);
        if(!CapturedBaseline) {
            FScreenshotRequest::RequestScreenshot(Dir/TEXT("first-level-drops-rest.png"),true,false);
            CapturedBaseline=true;
            return;
        }
        if(Wait<1.55f) return;
        FScreenshotRequest::RequestScreenshot(Dir/TEXT("first-level-drops.png"),true,false);
        CoinMoved=CoinBody->GetActorLocation();
        OrbMoved=OrbBody->GetActorLocation();
        const auto* Orb=Drops.FindByPredicate([](const auto& D){return D.Kind==-2;});
        Check(CoinTravel>1 && OrbTravel>1 && Orb && Orb->Pos.Equals(PickupPoint),TEXT("both_bob_without_moving_pickup"));
        Check(PeakParticles>0,TEXT("niagara_emits_live_particles"));
        auto* CoinMaterial=Cast<UMaterialInstanceDynamic>(CoinBody->GetStaticMeshComponent()->GetMaterial(0));
        Check(CoinMaterial && CoinMaterial->K2_GetScalarParameterValue(TEXT("SweepPhase"))>0,TEXT("coin_sweep_phase_advances"));
        Phase=2;
        Wait=0;
        return;
    }
    if(Phase==2) {
        Panel=TEXT("pause");
        UpdateDropVisuals();
        if(Wait<.25f) return;
        Check(CoinBody->GetActorLocation().Equals(CoinMoved) && OrbBody->GetActorLocation().Equals(OrbMoved)
            && Motes.IsValid() && Motes->IsPaused(),TEXT("drop_art_pauses_with_menu"));
        Panel.Empty();
        UpdateDropVisuals();
        Check(Motes.IsValid() && !Motes->IsPaused(),TEXT("drop_particles_resume"));
        EndRun(false);
        Action(TEXT("village"));
        Check(GreyfordStage==0 && Drops.IsEmpty() && !CoinBody.IsValid() && !OrbBody.IsValid()
            && !Motes.IsValid(),TEXT("return_to_village_cleans_drop_effect"));
        UE_LOG(LogTemp,Display,TEXT("DROP_ART_%s"),OK?TEXT("PASS"):TEXT("FAIL"));
        FPlatformMisc::RequestExitWithStatus(false,OK?0:1);
        Phase=3;
    }
}
