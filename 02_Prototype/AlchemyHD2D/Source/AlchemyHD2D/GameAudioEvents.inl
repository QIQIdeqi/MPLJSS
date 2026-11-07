void AAlchemyWorld::PlayCue(FName Cue,float Gain,float Pitch) {
    float CueCooldown=0.f;
    if(Cue==TEXT("EnemyStep")) CueCooldown=.20f;
    else if(Cue==TEXT("EnemyHit") || Cue==TEXT("EnemyDeath")) CueCooldown=.10f;
    else if(Cue==TEXT("EnemyAttack") || Cue==TEXT("EnemyWarn")) CueCooldown=.18f;
    else if(Cue==TEXT("PlayerAttack") || Cue==TEXT("Fragment")) CueCooldown=.09f;
    else if(Cue.ToString().StartsWith(TEXT("Pickup"))) CueCooldown=.08f;
    if(CueCooldown>0.f) {
        const double Now=GetWorld()->GetTimeSeconds();
        if(const double* Last=CueLastTime.Find(Cue);Last && Now-*Last<CueCooldown) return;
        CueLastTime.Add(Cue,Now);
        Pitch*=AudioRandom.FRandRange(.94f,1.06f);
    }
    AlchemyGameAudio::Play(this,Cue,Gain,Pitch);
}

void AAlchemyWorld::PlayEnemyCue(FName Cue,const FAlchemyEnemy& Enemy) {
    const float Distance=FVector::Dist2D(Enemy.Pos,PlayerPos);
    if(Distance>=1700.f) return;
    const float Near=1.f-Distance/1700.f;
    const float Level=Cue==TEXT("EnemyStep")?.31f:.78f;
    const float Pitch=Enemy.Type>=7?.75f:1.16f-.05f*Enemy.Type;
    PlayCue(Cue,Near*Level,Pitch);
}

void AAlchemyWorld::UpdateGameMusic() {
    const FName Track=bRunEnded?NAME_None:FName(!bCombat?TEXT("Music_Village"):
        (GreyfordStage==2 || bBossSpawned)?TEXT("Music_Boss"):TEXT("Music_Field"));
    if(CurrentMusic==Track) return;
    CurrentMusic=Track;
    AlchemyGameAudio::SetMusic(this,Track);
    AlchemyGameAudio::SetAmbience(this,Track==TEXT("Music_Village")?FName(TEXT("Ambient_Village")):NAME_None);
}

void AAlchemyWorld::GameAudioAudit(float Dt) {
    static int32 Phase=0;
    static float Time=0.f;
    Time+=Dt;
    if(Phase==0) {
        FApp::SetUnfocusedVolumeMultiplier(1);
        UAudioMixerBlueprintLibrary::StartRecordingOutput(this,10);
        ++Phase;
    } else if(Phase==1 && Time>1.4f) {
        Progress->TutorialComplete=true;
        StartRun();
        ++Phase;
    } else if(Phase==2 && Time>2.2f) {
        Drop(PlayerPos,-1);
        Drop(PlayerPos,-2);
        Drop(PlayerPos,0);
        Drop(PlayerPos,6);
        SpawnEnemyAt(0,PlayerPos+FVector(220,0,0));
        ++Phase;
    } else if(Phase==3 && Time>3.5f) {
        RunTime=300.f;
        UpdateGreyfordPortal();
        if(GreyfordPortalReady) {
            PlayerPos=GreyfordPortalPos;
            EnterGreyfordBoss();
        }
        ++Phase;
    } else if(Phase==4 && Time>6.6f) {
        EndRun(false);
        ++Phase;
    } else if(Phase==5 && Time>7.8f) {
        const FString Folder=FPaths::ConvertRelativePathToFull(FPaths::ProjectDir()/TEXT("Evidence/GameAudio"));
        IFileManager::Get().MakeDirectory(*Folder,true);
        UAudioMixerBlueprintLibrary::StopRecordingOutput(this,EAudioRecordingExportType::WavFile,TEXT("GameAudioMix"),Folder);
        ++Phase;
    } else if(Phase==6 && Time>8.5f) {
        UE_LOG(LogTemp,Display,TEXT("GAME_AUDIO_AUDIT_DONE"));
        FPlatformMisc::RequestExit(false);
        ++Phase;
    }
}
