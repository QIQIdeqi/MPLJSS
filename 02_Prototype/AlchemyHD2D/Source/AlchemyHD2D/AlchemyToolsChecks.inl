bool AAlchemyWorld::CheckDesignRuntime() {
    const auto SavedSkill=RuntimeSkills[0];const auto SavedRecipe=RuntimeRecipes[0];const auto SavedQuality=RuntimeQuality[0];const auto SavedChain=RuntimeChains[0];
    const int Talent=Progress->Talents[1];Progress->Talents[1]=0;Progress->TutorialComplete=true;StartRun();
    for(auto& E:Enemies) {E.Body->Destroy();E.Shadow->Destroy();}Enemies.Empty();SpawnEnemy(0);Enemies[0].Pos=FVector(200,0,0);Enemies[0].HP=Enemies[0].MaxHP=10000;
    auto& S=RuntimeSkills[0];S.Damage=123;S.CD=2.25f;S.ProjectileSpeed=321;S.HitEffect=BlastFX;SkillCD[0]=0;CastSkills(.01f);
    bool OK=Shots.Num()>0 && Shots.Last().Damage==123 && FMath::IsNearlyEqual(Shots.Last().Velocity.Size(),321.,.01) && Shots.Last().HitEffect==BlastFX && FMath::IsNearlyEqual(SkillCD[0],2.25f);
    Enemies[0].Slow=0;SlowEnemy(0,.8f,.9f);OK &= FMath::IsNearlyEqual(Enemies[0].SlowFactor,.9f) && FMath::IsNearlyEqual(Enemies[0].Slow,.8f);
    SlowEnemy(0,.3f,.95f);OK &= FMath::IsNearlyEqual(Enemies[0].SlowFactor,.9f);
    SlowEnemy(0,.1f,.5f);SlowEnemy(0,0,.05f);OK &= FMath::IsNearlyEqual(Enemies[0].SlowFactor,.5f) && FMath::IsNearlyEqual(Enemies[0].Slow,.8f);
    const int Added=RuntimeSkills.Num();RuntimeSkills.Add(SavedSkill);RuntimeSkills.Last().Name=TEXT("Editor appended test skill");Levels.Add(0);SkillCD.Add(999);
    RuntimeRecipes[0].LowSkill=Added;RuntimeQuality[0].Low=5;RuntimeQuality[0].Mid=15;RuntimeQuality[0].High=80;
    Inventory={10,10,10,0,0,0};Selected={3,0,0,0,0,0};TArray<int> O;TArray<float> W;FString Reason;int Combination=-1;
    bool Craftable=CraftOptions(O,W,Reason,Combination);int At=O.Find(Added);OK &= Craftable && At>=0 && FMath::IsNearlyEqual(W[At],5.f,.001f);
    RuntimeQuality[0].Low=0;RuntimeQuality[0].Mid=0;RuntimeQuality[0].High=1;Levels[RuntimeRecipes[0].HighSkill]=5;
    OK &= !CraftOptions(O,W,Reason,Combination);Levels[RuntimeRecipes[0].HighSkill]=0;
    RuntimeChains[0].A=0;RuntimeChains[0].B=Added;RuntimeChains[0].Damage=211;RuntimeChains[0].Targets=0;RuntimeChains[0].Radius=500;
    Equipped={0,Added};SkillCD[0]=999;ChainCD[0]=0;float Before=Enemies[0].HP;CastSkills(.01f);OK &= FMath::IsNearlyEqual(Before-Enemies[0].HP,211.f,.01f);
    for(int K=-1;K<=8;K++) {Drop(FVector(0,-500,0),K);auto* Body=Drops.Last().Body;OK &= Body && Body->GetActorScale3D().X>=.949f && Body->GetStaticMeshComponent()->GetMaterial(0)!=nullptr;}
    OK &= Designer && Obstacles.Num()==8;
    RuntimeSkills[0]=SavedSkill;RuntimeSkills.RemoveAt(Added);Levels.RemoveAt(Added);SkillCD.RemoveAt(Added);
    RuntimeRecipes[0]=SavedRecipe;RuntimeQuality[0]=SavedQuality;RuntimeChains[0]=SavedChain;Progress->Talents[1]=Talent;
    StartRun();return OK;
}
void AAlchemyWorld::CaptureTools(float Dt) {
    if(VisualTime<2) return;
    if(CaptureStep==0) {
        StartRun();Progress->TutorialComplete=true;ToastTime=0;SmokeTime=0;
        for(auto& E:Enemies) {E.Body->Destroy();E.Shadow->Destroy();}Enemies.Empty();
        for(int Type:{0,7,10}) SpawnEnemy(Type);
        Enemies[0].Pos=FVector(-550,150,0);Enemies[1].Pos=FVector(0,400,0);Enemies[2].Pos=FVector(650,300,0);
        Enemies[0].HP=Enemies[0].MaxHP*.5f;Enemies[1].HP=Enemies[1].MaxHP*.75f;Enemies[2].HP=4500;
        RunTime=315;bBossSpawned=true;
        for(int K=-1;K<=8;K++) Drop(FVector((K%5-2)*280,-450-(K/5)*270,0),K);
        CaptureStep=1;
    }
    SmokeTime+=Dt;UpdateCamera(0);
    for(auto& E:Enemies) {const float Scale=E.Type==10?3:E.Type>=7?2:1;UpdateSprite(E.Body,FString::Printf(TEXT("Enemy%d"),FMath::Min(E.Type,9)),E.Pos,100*Scale,100*Scale);E.Shadow->SetActorLocation(E.Pos+FVector(0,0,4));}
    if(CaptureStep==1 && SmokeTime>.6f) {
        FScreenshotRequest::RequestScreenshot(FPaths::ProjectDir()/TEXT("Evidence/Tools_HUD_Drops.png"),false,false);CaptureStep=2;
    } else if(CaptureStep==2 && SmokeTime>1.2f) {
        bool OK=RenderedEliteBars==1 && RenderedBossBarY==102 && Drops.Num()==10 && Designer!=nullptr;
        UE_LOG(LogTemp,Display,TEXT("ALCHEMY_TOOL_CAPTURE_%s elite_bars=%d boss_y=%d drops=%d"),OK?TEXT("PASS"):TEXT("FAIL"),RenderedEliteBars,RenderedBossBarY,Drops.Num());
        FPlatformMisc::RequestExitWithStatus(false,OK?0:1);CaptureStep=3;
    }
}
