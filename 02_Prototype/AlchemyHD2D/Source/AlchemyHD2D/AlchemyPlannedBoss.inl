// Confirmed Greyford Boss rules. Unconfirmed presentation/loop defaults are editor tunables.
void AAlchemyWorld::SpawnTutorialEncounter() {
    TutorialEncounterRetry=RunTime+1;
    TArray<FVector> Positions;
    const int Authored=bBattleReference?BattleSpawnPixels.Num():0;
    for(int Try=0;Try<32+Authored && Positions.IsEmpty();Try++) {
        FVector Anchor;TArray<FVector> Path;
        if(Try<Authored)Anchor=BattleReferencePoint(BattleSpawnPixels[Try]);
        else if(!FindSpawnPoint(0,Anchor))continue;
        if(!FindPath(PlayerPos,Anchor,45,Path))continue;
        TArray<FVector> Candidates;
        for(int I=0;I<TutorialEncounterCount;I++) {
            const FVector P=Anchor+FVector((I%3-1)*55,(I/3)*60,0);
            bool Legal=Walkable(P,45) && FindPath(PlayerPos,P,45,Path);
            if(Legal && bBattleReference){
                const auto& K=EnemyDefinition(I%2);TArray<FVector> Corners;
                for(int X:{-1,1})for(int Y:{-1,1})Corners.Add(P+Camera->GetActorUpVector()*(K.VisualSize.Y*.46)+Camera->GetActorRightVector()*(X*K.VisualSize.X*.5)+(bUprightSprites?FVector::UpVector:Camera->GetActorUpVector())*(Y*K.VisualSize.Y*.5));
                Legal=BattleOffscreen(P,45) && BattleProjectedOutside(GetWorld()->GetFirstPlayerController(),Corners);
            }
            if(Legal)Candidates.Add(P);
        }
        if(Candidates.Num()==TutorialEncounterCount)Positions=MoveTemp(Candidates);
    }
    if(Positions.IsEmpty())return;
    for(int I=0;I<Positions.Num();I++) {
        const int Before=Enemies.Num();SpawnEnemy(I%2);
        if(Enemies.Num()>Before){Enemies.Last().Pos=Positions[I];UpdateEnemyVisual(Enemies.Last());}
    }
    TutorialEncounterPending=false;
    UE_LOG(LogTemp,Display,TEXT("FIRST_AOE_ENCOUNTER count=%d time=%.2f legal_offscreen_cluster=1"),Positions.Num(),RunTime);
}

FVector AAlchemyWorld::BossStraightMove(FVector From,FVector Delta,float Radius) const {
    const int Steps=FMath::Max(1,FMath::CeilToInt(Delta.Size2D()/10));
    const FVector Step=Delta/Steps;
    for(int I=0;I<Steps;I++) {
        if(!Walkable(From+Step,Radius)) {
            float Lo=0,Hi=1;
            for(int J=0;J<10;J++){const float M=(Lo+Hi)*.5f;if(Walkable(From+Step*M,Radius))Lo=M;else Hi=M;}
            return From+Step*Lo;
        }
        From+=Step;
    }
    return From;
}

void AAlchemyWorld::BossLockCue() {
    PlannedBossLockSounds++;
    if(BossLockSound)UGameplayStatics::PlaySound2D(this,BossLockSound,.55f);
}

void AAlchemyWorld::ShowPlannedBossLines(FAlchemyEnemy& E,bool Dash,bool Locked) {
    const int Count=Dash?36:5;
    while(PlannedBossLines.Num()<Count) {
        auto A=Mesh(TEXT("Plane"),E.Pos,FVector(1),FLinearColor::White);
        A->GetStaticMeshComponent()->SetMaterial(0,Material(TEXT("M_ThreatLane")));
        A->GetStaticMeshComponent()->SetCastShadow(false);PlannedBossLines.Add(A);
    }
    const FLinearColor Tint=Dash?(Locked?FLinearColor(1,.35f,.08f):FLinearColor(.7f,.35f,.08f)):FLinearColor(.15f,.9f,1);
    const auto Line=[&](int I,FVector Start,FVector End,float Width,bool Visible) {
        auto A=PlannedBossLines[I];A->SetActorHiddenInGame(!Visible);
        if(!Visible)return;
        A->SetActorLocation((Start+End)*.5f+FVector(0,0,16));
        A->SetActorRotation((End-Start).Rotation());
        A->SetActorScale3D(FVector(FVector::Dist2D(Start,End)/100,Width/100,1));
        auto M=Cast<UMaterialInstanceDynamic>(A->GetStaticMeshComponent()->GetMaterial(0));
        if(!M){M=UMaterialInstanceDynamic::Create(Material(TEXT("M_ThreatLane")),this);A->GetStaticMeshComponent()->SetMaterial(0,M);}
        M->SetVectorParameterValue(TEXT("Tint"),Tint);
    };
    const FVector Direction=E.DashDirection.GetSafeNormal2D();
    if(Dash) {
        const FVector End=BossStraightMove(E.Pos,Direction*1200,EnemyRadius(E));
        const float Length=FVector::Dist2D(E.Pos,End);const FVector Side(-Direction.Y,Direction.X,0);
        for(int S=0;S<2;S++) {
            const FVector Offset=Side*(S?100:-100);
            Line(S,E.Pos+Offset,End+Offset,7,Locked);
            for(int I=0;I<16;I++) {
                const float A=I*75.f,B=FMath::Min(Length,A+42);
                Line(2+S*16+I,E.Pos+Offset+Direction*A,E.Pos+Offset+Direction*B,7,!Locked && A<Length);
            }
        }
        Line(34,E.Pos-Side*100,E.Pos+Side*100,7,true);
        Line(35,End-Side*100,End+Side*100,7,true);
    } else for(int I=0;I<5;I++) {
        const FVector D=Direction.RotateAngleAxis(-30.f+15*I,FVector::UpVector);
        Line(I,E.Pos,BossStraightMove(E.Pos,D*(800*PlannedFanLifetime),30),60,true);
    }
    for(int I=Count;I<PlannedBossLines.Num();I++)PlannedBossLines[I]->SetActorHiddenInGame(true);
}

void AAlchemyWorld::FirePlannedBossWave(FAlchemyEnemy& E,float FrameOffset) {
    const int Wave=++PlannedBossWaveSerial;
    for(int I=0;I<5;I++) {
        const FVector D=E.DashDirection.RotateAngleAxis(-30.f+15*I,FVector::UpVector);
        Fire(E.Pos,E.Pos+D*1000,18,FLinearColor(.16f,.9f,1),true,800,nullptr,nullptr,PlannedFanLifetime);
        auto& S=Shots.Last();S.BossWave=Wave;S.SpawnDelay=FrameOffset;
        S.Body->SetActorScale3D(FVector(.6f));
        auto M=UMaterialInstanceDynamic::Create(Material(TEXT("M_PlannedBossBolt")),this);
        M->SetVectorParameterValue(TEXT("Tint"),S.Color);S.Body->GetStaticMeshComponent()->SetMaterial(0,M);
    }
    PlannedBossWavesFired++;ClearBossTelegraphs();
    for(auto A:PlannedBossLines)if(IsValid(A))A->SetActorHiddenInGame(true);
}

void AAlchemyWorld::UpdatePlannedBoss(FAlchemyEnemy& E,float Dt) {
    if(!Panel.IsEmpty() || bRunEnded || GreyfordBossPreparation>0)return;
    float Remaining=Dt;
    while(Remaining>KINDA_SMALL_NUMBER && !bRunEnded && Panel.IsEmpty()) {
        const float Step=FMath::Min(Remaining,.005f);Remaining-=Step;
        if(E.PlannedState==0) {
            E.BossAttack=E.BossSequence==0?Random.RandRange(0,1):1-E.BossAttack;
            E.BossSequence++;E.PlannedTime=0;E.PlannedLocked=false;E.BossDashHit=false;
            E.PlannedState=E.BossAttack==0?1:4;
            E.DashDirection=(PlayerPos-E.Pos).GetSafeNormal2D();
            if(E.DashDirection.IsNearlyZero())E.DashDirection=FVector(0,-1,0);
            BossAttackCounts[E.BossAttack]++;
        }
        E.PlannedTime+=Step;
        const auto Lock=[&](){E.PlannedLocked=true;E.DashDirection=(PlayerPos-E.Pos).GetSafeNormal2D();if(E.DashDirection.IsNearlyZero())E.DashDirection=FVector(0,-1,0);BossLockCue();};
        const auto Hide=[&](){for(auto A:PlannedBossLines)if(IsValid(A))A->SetActorHiddenInGame(true);};
        if(E.PlannedState==1) {
            if(!E.PlannedLocked && E.PlannedTime+KINDA_SMALL_NUMBER>=.6f)Lock();
            if(!E.PlannedLocked)E.DashDirection=(PlayerPos-E.Pos).GetSafeNormal2D();
            if(E.PlannedTime+KINDA_SMALL_NUMBER>=1) {
                Hide();E.PlannedState=2;E.PlannedTime=0;E.PlannedDistance=0;
                SpawnVFX(BlastFX,E.Pos+FVector(0,0,35),FLinearColor(1,.4f,.1f),.65f,.6f);
            }
        } else if(E.PlannedState==2) {
            const FVector Before=E.Pos;
            const float Travel=FMath::Min(2000*Step,1200-E.PlannedDistance);
            E.Pos=BossStraightMove(E.Pos,E.DashDirection*Travel,EnemyRadius(E));
            const float Moved=FVector::Dist2D(Before,E.Pos);E.PlannedDistance+=Moved;
            if(!E.BossDashHit && FMath::PointDistToSegmentSquared(PlayerPos,Before,E.Pos)<=FMath::Square(100.f+45)) {
                const float OldHP=HP;Hurt(24);
                if(HP<OldHP){E.BossDashHit=true;if(HP>0){BossKnockRemaining=.15f;BossKnockDirection=E.DashDirection;DodgeTime=0;}}
            }
            if(Moved+0.01f<Travel || E.PlannedDistance+0.01f>=1200) {E.PlannedState=3;E.PlannedTime=0;}
        } else if(E.PlannedState==3) {
            const float Recovery=E.BossAttack==0?1.f:PlannedFanRecovery;
            if(E.PlannedTime+KINDA_SMALL_NUMBER>=Recovery){E.PlannedState=0;E.PlannedTime=0;}
        } else if(E.PlannedState==4) {
            if(!E.PlannedLocked && E.PlannedTime+KINDA_SMALL_NUMBER>=FMath::Max(.05f,PlannedFanWindup-.3f))Lock();
            if(!E.PlannedLocked)E.DashDirection=(PlayerPos-E.Pos).GetSafeNormal2D();
            if(E.PlannedTime+KINDA_SMALL_NUMBER>=PlannedFanWindup) {
                FirePlannedBossWave(E,Dt-Remaining);E.PlannedState=5;E.PlannedTime=0;E.PlannedLocked=false;
            }
        } else if(E.PlannedState==5) {
            if(!E.PlannedLocked && E.PlannedTime+KINDA_SMALL_NUMBER>=.5f)Lock();
            if(E.PlannedTime+KINDA_SMALL_NUMBER>=.8f) {
                FirePlannedBossWave(E,Dt-Remaining);E.PlannedState=3;E.PlannedTime=0;
            }
        }
    }
    if(E.PlannedState==1)ShowPlannedBossLines(E,true,E.PlannedLocked);
    else if(E.PlannedState==4)ShowPlannedBossLines(E,false,E.PlannedLocked);
    else if(E.PlannedState==5 && E.PlannedLocked)ShowPlannedBossLines(E,false,true);
}

FVector AAlchemyWorld::PlannedPlayerMove(FVector ManualDelta,float Dt) {
    if(BossKnockRemaining<=0)return Move(PlayerPos,ManualDelta);
    const float Used=FMath::Min(Dt,BossKnockRemaining);
    const FVector Delta=BossKnockDirection*(100/.15f)*Used;
    const FVector End=BossStraightMove(PlayerPos,Delta,45);
    const bool Blocked=FVector::Dist2D(End,PlayerPos)+.01f<Delta.Size2D();
    BossKnockRemaining=Blocked?0:FMath::Max(0.f,BossKnockRemaining-Used);
    // A completed/truncated knockback resumes the currently held input for the rest of this tick.
    const float EffectiveUsed=Blocked?FVector::Dist2D(End,PlayerPos)/(100/.15f):Used;
    return Move(End,ManualDelta*(FMath::Max(0.f,Dt-EffectiveUsed)/FMath::Max(Dt,SMALL_NUMBER)));
}

void AAlchemyWorld::UpdatePlannedShot(FAlchemyShot& S,float Dt) {
    if(!Panel.IsEmpty())return;
    if(SpentBossWaves.Contains(S.BossWave) && S.FadeRemaining<0) {
        S.FadeRemaining=PlannedWaveFade;S.Damage=0;
        if(S.Trail.IsValid())S.Trail->Deactivate();
    }
    if(S.FadeRemaining>=0) {
        S.FadeRemaining=FMath::Max(0.f,S.FadeRemaining-Dt);
        const float A=S.FadeRemaining/FMath::Max(.01f,PlannedWaveFade);
        if(auto M=Cast<UMaterialInstanceDynamic>(S.Body->GetStaticMeshComponent()->GetMaterial(0)))M->SetScalarParameterValue(TEXT("Opacity"),A);
        if(S.FadeRemaining<=0)S.Life=0;return;
    }
    const int Steps=FMath::Max(1,FMath::CeilToInt(800*Dt/10));
    for(int I=0;I<Steps && S.Life>0;I++) {
        S.Pos+=S.Velocity*(Dt/Steps);
        if(!Walkable(S.Pos,30)){S.Life=0;break;}
        if(FVector::Dist2D(S.Pos,PlayerPos)<=75) {
            const float Before=HP;Hurt(S.Damage);
            if(HP<Before){SpentBossWaves.Add(S.BossWave);S.Life=0;break;}
        }
    }
}
