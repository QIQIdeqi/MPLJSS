#include "Camera/CameraActor.h"
#include "Camera/CameraComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/StaticMeshActor.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "InputKeyEventArgs.h"

// Explicit opt-in fixture: true freezes simulation for inspection; false runs injected keys through production Tick.
bool AAlchemyWorld::VillagePerspectiveCheck(float Dt) {
    static int32 Phase=-1,PointIndex=0;
    static float Wait=0;
    static bool OK=true;
    static FString Resolution;
    static TArray<FVector2D> Pixels;
    static TArray<FString> Names,Files;
    static FString Coverage;
    static FVector MovementStart=FVector::ZeroVector,LegStart=FVector::ZeroVector;
    const FString Dir=FPaths::ProjectDir()/TEXT("Evidence/VillagePerspective_20261031");
    auto* PC=GetWorld()->GetFirstPlayerController();
    const auto Key=[&](FKey Value,bool Pressed){if(!PC)return;FInputKeyEventArgs Event;Event.Key=Value;Event.Event=Pressed?IE_Pressed:IE_Released;Event.AmountDepressed=Pressed?1:0;PC->InputKey(Event);};
    const auto Check=[&](bool Pass,const TCHAR* Name){OK &= Pass;UE_LOG(LogTemp,Display,TEXT("VILLAGE_PERSPECTIVE_CHECK %s %s"),Name,Pass?TEXT("PASS"):TEXT("FAIL"));};
    const auto Finish=[&](){
        for(const FKey K:{EKeys::D,EKeys::W,EKeys::S})Key(K,false);
        FFileHelper::SaveStringToFile(Coverage,*(Dir/FString::Printf(TEXT("coverage_%s.csv"),*Resolution)),FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM);
        FFileHelper::SaveStringToFile(FString::Printf(TEXT("{\"result\":\"%s\",\"resolution\":\"%s\",\"points\":%d,\"screenshots\":%d}\n"),OK?TEXT("PASS"):TEXT("FAIL"),*Resolution,Pixels.Num(),Files.Num()),*(Dir/FString::Printf(TEXT("verification_%s.json"),*Resolution)));
        UE_LOG(LogTemp,Display,TEXT("VILLAGE_PERSPECTIVE_%s resolution=%s points=%d screenshots=%d"),OK?TEXT("PASS"):TEXT("FAIL"),*Resolution,Pixels.Num(),Files.Num());
        Phase=2;FPlatformMisc::RequestExitWithStatus(false,OK?0:1);
    };
    if(Phase==2)return true;
    if(!PC){Check(false,TEXT("player_controller_available"));Finish();return true;}
    int32 VX=0,VY=0;PC->GetViewportSize(VX,VY);
    if(VX<=0 || VY<=0)return true;
    const auto Position=[&](){
        PlayerPos=ReferencePoint(Pixels[PointIndex].X,Pixels[PointIndex].Y);
        Check(Walkable(PlayerPos,45),TEXT("source_landmark_is_valid_player_ground"));
        ReferenceCameraReady=false;UpdateCamera(0);
        LastDirection=-Camera->GetActorForwardVector().GetSafeNormal2D();UpdateCharacterVisual(0,false);
        Player->SetActorHiddenInGame(false);
        if(PlayerShadow){PlayerShadow->SetActorLocation(VillageVisualPoint(PlayerPos+FVector(0,0,5)));PlayerShadow->SetActorHiddenInGame(false);}
        Panel.Empty();ToastTime=0;Wait=0;Phase=0;
    };
    if(Phase<0){
        OK=true;Resolution=FString::Printf(TEXT("%dx%d"),VX,VY);
        Coverage=TEXT("landmark,source_x,source_y,corner,ground_source_x,ground_source_y,camera_x,camera_y,camera_z\n");
        IFileManager::Get().MakeDirectory(*Dir,true);
        Check(bCapture,TEXT("fixture_has_isolated_no_save_capture_mode"));
        if(!bCapture){Finish();return true;}
        Progress=NewObject<UAlchemyProgress>(this);MigrateProgress(true);BuildScene(false);
        Check(bGreyfordFlow && bGreyfordReference && GreyfordStage==0 && !bCombat,TEXT("isolated_fixture_stays_in_village_stage_zero"));
        Check(Camera && Player,TEXT("village_camera_and_player_ready"));
        TSharedPtr<FJsonObject> Spec;FString Input;
        const bool Loaded=FFileHelper::LoadFileToString(Input,*(FPaths::ProjectDir()/TEXT("Tools/GreyfordReference.json"))) && FJsonSerializer::Deserialize(TJsonReaderFactory<>::Create(Input),Spec) && Spec.IsValid();
        Check(Loaded,TEXT("village_source_fixture_loaded"));
        if(!OK){Finish();return true;}
        const auto ReadPoint=[](const TSharedPtr<FJsonValue>& V){const auto& A=V->AsArray();return FVector2D(A[0]->AsNumber(),A[1]->AsNumber());};
        const auto& Spawn=Spec->GetArrayField(TEXT("spawn"));
        Pixels.Add({Spawn[0]->AsNumber(),Spawn[1]->AsNumber()});Names.Add(TEXT("spawn"));
        for(const auto& V:Spec->GetArrayField(TEXT("nodes"))){
            const FVector2D P=ReadPoint(V);
            if(P.Equals(FVector2D(375,615),.1)){Pixels.Add(P);Names.Add(TEXT("bridge"));break;}
        }
        for(const auto& V:Spec->GetArrayField(TEXT("nodes"))){
            const FVector2D P=ReadPoint(V);
            if(P.Equals(FVector2D(119,690),.1)){Pixels.Add(P);Names.Add(TEXT("pier_left_edge"));break;}
        }
        const auto& Facilities=Spec->GetArrayField(TEXT("facilities"));
        if(Facilities.Num()>=3){Pixels.Add(ReadPoint(Facilities[2]));Names.Add(TEXT("right_gate_edge"));Pixels.Add(ReadPoint(Facilities[0]));Names.Add(TEXT("left_workshop"));}
        Check(Pixels.Num()==5 && Names.Num()==5,TEXT("five_landmarks_come_from_source_spawn_nodes_and_facilities"));
        if(!OK){Finish();return true;}
        Position();return true;
    }
    Wait+=Dt;
    const bool MovingCapture=(Phase==3 || Phase==4) && Wait>=.35f;
    const bool MovementDone=Phase==5 && Wait>=.3f;
    if((Phase==0 && Wait>=.7f) || MovingCapture || MovementDone){
        const FString CaptureName=Phase==3?TEXT("moving_D"):Phase==4?TEXT("moving_W"):Phase==5?TEXT("movement_end"):Names[PointIndex];
        const FVector2D CapturePixel=Phase>=3?FVector2D(836-PlayerPos.X/(180./52),470.5-PlayerPos.Y*FMath::Sin(FMath::DegreesToRadians(48.))/(180./52)):Pixels[PointIndex];
        const auto C=Camera->GetCameraComponent();
        Check(bGreyfordReference && GreyfordStage==0 && !bCombat,TEXT("capture_did_not_leave_village"));
        Check(C->ProjectionMode==ECameraProjectionMode::Perspective && FMath::IsNearlyEqual(Camera->GetActorRotation().Pitch,-60.f,.01f) && FMath::IsNearlyEqual(C->FieldOfView,50.f,.01f),TEXT("actual_camera_is_perspective_pitch60_hfov50"));
        bool CornersInside=true,RaysHit=true;int32 Corner=0;
        for(const FVector2D Screen:{FVector2D(0,0),FVector2D(VX,0),FVector2D(VX,VY),FVector2D(0,VY)}){
            FVector Origin,Direction;
            const bool Deprojected=PC->DeprojectScreenPositionToWorld(Screen.X,Screen.Y,Origin,Direction);
            const double T=Deprojected && FMath::Abs(Direction.Z)>1.e-8?-Origin.Z/Direction.Z:-1;
            const bool Hit=Deprojected && T>=0;RaysHit &= Hit;
            FVector2D Source(-99999,-99999);
            if(Hit){
                const FVector Ground=Origin+Direction*T;
                Source=FVector2D(836-Ground.X/(180./52),470.5-Ground.Y*FMath::Sin(FMath::DegreesToRadians(48.))/(180./52));
                CornersInside &= FMath::IsFinite(Source.X) && FMath::IsFinite(Source.Y) && Source.X>=-.5 && Source.X<=1672.5 && Source.Y>=-.5 && Source.Y<=941.5;
            }else CornersInside=false;
            const FVector CameraPos=Camera->GetActorLocation();
            Coverage+=FString::Printf(TEXT("%s,%.3f,%.3f,%d,%.6f,%.6f,%.6f,%.6f,%.6f\n"),*CaptureName,CapturePixel.X,CapturePixel.Y,Corner++,Source.X,Source.Y,CameraPos.X,CameraPos.Y,CameraPos.Z);
        }
        Check(RaysHit,TEXT("all_four_actual_viewport_corner_rays_intersect_ground"));
        Check(CornersInside,TEXT("all_four_ground_corners_inside_source_image_with_half_pixel_tolerance"));
        Check(ReferencePerspectiveCards.Num()>0 && ReferencePerspectiveMaterials.Num()>0,TEXT("perspective_cards_and_materials_exist"));
        bool Modes=true,CoverageOK=true,DepthOK=true,PlanesOK=true;
        for(auto M:ReferencePerspectiveMaterials){Modes &= IsValid(M) && FMath::IsNearlyEqual(M->K2_GetScalarParameterValue(TEXT("VillagePerspective")),1.f,.001f);}
        for(auto Card:ReferencePerspectiveCards){
            if(!IsValid(Card)){CoverageOK=DepthOK=PlanesOK=false;continue;}
            const FVector Offset=Card->GetActorLocation()-Camera->GetActorLocation();
            const double Depth=FVector::DotProduct(Offset,Camera->GetActorForwardVector());
            DepthOK &= FMath::Abs(Depth-100)<1 && (Offset-Camera->GetActorForwardVector()*Depth).Size()<1;
            PlanesOK &= FMath::Abs(FVector::DotProduct(Card->GetActorUpVector(),Camera->GetActorForwardVector()))>.999;
            FBox2D Bounds(ForceInit);bool Projected=true;
            for(int X:{-1,1})for(int Y:{-1,1}){
                FVector2D Screen;const FVector World=Card->GetActorTransform().TransformPosition(FVector(X*50,Y*50,0));
                const bool Visible=PC->ProjectWorldLocationToScreen(World,Screen);Projected &= Visible;if(Visible)Bounds+=Screen;
            }
            CoverageOK &= Projected && Bounds.bIsValid && Bounds.Min.X<=.5 && Bounds.Min.Y<=.5 && Bounds.Max.X>=VX-.5 && Bounds.Max.Y>=VY-.5;
            auto M=Cast<UMaterialInstanceDynamic>(Card->GetStaticMeshComponent()->GetMaterial(0));
            Modes &= IsValid(M) && FMath::IsNearlyEqual(M->K2_GetScalarParameterValue(TEXT("VillagePerspective")),1.f,.001f);
        }
        Check(Modes,TEXT("all_cached_and_drawn_MIDs_use_VillagePerspective_one"));
        Check(DepthOK,TEXT("registered_plane_centers_are_camera_forward_100cm"));
        Check(PlanesOK && CoverageOK,TEXT("camera_facing_planes_cover_all_viewport_corners_without_gaps"));
        if(Phase>=3){
            Check(FVector::Dist2D(PlayerPos,LegStart)>10 && CharacterAnimation.Moving,TEXT("injected_controller_key_runs_real_production_movement"));
            Check(Walkable(PlayerPos,45),TEXT("moving_player_remains_on_legal_village_ground"));
            if(MovementDone){
                Check(FVector::Dist2D(PlayerPos,MovementStart)>20,TEXT("one_second_controller_sequence_has_real_net_displacement"));
                for(int I=5;I<Files.Num();I++)Check(IFileManager::Get().FileSize(*Files[I])>0,TEXT("moving_show_UI_native_screenshot_was_written"));
                Finish();return true;
            }
            const FString MovingFile=Dir/FString::Printf(TEXT("%02d-moving%s_%s.png"),Phase==3?6:7,Phase==3?TEXT(""):TEXT("_W"),*Resolution);
            Files.Add(MovingFile);FScreenshotRequest::RequestScreenshot(MovingFile,true,false);
            Key(Phase==3?EKeys::D:EKeys::W,false);Key(Phase==3?EKeys::W:EKeys::S,true);
            LegStart=PlayerPos;Phase++;Wait=0;return true;
        }
        const FString File=Dir/FString::Printf(TEXT("%02d-%s_%s.png"),PointIndex+1,*Names[PointIndex],*Resolution);
        Files.Add(File);FScreenshotRequest::RequestScreenshot(File,true,false);
        Phase=1;Wait=0;return true;
    }
    if(Phase==1 && Wait>=.35f){
        Check(IFileManager::Get().FileSize(*Files.Last())>0,TEXT("show_UI_native_screenshot_was_written"));
        PointIndex++;
        if(PointIndex>=Pixels.Num()){
            PointIndex=0;Position();
            bool RouteFound=false;
            const FVector Right=Camera->GetActorRightVector().GetSafeNormal2D(),Forward=Camera->GetActorForwardVector().GetSafeNormal2D();
            for(int Y=480;Y<=720 && !RouteFound;Y+=40)for(int X=550;X<=1200 && !RouteFound;X+=50){
                const FVector P=ReferencePoint(X,Y),A=P+Right*190,B=A+Forward*190,C=B-Forward*160;
                if(Walkable(P,45) && SegmentClear(P,A,45) && SegmentClear(A,B,45) && SegmentClear(B,C,45)){
                    PlayerPos=P;UpdateCamera(0);UpdateCharacterVisual(0,false);RouteFound=true;
                    UE_LOG(LogTemp,Display,TEXT("VILLAGE_PERSPECTIVE_MOVEMENT_ROUTE source=%d,%d swept_clear=1"),X,Y);
                }
            }
            Check(RouteFound,TEXT("controller_fixture_uses_an_open_swept_route_not_a_wall"));
            if(!RouteFound){Finish();return true;}
            MovementStart=LegStart=PlayerPos;Key(EKeys::D,true);Phase=3;Wait=0;return false;
        }
        Position();return true;
    }
    return !(Phase>=3 && Phase<=5);
}
