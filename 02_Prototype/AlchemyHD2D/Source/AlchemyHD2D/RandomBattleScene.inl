// The shared authoring generator produces both layers; production queries own traversal.
void AAlchemyWorld::ClearRandomBattleScene(){
    if(bRandomBattleScene && bTODEnabled && IsValid(Camera))
        Camera->GetCameraComponent()->PostProcessSettings.bOverride_ColorGain=false;
    GreyfordTOD.Clear();
    TODPropCasters.Reset();
    TODVisibleCasters.Reset();
    if(bRandomBattleScene && IsValid(Designer)){
        if(Designer->GetWorld())Designer->SetRuntimeVisible(false);
        Designer->CanPlaceObject=nullptr;Designer->ValidateBlockingLayout=nullptr;
    }
    bRandomBattleScene=false;
}

bool AAlchemyWorld::BuildRandomBattleScene(bool Boss){
    AAlchemyLevelDesigner* Layout=nullptr;
    for(TActorIterator<AAlchemyLevelDesigner> It(GetWorld());It;++It)
        if(It->GetLevel()==GreyfordActiveLevel && It->ActorHasTag(TEXT("AlchemyRandomStage"))){Layout=*It;break;}
    if(!Layout){UE_LOG(LogTemp,Error,TEXT("RANDOM_LAYERS missing stage preset; run SetupRandomLayers.py"));return false;}
    Designer=Layout;bRandomBattleScene=true;
    CombatHalfSize=Boss?FVector2D(1600,1300):Layout->PlayHalfSize;
    Obstacles.Empty();ReferenceRegions.Empty();ReferenceNodes.Empty();ReferenceBoundary.Empty();
    Layout->bBossLayout=Boss;Layout->Seed=Boss?(RandomMapSeed^0x424F5353):RandomMapSeed;
    Layout->CanPlaceObject=[Layout](FVector P,FVector2D Half){
        const FVector Local=Layout->GetActorTransform().InverseTransformPosition(P);
        return FMath::Abs(Local.X)+Half.X<Layout->PlayHalfSize.X && FMath::Abs(Local.Y)+Half.Y<Layout->PlayHalfSize.Y;
    };
    Layout->ValidateBlockingLayout=[this,Boss](const TArray<FBox2D>& Boxes){
        const auto Previous=Obstacles;Obstacles.Empty();
        for(const auto& Box:Boxes)Obstacles.Add({Box.GetCenter(),Box.GetSize()*.5});
        const TArray<FVector> Goals=Boss?TArray<FVector>{FVector(0,-500,0),FVector(0,500,0),FVector(900,0,0),FVector(-900,0,0)}:
            TArray<FVector>{FVector(CombatHalfSize.X-700,0,0),FVector(-CombatHalfSize.X+700,0,0),FVector(0,CombatHalfSize.Y-700,0),FVector(0,-CombatHalfSize.Y+700,0)};
        bool Valid=Walkable(FVector::ZeroVector,240);
        for(const FVector P:Goals){TArray<FVector> Path;Valid &= Walkable(P,240) && FindPath(FVector::ZeroVector,P,45,Path);}
        Obstacles=Previous;return Valid;
    };
    if(!Layout->GenerateLayers(3)){UE_LOG(LogTemp,Error,TEXT("RANDOM_LAYERS stage=%d seed=%d failed: %s"),Boss?2:1,Layout->Seed,*Layout->Status);ClearRandomBattleScene();return false;}
    for(TActorIterator<AActor> It(GetWorld());It;++It){
        AActor* A=*It;
        if(A->GetLevel()!=GreyfordActiveLevel || A==Layout || A->GetOwner()==Layout || A->IsHidden() || A->IsA<ALight>() || A->IsA<ASkyLight>() || A->IsA<ACameraActor>())continue;
        A->SetActorHiddenInGame(true);BattleHiddenActors.Add(A);
    }
    Layout->SetRuntimeVisible(true);
    int Ground=0,Objects=0;
    for(TActorIterator<AAlchemyTileCell> It(GetWorld());It;++It)if(It->GetOwner()==Layout){
        if(It->bGround)Ground++;
        else {
            Objects++;
            if(bTODEnabled && It->Texture && It->Image){
                FVector Foot=It->GetActorLocation();Foot.Z=1;
                const auto& ImageTransform=It->Image->GetComponentTransform();
                const FVector ImageWidth=ImageTransform.TransformVector(FVector(100,0,0));
                const float Height=ImageTransform.TransformVector(FVector(0,100,0)).Size()*.66f;
                TODPropCasters.Add({Foot,float(ImageWidth.Size2D()),Height,It->bBlocksMovement?1.f:.6f,
                    It->Texture.Get(),It->FootFraction,ImageWidth.GetSafeNormal2D()});
            }
        }
        if(It->bBlocksMovement)Obstacles.Add({FVector2D(It->GetActorLocation()),It->WorldHalfSize()});
    }
    auto Floor=Mesh(TEXT("Plane"),FVector(0,0,-2),FVector((Layout->PlayHalfSize.X+2500)/50,(Layout->PlayHalfSize.Y+2500)/50,1),FLinearColor::White);
    Floor->GetStaticMeshComponent()->SetMaterial(0,LoadObject<UMaterialInterface>(nullptr,TEXT("/Game/Greyford/Materials/M_GF_Grass.M_GF_Grass")));
    Floor->GetStaticMeshComponent()->SetCastShadow(false);BattleCards.Add(Floor);
    if(Boss){auto Edge=Mesh(TEXT("Plane"),FVector(0,0,5),FVector(32,26,1),FLinearColor::White);
        Edge->GetStaticMeshComponent()->SetMaterial(0,Material(TEXT("M_ArenaRing")));Edge->GetStaticMeshComponent()->SetCastShadow(false);BattleCards.Add(Edge);}
    bPerspective=true;bUprightSprites=false;bDepthOfField=false;CameraPitch=60;CameraFOV=50;ViewWidth=2400;
    PlayerPos=Boss?FVector(0,-500,0):FVector::ZeroVector;
    if(bTODEnabled)BindGreyfordTOD();
    UpdateRandomBattleCamera(0);
    UE_LOG(LogTemp,Display,TEXT("RANDOM_LAYERS_READY stage=%d master_seed=%d seed=%d ground=%d objects=%d blockers=%d"),Boss?2:1,RandomMapSeed,Layout->Seed,Ground,Objects,Obstacles.Num());
    const bool Ready=Ground>0 && Walkable(PlayerPos,45);
    if(!Ready)ClearRandomBattleScene();
    return Ready;
}

void AAlchemyWorld::BindGreyfordTOD(){
    ADirectionalLight* Sun=nullptr;
    ASkyLight* Sky=nullptr;
    // Flow owns a shared pair in its persistent level. Prefer an authored active-stage pair if present.
    for(TActorIterator<ADirectionalLight> It(GetWorld());It;++It){
        if(It->GetLevel()==GreyfordActiveLevel){Sun=*It;break;}
        if(It->GetLevel()==GetWorld()->PersistentLevel && !Sun)Sun=*It;
    }
    for(TActorIterator<ASkyLight> It(GetWorld());It;++It){
        if(It->GetLevel()==GreyfordActiveLevel){Sky=*It;break;}
        if(It->GetLevel()==GetWorld()->PersistentLevel && !Sky)Sky=*It;
    }
    GreyfordTOD.BindLights(Sun,Sky);
    if(!TODShadowMaterial)TODShadowMaterial=LoadObject<UMaterialInterface>(nullptr,TEXT("/Game/Design/M_TODPropShadow.M_TODPropShadow"));
    UE_LOG(LogTemp,Display,TEXT("GREYFORD_TOD stage=%d sun=%s sky=%s prop_casters=%d material=%s"),GreyfordStage,
        *GetNameSafe(Sun),*GetNameSafe(Sky),TODPropCasters.Num(),*GetNameSafe(TODShadowMaterial));
}

void AAlchemyWorld::UpdateGreyfordTOD(){
    if(!bTODEnabled)return;
    GreyfordTOD.Update(bTODFixedHour?0.f:RunTime,TODSettings);
    const auto Tint=GreyfordTOD.GetSceneTint();
    auto& Grade=Camera->GetCameraComponent()->PostProcessSettings;
    Grade.bOverride_ColorGain=true;
    Grade.ColorGain=FVector4(Tint.R,Tint.G,Tint.B,1);

    TODVisibleCasters.Reset();
    // Include off-screen casters whose long shadow can reach the camera's view.
    const float Radius=ViewWidth*.75f+TODSettings.MaxShadowLength;
    for(const auto& Caster:TODPropCasters)
        if(FVector::DistSquared2D(Caster.Foot,PlayerPos)<FMath::Square(Radius))TODVisibleCasters.Add(Caster);
    GreyfordTOD.UpdateShadows(GetWorld(),TODShadowMaterial,TODVisibleCasters);
}

void AAlchemyWorld::UpdateRandomBattleCamera(float Dt){
    if(!Camera)return;
    auto C=CastChecked<UAlchemyCameraComponent>(Camera->GetCameraComponent());
    int W=1280,H=720;auto PC=GetWorld()->GetFirstPlayerController();PC->GetViewportSize(W,H);
    const double Aspect=W>0 && H>0?double(W)/H:16./9,T=FMath::Tan(FMath::DegreesToRadians(25.));
    FVector Focus=PlayerPos+FVector(0,100,120);
    const bool FrameBoss=GreyfordStage==2 && !Enemies.IsEmpty() && (GreyfordBossPreparation>0 || FVector::Dist2D(PlayerPos,Enemies[0].Pos)<1600);
    if(FrameBoss)Focus=(PlayerPos+Enemies[0].Pos)*.5+FVector(0,0,160);
    ViewWidth=2400*Aspect/(16./9);double Distance=ViewWidth/(2*T);
    Camera->SetActorRotation(FRotator(-60,90,0));
    const FVector Forward=Camera->GetActorForwardVector(),Right=Camera->GetActorRightVector(),Up=Camera->GetActorUpVector();
    if(FrameBoss){
        TArray<FVector> Corners;
        for(AActor* Body:{static_cast<AActor*>(Player),static_cast<AActor*>(Enemies[0].Body)})if(IsValid(Body)){
            const FBox B=Body->GetComponentsBoundingBox(true);
            for(int I=0;I<8;I++)Corners.Add(FVector(I&1?B.Max.X:B.Min.X,I&2?B.Max.Y:B.Min.Y,I&4?B.Max.Z:B.Min.Z)-Focus);
        }
        const double Fit=FMath::Min(double(W)/1672,double(H)/940),Top=(H-940*Fit)*.5;
        double SafeTop=Top+50*Fit+6,SafeBottom=Top+804*Fit-6;
        if(BattleWidget)for(const TCHAR* Name:{TEXT("TimerText"),TEXT("SkillGroup")})if(auto Widget=BattleWidget->GetWidgetFromName(Name)){
            const auto G=Widget->GetCachedGeometry();if(G.GetLocalSize().GetMin()<=0)continue;
            FVector2D Pixel,Unused;const bool Timer=FCString::Strcmp(Name,TEXT("TimerText"))==0;
            USlateBlueprintLibrary::LocalToViewport(this,G,Timer?G.GetLocalSize():FVector2D::ZeroVector,Pixel,Unused);
            if(Timer)SafeTop=Pixel.Y+6;else SafeBottom=Pixel.Y-6;
        }
        const double Upper=1-2*SafeTop/H,Lower=1-2*SafeBottom/H,VerticalT=T/Aspect;
        for(const FVector V:Corners)Distance=FMath::Max(Distance,FMath::Abs(FVector::DotProduct(V,Right))/(T*.80)-FVector::DotProduct(V,Forward));
        const auto ShiftRange=[&](double D){double Low=-DBL_MAX,High=DBL_MAX;
            for(const FVector V:Corners){const double Depth=D+FVector::DotProduct(V,Forward),Y=FVector::DotProduct(V,Up);
                Low=FMath::Max(Low,Y-Upper*VerticalT*Depth);High=FMath::Min(High,Y-Lower*VerticalT*Depth);}
            return FVector2D(Low,High);
        };
        const double MinimumCameraDistance=Distance;auto Range=ShiftRange(Distance);
        for(int I=0;I<32 && Range.X>Range.Y;I++){Distance*=1.08;Range=ShiftRange(Distance);}
        if(Range.X<=Range.Y){double Low=MinimumCameraDistance,High=Distance;
            for(int I=0;I<20;I++){const double Mid=(Low+High)*.5;const auto R=ShiftRange(Mid);if(R.X<=R.Y)High=Mid;else Low=Mid;}
            Distance=High;Range=ShiftRange(Distance);Focus+=Up*FMath::Clamp(0.,Range.X,Range.Y);
        }
    }
    C->ProjectionOffset=FVector2D::ZeroVector;C->ProjectionMode=ECameraProjectionMode::Perspective;C->SetFieldOfView(50);
    C->bConstrainAspectRatio=false;C->SetAspectRatio(Aspect);C->bOverrideAspectRatioAxisConstraint=true;C->SetAspectRatioAxisConstraint(EAspectRatioAxisConstraint::AspectRatio_MaintainXFOV);
    auto& PP=C->PostProcessSettings;PP.bOverride_VignetteIntensity=true;PP.VignetteIntensity=0;PP.bOverride_BloomIntensity=true;PP.BloomIntensity=0;
    PP.bOverride_ToneCurveAmount=true;PP.ToneCurveAmount=0;PP.bOverride_ExpandGamut=true;PP.ExpandGamut=0;
    PP.bOverride_AutoExposureMinBrightness=PP.bOverride_AutoExposureMaxBrightness=true;PP.AutoExposureMinBrightness=PP.AutoExposureMaxBrightness=1;
    PP.bOverride_DepthOfFieldFstop=true;PP.DepthOfFieldFstop=32;
    const FVector Goal=Focus-Forward*Distance;
    Camera->SetActorLocation(Dt<=0?Goal:FMath::VInterpTo(Camera->GetActorLocation(),Goal,Dt,10));
    if(Dt<=0)UpdateGreyfordTOD();
    if(PC->PlayerCameraManager)PC->PlayerCameraManager->UpdateCamera(0);
}
