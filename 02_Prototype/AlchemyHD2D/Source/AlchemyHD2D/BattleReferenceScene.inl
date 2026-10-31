// Registered perspective cards: painted pixels are scenery; simulation uses authored ground regions.
namespace {
constexpr double BattleImageWidth=1672, BattleImageHeight=941, BattleCameraDistance=3201.4425;
constexpr double BattleOverscan=1.2;
FVector BattleForward(){return FVector(0,.5,-FMath::Sqrt(3.)/2);}
FVector BattleRight(){return FVector(-1,0,0);}
FVector BattleUp(){return FVector(0,FMath::Sqrt(3.)/2,.5);}
FVector BattleCameraPosition(){return -BattleForward()*BattleCameraDistance;}
double BattleFocalPixels(){return BattleImageWidth/(2*BattleOverscan*FMath::Tan(FMath::DegreesToRadians(25.)));}
bool LoadBattleJson(const FString& Path,TSharedPtr<FJsonObject>& Out){
    FString Text;return FFileHelper::LoadFileToString(Text,*Path) && FJsonSerializer::Deserialize(TJsonReaderFactory<>::Create(Text),Out) && Out.IsValid();
}
FVector2D BattleJsonPoint(const TSharedPtr<FJsonValue>& Value){
    const auto& A=Value->AsArray();return FVector2D(A[0]->AsNumber(),A[1]->AsNumber());
}
bool BattleProjectedOutside(APlayerController* PC,const TArray<FVector>& Corners){
    if(!PC)return false;int VX=0,VY=0;PC->GetViewportSize(VX,VY);
    if(VX<=0 || VY<=0){
        if(!PC->PlayerCameraManager)return false;
        const auto& View=PC->PlayerCameraManager->GetCameraCacheView();
        const FRotationMatrix Rotation(View.Rotation);const FVector Forward=Rotation.GetUnitAxis(EAxis::X),Right=Rotation.GetUnitAxis(EAxis::Y),Up=Rotation.GetUnitAxis(EAxis::Z);
        const double T=FMath::Tan(FMath::DegreesToRadians(View.FOV*.5)),Aspect=View.AspectRatio>0?View.AspectRatio:16./9;
        FBox2D Normalized(ForceInit);
        for(const FVector P:Corners){const FVector V=P-View.Location;const double D=FVector::DotProduct(V,Forward);if(D<=0)return false;
            Normalized+=FVector2D(FVector::DotProduct(V,Right)/(D*T)-View.OffCenterProjectionOffset.X,FVector::DotProduct(V,Up)/(D*T)*Aspect-View.OffCenterProjectionOffset.Y);}
        return Normalized.Max.X<-1 || Normalized.Min.X>1 || Normalized.Max.Y<-1 || Normalized.Min.Y>1;
    }
    FBox2D Box(ForceInit);
    for(const FVector P:Corners){FVector2D Pixel;if(!PC->ProjectWorldLocationToScreen(P,Pixel))return false;Box+=Pixel;}
    return Box.Max.X<0 || Box.Min.X>VX || Box.Max.Y<0 || Box.Min.Y>VY;
}
}

FVector AAlchemyWorld::BattleReferencePoint(FVector2D Pixel) const {
    const double F=BattleFocalPixels();
    const FVector Ray=BattleForward()+BattleRight()*((Pixel.X-BattleImageWidth/2)/F)+BattleUp()*((BattleImageHeight/2-Pixel.Y)/F);
    const FVector C=BattleCameraPosition();
    return C+Ray*(-C.Z/Ray.Z);
}

FVector2D AAlchemyWorld::BattleReferencePixel(FVector World) const {
    const FVector V=World-BattleCameraPosition();const double Depth=FVector::DotProduct(V,BattleForward());
    if(Depth<=KINDA_SMALL_NUMBER)return FVector2D(-1,-1);
    return FVector2D(BattleImageWidth/2+BattleFocalPixels()*FVector::DotProduct(V,BattleRight())/Depth,
                     BattleImageHeight/2-BattleFocalPixels()*FVector::DotProduct(V,BattleUp())/Depth);
}

void AAlchemyWorld::UpdateBattleReferenceCamera(float Delta) {
    if((!bBattleReference && !bReferenceBossScene) || !Camera)return;
    const double Scale=bReferenceBossScene?1.75:1;
    const FVector Eye=BattleCameraPosition()*Scale;
    auto* C=CastChecked<UAlchemyCameraComponent>(Camera->GetCameraComponent());
    int VX=1280,VY=720;auto* PC=GetWorld()->GetFirstPlayerController();PC->GetViewportSize(VX,VY);
    const double Aspect=VX>0 && VY>0?double(VX)/VY:16./9;
    // Narrow the native frustum rather than translating the eye: all original depth slices remain registered.
    const double Depth=FMath::Max(100.,FVector::DotProduct(PlayerPos-Eye,BattleForward()));
    const double SharedWidth=1672*180./52/FMath::Max(1.f,ReferenceZoom)*Aspect/(16./9);
    double Tangent=SharedWidth/(2*Depth);
    FVector Goal=PlayerPos+FVector(0,100,0);
    if(bReferenceBossScene && !Enemies.IsEmpty() && (GreyfordBossPreparation>0 || FVector::Dist2D(PlayerPos,Enemies[0].Pos)<1600)){
        Goal=(PlayerPos+Enemies[0].Pos)*.5+BattleUp()*80;
        FBox2D Angular(ForceInit);
        for(AActor* Body:{static_cast<AActor*>(Player),static_cast<AActor*>(Enemies[0].Body)})if(IsValid(Body)){
            const FBox Bounds=Body->GetComponentsBoundingBox(true);
            for(int I=0;I<8;I++){const FVector P((I&1)?Bounds.Max.X:Bounds.Min.X,(I&2)?Bounds.Max.Y:Bounds.Min.Y,(I&4)?Bounds.Max.Z:Bounds.Min.Z),V=P-Eye;
                const double D=FMath::Max(100.,FVector::DotProduct(V,BattleForward()));Angular+=FVector2D(FVector::DotProduct(V,BattleRight())/D,FVector::DotProduct(V,BattleUp())/D);}}
        if(Angular.bIsValid)Tangent=FMath::Max3(Tangent,Angular.GetSize().Y*Aspect/(2*.76),Angular.GetSize().X/(2*.82));
    }
    const double K=BattleOverscan*FMath::Tan(FMath::DegreesToRadians(25.));
    const double MaxT=K*FMath::Min(1.,Aspect/(BattleImageWidth/BattleImageHeight));
    Tangent=FMath::Min(Tangent,MaxT*.9999);
    FVector2D Target=BattleReferencePixel(Goal/Scale);
    if(!CombatCameraReady || Delta<=0){CombatCameraSourceFocus=Target;CombatCameraTangent=Tangent;CombatCameraReady=true;}
    else {
        FVector2D Desired=CombatCameraSourceFocus;
        for(int I=0;I<2;I++){const double D=Target[I]-Desired[I];Desired[I]+=FMath::Sign(D)*FMath::Max(0.,FMath::Abs(D)-12);}
        const double Alpha=1-FMath::Exp(-10*Delta);
        CombatCameraSourceFocus=FMath::Lerp(CombatCameraSourceFocus,Desired,Alpha);CombatCameraTangent=FMath::Lerp(CombatCameraTangent,Tangent,Alpha);
    }
    CombatCameraTangent=FMath::Min(CombatCameraTangent,MaxT*.9999);
    const double HalfW=BattleImageWidth*.5*CombatCameraTangent/K,HalfH=HalfW/Aspect;
    CombatCameraSourceFocus.X=FMath::Clamp(CombatCameraSourceFocus.X,HalfW,BattleImageWidth-HalfW);
    CombatCameraSourceFocus.Y=FMath::Clamp(CombatCameraSourceFocus.Y,HalfH,BattleImageHeight-HalfH);
    C->ProjectionOffset=FVector2D((CombatCameraSourceFocus.X-BattleImageWidth*.5)/HalfW,(BattleImageHeight*.5-CombatCameraSourceFocus.Y)/HalfH);
    bPerspective=true;CameraPitch=60;CameraFOV=FMath::RadiansToDegrees(2*FMath::Atan(CombatCameraTangent));ViewWidth=SharedWidth;
    C->ProjectionMode=ECameraProjectionMode::Perspective;C->SetFieldOfView(CameraFOV);C->bConstrainAspectRatio=false;C->SetAspectRatio(float(Aspect));
    C->bOverrideAspectRatioAxisConstraint=true;C->SetAspectRatioAxisConstraint(EAspectRatioAxisConstraint::AspectRatio_MaintainXFOV);
    Camera->SetActorRotation(FRotator(-60,90,0));Camera->SetActorLocation(Eye);
    auto& PP=C->PostProcessSettings;
    PP.bOverride_ToneCurveAmount=true;PP.ToneCurveAmount=0;PP.bOverride_ExpandGamut=true;PP.ExpandGamut=0;
    PP.bOverride_VignetteIntensity=true;PP.VignetteIntensity=0;PP.bOverride_BloomIntensity=true;PP.BloomIntensity=0;
    PP.bOverride_DepthOfFieldFstop=true;PP.DepthOfFieldFstop=32;PP.bOverride_DepthOfFieldFocalDistance=true;PP.DepthOfFieldFocalDistance=Depth;
    PP.bOverride_AutoExposureBias=true;PP.AutoExposureBias=0;PP.bOverride_AutoExposureMinBrightness=true;PP.AutoExposureMinBrightness=1;PP.bOverride_AutoExposureMaxBrightness=true;PP.AutoExposureMaxBrightness=1;
    if(PC->PlayerCameraManager)PC->PlayerCameraManager->UpdateCamera(0);
}

void AAlchemyWorld::ClearBattleReferenceScene() {
    bReferenceBossScene=false;CombatCameraReady=false;
    if(Camera)CastChecked<UAlchemyCameraComponent>(Camera->GetCameraComponent())->ProjectionOffset=FVector2D::ZeroVector;
    for(auto A:BattleCards)if(IsValid(A))A->Destroy();BattleCards.Empty();
    for(auto R:BattleRegions)if(IsValid(R))R->Destroy();BattleRegions.Empty();
    for(auto A:BattleHiddenActors)if(A.IsValid())A->SetActorHiddenInGame(false);BattleHiddenActors.Empty();
    if(bBattleReference && IsValid(Designer))Designer->SetRuntimeVisible(true);
    if(bBattleReference && IsValid(PlayerShadow)){
        PlayerShadow->GetStaticMeshComponent()->SetMaterial(0,Material(TEXT("M_SoftShadow")));
    }
    if(bBattleReference){ReferencePlayerRadius=BattlePreviousReferenceRadius;ReferenceRegions.Empty();ReferenceNodes.Empty();ReferenceBoundary.Empty();}
    if(BattleSavedCameraPostProcess && Camera)Camera->GetCameraComponent()->PostProcessSettings=BattlePreviousCameraPostProcess;
    BattleSavedCameraPostProcess=false;BattleSpawnPixels.Empty();bBattleReference=false;
}

bool AAlchemyWorld::BuildBattleReferenceScene() {
    ClearBattleReferenceScene();
    TSharedPtr<FJsonObject> Spec,LayerData;
    if(!LoadBattleJson(FPaths::ProjectContentDir()/TEXT("Reference/BattleReferenceSpec.json"),Spec) ||
       !LoadBattleJson(FPaths::ProjectContentDir()/TEXT("Reference/BattleReferenceLayers.json"),LayerData)){
        UE_LOG(LogTemp,Error,TEXT("BATTLE_REFERENCE missing cooked NonUFS spec/layers; run Prepare/ImportBattleReferenceScene"));return false;
    }
    if(!bGreyfordFlow || GreyfordStage!=1 || !Camera)return false;
    bBattleReference=true;BattlePreviousReferenceRadius=ReferencePlayerRadius;ReferencePlayerRadius=45;
    BattlePreviousCameraPostProcess=Camera->GetCameraComponent()->PostProcessSettings;BattleSavedCameraPostProcess=true;
    ReferenceRegions.Empty();ReferenceNodes.Empty();ReferenceBoundary.Empty();Obstacles.Empty();
    UpdateBattleReferenceCamera();
    Mats.Add(TEXT("BattleReference_Disc"),LoadObject<UMaterialInterface>(nullptr,TEXT("/Game/ReferenceBattle/M_Disc.M_Disc")));
    Mats.Add(TEXT("BattleReference_Shadow"),LoadObject<UMaterialInterface>(nullptr,TEXT("/Game/ReferenceBattle/M_Shadow.M_Shadow")));
    const auto Fail=[&](const TCHAR* Why){UE_LOG(LogTemp,Error,TEXT("BATTLE_REFERENCE %s"),Why);ClearBattleReferenceScene();return false;};
    FBox Bounds(ForceInit);
    for(bool Blocked:{false,true})for(const auto& Value:Spec->GetArrayField(Blocked?TEXT("blocked"):TEXT("walk"))){
        const auto Row=Value->AsObject();TArray<FVector> Points;
        for(const auto& P:Row->GetArrayField(TEXT("points"))){const FVector W=BattleReferencePoint(BattleJsonPoint(P));Points.Add(W);if(!Blocked)Bounds+=W;}
        FActorSpawnParameters Params;Params.ObjectFlags|=RF_Transient;
        auto R=GetWorld()->SpawnActor<AGreyfordReferenceRegion>(FVector::ZeroVector,FRotator::ZeroRotator,Params);
        if(!R)return Fail(TEXT("cannot create ground region"));
        R->bBlocked=Blocked;R->bShowOutline=false;R->SetActorTickEnabled(false);R->Tags.Add(TEXT("BattleReferenceRuntime"));
        R->Outline->ClearSplinePoints(false);R->Outline->SetSplinePoints(Points,ESplineCoordinateSpace::World,false);
        R->InitializeOutline();
#if WITH_EDITOR
        R->Outline->SetDrawDebug(false);
#endif
        ReferenceRegions.Add(R);BattleRegions.Add(R);
    }
    BuildReferenceBoundary();
    for(const auto& P:Spec->GetArrayField(TEXT("path_nodes"))){const FVector W=BattleReferencePoint(BattleJsonPoint(P));if(ReferenceWalkable(W,45))ReferenceNodes.Add(W);}
    // Add a small ring at obstacle vertices, keeping only legal nodes. The existing visibility graph owns pathfinding.
    for(auto R:BattleRegions)if(R->bBlocked)for(const FVector Vertex:R->GetWorldVertices()){
        for(int I=0;I<8;I++){
            const double A=I*PI/4;const FVector P=Vertex+FVector(FMath::Cos(A),FMath::Sin(A),0)*150;
            if(ReferenceWalkable(P,45) && !ReferenceNodes.ContainsByPredicate([&](FVector N){return FVector::DistSquared2D(N,P)<FMath::Square(100.);}))ReferenceNodes.Add(P);
        }
    }
    const auto& Spawn=Spec->GetArrayField(TEXT("spawn"));PlayerPos=BattleReferencePoint(FVector2D(Spawn[0]->AsNumber(),Spawn[1]->AsNumber()));
    if(!ReferenceWalkable(PlayerPos,45))return Fail(TEXT("authored player spawn is blocked"));
    CombatHalfSize=FVector2D(FMath::Max(FMath::Abs(Bounds.Min.X),FMath::Abs(Bounds.Max.X)),FMath::Max(FMath::Abs(Bounds.Min.Y),FMath::Abs(Bounds.Max.Y)));
    for(const auto& P:Spec->GetArrayField(TEXT("spawn_candidate_source_pixels")))BattleSpawnPixels.Add(BattleJsonPoint(P));
    // Hide only the old active stage's authored actors. Restore exactly those we hid on stage exit.
    for(TActorIterator<AActor> It(GetWorld());It;++It){
        AActor* A=*It;if(A->GetLevel()!=GreyfordActiveLevel || A->IsHidden() || A->IsA<ACameraActor>())continue;
        A->SetActorHiddenInGame(true);BattleHiddenActors.Add(A);
    }
    if(Designer)Designer->SetRuntimeVisible(false);
    for(const auto& Value:LayerData->GetArrayField(TEXT("layers"))){
        const auto Row=Value->AsObject();const FString Name=Row->GetStringField(TEXT("name"));
        auto* Mat=LoadObject<UMaterialInterface>(nullptr,*(TEXT("/Game/ReferenceBattle/M_")+Name+TEXT(".M_")+Name));
        if(!Mat)return Fail(TEXT("scene card material is missing"));
        double Depth=9000;
        if(Name!=TEXT("Backdrop")){
            const auto& Foot=Row->GetArrayField(TEXT("foot"));
            Depth=FVector::DotProduct(BattleReferencePoint(FVector2D(Foot[0]->AsNumber(),Foot[1]->AsNumber()))-BattleCameraPosition(),BattleForward())-.5;
        }
        const double Width=Depth*2*FMath::Tan(FMath::DegreesToRadians(25.))*BattleOverscan;
        auto Card=Mesh(TEXT("Plane"),BattleCameraPosition()+BattleForward()*Depth,FVector(Width/100,Width*BattleImageHeight/BattleImageWidth/100,1),FLinearColor::White);
        Card->SetActorRotation(FRotationMatrix::MakeFromXZ(BattleRight(),-BattleForward()).Rotator());
        Card->GetStaticMeshComponent()->SetMaterial(0,Mat);Card->GetStaticMeshComponent()->SetCastShadow(false);
        Card->Tags.Add(TEXT("BattleReferenceRuntime"));BattleCards.Add(Card);
    }
    if(auto PC=GetWorld()->GetFirstPlayerController();PC && PC->PlayerCameraManager)PC->PlayerCameraManager->UpdateCamera(0);
    UE_LOG(LogTemp,Display,TEXT("BATTLE_REFERENCE_READY regions=%d nodes=%d cards=%d player_clear=1 authoring_pitch=60 authoring_hfov=50 overscan=1.2"),BattleRegions.Num(),ReferenceNodes.Num(),BattleCards.Num());
    return true;
}

bool AAlchemyWorld::BattleOffscreen(FVector P,float Radius) const {
    if(!Camera)return false;TArray<FVector> Corners;
    for(int X:{-1,1})for(int Y:{-1,1})for(int Z:{-1,1})Corners.Add(P+FVector(X,Y,Z)*Radius);
    return BattleProjectedOutside(GetWorld()->GetFirstPlayerController(),Corners);
}

bool AAlchemyWorld::BattleFindSpawn(int DefinitionID,FVector& P) {
    if(!RuntimeEnemies.IsValidIndex(DefinitionID))return false;
    const auto& K=EnemyDefinition(DefinitionID);
    const auto Accept=[&](FVector2D Pixel){
        const FVector Candidate=BattleReferencePoint(Pixel);TArray<FVector> Path;
        if(!ReferenceWalkable(Candidate,K.CollisionRadius) || !BattleOffscreen(Candidate,K.CollisionRadius))return false;
        TArray<FVector> VisualCorners;
        const FVector VisualUp=bUprightSprites?FVector::UpVector:BattleUp();
        for(int X:{-1,1})for(int Y:{-1,1})VisualCorners.Add(Candidate+BattleUp()*(K.VisualSize.Y*.46)+BattleRight()*(X*K.VisualSize.X*.5)+VisualUp*(Y*K.VisualSize.Y*.5));
        if(!BattleProjectedOutside(GetWorld()->GetFirstPlayerController(),VisualCorners) || !FindPath(Candidate,PlayerPos,K.CollisionRadius,Path))return false;
        P=Candidate;return true;
    };
    // Random choice avoids privileging the first authored edge; all candidates still pass production queries.
    const int Start=BattleSpawnPixels.IsEmpty()?0:Random.RandRange(0,BattleSpawnPixels.Num()-1);
    for(int I=0;I<BattleSpawnPixels.Num();I++)if(Accept(BattleSpawnPixels[(Start+I)%BattleSpawnPixels.Num()]))return true;
    for(int I=0;I<160;I++)if(Accept(FVector2D(Random.FRandRange(0,1671),Random.FRandRange(160,900))))return true;
    return false;
}

// Authored walk/blocked regions own traversal; the old static-screen fence is no longer needed.
FVector AAlchemyWorld::BattlePlayerPoint(FVector Point) const { return Point; }

bool AAlchemyWorld::BuildBossReferenceScene(){
    TSharedPtr<FJsonObject> BossLayerSpec;
    if(!LoadBattleJson(FPaths::ProjectContentDir()/TEXT("Reference/BattleReferenceLayers.json"),BossLayerSpec)){UE_LOG(LogTemp,Error,TEXT("BOSS_REFERENCE missing shared layer manifest"));return false;}
    bReferenceBossScene=true;CombatCameraReady=false;
    // Reuse the same countryside artwork, enlarged only enough to place its scenery outside the existing arena.
    constexpr double Scale=1.75;
    for(TActorIterator<AStaticMeshActor> It(GetWorld());It;++It)if(It->GetLevel()==GreyfordActiveLevel && !It->IsHidden()){
        // The existing 32x26m ellipse remains the exact playable boundary and visible ground marking.
        if(FMath::IsNearlyEqual(It->GetActorScale3D().X,32.,.01) && FMath::IsNearlyEqual(It->GetActorScale3D().Y,26.,.01))continue;
        It->SetActorHiddenInGame(true);BattleHiddenActors.Add(*It);
    }
    for(const auto& Value:BossLayerSpec->GetArrayField(TEXT("layers"))){
        const auto Row=Value->AsObject();const FString Name=Row->GetStringField(TEXT("name"));
        auto* Mat=LoadObject<UMaterialInterface>(nullptr,*(TEXT("/Game/ReferenceBattle/M_")+Name+TEXT(".M_")+Name));if(!Mat)return false;
        double Depth=9000;if(Name!=TEXT("Backdrop")){const auto& Foot=Row->GetArrayField(TEXT("foot"));Depth=FVector::DotProduct(BattleReferencePoint({Foot[0]->AsNumber(),Foot[1]->AsNumber()})-BattleCameraPosition(),BattleForward())-.5;}
        const double Width=Depth*2*FMath::Tan(FMath::DegreesToRadians(25.))*BattleOverscan*Scale;
        auto* Card=Mesh(TEXT("Plane"),(BattleCameraPosition()+BattleForward()*Depth)*Scale,FVector(Width/100,Width*BattleImageHeight/BattleImageWidth/100,1),FLinearColor::White);
        Card->SetActorRotation(FRotationMatrix::MakeFromXZ(BattleRight(),-BattleForward()).Rotator());Card->GetStaticMeshComponent()->SetMaterial(0,Mat);Card->GetStaticMeshComponent()->SetCastShadow(false);
        Card->Tags.Add(TEXT("BossReferenceRuntime"));BattleCards.Add(Card);
    }
    UE_LOG(LogTemp,Display,TEXT("BOSS_REFERENCE_READY cards=%d art_scale=1.75 ellipse=3200x2600 gameplay_unchanged=1"),BattleCards.Num());return BattleCards.Num()==7;
}
