// Bounded bot observation. No resource/HP/time/spawn overrides and no success target.
namespace {
struct FTeachingJourneyObservation {
    bool Started=false,Failed=false,Finished=false,WasStuck=false,IntendedMove=false,HasGoal=false;
    int Seed=77,Width=0,Height=0,CraftPhase=0,Patrol=0,BlockedPaths=0,StuckEvents=0;
    float Elapsed=0,NextSample=0,Repath=0,StuckTime=0,ReadyElapsed=-1;
    float FirstAny=-1,FirstKind[3]={-1,-1,-1},FirstGround[3]={-1,-1,-1},FirstReady=-1,FirstHUDReady=-1,FirstField=-1,FirstCraft=-1,FirstAccept=-1,FirstComplete=-1;
    double WallStart=0;
    float InitialHP=-1,InitialMaxHP=-1;FVector InitialPosition=FVector::ZeroVector;
    int LastInventory[3]={0,0,0};FVector LastPosition=FVector::ZeroVector,Goal=FVector::ZeroVector;
    TArray<FVector> Path;
    TArray<TSharedPtr<FJsonValue>> Samples,Events,InitialEnemies;
    FString Navigation=TEXT("none");
};
FTeachingJourneyObservation TeachingObservation;
void TeachingEvent(const FString& Name,float Time,int Value=0){
    auto E=MakeShared<FJsonObject>();E->SetStringField(TEXT("event"),Name);E->SetNumberField(TEXT("runTime"),Time);E->SetNumberField(TEXT("value"),Value);
    TeachingObservation.Events.Add(MakeShared<FJsonValueObject>(E));
}
}

bool AAlchemyWorld::TeachingJourneyCheck(float Dt) {
    auto& J=TeachingObservation;auto PC=GetWorld()->GetFirstPlayerController();if(!PC || !Player)return true;
    if(!J.Started){
        int W=0,H=0;PC->GetViewportSize(W,H);if(W<=0 || H<=0)return true;
        J=FTeachingJourneyObservation();J.Started=true;J.Width=W;J.Height=H;J.WallStart=FPlatformTime::Seconds();FParse::Value(FCommandLine::Get(),TEXT("JourneySeed="),J.Seed);
        J.Failed=!bCapture;
        if(bCapture){Progress=NewObject<UAlchemyProgress>(this);MigrateProgress(false);Progress->TutorialComplete=false;Random.Initialize(J.Seed);StartRun();}
        J.InitialHP=HP;J.InitialMaxHP=MaxHP;J.InitialPosition=PlayerPos;
        for(const auto& Enemy:Enemies){auto E=MakeShared<FJsonObject>();E->SetNumberField(TEXT("definition"),Enemy.Definition);E->SetNumberField(TEXT("type"),Enemy.Type);E->SetNumberField(TEXT("hp"),Enemy.HP);E->SetNumberField(TEXT("x"),Enemy.Pos.X);E->SetNumberField(TEXT("y"),Enemy.Pos.Y);J.InitialEnemies.Add(MakeShared<FJsonValueObject>(E));}
        J.LastPosition=PlayerPos;
        UE_LOG(LogTemp,Display,TEXT("TEACHING_JOURNEY_START seed=%d viewport=%dx%d bounded_run_seconds=120 bot_ready_reaction=.25 no_HP_resource_time_spawn_injection=1"),J.Seed,W,H);
    }
    if(J.Finished)return true;
    J.Elapsed+=Dt;TeachingJourneyDodge=false;
    const bool Valid=bCapture && Progress && Progress->SchemaVersion==3 && Inventory.Num()==6 && Selected.Num()==6
        && FMath::IsFinite(RunTime) && RunTime>=0 && FMath::IsFinite(HP) && FMath::IsFinite(MaxHP) && MaxHP>0 && HP>=0 && HP<=MaxHP+.01f;
    if(!Valid){J.Failed=true;TeachingEvent(TEXT("schema_or_state_invariant_failed"),RunTime);}
    if(Valid){
        for(int M=0;M<3;M++){
            if(Inventory[M]>0 && J.FirstKind[M]<0){J.FirstKind[M]=RunTime;if(J.FirstAny<0)J.FirstAny=RunTime;TeachingEvent(FString::Printf(TEXT("first_inventory_kind_%d"),M),RunTime,Inventory[M]);}
            if(Inventory[M]!=J.LastInventory[M]){TeachingEvent(FString::Printf(TEXT("inventory_kind_%d_delta"),M),RunTime,Inventory[M]-J.LastInventory[M]);J.LastInventory[M]=Inventory[M];}
        }
        const bool Ready=Inventory[0]>0 && Inventory[1]>0 && Inventory[2]>0;
        if(Ready && J.FirstReady<0){J.FirstReady=RunTime;J.ReadyElapsed=J.Elapsed;TeachingEvent(TEXT("inventory_ready_inferred"),RunTime);}
        if(auto HUD=Cast<AAlchemyHUD>(PC->GetHUD()))if(J.FirstHUDReady<0 && HUD->UIV02DrawnText.Contains(TEXT("材料已齐！按 Q，尝试第一次炼金。"))){J.FirstHUDReady=RunTime;TeachingEvent(TEXT("actual_HUD_ready_text_observed"),RunTime);}
        if(J.Elapsed>=J.NextSample || bRunEnded || Progress->TutorialComplete){
            J.NextSample=J.Elapsed+.25f;TArray<TSharedPtr<FJsonValue>> InventoryJSON,AvailableJSON,DistanceJSON;
            bool AllAvailable=true;
            for(int M=0;M<3;M++){
                bool Available=Inventory[M]>0,OnGround=false;float Nearest=-1;
                for(const auto& D:Drops)if(D.Kind==M && D.Count>0){TArray<FVector> Route;if(FindPath(PlayerPos,D.Pos,45,Route)){Available=true;OnGround=true;if(Inventory[M]<=0){const float Distance=FVector::Dist2D(PlayerPos,D.Pos);if(Nearest<0 || Distance<Nearest)Nearest=Distance;}}}
                if(OnGround && J.FirstGround[M]<0)J.FirstGround[M]=RunTime;
                InventoryJSON.Add(MakeShared<FJsonValueNumber>(Inventory[M]));AvailableJSON.Add(MakeShared<FJsonValueBoolean>(Available));DistanceJSON.Add(MakeShared<FJsonValueNumber>(Nearest));AllAvailable &= Available;
            }
            if(AllAvailable && J.FirstField<0){J.FirstField=RunTime;TeachingEvent(TEXT("all_kinds_available_in_inventory_or_reachable_ground"),RunTime);}
            auto Sample=MakeShared<FJsonObject>();Sample->SetNumberField(TEXT("runTime"),RunTime);Sample->SetNumberField(TEXT("observedElapsed"),J.Elapsed);
            Sample->SetNumberField(TEXT("hp"),HP);Sample->SetNumberField(TEXT("kills"),Kills);Sample->SetNumberField(TEXT("enemies"),Enemies.Num());
            Sample->SetNumberField(TEXT("x"),PlayerPos.X);Sample->SetNumberField(TEXT("y"),PlayerPos.Y);Sample->SetStringField(TEXT("panel"),Panel);Sample->SetStringField(TEXT("navigation"),J.Navigation);
            Sample->SetArrayField(TEXT("inventory"),InventoryJSON);Sample->SetArrayField(TEXT("fieldAvailable"),AvailableJSON);Sample->SetArrayField(TEXT("nearestReachableMissingKindDistanceCm"),DistanceJSON);Sample->SetBoolField(TEXT("inventoryReady"),Ready);
            J.Samples.Add(MakeShared<FJsonValueObject>(Sample));
        }
        if(Panel.IsEmpty() && J.IntendedMove && FVector::Dist2D(PlayerPos,J.LastPosition)<.1f){
            J.StuckTime+=Dt;if(J.StuckTime>=2 && !J.WasStuck){J.WasStuck=true;J.StuckEvents++;TeachingEvent(TEXT("movement_intent_blocked_for_two_seconds"),RunTime);}
        }else{J.StuckTime=0;J.WasStuck=false;}
        J.LastPosition=PlayerPos;J.IntendedMove=false;
    }
    const bool Complete=Valid && Progress->TutorialComplete;
    const bool Dead=Valid && (HP<=0 || bRunEnded);
    if(J.Failed || Complete || Dead || RunTime>=120){
        if(Complete)J.FirstComplete=RunTime;
        const FString Outcome=J.Failed?TEXT("invariant_failure"):Complete?TEXT("complete"):Dead?TEXT("death"):TEXT("timebox");
        auto Result=MakeShared<FJsonObject>();Result->SetNumberField(TEXT("schemaVersion"),1);Result->SetStringField(TEXT("outcome"),Outcome);Result->SetBoolField(TEXT("invariantOK"),!J.Failed);
        Result->SetNumberField(TEXT("seed"),J.Seed);Result->SetNumberField(TEXT("width"),J.Width);Result->SetNumberField(TEXT("height"),J.Height);Result->SetNumberField(TEXT("runTime"),RunTime);Result->SetNumberField(TEXT("observedElapsed"),J.Elapsed);Result->SetNumberField(TEXT("wallElapsedIncludingStartRunSetup"),FPlatformTime::Seconds()-J.WallStart);Result->SetNumberField(TEXT("hp"),HP);Result->SetNumberField(TEXT("kills"),Kills);
        auto Initial=MakeShared<FJsonObject>();Initial->SetNumberField(TEXT("hp"),J.InitialHP);Initial->SetNumberField(TEXT("maxHP"),J.InitialMaxHP);Initial->SetNumberField(TEXT("playerX"),J.InitialPosition.X);Initial->SetNumberField(TEXT("playerY"),J.InitialPosition.Y);Initial->SetNumberField(TEXT("enemyCount"),J.InitialEnemies.Num());Initial->SetArrayField(TEXT("enemies"),J.InitialEnemies);Result->SetObjectField(TEXT("initialProductionState"),Initial);
        Result->SetNumberField(TEXT("unobservedTimeSentinel"),-1);Result->SetStringField(TEXT("timeUnits"),TEXT("seconds of production RunTime; observedElapsed also includes bot menu frames"));
        Result->SetStringField(TEXT("strategy"),TEXT("bot: viewport-visible missing-material drops first; native FindPath45 replanned at most every .5s; fixed reference patrol targets; eight camera-relative movement directions; pre-AoE 300-500cm band and dodge below160; post-AoE 140-180cm band and emergency dodge below90; first upgrade option; ready reaction at least .25 observed seconds; production Action menus are fast bot actions, not physical keyboard or human reaction. No teleport, clear, HP, resource, probability, timer or wave overrides."));
        Result->SetStringField(TEXT("firstAnyMeaning"),TEXT("first ordinary material observed entering Inventory; fieldAvailable includes reachable offscreen drops and is not HUD readiness"));
        Result->SetNumberField(TEXT("fieldSamplingPeriodSeconds"),.25);Result->SetStringField(TEXT("samplingNote"),TEXT("ground/field first times are sampled every .25 observed seconds plus frame quantization; inventory is checked every helper tick; HUD text comes from the previous rendered frame. firstFieldAvailable requires all three at the same sample, not the max of historical first times. Equal seeds across viewports do not imply identical drop sequences."));
        Result->SetNumberField(TEXT("firstAny"),J.FirstAny);TArray<TSharedPtr<FJsonValue>> FirstKinds;for(float T:J.FirstKind)FirstKinds.Add(MakeShared<FJsonValueNumber>(T));Result->SetArrayField(TEXT("firstPerKind"),FirstKinds);
        TArray<TSharedPtr<FJsonValue>> FirstGround;for(float T:J.FirstGround)FirstGround.Add(MakeShared<FJsonValueNumber>(T));Result->SetArrayField(TEXT("firstEachReachableGround"),FirstGround);
        Result->SetNumberField(TEXT("firstFieldAvailable"),J.FirstField);Result->SetNumberField(TEXT("firstInventoryReady"),J.FirstReady);Result->SetNumberField(TEXT("firstActualHUDReadyText"),J.FirstHUDReady);Result->SetNumberField(TEXT("firstCraft"),J.FirstCraft);Result->SetNumberField(TEXT("firstAccept"),J.FirstAccept);Result->SetNumberField(TEXT("firstTutorialComplete"),J.FirstComplete);
        Result->SetStringField(TEXT("firstCraftWindow"),J.FirstCraft<0?TEXT("unobserved"):J.FirstCraft<40?TEXT("before40"):J.FirstCraft<=60?TEXT("40to60"):TEXT("after60"));
        auto Navigation=MakeShared<FJsonObject>();Navigation->SetStringField(TEXT("kind"),J.Navigation);Navigation->SetBoolField(TEXT("hasGoal"),J.HasGoal);Navigation->SetNumberField(TEXT("goalX"),J.Goal.X);Navigation->SetNumberField(TEXT("goalY"),J.Goal.Y);Navigation->SetNumberField(TEXT("remainingPathPoints"),J.Path.Num());Navigation->SetNumberField(TEXT("stuckSeconds"),J.StuckTime);Result->SetObjectField(TEXT("lastNavigation"),Navigation);
        Result->SetNumberField(TEXT("blockedPathAttempts"),J.BlockedPaths);Result->SetNumberField(TEXT("stuckEvents"),J.StuckEvents);Result->SetArrayField(TEXT("samples"),J.Samples);Result->SetArrayField(TEXT("events"),J.Events);
        const FString Dir=FPaths::ProjectDir()/TEXT("Evidence/TeachingJourney_20261101")/FString::Printf(TEXT("%dx%d/seed_%d"),J.Width,J.Height,J.Seed);IFileManager::Get().MakeDirectory(*Dir,true);
        FString JSON;auto Writer=TJsonWriterFactory<>::Create(&JSON);FJsonSerializer::Serialize(Result,Writer);
        if(!FFileHelper::SaveStringToFile(JSON,*(Dir/TEXT("journey.json"))))J.Failed=true;
        if(J.Failed)UE_LOG(LogTemp,Error,TEXT("TEACHING_JOURNEY_FAIL schema_state_or_output_invariant"));
        UE_LOG(LogTemp,Display,TEXT("TEACHING_JOURNEY_DONE outcome=%s seed=%d seconds=%.3f hp=%.1f kills=%d inventoryReady=%.3f actualHUDReady=%.3f craft=%.3f accept=%.3f complete=%.3f"),*Outcome,J.Seed,RunTime,HP,Kills,J.FirstReady,J.FirstHUDReady,J.FirstCraft,J.FirstAccept,J.FirstComplete);
        J.Finished=true;FPlatformMisc::RequestExitWithStatus(false,J.Failed?1:0);return true;
    }
    if(Panel==TEXT("levelup")){
        for(int Choice:LevelupChoices)if(Choice>=0){TeachingEvent(TEXT("bot_production_pick_first_upgrade"),RunTime,Choice);Action(FString::Printf(TEXT("pick%d"),Choice));break;}return false;
    }
    if(J.CraftPhase==1){
        if(Panel==TEXT("alchemy")){
            for(int M=0;M<3;M++)AddMaterial(M);const int Before=CraftCount;Action(TEXT("craft"));
            if(CraftCount>Before && PendingResultSkill>=0){J.FirstCraft=RunTime;J.CraftPhase=2;TeachingEvent(TEXT("bot_production_craft"),RunTime,PendingResultSkill);}
            else{J.Failed=true;TeachingEvent(TEXT("ready_tutorial_craft_rejected"),RunTime);}return false;
        }
        J.CraftPhase=0;
    }
    if(J.CraftPhase==2 && PendingResultSkill>=0){
        Action(TEXT("acceptresult"));J.FirstAccept=RunTime;J.CraftPhase=3;TeachingEvent(TEXT("bot_production_accept"),RunTime,TutorialSkill);return false;
    }
    if(J.CraftPhase==0 && J.FirstReady>=0 && J.Elapsed-J.ReadyElapsed>=.25f){TogglePanel(TEXT("alchemy"));if(Panel==TEXT("alchemy")){J.CraftPhase=1;TeachingEvent(TEXT("bot_production_open_alchemy_after_reaction"),RunTime);}return false;}
    return false;
}

FVector AAlchemyWorld::TeachingJourneyDirection(float Dt,FVector Manual) {
    (void)Manual;
    auto& J=TeachingObservation;TeachingJourneyDodge=false;if(!J.Started || J.Finished || !bCombat || !Panel.IsEmpty())return FVector::ZeroVector;
    const int NearestEnemy=Nearest(PlayerPos,100000);const bool HasAOE=TutorialSkill>=0;
    const float EnemyDistance=Enemies.IsValidIndex(NearestEnemy)?float(FVector::Dist2D(PlayerPos,Enemies[NearestEnemy].Pos)):100000;
    const float Near=HasAOE?140:300,Far=HasAOE?180:500;
    bool HasDrop=false;
    J.Repath-=Dt;
    if(J.Repath<=0){
        J.Repath=.5f;J.Path.Empty();J.HasGoal=false;J.Navigation=TEXT("patrol");
        auto PC=GetWorld()->GetFirstPlayerController();int W=0,H=0;PC->GetViewportSize(W,H);TArray<int> DropsByDistance;
        for(int I=0;I<Drops.Num();I++)if(Drops[I].Kind>=0 && Drops[I].Kind<3 && Drops[I].Count>0 && Inventory[Drops[I].Kind]<=0){
            FVector2D Screen;if(PC->ProjectWorldLocationToScreen(Drops[I].Pos,Screen) && Screen.X>=0 && Screen.X<W && Screen.Y>=0 && Screen.Y<H)DropsByDistance.Add(I);
        }
        DropsByDistance.Sort([&](int A,int B){return FVector::DistSquared2D(PlayerPos,Drops[A].Pos)<FVector::DistSquared2D(PlayerPos,Drops[B].Pos);});
        for(int I=0;I<FMath::Min(16,DropsByDistance.Num());I++){
            const auto& D=Drops[DropsByDistance[I]];
            if(FindPath(PlayerPos,D.Pos,45,J.Path)){J.Navigation=TEXT("missing_drop");J.Goal=D.Pos;J.HasGoal=true;break;}J.BlockedPaths++;
        }
        if(J.Path.IsEmpty() && Enemies.IsValidIndex(NearestEnemy)){
            J.Navigation=TEXT("combat_band");const FVector Away=(PlayerPos-Enemies[NearestEnemy].Pos).GetSafeNormal2D();
            const FVector Goal=Enemies[NearestEnemy].Pos+Away*((Near+Far)*.5f);
            if(FindPath(PlayerPos,Goal,45,J.Path)){J.Goal=Goal;J.HasGoal=true;}
            else{J.BlockedPaths++;if(FindPath(PlayerPos,Enemies[NearestEnemy].Pos,45,J.Path)){J.Goal=Enemies[NearestEnemy].Pos;J.HasGoal=true;}}
        }
        if(J.Path.IsEmpty()){
            J.Navigation=TEXT("patrol");
            const FVector2D Nodes[]={{560,400},{1000,400},{1140,620},{700,700},{440,580}};
            for(int I=0;I<5;I++){
                const FVector Goal=BattleReferencePoint(Nodes[J.Patrol%5]);if(FVector::Dist2D(PlayerPos,Goal)<100){J.Patrol++;continue;}
                if(Walkable(Goal,45) && FindPath(PlayerPos,Goal,45,J.Path)){J.Goal=Goal;J.HasGoal=true;break;}J.Patrol++;J.BlockedPaths++;
            }
        }
    }
    HasDrop=J.Navigation==TEXT("missing_drop");
    while(!J.Path.IsEmpty() && FVector::Dist2D(PlayerPos,J.Path[0])<45)J.Path.RemoveAt(0);
    FVector Intent=J.Path.IsEmpty()?FVector::ZeroVector:(J.Path[0]-PlayerPos).GetSafeNormal2D();
    if(Enemies.IsValidIndex(NearestEnemy)){
        if(EnemyDistance<Near)Intent=(PlayerPos-Enemies[NearestEnemy].Pos).GetSafeNormal2D();
        else if(!HasDrop && EnemyDistance<=Far)Intent=FVector::ZeroVector;
        TeachingJourneyDodge=DodgeCD<=0 && EnemyDistance<(HasAOE?90:160);
    }
    if(Intent.IsNearlyZero()){J.IntendedMove=false;return FVector::ZeroVector;}
    const FVector Right=Camera->GetActorRightVector().GetSafeNormal2D(),Forward=Camera->GetActorForwardVector().GetSafeNormal2D();
    const float Angle=FMath::Atan2(FVector::DotProduct(Intent,Forward),FVector::DotProduct(Intent,Right));const int Octant=FMath::RoundToInt(Angle/(PI/4));
    const FVector Result=(Right*FMath::RoundToInt(FMath::Cos(Octant*PI/4))+Forward*FMath::RoundToInt(FMath::Sin(Octant*PI/4))).GetSafeNormal2D();J.IntendedMove=!Result.IsNearlyZero();return Result;
}
