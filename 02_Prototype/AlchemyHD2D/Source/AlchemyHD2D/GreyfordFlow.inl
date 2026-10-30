// A persistent world streams the three authored scenes; run state never crosses a reset boundary.
bool AAlchemyWorld::SwitchGreyfordStage(int32 Stage) {
    const TCHAR* Names[]={TEXT("Village_Reference"),TEXT("Outskirts_Blockout"),TEXT("Greyford_Boss")};
    ULevelStreaming* Wanted=nullptr;
    for(auto* Level:GetWorld()->GetStreamingLevels()) {
        const bool Visible=Level->GetWorldAssetPackageName().EndsWith(Names[Stage]);
        Level->SetShouldBeLoaded(true);Level->SetShouldBeVisible(Visible);
        if(Visible)Wanted=Level;
    }
    GetWorld()->FlushLevelStreaming(EFlushLevelStreamingType::Full);
    if(!Wanted || !Wanted->GetLoadedLevel()){UE_LOG(LogTemp,Error,TEXT("GREYFORD_FLOW missing scene %s"),Names[Stage]);return false;}
    GreyfordActiveLevel=Wanted->GetLoadedLevel();GreyfordStage=Stage;
    if(auto AA=IConsoleManager::Get().FindConsoleVariable(TEXT("r.AntiAliasingMethod"))){
        if(Stage==0 && ReferencePreviousAA<0){ReferencePreviousAA=AA->GetInt();AA->Set(0,ECVF_SetByCode);}
        else if(Stage!=0 && ReferencePreviousAA>=0){AA->Set(ReferencePreviousAA,ECVF_SetByCode);ReferencePreviousAA=-1;}
    }
    bGreyfordReference=Stage==0;ReferenceCameraReady=false;ReferenceRegions.Empty();ReferenceNodes.Empty();
    if(bGreyfordReference){
        for(TActorIterator<AGreyfordReferenceRegion> It(GetWorld());It;++It)if(It->GetLevel()==GreyfordActiveLevel)ReferenceRegions.Add(*It);
        for(TActorIterator<ATargetPoint> It(GetWorld());It;++It)if(It->GetLevel()==GreyfordActiveLevel && It->ActorHasTag(TEXT("ReferencePathNode")))ReferenceNodes.Add(It->GetActorLocation());
        BuildReferenceBoundary();
    }
    ViewWidth=Stage==0?2400:2844;
    Designer=nullptr;
    if(Stage==0)for(TActorIterator<ATargetPoint> It(GetWorld());It;++It)if(It->GetLevel()==GreyfordActiveLevel)
        for(int I=0;I<3;I++)if(It->ActorHasTag(FName(*FString::Printf(TEXT("GreyfordVillageFacility_%d"),I))))GreyfordFacilities[I]=It->GetActorLocation();
    CombatHalfSize=Stage==2?FVector2D(1600,1300):FVector2D(7200,5400);
    Obstacles.Empty();
    for(TActorIterator<AAlchemyLevelDesigner> It(GetWorld());It;++It)if(It->GetLevel()==GreyfordActiveLevel){Designer=*It;Designer->SetRuntimeVisible(true);break;}
    if(Stage!=2)for(TActorIterator<AStaticMeshActor> It(GetWorld());It;++It) {
        if(It->GetLevel()!=GreyfordActiveLevel || !It->ActorHasTag(TEXT("GreyfordBlocker")))continue;
        FVector C,E;It->GetActorBounds(true,C,E);Obstacles.Add({FVector2D(C),FVector2D(E)});
    }
#if WITH_EDITOR
    if(Stage==2)Material(TEXT("M_BossCorruption"));
    FAssetCompilingManager::Get().FinishAllCompilation();
    if(GShaderCompilingManager)GShaderCompilingManager->FinishAllCompilation();
#endif
    UE_LOG(LogTemp,Display,TEXT("GREYFORD_FLOW_STAGE %d scene=%s obstacles=%d"),Stage,Names[Stage],Obstacles.Num());return true;
}

FVector AAlchemyWorld::FacilityPosition(int32 Index) const {
    return bGreyfordFlow?GreyfordFacilities[Index]:Index==0?FVector(-600,100,0):Index==1?FVector(600,100,0):FVector(0,1050,0);
}

float AAlchemyWorld::GreyfordSurfaceHeight(FVector P) const {
    if(bGreyfordReference)return 0; // Image-space bridge surface already includes its drawn elevation.
    if(GreyfordStage!=0)return 0;
    for(TActorIterator<AStaticMeshActor> It(GetWorld());It;++It) {
        if(It->GetLevel()!=GreyfordActiveLevel || !It->ActorHasTag(TEXT("GreyfordBridgeDeck")))continue;
        FVector C,E;It->GetActorBounds(false,C,E);
        if(FMath::Abs(P.X-C.X)<=E.X && FMath::Abs(P.Y-C.Y)<=E.Y)return C.Z*FMath::Clamp((E.Y-FMath::Abs(P.Y-C.Y))/150,0.,1.);
    }
    return 0;
}

void AAlchemyWorld::BuildReferenceBoundary(){
    ReferenceBoundary.Empty();TArray<TPair<FVector,FVector>> WalkEdges;
    const auto InWalk=[&](FVector P){for(auto R:ReferenceRegions)if(!R->bBlocked && R->Contains(P))return true;return false;};
    for(auto R:ReferenceRegions){const auto Points=R->GetWorldVertices();for(int I=0;I<Points.Num();I++){
        const FVector A=Points[I],B=Points[(I+1)%Points.Num()];
        if(R->bBlocked)ReferenceBoundary.Emplace(A,B);else WalkEdges.Emplace(A,B);
    }
    }
    const auto Cross=[](FVector A,FVector B){return A.X*B.Y-A.Y*B.X;};
    // Split overlaps first: seams between adjoining walk polygons are not walls.
    for(const auto& Edge:WalkEdges){
        const FVector A=Edge.Key,D=Edge.Value-A;const double DD=D.SizeSquared();if(DD<.001)continue;
        TArray<double> Cuts={0,1};
        for(const auto& Other:WalkEdges){
            const FVector Q=Other.Key-A,E=Other.Value-Other.Key;const double Den=Cross(D,E);
            if(FMath::Abs(Den)>.0001){const double T=Cross(Q,E)/Den,U=Cross(Q,D)/Den;if(T>0 && T<1 && U>=0 && U<=1)Cuts.Add(T);}
            else if(FMath::Abs(Cross(Q,D))<.001){Cuts.Add(FMath::Clamp(FVector::DotProduct(Q,D)/DD,0.,1.));Cuts.Add(FMath::Clamp(FVector::DotProduct(Other.Value-A,D)/DD,0.,1.));}
        }
        Cuts.Sort();const FVector N=FVector(-D.Y,D.X,0).GetSafeNormal()*.1;
        for(int I=1;I<Cuts.Num();I++)if(Cuts[I]-Cuts[I-1]>.000001){
            const FVector M=A+D*((Cuts[I]+Cuts[I-1])/2);
            if(InWalk(M+N)!=InWalk(M-N))ReferenceBoundary.Emplace(A+D*Cuts[I-1],A+D*Cuts[I]);
        }
    }
}

bool AAlchemyWorld::ReferenceWalkable(FVector P,float Radius) const {
    bool Inside=false;
    for(auto R:ReferenceRegions)if(R->Contains(P)){if(R->bBlocked)return false;Inside=true;}
    if(!Inside)return false;
    for(const auto& E:ReferenceBoundary)if(FMath::PointDistToSegmentSquared(P,E.Key,E.Value)<FMath::Square(Radius*ReferencePlayerRadius/45.f)-.001f)return false;
    return true;
}

bool AAlchemyWorld::ReferenceSweep(FVector A,FVector B,float Radius) const {
    if(!ReferenceWalkable(A,Radius) || !ReferenceWalkable(B,Radius))return false;
    for(const auto& E:ReferenceBoundary){FVector P,Q;FMath::SegmentDistToSegmentSafe(A,B,E.Key,E.Value,P,Q);if(FVector::DistSquared(P,Q)<FMath::Square(Radius*ReferencePlayerRadius/45.f)-.001f)return false;}
    return true;
}

void AAlchemyWorld::EndPlay(const EEndPlayReason::Type Reason){
    if(ReferencePreviousAA>=0)if(auto AA=IConsoleManager::Get().FindConsoleVariable(TEXT("r.AntiAliasingMethod")))AA->Set(ReferencePreviousAA,ECVF_SetByCode);
    Super::EndPlay(Reason);
}

void AAlchemyWorld::UpdateGreyfordPortal() {
    if(GreyfordStage!=1 || GreyfordPortalReady || RunTime<GreyfordPortalRetry)return;
    FVector P;TArray<FVector> Path;bool Found=false;
    const auto Accept=[&](FVector Candidate) {
        if(!Walkable(Candidate,240) || !FindPath(PlayerPos,Candidate,45,Path))return false;
        P=Candidate;return true;
    };
    for(int I=0;I<64 && !Found;I++) {
        const float A=Random.FRandRange(0,2*PI),D=Random.FRandRange(700,2000);
        Found=Accept(PlayerPos+FVector(FMath::Cos(A)*D,FMath::Sin(A)*D,0));
    }
    if(!Found)for(float X=-6400;X<=6400 && !Found;X+=400)for(float Y=-4600;Y<=4600 && !Found;Y+=400)Found=Accept(FVector(X,Y,0));
    if(!Found){GreyfordPortalRetry=RunTime+5;Message(TEXT("Boss传送阵正在寻找可达落点，5秒后重试。"));return;}
    GreyfordPortalPos=P;GreyfordPortalReady=true;
    GreyfordPortal=Sprite(TEXT("Portal"),P,420,560);
    Message(TEXT("Boss传送阵已开放 · 跟随箭头，站入阵内按F确认挑战。"));
    UE_LOG(LogTemp,Display,TEXT("GREYFORD_PORTAL_READY time=%.2f pos=(%.1f,%.1f) clearance=240 path_nodes=%d"),RunTime,P.X,P.Y,Path.Num());
}

bool AAlchemyWorld::EnterGreyfordBoss() {
    if(!GreyfordPortalReady || GreyfordStage!=1 || FVector::Dist2D(PlayerPos,GreyfordPortalPos)>220 || bRunEnded)return false;
    const float BeforeHP=HP;
    // Only already-generated material drops transfer, and never beyond inventory capacity.
    for(const auto& D:Drops)if(D.Kind>=0 && D.Kind<6)CollectDrop(D.Kind,D.Count,false);
    for(const auto& D:Drops)if(IsValid(D.Body))D.Body->Destroy();Drops.Empty();
    for(auto& E:Enemies){if(IsValid(E.Body))E.Body->Destroy();if(IsValid(E.Shadow))E.Shadow->Destroy();}Enemies.Empty();
    for(auto& S:Shots){if(S.Trail.IsValid())S.Trail->DestroyComponent();if(IsValid(S.Body))S.Body->Destroy();}Shots.Empty();
    for(auto& E:Effects)if(IsValid(E.Body))E.Body->Destroy();Effects.Empty();
    for(auto& E:NiagaraFX)if(IsValid(E.Component))E.Component->DestroyComponent();NiagaraFX.Empty();DamageNumbers.Empty();
    CloseMerchant();if(IsValid(GreyfordPortal))GreyfordPortal->Destroy();GreyfordPortal=nullptr;GreyfordPortalReady=false;
    if(!SwitchGreyfordStage(2)){EndRun(false);return false;}
    PlayerPos=FVector(0,-500,0);Panel.Empty();CharacterAnimation.Reset();
    SpawnEnemy(10);
    if(Enemies.IsEmpty()){EndRun(false);return false;}
    auto& Boss=Enemies.Last();Boss.Pos=FVector(0,500,0);Boss.AttackCD=0;
    GreyfordBossPreparation=2;GreyfordBossStartFlash=0;GreyfordBossWarmupFrames=2;GreyfordCountdownCapture=-1;
    bBossSpawned=bBossArenaActive=true;BossArenaCenter=FVector::ZeroVector;
    UpdateBossVisual(Boss);UpdateCamera(0);UpdateCharacterVisual(0,false);
    PlayerShadow->SetActorLocation(PlayerPos+FVector(0,0,5));
    Message(TEXT("雾界草甸 · 击败Boss后结算；本场不能返回，Tab炼金、B换技能均暂停。"));
    UE_LOG(LogTemp,Display,TEXT("GREYFORD_BOSS_ENTER hp_before=%.1f hp_after=%.1f spacing=1000 materials=%d,%d,%d,%d,%d,%d"),BeforeHP,HP,Inventory[0],Inventory[1],Inventory[2],Inventory[3],Inventory[4],Inventory[5]);return true;
}

bool AAlchemyWorld::GreyfordFlowAction(const FString& Id) {
    if(bRunEnded && Panel==TEXT("savefailed"))return false;
    if(Id==TEXT("enterboss")){EnterGreyfordBoss();return true;}
    if(Id==TEXT("bossportalstay")){Panel.Empty();return true;}
    if(GreyfordStage==2 && !bRunEnded && (Id==TEXT("return") || Id==TEXT("village") || Id==TEXT("start"))) {
        Message(TEXT("Boss战结束前不能返回；可以暂停、炼金和调整技能。"));return true;
    }
    if(Id==TEXT("village") && bRunEnded) {
        bBossArenaActive=bBossSpawned=false;
        Inventory={0,0,0,0,0,0};Selected=Inventory;Levels.Init(0,NumSkills());Levels[0]=1;Equipped={0};Bag.Empty();
        BuildScene(false);HP=MaxHP;CharacterAnimation.Reset();UpdateCamera(0);Message(TEXT("已返回格雷弗德村庄，本局金币已结算，可强化后再次出发。"));return true;
    }
    if(Id==TEXT("village") && bCombat) {
        EndRun(false);return true;
    }
    return false;
}

// A real movement/camera tour, also used to capture the animated scene at 20 fps.
void AAlchemyWorld::GreyfordAmbientCheck(float Dt){
    const FString Dir=FPaths::ProjectDir()/TEXT("Evidence/Greyford/Ambient/Tour");IFileManager::Get().MakeDirectory(*Dir,true);
    const TArray<FVector> Goals={ReferencePoint(375,615),ReferencePoint(119,690),ReferencePoint(375,615),ReferencePoint(443,340),ReferencePoint(603,133)};
    AmbientTime+=Dt;bool Moving=false;
    if(AmbientPause>0)AmbientPause-=Dt;
    else if(AmbientWaypoint<Goals.Num()){
        const auto Goal=Goals[AmbientWaypoint];
        if(FVector::Dist2D(PlayerPos,Goal)<15){AmbientWaypoint++;AmbientPath.Empty();AmbientPause=(AmbientWaypoint==2 || AmbientWaypoint==5)?4:1;}
        else {
            if(AmbientPath.IsEmpty() && !FindPath(PlayerPos,Goal,45,AmbientPath))AmbientOK=false;
            while(AmbientPath.Num()>1 && FVector::Dist2D(PlayerPos,AmbientPath[0])<15)AmbientPath.RemoveAt(0);
            if(!AmbientPath.IsEmpty()){
                const auto Before=PlayerPos;const FVector To=AmbientPath[0]-PlayerPos;LastDirection=To.GetSafeNormal2D();
                PlayerPos=Move(PlayerPos,LastDirection*FMath::Min(500*Dt,To.Size2D()));Moving=!PlayerPos.Equals(Before,.01);
                AmbientOK &= Moving || To.Size2D()<15;
            }
        }
    }
    UpdateCamera(Dt);UpdateCharacterVisual(Dt,Moving);PlayerShadow->SetActorLocation(PlayerPos+FVector(0,0,5));
    const float A=Camera->GetCameraComponent()->AspectRatio,FullW=1672*180.f/52,FullH=941*180.f/52,Sin=FMath::Sin(FMath::DegreesToRadians(48.f));
    const bool InBounds=FMath::Abs(ReferenceCameraFocus.X)+ViewWidth/2<=FullW/2+1 && FMath::Abs(ReferenceCameraFocus.Y)*Sin+ViewWidth/(2*A)<=FullH/2+1;
    AmbientOK &= InBounds && Walkable(PlayerPos);
    AmbientCaptureTime+=Dt;
    if(AmbientTime>1 && AmbientCaptureTime>=.05f){
        AmbientCaptureTime=FMath::Fmod(AmbientCaptureTime,.05f);
        FScreenshotRequest::RequestScreenshot(Dir/FString::Printf(TEXT("frame-%05d.png"),AmbientFrame),false,false);
        AmbientCSV+=FString::Printf(TEXT("%d,%.4f,%d,%.2f,%.2f,%.2f,%.2f,%d\n"),AmbientFrame++,AmbientTime,AmbientWaypoint,PlayerPos.X,PlayerPos.Y,ReferenceCameraFocus.X,ReferenceCameraFocus.Y,InBounds);
    }
    if(!AmbientOK || AmbientTime>45 || (AmbientWaypoint==Goals.Num() && AmbientPause<=0)){
        const bool Passed=AmbientOK && AmbientWaypoint==Goals.Num();
        FFileHelper::SaveStringToFile(TEXT("frame,seconds,waypoint,player_x,player_y,camera_x,camera_y,in_bounds\n")+AmbientCSV,*(Dir/TEXT("movement.csv")));
        FFileHelper::SaveStringToFile(FString::Printf(TEXT("result=%s\nseconds=%.3f\nwaypoints=%d/5\nframes=%d\nzoom=2\n"),Passed?TEXT("PASS"):TEXT("FAIL"),AmbientTime,AmbientWaypoint,AmbientFrame),*(Dir/TEXT("result.txt")));
        UE_LOG(LogTemp,Display,TEXT("GREYFORD_AMBIENT_%s"),Passed?TEXT("PASS"):TEXT("FAIL"));FPlatformMisc::RequestExitWithStatus(false,Passed?0:1);
    }
}

// Isolated state-boundary and image checks. Timer setup is accelerated, not a five-minute survival claim.
void AAlchemyWorld::GreyfordFlowCheck(float Dt) {
    GreyfordFlowTestTime+=Dt;UpdateCamera(Dt);UpdateCharacterVisual(Dt,false);
    const auto Check=[&](bool OK,const TCHAR* Name){GreyfordFlowTestOK &= OK;UE_LOG(LogTemp,Display,TEXT("GREYFORD_FLOW_CHECK %s %s"),Name,OK?TEXT("PASS"):TEXT("FAIL"));};
    const FString Dir=FPaths::ProjectDir()/TEXT("Evidence/Greyford/Flow");IFileManager::Get().MakeDirectory(*Dir,true);
    // Allow camera caches and streamed render resources to catch up after test teleports.
    const auto Shot=[&](const TCHAR* Name){const FString Path=Dir/Name;FTimerHandle Timer;GetWorld()->GetTimerManager().SetTimer(Timer,[Path](){FScreenshotRequest::RequestScreenshot(Path,false,false);},.1f,false);};
    if(GreyfordFlowTestTime<1)return;GreyfordFlowTestTime=0;
    switch(GreyfordFlowTestStep++) {
        case 0:{Check(GreyfordStage==0 && !bCombat && CharacterAnimation.Material,TEXT("village_character"));for(int I=0;I<3;I++){TArray<FVector> Path;Check(Walkable(FacilityPosition(I),45) && FindPath(PlayerPos,FacilityPosition(I),45,Path),*FString::Printf(TEXT("facility_%d_reachable"),I));}
            int Life=0,Routes=0;for(TActorIterator<AActor> It(GetWorld());It;++It)if(It->GetLevel()==GreyfordActiveLevel){if(It->ActorHasTag(TEXT("GreyfordVillageLife")))++Life;if(It->ActorHasTag(TEXT("GreyfordVillageLifeWalk"))){TArray<FVector> Path;Check(Walkable(It->GetActorLocation(),45) && FindPath(PlayerPos,It->GetActorLocation(),45,Path),*FString::Printf(TEXT("village_route_%d"),Routes++));}}
            if(Life>0)Check(Life>=80 && Routes>=14,TEXT("reference_village_set_dressing"));
            if(bGreyfordReference){
                Check(ReferenceRegions.Num()>=11 && Routes==16,TEXT("reference_regions_and_routes"));
                Check(!Walkable(ReferencePoint(390,720)) && !Walkable(ReferencePoint(400,260)) && Walkable(ReferencePoint(375,615)),TEXT("river_house_blocked_bridge_open"));
                bool Traversed=true;for(auto Goal:ReferenceNodes){TArray<FVector> Path;if(!FindPath(PlayerPos,Goal,45,Path))continue;FVector P=PlayerPos;for(auto Target:Path){for(int I=0;I<1000 && FVector::Dist2D(P,Target)>1;I++){auto Next=Move(P,(Target-P).GetClampedToMaxSize(20));if(Next.Equals(P,.01)){Traversed=false;break;}P=Next;}Traversed &= FVector::Dist2D(P,Target)<2;}}Check(Traversed,TEXT("reference_paths_use_production_move"));
                if(FParse::Param(FCommandLine::Get(),TEXT("GreyfordReferenceClean"))){Player->SetActorHiddenInGame(true);PlayerShadow->SetActorHiddenInGame(true);}
            }
            if(!bGreyfordReference && FParse::Param(FCommandLine::Get(),TEXT("GreyfordVillageOverview"))){ViewWidth=11000;PlayerPos=FVector(0,-500,0);UpdateCamera(0);UpdateCharacterVisual(0,false);Shot(TEXT("00-village-overview.png"));}else Shot(TEXT("01-village.png"));break;}
        case 1:Player->SetActorHiddenInGame(false);PlayerShadow->SetActorHiddenInGame(false);ViewWidth=2400;PlayerPos=bGreyfordReference?ReferencePoint(375,615):FVector(2700,-3300,GreyfordSurfaceHeight(FVector(2700,-3300,0)));Check(bGreyfordReference?Walkable(PlayerPos):PlayerPos.Z>20,TEXT("bridge_walkable_surface"));UpdateCamera(0);UpdateCharacterVisual(0,false);PlayerShadow->SetActorLocation(PlayerPos+FVector(0,0,5));Shot(TEXT("02-bridge-deck.png"));break;
        case 2:PlayerPos=bGreyfordReference?ReferencePoint(778,365):FVector(2700,-3920,0);UpdateCamera(0);UpdateCharacterVisual(0,false);Shot(TEXT("03-bridge-front.png"));break;
        case 3:PlayerPos=bGreyfordReference?ReferencePoint(797,480):FVector(2700,-2680,0);UpdateCamera(0);UpdateCharacterVisual(0,false);Shot(TEXT("04-bridge-behind.png"));break;
        case 4:Action(TEXT("start"));Check(GreyfordStage==1 && bCombat && HP==MaxHP,TEXT("village_to_field"));RunTime=299.9f;UpdateGreyfordPortal();Check(!GreyfordPortalReady,TEXT("no_portal_before_300"));RunTime=300;UpdateGreyfordPortal();Check(GreyfordPortalReady && Walkable(GreyfordPortalPos,240),TEXT("portal_at_300_clearance"));Shot(TEXT("05-portal-guide.png"));break;
        case 5:HP=73;Inventory={9,0,0,0,0,0};Drop(PlayerPos,0,5);Drop(PlayerPos,1,3);PlayerPos=GreyfordPortalPos;Panel=TEXT("bossportal");Action(TEXT("bossportalstay"));Check(Panel.IsEmpty() && GreyfordStage==1 && GreyfordPortalReady,TEXT("portal_can_cancel_without_transition"));Panel=TEXT("bossportal");GreyfordPausedTime=RunTime;UpdateCamera(0);UpdateCharacterVisual(0,false);Shot(TEXT("06-confirm-portal.png"));break;
        case 6:{Check(FMath::IsNearlyEqual(RunTime,GreyfordPausedTime),TEXT("portal_confirmation_pauses_timer"));const auto PriorSkills=Equipped;const auto Cooldowns=SkillCD;Action(TEXT("enterboss"));Check(GreyfordStage==2 && HP==73 && Inventory[0]==10 && Inventory[1]==3 && Equipped==PriorSkills && SkillCD==Cooldowns,TEXT("boss_preserves_hp_skills_cooldowns_capped_materials"));Check(Enemies.Num()==1 && Enemies[0].Type==10 && !Walkable(FVector(1700,0,0)) && Walkable(FVector::ZeroVector),TEXT("boss_ellipse_clear_arena"));Action(TEXT("village"));Check(GreyfordStage==2 && !bRunEnded,TEXT("boss_cannot_retreat"));Shot(TEXT("07-boss.png"));break;}
        case 7:Check(GreyfordBossPreparation>0 && Enemies[0].Pos.Equals(FVector(0,500,0)) && BossAttackCounts[0]+BossAttackCounts[1]+BossAttackCounts[2]==0,TEXT("preparation_boss_waits_without_attacks"));Panel=TEXT("skills");GreyfordPausedTime=RunTime;GreyfordPausedPreparation=GreyfordBossPreparation;Shot(TEXT("08-boss-skills.png"));break;
        case 8:Check(FMath::IsNearlyEqual(RunTime,GreyfordPausedTime) && GreyfordBossPreparation==GreyfordPausedPreparation,TEXT("boss_skills_pause_battle_and_preparation"));Panel=TEXT("alchemy");GreyfordPausedTime=RunTime;Shot(TEXT("09-boss-alchemy.png"));break;
        case 9:Check(FMath::IsNearlyEqual(RunTime,GreyfordPausedTime) && GreyfordBossPreparation==GreyfordPausedPreparation,TEXT("boss_alchemy_pause_battle_and_preparation"));Panel.Empty();GreyfordFlowTestTime=-1;break;
        case 10:Check(GreyfordBossPreparation==0,TEXT("preparation_resumes_and_starts_combat"));RunCoins=17;GreyfordFlowExpectedCoins=Progress->Coins+17;DamageEnemy(0,Enemies[0].HP+1);break;
        case 11:Check(bRunEnded && Panel==TEXT("victory") && Progress->Coins==GreyfordFlowExpectedCoins && ResultCoins==17,TEXT("boss_death_settles_once"));EndRun(true);Check(Progress->Coins==GreyfordFlowExpectedCoins,TEXT("no_double_settlement"));Shot(TEXT("10-victory.png"));break;
        case 12:Action(TEXT("village"));Check(GreyfordStage==0 && !bCombat && !bRunEnded,TEXT("victory_returns_village"));Shot(TEXT("11-returned-village.png"));break;
        case 13:Action(TEXT("start"));Check(GreyfordStage==1 && bCombat,TEXT("second_run_starts"));HurtInv=DodgeInv=0;Hurt(10000);Check(Panel==TEXT("defeat"),TEXT("player_death_result"));break;
        case 14:Action(TEXT("village"));Check(GreyfordStage==0 && !bCombat,TEXT("defeat_returns_village"));break;
        default:FFileHelper::SaveStringToFile(GreyfordFlowTestOK?TEXT("result=PASS\nmethod=accelerated state-boundary checks and native rendering; not human balance acceptance\n"):TEXT("result=FAIL\n"),*(Dir/TEXT("flow-result.txt")));UE_LOG(LogTemp,Display,TEXT("GREYFORD_FLOW_%s"),GreyfordFlowTestOK?TEXT("PASS"):TEXT("FAIL"));FPlatformMisc::RequestExitWithStatus(false,GreyfordFlowTestOK?0:1);break;
    }
}

void AAlchemyHUD::DrawGreyfordFlow() {
    const FLinearColor White(.94f,.95f,.93f),Dim(.72f,.79f,.8f),Surface(.035f,.06f,.075f,.97f);
    if(!World->Panel.IsEmpty() || World->bRunEnded)return;
    if(World->GreyfordStage==2) {
        const float Remaining=World->GreyfordBossPreparation;
        if(Remaining<=0 && World->GreyfordBossStartFlash<=0)return;
        const FString Value=Remaining>0?FString::FromInt(FMath::CeilToInt(Remaining)):TEXT("开战");
        const float HalfWidth=FMath::Max(38.f,Measure(Value,34)/2+10);
        TArray<FBox2D> Figures;
        TArray<AActor*> Bodies={World->Player};if(!World->Enemies.IsEmpty())Bodies.Add(World->Enemies[0].Body);
        for(auto* Body:Bodies)if(IsValid(Body)) {
            FVector C,E;Body->GetActorBounds(false,C,E);FBox2D Bounds(ForceInit);
            for(int I=0;I<8;I++){FVector2D P;if(GetOwningPlayerController()->ProjectWorldLocationToScreen(C+E*FVector(I&1?1:-1,I&2?1:-1,I&4?1:-1),P))Bounds+=FVector2D((P.X-OX)/S,(P.Y-OY)/S);}
            if(Bounds.bIsValid)Figures.Add(Bounds.ExpandBy(16));
        }
        FVector2D Center(640,290);bool Clear=false;
        for(FVector2D Candidate:{FVector2D(640,290),FVector2D(470,290),FVector2D(810,290),FVector2D(640,340),FVector2D(940,190),FVector2D(400,190)}) {
            FBox2D Area(Candidate-FVector2D(HalfWidth+10,46),Candidate+FVector2D(HalfWidth+10,46));bool Overlap=false;
            for(const auto& F:Figures)Overlap|=Area.Intersect(F);
            if(!Overlap){Center=Candidate;Clear=true;break;}
        }
        if(!Clear)return;
        const float Alpha=Remaining>0?1:FMath::Clamp(World->GreyfordBossStartFlash/.35f,0.f,1.f);
        const float Radius=28+2*FMath::Sin(Remaining*2*PI);
        const float Arc=Remaining>0?Remaining-FMath::CeilToFloat(Remaining)+1:1;
        for(int I=0;I<64;I++) {
            const float A=-PI/2+I*2*PI/64,B=-PI/2+(I+1)*2*PI/64;
            const FVector2D From=Center+FVector2D(FMath::Cos(A),FMath::Sin(A))*Radius,To=Center+FVector2D(FMath::Cos(B),FMath::Sin(B))*Radius;
            FLinearColor Color=I<64*Arc?Teal:Dim;Color.A=Alpha*(I<64*Arc?1:.3f);
            DrawLine(OX+From.X*S,OY+From.Y*S,OX+To.X*S,OY+To.Y*S,Color,1.5f*S);
        }
        FLinearColor Color=Gold;Color.A=Alpha;Text(Value,Center.X-Measure(Value,34)/2,Center.Y-World->Progress->FontSize(34)/2,34,Color);return;
    }
    const bool Portal=World->GreyfordStage==1 && World->GreyfordPortalReady;
    if(World->GreyfordStage==1 && !Portal)return;
    const FVector Goal=Portal?World->GreyfordPortalPos:World->FacilityPosition(2);
    const FVector Delta=Goal-World->PlayerPos;
    const FVector2D Heading=FVector2D(FVector::DotProduct(Delta,World->Camera->GetActorRightVector()),-FVector::DotProduct(Delta,World->Camera->GetActorForwardVector().GetSafeNormal2D())).GetSafeNormal();
    Box(968,282,288,138,Surface);
    Text(Portal?TEXT("Boss传送阵已开放"):TEXT("沿主路前往村口雾门"),982,292,20,Gold);
    Text(FString::Printf(TEXT("距离 %.1f 米"),Delta.Size2D()/100),982,330,18,White);
    const FVector2D Center(1213,355),Tip=Center+Heading*22,Side(-Heading.Y,Heading.X);
    const auto Line=[&](FVector2D A,FVector2D B){DrawLine(OX+A.X*S,OY+A.Y*S,OX+B.X*S,OY+B.Y*S,Gold,3*S);};
    Line(Center-Heading*14,Tip);Line(Tip,Tip-Heading*12+Side*8);Line(Tip,Tip-Heading*12-Side*8);
    if(World->GreyfordStage==0) {
        int Nearest=0;for(int I=1;I<3;I++)if(FVector::Dist2D(World->PlayerPos,World->FacilityPosition(I))<FVector::Dist2D(World->PlayerPos,World->FacilityPosition(Nearest)))Nearest=I;
        const float Distance=FVector::Dist2D(World->PlayerPos,World->FacilityPosition(Nearest));
        if(Distance<800) {const TCHAR* Ids[]={TEXT("talents"),TEXT("codex"),TEXT("level")};const TCHAR* Names[]={TEXT("F 强化台"),TEXT("F 配方图鉴"),TEXT("F 村口雾门")};Button(Ids[Nearest],Distance<280?FString(Names[Nearest]):FString(TEXT("靠近后按 "))+Names[Nearest],982,371,252,Distance<280,38);}
        else Text(TEXT("广场可强化、查看图鉴"),982,378,16,Dim);
    } else Text(Delta.Size2D()<=220?TEXT("按 F 确认出发"):TEXT("可以继续成长，注意退路"),982,378,16,Dim);
}
