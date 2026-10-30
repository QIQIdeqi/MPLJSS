// Authored scene adapter; movement, skills, enemies and damage remain the production simulation.
void AAlchemyWorld::BuildGreyfordScene() {
    if(bGreyfordFlow && !SwitchGreyfordStage(bCombat?1:0)){SetActorTickEnabled(false);FPlatformMisc::RequestExitWithStatus(false,1);return;}
    CombatHalfSize=FVector2D(7200,5400);
    for(TActorIterator<APlayerStart> It(GetWorld());It;++It){if(bGreyfordFlow && It->GetLevel()!=GreyfordActiveLevel)continue;PlayerPos=It->GetActorLocation();PlayerPos.Z=0;break;}
    if(!bGreyfordFlow)for(TActorIterator<AStaticMeshActor> It(GetWorld());It;++It) {
        if(bGreyfordFlow && It->GetLevel()!=GreyfordActiveLevel)continue;
        if(!It->ActorHasTag(TEXT("GreyfordBlocker")))continue;
        FVector Center,Extent;It->GetActorBounds(true,Center,Extent);
        Obstacles.Add({FVector2D(Center),FVector2D(Extent)});
    }
    if(bGreyfordFlow && !bCombat && !bGreyfordReference) {
        Sprite(TEXT("Cauldron"),GreyfordFacilities[0],210,250);
        Sprite(TEXT("Lectern"),GreyfordFacilities[1],180,230);
        bool AuthoredGate=false;for(TActorIterator<AStaticMeshActor> It(GetWorld());It;++It)if(It->GetLevel()==GreyfordActiveLevel && It->ActorHasTag(TEXT("GreyfordVillageFogGate"))){AuthoredGate=true;break;}
        if(!AuthoredGate)Sprite(TEXT("Portal"),GreyfordFacilities[2],420,560);
    }
    if(bGreyfordFlow && bCombat)for(int I=0;I<64;I++) {
        const FVector Candidate(Random.FRandRange(-6800,6800),Random.FRandRange(-5000,5000),0);TArray<FVector> Path;
        if(Walkable(Candidate,45) && FindPath(PlayerPos,Candidate,45,Path)){PlayerPos=Candidate;break;}
    }
    UE_LOG(LogTemp,Display,TEXT("GREYFORD_COMBAT_SCENE blockers=%d spawn_clear=%d no_save=%d"),Obstacles.Num(),Walkable(PlayerPos),bCapture);
}

void AAlchemyWorld::StartGreyfordReview() {
    TArray<TPair<int32,FVector>> Points;
    for(TActorIterator<ATargetPoint> It(GetWorld());It;++It)for(FName Tag:It->Tags) {
        const FString S=Tag.ToString();
        if(S.StartsWith(TEXT("GreyfordWalk_"))) {FVector P=It->GetActorLocation();P.Z=0;Points.Emplace(FCString::Atoi(*S.RightChop(13)),P);}
    }
    Points.Sort([](const auto& A,const auto& B){return A.Key<B.Key;});
    GreyfordRoute.Empty();for(const auto& P:Points)GreyfordRoute.Add(P.Value);
    GreyfordReviewOK=GreyfordRoute.Num()==9 && Walkable(GreyfordRoute[0]);
    if(!GreyfordReviewOK){FinishGreyfordReview();return;}
    // Continue back along the route after the primary eight segments, without teleporting.
    for(int I=7;I>=0;--I){const FVector P=GreyfordRoute[I];GreyfordRoute.Add(P);}
    PlayerPos=GreyfordRoute[0];GreyfordWaypoint=1;GreyfordPath.Empty();
    GreyfordReviewTime=GreyfordSegmentTime=0;GreyfordDodges=GreyfordAttackFrames=GreyfordPeakEnemies=0;
    GreyfordMinHP=HP;GreyfordReviewActive=true;
    GreyfordReviewCSV=TEXT("point,seconds,x_cm,y_cm,hp,kills,enemies\n");
    // A reproducible local pressure setup. HP/damage/speed/skill levels are unchanged.
    for(int I=0;I<Enemies.Num();I++) {
        for(int J=0;J<24;J++) {
            const float A=(I*3+J)*2*PI/24;
            const FVector P=PlayerPos+FVector(FMath::Cos(A)*950,FMath::Sin(A)*950,0);
            if(Walkable(P,EnemyRadius(Enemies[I].Type))){Enemies[I].Pos=P;break;}
        }
    }
    UE_LOG(LogTemp,Display,TEXT("GREYFORD_COMBAT_REVIEW_START seconds=60 primary_segments=8 player_radius=45 speed=500 dodge=280 normal_hp=%.0f"),HP);
}

FVector AAlchemyWorld::UpdateGreyfordReview(float Dt,FVector Manual) {
    GreyfordReviewTime+=Dt;GreyfordSegmentTime+=Dt;GreyfordReviewDodge=false;
    GreyfordPeakEnemies=FMath::Max(GreyfordPeakEnemies,Enemies.Num());
    GreyfordMinHP=FMath::Min(GreyfordMinHP,HP);
    if(!Shots.IsEmpty() || CharacterAnimation.Throwing)GreyfordAttackFrames++;
    GreyfordReviewOK &= Walkable(PlayerPos);
    for(const auto& E:Enemies)if(E.HP>0)GreyfordReviewOK &= Walkable(E.Pos,EnemyRadius(E.Type));
    if(GreyfordReviewTime>=60 || GreyfordSegmentTime>26 || !GreyfordReviewOK) {FinishGreyfordReview();return FVector::ZeroVector;}
    if(GreyfordWaypoint>=GreyfordRoute.Num())return FVector::ZeroVector;
    const FVector Goal=GreyfordRoute[GreyfordWaypoint];
    if(FVector::Dist2D(PlayerPos,Goal)<65) {
        GreyfordReviewCSV+=FString::Printf(TEXT("%d,%.3f,%.1f,%.1f,%.1f,%d,%d\n"),GreyfordWaypoint,GreyfordReviewTime,PlayerPos.X,PlayerPos.Y,HP,Kills,Enemies.Num());
        if(GreyfordWaypoint==1 || GreyfordWaypoint==5) {
            FScreenshotRequest::RequestScreenshot(FPaths::ProjectDir()/FString::Printf(TEXT("Evidence/Greyford/P2/combat-gap-%d.png"),GreyfordWaypoint),false,false);
        }
        GreyfordWaypoint++;GreyfordSegmentTime=0;GreyfordPath.Empty();
        return FVector::ZeroVector;
    }
    if(GreyfordPath.IsEmpty() && !FindPath(PlayerPos,Goal,45,GreyfordPath)){GreyfordReviewOK=false;FinishGreyfordReview();return FVector::ZeroVector;}
    while(GreyfordPath.Num()>1 && FVector::Dist2D(PlayerPos,GreyfordPath[0])<45)GreyfordPath.RemoveAt(0);
    const FVector Direction=(GreyfordPath[0]-PlayerPos).GetSafeNormal2D();
    GreyfordReviewDodge=DodgeCD<=0 && FMath::Fmod(GreyfordReviewTime,3.f)<.15f && SegmentClear(PlayerPos,PlayerPos+Direction*320,45);
    return Direction;
}

void AAlchemyWorld::FinishGreyfordReview() {
    GreyfordReviewActive=GreyfordReviewDodge=false;
    const bool OK=GreyfordReviewOK && GreyfordWaypoint>8 && GreyfordDodges>=4 && GreyfordAttackFrames>0 && Kills>0 && HP>0 && GreyfordReviewTime>=59.9f;
    const FString Dir=FPaths::ProjectDir()/TEXT("Evidence/Greyford/P2");IFileManager::Get().MakeDirectory(*Dir,true);
    FFileHelper::SaveStringToFile(GreyfordReviewCSV,*(Dir/TEXT("combat-route.csv")));
    FFileHelper::SaveStringToFile(FString::Printf(TEXT("result=%s\nseconds=%.3f\nprimary_segments_reached=%d/8\nroute_segments_reached=%d\ndodges=%d\nkills=%d\npeak_enemies=%d\nattack_frames=%d\nminimum_hp=%.1f\nfinal_hp=%.1f\nwalkable_checks=%d\nmethod=automated movement through production combat simulation; seeded local enemy pressure; no HP/damage cheats; no human balance acceptance\n"),OK?TEXT("PASS"):TEXT("FAIL"),GreyfordReviewTime,FMath::Min(8,GreyfordWaypoint-1),GreyfordWaypoint-1,GreyfordDodges,Kills,GreyfordPeakEnemies,GreyfordAttackFrames,GreyfordMinHP,HP,GreyfordReviewOK),*(Dir/TEXT("combat-result.txt")));
    UE_LOG(LogTemp,Display,TEXT("GREYFORD_COMBAT_REVIEW_%s segments=%d dodges=%d kills=%d hp=%.1f"),OK?TEXT("PASS"):TEXT("FAIL"),GreyfordWaypoint-1,GreyfordDodges,Kills,HP);
    FPlatformMisc::RequestExitWithStatus(false,OK?0:1);
}
