// Isolated native-rendered animation preview; scripted poses use production movement/event/visual handlers.
void AAlchemyWorld::MotionPreview(float Dt){
    static bool Ready=false,OK=true,Walk[3]={},Attack[3]={},HurtSeen=false,DeathSeen=false,ResultSeen=false;
    static float Time=-2;static int Section=-1,Frame=0;static FString CSV;
    FString Dir=FPaths::ProjectDir()/TEXT("Evidence/MotionPreview_20261101/Frames");FParse::Value(FCommandLine::Get(),TEXT("MotionPreviewOut="),Dir);
    const float Ends[]={.5f,2.f,3.5f,5.f,6.f,7.f,8.f,8.65f,9.85f};
    if(!Ready){
        if(!bCapture){UE_LOG(LogTemp,Error,TEXT("MOTION_PREVIEW_FAIL not_isolated"));FPlatformMisc::RequestExitWithStatus(false,1);return;}
        Progress=NewObject<UAlchemyProgress>(this);MigrateProgress(true);Progress->TutorialComplete=true;StartRun();
        for(auto& E:Enemies){if(IsValid(E.Body))E.Body->Destroy();if(IsValid(E.Shadow))E.Shadow->Destroy();}Enemies.Empty();
        SpawnCD=NextElite=NextMerchantTime=10000;for(float& CD:SkillCD)CD=10000;ToastTime=0;Panel.Empty();
        IFileManager::Get().MakeDirectory(*Dir,true);CSV=TEXT("frame,time,section,x,y,facing,row,atlas_frame,hp,panel\n");Ready=true;
    }
    if(FScreenshotRequest::IsScreenshotRequested())return;
    if(Time>=Ends[8]){
        for(int I=0;I<3;I++)OK &= Walk[I] && Attack[I];OK &= HurtSeen && DeathSeen && ResultSeen && Frame>=190;
        FFileHelper::SaveStringToFile(CSV,*(Dir/TEXT("frames.csv")),FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM);
        FFileHelper::SaveStringToFile(FString::Printf(TEXT("{\"result\":\"%s\",\"frames\":%d,\"fps\":20,\"walk_three_directions\":%s,\"attack_three_directions\":%s,\"hurt\":%s,\"death_last_frame\":%s,\"settlement\":%s}\n"),OK?TEXT("PASS"):TEXT("FAIL"),Frame,Walk[0]&&Walk[1]&&Walk[2]?TEXT("true"):TEXT("false"),Attack[0]&&Attack[1]&&Attack[2]?TEXT("true"):TEXT("false"),HurtSeen?TEXT("true"):TEXT("false"),DeathSeen?TEXT("true"):TEXT("false"),ResultSeen?TEXT("true"):TEXT("false")),*(Dir/TEXT("result.json")));
        UE_LOG(LogTemp,Display,TEXT("MOTION_PREVIEW_%s frames=%d"),OK?TEXT("PASS"):TEXT("FAIL"),Frame);FPlatformMisc::RequestExitWithStatus(false,OK?0:1);return;
    }
    int Next=0;while(Next<8 && Time>=Ends[Next])Next++;
    const bool Changed=Next!=Section;Section=Next;
    const FVector Right=Camera->GetActorRightVector().GetSafeNormal2D(),Forward=Camera->GetActorForwardVector().GetSafeNormal2D();
    const FVector Before=PlayerPos;
    if(Time>=0 && Section>=1 && Section<=3){LastDirection=Section==1?Right:Section==2?Forward:-Forward;PlayerPos=Move(PlayerPos,LastDirection*500*Dt);}
    UpdateCamera(Dt);UpdateCharacterVisual(Dt,!Before.Equals(PlayerPos));
    // Like production Tick, casts/damage occur after movement has advanced the previous pose.
    if(Time>=0 && Changed){
        if(Section>=4 && Section<=6){const FVector D=Section==4?Right:Section==5?Forward:-Forward;Fire(PlayerPos,PlayerPos+D*800,1,FLinearColor(.7f,.4f,1),false,800,nullptr,nullptr,1,1,.4f,true);}
        if(Section==7 || Section==8){HurtInv=DodgeInv=0;Hurt(Section==7?24:10000);}
    }
    UpdateShots(Dt);UpdateFeedback(Dt);if(Panel.IsEmpty())UpdateTransientEffects(Dt);
    Player->SetActorHiddenInGame(false);PlayerShadow->SetActorLocation(VillageVisualPoint(PlayerPos+FVector(0,0,bBattleReference?-8:5)));
    if(Time>=0){
        OK &= Walkable(PlayerPos,45);RunTime=Time;
        if(CharacterAnimation.Moving && CharacterAnimation.Row==1 && CharacterAnimation.Frame>0)Walk[CharacterAnimation.Facing]=true;
        if(CharacterAnimation.Throwing && CharacterAnimation.Row==2 && CharacterAnimation.Frame>=6)Attack[CharacterAnimation.Facing]=true;
        HurtSeen |= CharacterAnimation.Hurting && CharacterAnimation.Frame>=3;
        DeathSeen |= CharacterAnimation.Dead && CharacterAnimation.Frame==5;ResultSeen |= CharacterAnimation.DeathFinished() && Panel==TEXT("defeat");
        CSV+=FString::Printf(TEXT("%d,%.3f,%d,%.3f,%.3f,%d,%d,%d,%.0f,%s\n"),Frame,Time,Section,PlayerPos.X,PlayerPos.Y,CharacterAnimation.Facing,CharacterAnimation.Row,CharacterAnimation.Frame,HP,*Panel);
        FScreenshotRequest::RequestScreenshot(Dir/FString::Printf(TEXT("frame-%05d.png"),Frame++),true,false);
    }
    Time+=Dt;
}
