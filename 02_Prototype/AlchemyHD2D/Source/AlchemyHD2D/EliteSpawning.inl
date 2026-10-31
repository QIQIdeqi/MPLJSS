// Natural elite scheduling only. Scripted SpawnEnemy keeps its synchronous placement rules.
namespace { constexpr float EliteWarningSeconds=1.5f; }
void AAlchemyWorld::ClearEliteWarning() {
    if(auto* Marker=EliteWarning.Marker.Get()){Scene.Remove(Marker);Marker->Destroy();}
    EliteWarning=FAlchemyEliteWarning();
}
bool AAlchemyWorld::EliteWarningPointSafe(int32 ID,FVector P,float MinDistance) const {
    if(!RuntimeEnemies.IsValidIndex(ID))return false;
    const auto& K=EnemyDefinition(ID);
    if(K.Archetype<7 || K.Archetype>9 || FVector::Dist2D(P,PlayerPos)<MinDistance || !Walkable(P,K.CollisionRadius))return false;
    TArray<FVector> Path;return FindPath(P,PlayerPos,K.CollisionRadius,Path);
}
bool AAlchemyWorld::FindVisibleEliteSpawn(int32 ID,FVector& Position) {
    if(!bBattleReference || !RuntimeEnemies.IsValidIndex(ID))return false;
    auto* PC=GetWorld()->GetFirstPlayerController();if(!PC)return false;
    int VX=0,VY=0;PC->GetViewportSize(VX,VY);if(VX<=0 || VY<=0)return false;
    const auto& K=EnemyDefinition(ID);
    const float Speed=500*(1+.03f*Progress->Talents[2]+.05f*RunAttrs[2]);
    // A full warning's movement plus one existing 280cm dodge; rechecked again at materialization.
    const float Distance=FMath::Max(900.f,K.CollisionRadius+45+Speed*EliteWarningSeconds+280);
    const auto Accept=[&](FVector2D Pixel){
        const FVector P=BattleReferencePoint(Pixel);
        if(!EliteWarningPointSafe(ID,P,Distance))return false;
        FBox2D Bounds(ForceInit);const FVector Up=bUprightSprites?FVector::UpVector:BattleUp();
        for(int X:{-1,1})for(int Y:{-1,1}){
            FVector2D Screen;
            if(!PC->ProjectWorldLocationToScreen(P+BattleUp()*(K.VisualSize.Y*.46f)+BattleRight()*(X*K.VisualSize.X*.5f)+Up*(Y*K.VisualSize.Y*.5f),Screen))return false;
            Bounds+=Screen;
        }
        // Keep the warning and complete future sprite clear of the HUD edges and equipment footer.
        if(Bounds.Min.X<VX*.08f || Bounds.Max.X>VX*.92f || Bounds.Min.Y<VY*.22f || Bounds.Max.Y>VY*.78f)return false;
        Position=P;return true;
    };
    // A finite grid gives stable coverage rather than repeatedly hoping a random point fits.
    constexpr int Cols=52,Rows=24,Count=Cols*Rows;
    const int First=Random.RandRange(0,Count-1);
    for(int I=0;I<Count;I++){const int Cell=(First+I)%Count;if(Accept({16.+32*(Cell%Cols),160.+32*(Cell/Cols)}))return true;}
    return false;
}
void AAlchemyWorld::UpdateEliteSpawning(float Dt) {
    if(!bCombat || bRunEnded || bBossSpawned || (bGreyfordFlow && GreyfordStage!=1)){ClearEliteWarning();return;}
    if(!Panel.IsEmpty())return;
    if(NextElite>=1800 || RunTime<NextElite-EliteWarningSeconds)return;
    if(EliteWarning.Retry>0){EliteWarning.Retry=FMath::Max(0.f,EliteWarning.Retry-Dt);if(EliteWarning.Retry>0)return;}
    if(EliteWarning.Definition<0){
        EliteWarning.Definition=ChooseEliteDefinition();
        if(EliteWarning.Definition<0){NextElite+=90;return;}
        // Visible arrivals need their sprite resource before materialization, not on its first frame.
        const auto& K=EnemyDefinition(EliteWarning.Definition);
        auto* SpriteMaterial=K.MaterialOverride?K.MaterialOverride.Get():Material(TEXT("M_")+K.SpriteKey+(bLitSprites?TEXT("_Lit"):TEXT("")));
        if(SpriteMaterial)SpriteMaterial->SetForceMipLevelsToBeResident(false,false,EliteWarningSeconds+1);
    }
    const int ID=EliteWarning.Definition;
    if(!RuntimeEnemies.IsValidIndex(ID)){ClearEliteWarning();return;}
    const auto Complete=[&](FVector P){SpawnEnemyAt(ID,P);ClearEliteWarning();NextElite+=90;EliteIndex++;};
    if(EliteWarning.Marker.IsValid()){
        EliteWarning.Remaining=FMath::Max(0.f,EliteWarning.Remaining-Dt);
        if(EliteWarning.Remaining>0 || RunTime<NextElite)return;
        const float Speed=500*(1+.03f*Progress->Talents[2]+.05f*RunAttrs[2]);
        const float Clearance=FMath::Max(450.f,EnemyRadius(ID)+45+Speed*.5f);
        if(EliteWarningPointSafe(ID,EliteWarning.Position,Clearance)){Complete(EliteWarning.Position);return;}
        // Never relocate and materialize in one step. Keep the chosen definition and warn afresh.
        ClearEliteWarning();EliteWarning.Definition=ID;EliteWarning.Retry=1;return;
    }
    FVector P;
    if(FindSpawnPoint(ID,P)){
        if(RunTime<NextElite){EliteWarning.Retry=NextElite-RunTime;return;}
        Complete(P);return;
    }
    if(FindVisibleEliteSpawn(ID,P)){
        EliteWarning.Position=P;EliteWarning.Remaining=EliteWarningSeconds;
        const float Radius=FMath::Max(110.f,EnemyRadius(ID)+45);
        EliteWarning.Marker=Mesh(TEXT("Cylinder"),P+FVector(0,0,-6),FVector(Radius/50,Radius/50,.015f),FLinearColor(1,.48f,.08f,.7f));
        return;
    }
    EliteWarning.Retry=1;
}
