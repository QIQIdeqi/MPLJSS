// Isolated Research-map regression: real controller keys, automatic cast and projectile collision.
void AAlchemyWorld::CharacterSmoke(float Delta) {
    auto PC=GetWorld()->GetFirstPlayerController();
    auto Key=[PC](FKey K,EInputEvent E){PC->InputKey(FInputKeyEventArgs(nullptr,INPUTDEVICEID_NONE,K,E,E==IE_Pressed?1.f:0.f,false,FPlatformTime::Cycles64()));};
    const FString Folder=FPaths::ProjectDir()/TEXT("Evidence/AlchemistCombatV2");
    if(!FParse::Param(FCommandLine::Get(),TEXT("nullrhi"))) {
        static int LastImage=-1;
        const int Image=FMath::FloorToInt(VisualTime*10);
        if(Image!=LastImage) {
            IFileManager::Get().MakeDirectory(*(Folder/TEXT("frames")),true);
            FScreenshotRequest::RequestScreenshot(Folder/FString::Printf(TEXT("frames/Frame%04d.png"),Image),false,false);
            LastImage=Image;
        }
    }
    for(const auto& S:Shots) if(S.Potion) {
        if(S.ReleaseDelay>0 && S.Body->IsHidden()) {CharacterPending=true;SkillCD[0]=100;}
        if(S.ReleaseDelay<=0 && !S.Body->IsHidden() && CharacterAnimation.Throwing && CharacterAnimation.Frame>=2) CharacterReleased=true;
    }
    if(CaptureStep>=5 && !Enemies.IsEmpty() && Enemies[0].HP<CharacterInitialHP) CharacterHit=true;
    switch(CaptureStep) {
    case 0: if(VisualTime>.4f) {
        Progress->TutorialComplete=true;
        for(auto& E:Enemies) {E.Body->Destroy();E.Shadow->Destroy();} Enemies.Empty();
        for(auto& S:Shots) {if(S.Trail.IsValid()) S.Trail->DestroyComponent();S.Body->Destroy();} Shots.Empty();
        SpawnCD=1000;SkillCD[0]=100;
        Key(EKeys::D,IE_Pressed);CaptureStep++;
    } break;
    case 1: if(VisualTime>1.f) {
        CharacterWalks[0]=CharacterAnimation.Row==1 && CharacterAnimation.Facing==0 && CharacterAnimation.Frame>0;
        Key(EKeys::D,IE_Released);Key(EKeys::W,IE_Pressed);CaptureStep++;
    } break;
    case 2: if(VisualTime>1.6f) {
        CharacterWalks[2]=CharacterAnimation.Row==1 && CharacterAnimation.Facing==2 && CharacterAnimation.Frame>0;
        Key(EKeys::W,IE_Released);Key(EKeys::S,IE_Pressed);CaptureStep++;
    } break;
    case 3: if(VisualTime>2.2f) {
        CharacterWalks[1]=CharacterAnimation.Row==1 && CharacterAnimation.Facing==1 && CharacterAnimation.Frame>0;
        Key(EKeys::S,IE_Released);Key(EKeys::SpaceBar,IE_Pressed);CaptureStep++;
    } break;
    case 4: if(VisualTime>2.7f) {
        CharacterDodge=DodgeCD>0;Key(EKeys::SpaceBar,IE_Released);
        SpawnEnemy(0);auto& E=Enemies.Last();E.Pos=PlayerPos+Camera->GetActorRightVector().GetSafeNormal2D()*400;
        E.HP=E.MaxHP=1000;E.Speed=0;E.AttackCD=1000;E.Contact=0;CharacterInitialHP=E.HP;
        CharacterPending=CharacterReleased=false;SkillCD[0]=0;CaptureStep++;
    } break;
    case 5: if(VisualTime>5.f) {
        const bool OK=CharacterAnimation.Material && CharacterWalks[0] && CharacterWalks[1] && CharacterWalks[2] && CharacterPending && CharacterReleased && CharacterHit && CharacterDodge && !CharacterAnimation.Throwing;
        const FString Proof=FString::Printf(TEXT("{\"result\":\"%s\",\"map\":\"/Game/Maps/Research\",\"side_walk\":%s,\"front_walk\":%s,\"back_walk\":%s,\"delayed_release\":%s,\"release_at_frame3\":%s,\"actual_projectile_damage\":%s,\"space_dodge\":%s,\"throw_return_idle\":%s,\"enemy_hp_before\":%.2f,\"enemy_hp_after\":%.2f}"),
            OK?TEXT("PASS"):TEXT("FAIL"),CharacterWalks[0]?TEXT("true"):TEXT("false"),CharacterWalks[1]?TEXT("true"):TEXT("false"),CharacterWalks[2]?TEXT("true"):TEXT("false"),CharacterPending?TEXT("true"):TEXT("false"),CharacterReleased?TEXT("true"):TEXT("false"),CharacterHit?TEXT("true"):TEXT("false"),CharacterDodge?TEXT("true"):TEXT("false"),!CharacterAnimation.Throwing?TEXT("true"):TEXT("false"),CharacterInitialHP,Enemies.IsEmpty()?0:Enemies[0].HP);
        IFileManager::Get().MakeDirectory(*Folder,true);FFileHelper::SaveStringToFile(Proof,*(Folder/TEXT("runtime-check.json")));
        UE_LOG(LogTemp,Display,TEXT("ALCHEMIST_COMBAT_V2_%s %s"),OK?TEXT("PASS"):TEXT("FAIL"),*Proof);
        if(!OK) {FPlatformMisc::RequestExitWithStatus(false,1);return;} CaptureStep++;
    } break;
    case 6: if(VisualTime>6.f) FPlatformMisc::RequestExit(false);break;
    }
    if(VisualTime>15) FPlatformMisc::RequestExitWithStatus(false,1);
}
