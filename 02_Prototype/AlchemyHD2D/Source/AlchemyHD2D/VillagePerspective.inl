// Screen-covering image layers sample the authored ground projection; depth still belongs to each prop foot.
void AAlchemyWorld::UpdateVillagePerspectiveCards(bool Perspective) {
    if(ReferencePerspectiveCards.IsEmpty() && Perspective){
        for(TActorIterator<AStaticMeshActor> It(GetWorld());It;++It){
            if(It->GetLevel()!=GreyfordActiveLevel || !It->ActorHasTag(TEXT("GreyfordReference")))continue;
            auto* Component=It->GetStaticMeshComponent();auto* Parent=Component->GetMaterial(0);float Mode=0;
            if(!Parent || !Parent->GetScalarParameterValue(FMaterialParameterInfo(TEXT("VillagePerspective")),Mode))continue;
            Component->SetMobility(EComponentMobility::Movable);
            ReferencePerspectiveCards.Add(*It);ReferencePerspectiveTransforms.Add(It->GetActorTransform());
            auto* MID=UMaterialInstanceDynamic::Create(Parent,this);Component->SetMaterial(0,MID);ReferencePerspectiveMaterials.Add(MID);
        }
        UE_LOG(LogTemp,Display,TEXT("VILLAGE_PERSPECTIVE_CARDS_READY count=%d"),ReferencePerspectiveCards.Num());
    }
    // The near cards and the renderer must use the same camera pose in a moving frame.
    if(Perspective)if(auto Manager=GetWorld()->GetFirstPlayerController()->PlayerCameraManager)Manager->UpdateCamera(0);
    int VX=1280,VY=720;GetWorld()->GetFirstPlayerController()->GetViewportSize(VX,VY);
    const double Aspect=VX>0 && VY>0?double(VX)/VY:16./9;
    const double Width=200*FMath::Tan(FMath::DegreesToRadians(CameraFOV*.5))*1.01;
    const FTransform Plane(FRotationMatrix::MakeFromXZ(Camera->GetActorRightVector(),-Camera->GetActorForwardVector()).ToQuat(),
        Camera->GetActorLocation()+Camera->GetActorForwardVector()*100,FVector(Width/100,Width/Aspect/100,1));
    for(int I=0;I<ReferencePerspectiveCards.Num();I++)if(IsValid(ReferencePerspectiveCards[I])){
        ReferencePerspectiveMaterials[I]->SetScalarParameterValue(TEXT("VillagePerspective"),Perspective?1:0);
        ReferencePerspectiveMaterials[I]->SetVectorParameterValue(TEXT("VillageFocus"),FLinearColor(ReferenceCameraFocus.X,ReferenceCameraFocus.Y,0,0));
        ReferencePerspectiveMaterials[I]->SetScalarParameterValue(TEXT("VillageWidth"),ViewWidth);
        ReferencePerspectiveMaterials[I]->SetScalarParameterValue(TEXT("VillageTangent"),FMath::Tan(FMath::DegreesToRadians(CameraFOV*.5)));
        ReferencePerspectiveCards[I]->SetActorTransform(Perspective?Plane:ReferencePerspectiveTransforms[I]);
    }
}

// Preserve the painted source registration while gameplay retains its authored collision coordinates.
FVector AAlchemyWorld::VillageVisualPoint(FVector Logical) const {
    if(!bGreyfordReference || !bPerspective || !Camera)return Logical;
    const FVector F=Camera->GetActorForwardVector(),R=Camera->GetActorRightVector(),U=Camera->GetActorUpVector(),E=Camera->GetActorLocation();
    const double T=FMath::Tan(FMath::DegreesToRadians(CameraFOV*.5));
    const double X=FVector::DotProduct(Logical-ReferenceCameraFocus,R)*2/ViewWidth;
    const double Y=((Logical.Y-ReferenceCameraFocus.Y)*FMath::Sin(FMath::DegreesToRadians(48.))+Logical.Z*FMath::Cos(FMath::DegreesToRadians(48.)))*2/ViewWidth;
    return E+(F+R*(X*T)+U*(Y*T))*FVector::DotProduct(Logical-E,F);
}
float AAlchemyWorld::VillageVisualScale(FVector Logical) const {
    if(!bGreyfordReference || !bPerspective || !Camera)return 1;
    const double D=ViewWidth/(2*FMath::Tan(FMath::DegreesToRadians(CameraFOV*.5)));
    return FVector::DotProduct(Logical-Camera->GetActorLocation(),Camera->GetActorForwardVector())/D;
}
