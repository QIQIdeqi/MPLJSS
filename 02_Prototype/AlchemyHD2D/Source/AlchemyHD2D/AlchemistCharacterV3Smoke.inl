// Reproduce leftward movement while an enemy and projectile aim remain to the right.
void AAlchemyWorld::CharacterV3Smoke(float Delta) {
    auto PC=GetWorld()->GetFirstPlayerController();
    auto Key=[PC](FKey K,EInputEvent E){PC->InputKey(FInputKeyEventArgs(nullptr,INPUTDEVICEID_NONE,K,E,E==IE_Pressed?1.f:0.f,false,FPlatformTime::Cycles64()));};
    static FVector Start,DeathPosition;
    static bool LeftWalk=false,RightAim=false,LeftMovement=false,StableAnchor=true,BurstVisible=false,HurtVisible=false,HurtReturn=false,DeathStarted=false,DeathHeld=false;
    const FString Folder=FPaths::ProjectDir()/TEXT("Evidence/AlchemistCombatV3");
    if(!FParse::Param(FCommandLine::Get(),TEXT("nullrhi"))) {
        static int LastImage=-1;const int Image=FMath::FloorToInt(VisualTime*10);
        if(Image!=LastImage) {IFileManager::Get().MakeDirectory(*(Folder/TEXT("frames")),true);FScreenshotRequest::RequestScreenshot(Folder/FString::Printf(TEXT("frames/Frame%04d.png"),Image),false,false);LastImage=Image;}
    }
    if(CaptureStep==1) {
        LeftWalk |= CharacterAnimation.Row==1 && CharacterAnimation.Mirror && !CharacterAnimation.Throwing;
        for(const auto& Shot:Shots) if(Shot.Potion && FVector::DotProduct(Shot.Velocity,Camera->GetActorRightVector())>0) {RightAim=true;SkillCD[0]=100;}
        for(const auto& FX:Effects) if(FX.PotionBreak && !FX.Body->IsHidden()) BurstVisible=true;
        const FVector Expected=Camera->GetActorUpVector()*(104.f/256*220);
        StableAnchor &= (Player->GetActorLocation()-PlayerPos).Equals(Expected,.05f);
    }
    switch(CaptureStep) {
    case 0: if(VisualTime>.4f) {
        Progress->TutorialComplete=true;ViewWidth=1400;
        for(auto& E:Enemies) {E.Body->Destroy();E.Shadow->Destroy();}Enemies.Empty();
        for(auto& S:Shots) {if(S.Trail.IsValid()) S.Trail->DestroyComponent();S.Body->Destroy();}Shots.Empty();
        SpawnCD=1000;PotionBreakCount=0;SpawnEnemy(0);auto& E=Enemies.Last();
        E.Pos=PlayerPos+Camera->GetActorRightVector().GetSafeNormal2D()*300;E.HP=E.MaxHP=1000;E.Speed=0;E.Contact=0;E.AttackCD=1000;
        Start=PlayerPos;SkillCD[0]=0;Key(EKeys::A,IE_Pressed);CaptureStep++;
    } break;
    case 1: if(VisualTime>1.5f) {
        LeftMovement=FVector::DotProduct(PlayerPos-Start,Camera->GetActorRightVector())<-100;
        Key(EKeys::A,IE_Released);SkillCD[0]=100;CaptureStep++;
    } break;
    case 2: if(VisualTime>1.8f) {
        LastDirection=-Camera->GetActorForwardVector().GetSafeNormal2D();UpdateCharacterVisual(0,false);
        HurtInv=DodgeInv=0;Hurt(7);HurtVisible=CharacterAnimation.Row==3 && HP==113;CaptureStep++;
    } break;
    case 3: if(VisualTime>2.5f) {HurtReturn=!CharacterAnimation.Hurting && !CharacterAnimation.Dead;CaptureStep++;} break;
    case 4: if(VisualTime>2.8f) {
        HurtInv=DodgeInv=0;Hurt(1000);DeathPosition=PlayerPos;Key(EKeys::D,IE_Pressed);
        DeathStarted=CharacterAnimation.Dead && CharacterAnimation.Row==4 && !CharacterAnimation.DeathFinished() && bRunEnded && HP==0;CaptureStep++;
    } break;
    case 5: if(VisualTime>4.2f) {
        Key(EKeys::D,IE_Released);
        DeathHeld=CharacterAnimation.DeathFinished() && CharacterAnimation.Frame==5 && CharacterAnimation.Row==4 && PlayerPos.Equals(DeathPosition) && Panel==TEXT("defeat");
        const bool BurstClean=!Effects.ContainsByPredicate([](const FAlchemyFX& E){return E.PotionBreak;});
        const bool OK=LeftWalk && RightAim && LeftMovement && StableAnchor && BurstVisible && PotionBreakCount>0 && BurstClean && HurtVisible && HurtReturn && DeathStarted && DeathHeld;
        const FString Proof=FString::Printf(TEXT("{\"result\":\"%s\",\"left_walk_right_aim\":%s,\"moves_left\":%s,\"stable_ground_anchor\":%s,\"potion_break_visible\":%s,\"break_count\":%d,\"break_cleanup\":%s,\"hurt_damage_animation\":%s,\"hurt_return\":%s,\"death_started\":%s,\"death_last_frame_held\":%s,\"no_movement_after_death\":%s}"),OK?TEXT("PASS"):TEXT("FAIL"),LeftWalk&&RightAim?TEXT("true"):TEXT("false"),LeftMovement?TEXT("true"):TEXT("false"),StableAnchor?TEXT("true"):TEXT("false"),BurstVisible?TEXT("true"):TEXT("false"),PotionBreakCount,BurstClean?TEXT("true"):TEXT("false"),HurtVisible?TEXT("true"):TEXT("false"),HurtReturn?TEXT("true"):TEXT("false"),DeathStarted?TEXT("true"):TEXT("false"),DeathHeld?TEXT("true"):TEXT("false"),PlayerPos.Equals(DeathPosition)?TEXT("true"):TEXT("false"));
        IFileManager::Get().MakeDirectory(*Folder,true);FFileHelper::SaveStringToFile(Proof,*(Folder/TEXT("runtime-check.json")));
        UE_LOG(LogTemp,Display,TEXT("ALCHEMIST_COMBAT_V3_%s %s"),OK?TEXT("PASS"):TEXT("FAIL"),*Proof);
        if(!OK) {FPlatformMisc::RequestExitWithStatus(false,1);return;}CaptureStep++;
    } break;
    case 6: if(VisualTime>5.2f) FPlatformMisc::RequestExit(false);break;
    }
    if(VisualTime>12) FPlatformMisc::RequestExitWithStatus(false,1);
}
