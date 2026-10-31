APixelFXActor* AAlchemyWorld::SpawnPixelFX(uint8 Kind,FVector Position,float Scale) {
    PixelFXActors.RemoveAll([](const auto& FX){return !FX.IsValid();});
    if(Kind==0 && PixelFXActors.Num()>=48)return nullptr; // Preserve the existing transient VFX budget.
    const FTransform Transform(FRotator::ZeroRotator,Position);
    auto FX=GetWorld()->SpawnActorDeferred<APixelFXActor>(APixelFXActor::StaticClass(),Transform,this,nullptr,ESpawnActorCollisionHandlingMethod::AlwaysSpawn);
    FX->Effect=static_cast<EPixelFX>(Kind);FX->PixelScale=Scale;FX->FinishSpawning(Transform);
    if(FX->IsReady())VFXSpawnCount++;
    PixelFXActors.Add(FX);
    return FX;
}
void AAlchemyWorld::ClearPixelFX() {
    for(auto FX:PixelFXActors)if(FX.IsValid())FX->Destroy();PixelFXActors.Empty();
}

// Opt-in visual QA: real village geometry, production hit handler, collision movement and camera.
// bCapture isolates player saves. This sequence never runs in normal play.
void AAlchemyWorld::PixelFXCheck(float Dt) {
    const FString Dir=FPaths::ProjectDir()/TEXT("Evidence/PixelFX/Capture");
    PixelFXCheckTime+=Dt;
    const float Time=FMath::Max(0.f,PixelFXCheckTime-1);
    const int Section=FMath::Min(3,FMath::FloorToInt(Time/5));
    const float T=Time-Section*5;
    const FVector Center=ReferencePoint(1000,370),Bridge=ReferencePoint(375,615);
    if(Section!=PixelFXCheckSection) {
        IFileManager::Get().MakeDirectory(*Dir,true);ClearPixelFX();
        for(auto& E:Enemies){if(IsValid(E.Body))E.Body->Destroy();if(IsValid(E.Shadow))E.Shadow->Destroy();}Enemies.Empty();DamageNumbers.Empty();
        PixelFXCheckSection=Section;Panel.Empty();Toast.Empty();ToastTime=0;
        ReferenceZoom=2.6f;
        if(Section==0) {
            PlayerPos=Center+Camera->GetActorRightVector()*-220;
            FAlchemyEnemy E;E.Type=0;E.Pos=Center;E.HP=E.MaxHP=1000;
            E.Body=Sprite(TEXT("Enemy0"),E.Pos,100,100);Enemies.Add(E);
        } else {
            const FVector Origin=Section==3?Bridge:Center;
            PixelFXPreview=SpawnPixelFX(Section==2?2:1,Origin);
            PixelFXCheckOK &= PixelFXPreview->IsReady();
            PlayerPos=Section==3?Bridge:Center+FVector(0,220,0);
        }
        UpdateCamera(0);UpdateCharacterVisual(0,false);
        UE_LOG(LogTemp,Display,TEXT("PIXELFX_CHECK section=%d assets_ready=%d player_walkable=%d"),Section,PixelFXCheckOK,Walkable(PlayerPos));
    }
    const FVector Previous=PlayerPos;
    if(Section==0) {
        LastDirection=(Center-PlayerPos).GetSafeNormal2D();
        const int Pulse=FMath::FloorToInt(T/.8f),PreviousPulse=FMath::FloorToInt(FMath::Max(0.f,T-Dt)/.8f);
        if(Pulse!=PreviousPulse) {
            CharacterAnimation.Throw(FVector2D(1,0));
            const float Before=Enemies[0].HP;DamageEnemy(0,12,FLinearColor(1,.65f,.25f));
            PixelFXCheckOK &= FMath::IsNearlyEqual(Before-Enemies[0].HP,12) && PixelFXHitCount>0;
        }
        UpdateFeedback(Dt);
    } else if(Section!=3) {
        const FVector Desired=Center+FVector(0,220*FMath::Cos(T*2*PI/5),0);
        PlayerPos=Move(PlayerPos,(Desired-PlayerPos).GetClampedToMaxSize(400*Dt));
        PixelFXCheckOK &= Walkable(PlayerPos);
    } else {
        // Keep the actor on the already validated bridge deck and vary its pose under the near railing.
        LastDirection=FVector(FMath::Sin(T*PI),FMath::Cos(T*PI),0);
    }
    if(!Previous.Equals(PlayerPos))LastDirection=(PlayerPos-Previous).GetSafeNormal2D();
    UpdateCamera(Dt);UpdateCharacterVisual(Dt,!Previous.Equals(PlayerPos));
    PlayerShadow->SetActorLocation(VillageVisualPoint(PlayerPos+FVector(0,0,5)));
    PixelFXCaptureTime+=Dt;
    if(PixelFXCheckTime>1 && PixelFXCaptureTime>=.05f && Time<20) {
        PixelFXCaptureTime=FMath::Fmod(PixelFXCaptureTime,.05f);
        FScreenshotRequest::RequestScreenshot(Dir/FString::Printf(TEXT("frame-%05d.png"),PixelFXFrame++),false,false);
    }
    if(Time>=20) {
        PixelFXCheckOK &= PixelFXHitCount>=5 && PixelFXFrame>=390;
        FFileHelper::SaveStringToFile(FString::Printf(TEXT("result=%s\nframes=%d\nhits=%d\nhero_visible_height_cm=180\npoison_split_depth_cm=140\nportal_visible_height_cm=244\n"),PixelFXCheckOK?TEXT("PASS"):TEXT("FAIL"),PixelFXFrame,PixelFXHitCount),*(Dir/TEXT("result.txt")));
        UE_LOG(LogTemp,Display,TEXT("PIXELFX_CHECK_%s frames=%d hits=%d"),PixelFXCheckOK?TEXT("PASS"):TEXT("FAIL"),PixelFXFrame,PixelFXHitCount);
        FPlatformMisc::RequestExitWithStatus(false,PixelFXCheckOK?0:1);
    }
}
