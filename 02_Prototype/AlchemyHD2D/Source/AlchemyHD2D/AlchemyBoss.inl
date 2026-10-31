// Existing world owns movement, reward rolls and pause. Boss attacks use those same paths.
void AAlchemyWorld::CollectDrop(int32 Kind,int32 Count,bool BossTransfer) {
    auto Add=[&](int32 M,int32 N) {
        const int32 Space=BossTransfer?N:FMath::Max(0,10-Inventory[M]);
        Inventory[M]+=FMath::Min(N,Space);
    };
    if(Kind>=6 && Kind<=8) {
        Add(Kind-3,1);
        for(int J=0;J<4;J++) {const float R=Random.FRand();Add(R<.4f?0:R<.75f?1:2,1);}
        if(!BossTransfer) Message(TEXT("精英宝箱已收入背包；满仓部分不入库。"));
    } else if(Kind==-2) {
        // 系统 UI V0.2 §7.1：腐化鼠1 泥团1 骷髅2 毒囊2 猎犬2 术徒3 蛮徒4
        static const float XP[7]={1,1,2,2,2,3,4};GrantXP(XP[FMath::Clamp(Count,0,6)]);
    } else if(Kind<0) RunCoins+=Count;
    else if(Kind<6) {
        Add(Kind,Count);
        // Codex: record first pickup of a normal material permanently (materials 0..2 only).
        if(Progress && Kind>=0 && Kind<3 && !Progress->Materials.Contains(Kind)) { Progress->Materials.Add(Kind); SaveProgress(); }
    }
}
void AAlchemyWorld::RewardEnemy(const FAlchemyEnemy& E) {
    if(E.Type>=7 && E.Type<=9) MerchantEliteUnlocked[E.Type-7]=true;
    if(E.Type==10) return;
    // Codex: record first defeat of this monster type permanently.
    if(Progress && !Progress->Monsters.Contains(E.Type)) { Progress->Monsters.Add(E.Type); SaveProgress(); }
    if(E.Type>=7) {Drop(E.Pos,6+E.Type-7);Drop(E.Pos,-1,10);}
    else {
        Drop(E.Pos,-2,E.Type);
        if(Random.FRand()<.7f) Drop(E.Pos,-1);
        if(Random.FRand()<MaterialDropChance()) {const float R=Random.FRand();Drop(E.Pos,R<.4f?0:R<.75f?1:2);}
    }
}
void AAlchemyWorld::EndBossArena() {
    bBossArenaActive=false;BossKnockRemaining=0;SpentBossWaves.Empty();
    for(auto A:PlannedBossLines)if(IsValid(A))A->Destroy();PlannedBossLines.Empty();
    if(IsValid(BossArenaRing)) BossArenaRing->Destroy();BossArenaRing=nullptr;
    ClearBossTelegraphs();
}
void AAlchemyWorld::ClearBossTelegraphs() {
    if(IsValid(BossTelegraph)) BossTelegraph->Destroy();BossTelegraph=nullptr;
    for(auto A:BossFanTelegraphs) if(IsValid(A)) A->Destroy();BossFanTelegraphs.Empty();
}
bool AAlchemyWorld::StartBossEncounter() {
    if(bBossSpawned) return true;
    BossArenaCenter=PlayerPos;
    // Find a legal boss position before granting any rewards: a retry cannot pay twice.
    const int Before=Enemies.Num();SpawnEnemy(10);
    if(Enemies.Num()==Before) return false;
    CloseMerchant();
    bBossSpawned=true;BossClearCount=0;bCollectBossRewards=true;
    for(int I=Enemies.Num()-1;I>=0;I--) if(Enemies[I].Type!=10) {
        const auto E=Enemies[I];RewardEnemy(E);Kills++;BossClearCount++;
        E.Body->Destroy();E.Shadow->Destroy();Enemies.RemoveAtSwap(I);
    }
    for(const auto& D:Drops) {CollectDrop(D.Kind,D.Count,true);D.Body->Destroy();}Drops.Empty();
    bCollectBossRewards=false;
    for(auto& S:Shots) {if(S.Trail.IsValid()) S.Trail->DestroyComponent();S.Body->Destroy();}Shots.Empty();
    for(auto& E:Effects) E.Body->Destroy();Effects.Empty();
    for(auto& FX:NiagaraFX) if(IsValid(FX.Component)) FX.Component->DestroyComponent();NiagaraFX.Empty();
    bBossArenaActive=true;
    auto& Boss=Enemies[0];Boss.AttackCD=2.2f;
    BossArenaRing=Mesh(TEXT("Plane"),BossArenaCenter+FVector(0,0,12),FVector(BossArenaRadius/50,BossArenaRadius/50,1),Gold);
    BossArenaRing->GetStaticMeshComponent()->SetMaterial(0,Material(TEXT("M_ArenaRing")));
    BossArenaRing->GetStaticMeshComponent()->SetCastShadow(false);
    Message(FString::Printf(TEXT("BOSS 封锁战场 · 清场 %d 只，素材与金币已入库（本次可超容量）"),BossClearCount));
    UE_LOG(LogTemp,Display,TEXT("BOSS_BEGIN cleared=%d coins=%d materials=%d,%d,%d,%d,%d,%d radius=%.0f"),BossClearCount,RunCoins,Inventory[0],Inventory[1],Inventory[2],Inventory[3],Inventory[4],Inventory[5],BossArenaRadius);
    return true;
}
void AAlchemyWorld::UpdateBoss(FAlchemyEnemy& E,float Dt) {
    if(bGreyfordFlow && GreyfordStage==2){UpdatePlannedBoss(E,Dt);return;}
    if(!Panel.IsEmpty()) return;
    if(E.HP<=E.MaxHP*.5f && !E.Phase2) {
        E.Phase2=true;E.Transition=2;E.Windup=E.BossActive=0;
        ClearBossTelegraphs();
        Message(TEXT("腐化之源 · 二阶段：冲刺加速，弹幕增密"));
    }
    if(E.Transition>0) {E.Transition=FMath::Max(0.f,E.Transition-Dt);return;}
    if(E.BossActive>0) {
        const float Step=FMath::Min(Dt,E.BossActive);E.BossActive-=Step;
        const FVector Before=E.Pos;
        E.Pos=Move(E.Pos,E.DashDirection*(E.Phase2?1700.f:1350.f)*Step,EnemyRadius(10));
        const FVector Segment=E.Pos-Before;
        const float T=FMath::Clamp(FVector::DotProduct(PlayerPos-Before,Segment)/FMath::Max(1.f,Segment.SizeSquared2D()),0.f,1.f);
        if(!E.BossDashHit && FVector::Dist2D(Before+Segment*T,PlayerPos)<155) {Hurt(28);E.BossDashHit=true;}
        if(E.Pos.Equals(Before,.1f)) E.BossActive=0;
        return;
    }
    if(E.Windup>0) {
        E.Windup=FMath::Max(0.f,E.Windup-Dt);
        if(E.Windup>0) return;
        ClearBossTelegraphs();
        BossAttackCounts[E.BossAttack]++;
        const FVector D=(E.Aim-E.Pos).GetSafeNormal2D();
        if(E.BossAttack==0) {E.BossActive=.85f;E.DashDirection=D;E.BossDashHit=false;}
        else if(E.BossAttack==1) {
            const int N=E.Phase2?11:7;
            for(int I=0;I<N;I++) Fire(E.Pos,E.Pos+D.RotateAngleAxis(FMath::Lerp(-65.f,65.f,I/float(N-1)),FVector::UpVector)*500,14,FLinearColor(.8f,.25f,.8f),true,E.Phase2?480:400,nullptr,nullptr,5);
        } else {
            // A broad travelling wave, not an instant full-line hit. Side-step the marked lane.
            for(int I=-2;I<=2;I++) {
                const FVector Side=FVector(-D.Y,D.X,0)*I*42;
                Fire(E.Pos+Side,E.Pos+Side+D*1000,24,FLinearColor(1,.48f,.13f),true,E.Phase2?1000:780,nullptr,nullptr,3);
                Shots.Last().Body->SetActorScale3D(FVector(.54f,.4f,1));
            }
        }
        E.AttackCD=E.Phase2?1.8f:2.6f;return;
    }
    E.AttackCD-=Dt;
    if(E.AttackCD<=0) {
        E.BossAttack=E.BossSequence++%3;E.Aim=PlayerPos;
        if(FVector::DistSquared2D(E.Aim,E.Pos)<1) E.Aim=E.Pos+FVector(1,0,0);
        E.Windup=E.BossAttack==0?1.1f:E.BossAttack==1?1.25f:1.35f;
        const FVector D=(E.Aim-E.Pos).GetSafeNormal2D();
        const float Length=1800;
        const float Width=E.BossAttack==0?310.f:E.BossAttack==1?126.f:300.f;
        BossTelegraph=Mesh(TEXT("Plane"),E.Pos+D*Length*.5f+FVector(0,0,14),FVector(Length/100,Width/100,1),Gold);
        BossTelegraph->SetActorRotation(FRotator(0,D.Rotation().Yaw,0));
        auto M=UMaterialInstanceDynamic::Create(Material(TEXT("M_ThreatLane")),this);
        M->SetVectorParameterValue(TEXT("Tint"),E.BossAttack==1?FLinearColor(.75f,.2f,.85f):FLinearColor(1,.38f,.08f));
        BossTelegraph->GetStaticMeshComponent()->SetMaterial(0,M);BossTelegraph->GetStaticMeshComponent()->SetCastShadow(false);
        if(E.BossAttack==1) {
            const int N=E.Phase2?11:7;
            for(int I=0;I<N;I++) if(I!=N/2) {
                const FVector Ray=D.RotateAngleAxis(FMath::Lerp(-65.f,65.f,I/float(N-1)),FVector::UpVector);
                auto A=Mesh(TEXT("Plane"),E.Pos+Ray*Length*.5f+FVector(0,0,14),FVector(Length/100,Width/100,1),Gold);
                A->SetActorRotation(FRotator(0,Ray.Rotation().Yaw,0));A->GetStaticMeshComponent()->SetMaterial(0,M);BossFanTelegraphs.Add(A);
            }
        }
    } else if(FVector::Dist2D(E.Pos,PlayerPos)>700) Chase(E,Dt);
}

void AAlchemyWorld::UpdateBossVisual(FAlchemyEnemy& E) {
    const float Width=300*(1+.06f*E.HitFlash/.1f),Height=350*(1-.04f*E.HitFlash/.1f);
    const FVector Facing=(bGreyfordFlow && GreyfordStage==2 && (E.PlannedLocked || E.PlannedState==2))?E.DashDirection:PlayerPos-E.Pos;
    UpdateSprite(E.Body,TEXT("BossCorruption"),E.Pos,Width,Height,Facing.X<0);
    // Sprite-gen's 432px baseline on a 448px canvas stays fixed during hit squash.
    E.Body->SetActorLocation(E.Pos+Camera->GetActorUpVector()*(208.f/448*Height));
    E.Shadow->SetActorLocation(E.Pos+FVector(0,0,4));
}
void AAlchemyWorld::BossSmoke(float Dt) {
    if(VisualTime<.5f || CaptureStep) return;CaptureStep=1;
    bool OK=true;
    auto Check=[&](bool Pass,const TCHAR* Name) {OK&=Pass;UE_LOG(LogTemp,Display,TEXT("BOSS_CHECK %s %s"),Name,Pass?TEXT("PASS"):TEXT("FAIL"));};
    Progress->TutorialComplete=true;StartRun();
    SpawnEnemy(7);SpawnEnemy(8);
    Inventory={10,10,10,0,0,0};Drop(FVector(4000,0,0),0,4);Drop(FVector(4000,0,0),-1,7);
    const int Count=Enemies.Num();
    Check(StartBossEncounter(),TEXT("entry"));
    Check(BossClearCount==Count && Enemies.Num()==1 && Enemies[0].Type==10,TEXT("clears_all_mobs_and_elites"));
    Check(Drops.IsEmpty() && Inventory[0]>=14 && Inventory[3]==1 && Inventory[4]==1 && RunCoins>=27,TEXT("all_loot_transferred_without_cap_loss"));
    Check(PendingLevelUps>0,TEXT("xp_rewards_preserve_levelup_choices"));
    const int FirstChoice=LevelupChoices[0],SecondChoice=LevelupChoices[1],ThirdChoice=LevelupChoices[2];
    Panel=TEXT("codex");Action(TEXT("close"));RollLevelupChoices();
    Check(FirstChoice==LevelupChoices[0] && SecondChoice==LevelupChoices[1] && ThirdChoice==LevelupChoices[2],TEXT("reopen_does_not_reroll_upgrade_choices"));
    const int Coins=RunCoins;const auto BagBefore=Inventory;
    StartBossEncounter();Check(RunCoins==Coins && Inventory==BagBefore,TEXT("entry_pays_once"));
    const int EnemyCount=Enemies.Num();SpawnWave();SpawnEnemy(7);
    Check(Enemies.Num()==EnemyCount,TEXT("waves_and_elites_blocked"));
    bool Contained=true;
    for(int I=0;I<16;I++) {
        FVector D(FMath::Cos(I*PI/8),FMath::Sin(I*PI/8),0);
        Contained&=!Walkable(BossArenaCenter+D*(BossArenaRadius+1),0);
        Contained&=FVector::Dist2D(Move(BossArenaCenter,D*8000,45),BossArenaCenter)<=BossArenaRadius-44;
    }
    Check(Contained,TEXT("circle_blocks_walk_and_dash"));
    while(PendingLevelUps>0) {const int Old=PendingLevelUps;Action(FString::Printf(TEXT("pick%d"),LevelupChoices[0]));if(Old==PendingLevelUps) break;}
    Check(PendingLevelUps==0,TEXT("all_queued_choices_resolve"));Panel.Empty();
    auto& E=Enemies[0];E.AttackCD=0;UpdateBoss(E,.01f);
    UpdateBossVisual(E);Check((E.Body->GetActorLocation()-E.Pos).Equals(Camera->GetActorUpVector()*(208.f/448*350),.01f),TEXT("boss_feet_keep_sprite_baseline"));
    const float Windup=E.Windup;const int ShotsBefore=Shots.Num();Panel=TEXT("pause");UpdateBoss(E,.7f);
    Check(E.Windup==Windup && Shots.Num()==ShotsBefore,TEXT("pause_freezes_boss"));Panel.Empty();
    for(int Phase=0;Phase<2;Phase++) {
        if(Phase==1) {
            E.HP=E.MaxHP*.5f;UpdateBoss(E,.01f);
            Check(E.Phase2 && E.Transition>0,TEXT("half_health_transition"));UpdateBoss(E,2.1f);
        }
        for(int Attack=0;Attack<3;Attack++) {
            E.BossSequence=Attack;E.Windup=E.BossActive=0;E.AttackCD=0;
            const int Before=BossAttackCounts[Attack];UpdateBoss(E,.01f);
            Check(E.Windup>=1 && IsValid(BossTelegraph),TEXT("every_attack_has_telegraph"));
            UpdateBoss(E,E.Windup+.01f);
            Check(BossAttackCounts[Attack]==Before+1,TEXT("attack_fires_after_windup"));
        }
    }
    Check(Shots.Num()==28,TEXT("phase1_7_phase2_11_bullets_and_two_5_wide_waves"));
    E.Windup=0;E.BossActive=1;E.Pos=BossArenaCenter-FVector(450,0,0);E.DashDirection=FVector(1,0,0);E.BossDashHit=false;
    PlayerPos=BossArenaCenter;HP=MaxHP;HurtInv=DodgeInv=0;const float BeforeHP=HP;
    UpdateBoss(E,.7f);Check(E.BossDashHit && HP<BeforeHP,TEXT("dash_sweep_hits_without_tunnelling"));
    CollectDrop(0,1);Check(Inventory[0]>=14,TEXT("ordinary_pickup_never_truncates_boss_supplies"));
    EndBossArena();Check(!bBossArenaActive && !IsValid(BossArenaRing) && !IsValid(BossTelegraph),TEXT("arena_releases_on_end"));
    const FString Folder=FPaths::ProjectDir()/TEXT("Evidence/Boss20261029");IFileManager::Get().MakeDirectory(*Folder,true);
    FFileHelper::SaveStringToFile(FString::Printf(TEXT("{\"result\":\"%s\",\"cleared\":%d,\"attack_counts\":[%d,%d,%d],\"hostile_shots\":%d}\n"),OK?TEXT("PASS"):TEXT("FAIL"),BossClearCount,BossAttackCounts[0],BossAttackCounts[1],BossAttackCounts[2],Shots.Num()),*(Folder/TEXT("verification.json")));
    UE_LOG(LogTemp,Display,TEXT("ALCHEMY_BOSS_%s"),OK?TEXT("PASS"):TEXT("FAIL"));FPlatformMisc::RequestExitWithStatus(false,OK?0:1);
}

void AAlchemyWorld::BossPresentationCapture(float Dt) {
    const float Time=VisualTime-4; // Let initial shader and texture uploads settle before capture.
    auto Shot=[&](const TCHAR* Name) {
        int X=0,Y=0;GetWorld()->GetFirstPlayerController()->GetViewportSize(X,Y);
        const FString Folder=FPaths::ProjectDir()/FString::Printf(TEXT("Evidence/Boss20261029/%dx%d"),X,Y);
        IFileManager::Get().MakeDirectory(*Folder,true);FScreenshotRequest::RequestScreenshot(Folder/Name,false,false);
    };
    if(CaptureStep==0 && Time>.5f) {
        Progress->TutorialComplete=true;StartRun();RunTime=310;ViewWidth=3600;CaptureStep=1;
    } else if(CaptureStep==1 && bBossSpawned) {
        PendingLevelUps=0;Panel.Empty();SpawnCD=10000;HurtInv=0;
        for(float& CD:SkillCD) CD=10000;
        auto& E=Enemies[0];E.Pos=BossArenaCenter-FVector(450,0,0);E.AttackCD=0;E.BossSequence=0;
        PlayerPos=BossArenaCenter+FVector(230,120,0);ToastTime=0;CaptureStep=2;
    } else if(CaptureStep==2 && Time>1.2f) {Shot(TEXT("01_DashWarning.png"));CaptureStep=3;}
    else if(CaptureStep==3 && Time>2) {Shot(TEXT("02_Dash.png"));CaptureStep=4;}
    else if(CaptureStep==4 && Time>2.6f) {
        auto& E=Enemies[0];E.Pos=BossArenaCenter-FVector(450,0,0);E.BossActive=E.Windup=0;E.AttackCD=0;E.BossSequence=1;CaptureStep=5;
    } else if(CaptureStep==5 && Time>3.2f) {Shot(TEXT("03_BarrageWarning.png"));CaptureStep=6;}
    else if(CaptureStep==6 && Time>4.2f) {Shot(TEXT("04_Barrage.png"));CaptureStep=7;}
    else if(CaptureStep==7 && Time>4.8f) {
        auto& E=Enemies[0];E.Pos=BossArenaCenter-FVector(450,0,0);E.Phase2=true;E.HP=E.MaxHP*.5f;E.BossActive=E.Windup=E.Transition=0;E.AttackCD=0;E.BossSequence=2;CaptureStep=8;
    } else if(CaptureStep==8 && Time>5.4f) {Shot(TEXT("05_WaveWarning.png"));CaptureStep=9;}
    else if(CaptureStep==9 && Time>6.5f) {Shot(TEXT("06_Shockwave.png"));CaptureStep=10;}
    else if(CaptureStep==10 && Time>7.2f) {UE_LOG(LogTemp,Display,TEXT("ALCHEMY_BOSS_CAPTURE_PASS"));FPlatformMisc::RequestExitWithStatus(false,0);CaptureStep=11;}
}
