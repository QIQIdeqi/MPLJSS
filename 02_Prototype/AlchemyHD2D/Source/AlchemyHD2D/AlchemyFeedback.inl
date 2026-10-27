int32 AAlchemyWorld::FeedbackParticles() const {
    int32 Count=0;
    for(const auto& FX:NiagaraFX) if(IsValid(FX.Component)) {
        auto Controller=FX.Component->GetSystemInstanceController();
        if(Controller.IsValid()) {Controller->WaitForConcurrentTickAndFinalize();if(auto* SI=Controller->GetSystemInstance_Unsafe()) for(auto& E:SI->GetEmitters()) Count+=E->GetNumParticles();}
    }
    return Count;
}
float AAlchemyWorld::FeedbackAge() const {
    float Age=0;
    for(const auto& FX:NiagaraFX) if(IsValid(FX.Component)) {
        auto Controller=FX.Component->GetSystemInstanceController();
        if(Controller.IsValid()) {Controller->WaitForConcurrentTickAndFinalize();if(auto* SI=Controller->GetSystemInstance_Unsafe()) Age+=SI->GetAge();}
    }
    return Age;
}
bool AAlchemyWorld::CaptureFeedback(float Dt) {
    if(VisualTime<2) return true;
    if(CaptureStep==0) {
        StartRun();Progress->TutorialComplete=true;Progress->UITextScale=1.17f;ToastTime=0;SmokeTime=0;CaptureStep=1;
        for(int I=0;I<Enemies.Num();I++) {
            Enemies[I].Pos=FVector((I%4-1.5f)*320,(I/4?1:-1)*220,0);Enemies[I].HP=Enemies[I].MaxHP=200;
        }
        IFileManager::Get().MakeDirectory(*(FPaths::ProjectDir()/TEXT("Evidence/Feedback")),true);
    }
    SmokeTime+=Dt;UpdateFeedback(Dt);UpdateCamera(0);
    for(auto& E:Enemies) {float Scale=E.Type>=7?2:1;E.HitFlash=FMath::Max(0.f,E.HitFlash-Dt);UpdateSprite(E.Body,FString::Printf(TEXT("Enemy%d"),E.Type),E.Pos,100*Scale,100*Scale);E.Shadow->SetActorLocation(E.Pos+FVector(0,0,4));}
    FeedbackPeak=FMath::Max(FeedbackPeak,FeedbackParticles());
    const auto Shot=[&](const TCHAR* Name) {
        FScreenshotRequest::RequestScreenshot(FPaths::ProjectDir()/TEXT("Evidence/Feedback")/Name,false,false);
        UE_LOG(LogTemp,Display,TEXT("FEEDBACK_FRAME %s particles=%d peak=%d components=%d"),Name,FeedbackParticles(),FeedbackPeak,NiagaraFX.Num());
        for(const auto& FX:NiagaraFX) if(IsValid(FX.Component)) {
            TArray<UMaterialInterface*> Used;FX.Component->GetUsedMaterials(Used);for(auto* M:Used) UE_LOG(LogTemp,Display,TEXT("FEEDBACK_MATERIAL %s"),M?*M->GetName():TEXT("null"));
            auto Controller=FX.Component->GetSystemInstanceController();if(Controller.IsValid()) if(auto* SI=Controller->GetSystemInstance_Unsafe()) for(auto& E:SI->GetEmitters()) {
                UE_LOG(LogTemp,Display,TEXT("FEEDBACK_EMITTER system=%s count=%d age=%.3f state=%d"),*FX.Component->GetAsset()->GetName(),E->GetNumParticles(),SI->GetAge(),int(SI->GetActualExecutionState()));
                if(E->GetNumParticles()>0) {
                    auto& Data=E->GetParticleData();auto Colors=FNiagaraDataSetAccessor<FLinearColor>(Data,TEXT("Color")).GetReader(Data);auto Sizes=FNiagaraDataSetAccessor<FVector2f>(Data,TEXT("SpriteSize")).GetReader(Data);
                    UE_LOG(LogTemp,Display,TEXT("FEEDBACK_PARTICLE alpha=%.3f size=(%.2f,%.2f)"),Colors.IsValid()?Colors.Get(0).A:-1,Sizes.IsValid()?Sizes.Get(0).X:-1,Sizes.IsValid()?Sizes.Get(0).Y:-1);
                }
            }
        }
    };
    if(CaptureStep==1 && SmokeTime>.6f) {
        DamageEnemy(0,42,FLinearColor(1,.25f,.04f));Area(Enemies[2].Pos,340,28,FLinearColor(.3f,1,.2f));CaptureStep=2;
    } else if(CaptureStep==2 && SmokeTime>.8f) {Shot(TEXT("01_Impact_Damage_Health.png"));CaptureStep=3;}
    else if(CaptureStep==3 && SmokeTime>1.8f) {
        Area(Enemies[5].Pos,360,36,FLinearColor(.1f,.6f,1));SpawnVFX(TrailFX,PlayerPos+FVector(0,-100,65),FLinearColor(.7f,.25f,1),.7f,1.1f);CaptureStep=4;
    } else if(CaptureStep==4 && SmokeTime>2) {Shot(TEXT("02_Frost_Arcane.png"));CaptureStep=5;}
    else if(CaptureStep==5 && SmokeTime>2.8f) {
        Area(Enemies[1].Pos,300,26,FLinearColor(1,.25f,.04f));CaptureStep=6;
    } else if(CaptureStep==6 && SmokeTime>3) {
        Panel=TEXT("pause");UpdateFeedback(0);FeedbackPauseAge=FeedbackAge();CaptureStep=7;
    } else if(CaptureStep==7 && SmokeTime>3.7f) {
        const bool Paused=FMath::IsNearlyEqual(FeedbackAge(),FeedbackPauseAge,.01f) && !DamageNumbers.IsEmpty();
        UE_LOG(LogTemp,Display,TEXT("FEEDBACK_NIAGARA_PAUSE %s age_before=%.3f after=%.3f"),Paused?TEXT("PASS"):TEXT("FAIL"),FeedbackPauseAge,FeedbackAge());
        if(!Paused) {FPlatformMisc::RequestExitWithStatus(false,1);return false;}
        Shot(TEXT("03_Pause.png"));Panel.Empty();CaptureStep=8;
    } else if(CaptureStep==8 && SmokeTime>7) {
        bool OK=FeedbackPeak>0 && NiagaraFX.IsEmpty() && DamageNumbers.IsEmpty();
        FString Report=FString::Printf(TEXT("real_particle_peak=%d\ncomponents_spawned=%d\nremaining_components=%d\nremaining_numbers=%d\nresult=%s\n"),FeedbackPeak,VFXSpawnCount,NiagaraFX.Num(),DamageNumbers.Num(),OK?TEXT("PASS"):TEXT("FAIL"));
        FFileHelper::SaveStringToFile(Report,*(FPaths::ProjectDir()/TEXT("Evidence/Feedback/result.txt")));
        UE_LOG(LogTemp,Display,TEXT("ALCHEMY_FEEDBACK_CAPTURE_%s particles=%d spawned=%d"),OK?TEXT("PASS"):TEXT("FAIL"),FeedbackPeak,VFXSpawnCount);
        FPlatformMisc::RequestExitWithStatus(false,OK?0:1);CaptureStep=9;
    }
    return true;
}
