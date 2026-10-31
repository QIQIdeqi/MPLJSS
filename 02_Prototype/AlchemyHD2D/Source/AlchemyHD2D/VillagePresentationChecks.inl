#include "Camera/CameraActor.h"
#include "Camera/CameraComponent.h"
#include "Engine/Level.h"
#include "Engine/StaticMeshActor.h"
#include "Materials/MaterialInstanceDynamic.h"

// Current presentation contract: stable source artwork, logical collisions, mapped render feet.
// The older ground-frustum homography fixture is intentionally not used here.
bool AAlchemyWorld::VillagePresentationCheck(float Dt) {
    static int32 Phase=-1,Index=0;
    static float Wait=0;
    static FVector MovingFrom;
    static bool OK=true;
    static FString Res,Coverage;
    static TArray<FVector2D> Points;
    static TArray<FString> Names,Files;
    const FString Dir=FPaths::ProjectDir()/TEXT("Evidence/VillagePresentation_20261031");
    auto* PC=GetWorld()->GetFirstPlayerController();
    const auto Check=[&](bool Pass,const TCHAR* Name){OK &= Pass;UE_LOG(LogTemp,Display,TEXT("VILLAGE_PRESENTATION_CHECK %s %s"),Name,Pass?TEXT("PASS"):TEXT("FAIL"));};
    const auto Finish=[&](){
        FFileHelper::SaveStringToFile(Coverage,*(Dir/FString::Printf(TEXT("projection_%s.csv"),*Res)),FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM);
        FFileHelper::SaveStringToFile(FString::Printf(TEXT("{\"result\":\"%s\",\"resolution\":\"%s\",\"village_landmarks\":%d,\"screenshots\":%d}\n"),OK?TEXT("PASS"):TEXT("FAIL"),*Res,Points.Num(),Files.Num()),*(Dir/FString::Printf(TEXT("verification_%s.json"),*Res)));
        UE_LOG(LogTemp,Display,TEXT("VILLAGE_PRESENTATION_%s resolution=%s screenshots=%d"),OK?TEXT("PASS"):TEXT("FAIL"),*Res,Files.Num());
        Phase=5;FPlatformMisc::RequestExitWithStatus(false,OK?0:1);
    };
    if(Phase==5)return true;
    if(!PC){Check(false,TEXT("controller_exists"));Finish();return true;}
    int VX=0,VY=0;PC->GetViewportSize(VX,VY);if(VX<=0 || VY<=0)return true;
    const auto Shot=[&](const FString& Name){const FString File=Dir/(Name+TEXT("_")+Res+TEXT(".png"));Files.Add(File);FScreenshotRequest::RequestScreenshot(File,true,false);Wait=0;};
    const auto CheckLastShot=[&](){Check(!Files.IsEmpty() && IFileManager::Get().FileSize(*Files.Last())>0,TEXT("show_UI_native_screenshot_written"));};
    const auto Pose=[&](){
        PlayerPos=ReferencePoint(Points[Index].X,Points[Index].Y);ReferenceCameraReady=false;UpdateCamera(0);
        LastDirection=-Camera->GetActorForwardVector().GetSafeNormal2D();UpdateCharacterVisual(0,false);
        if(PlayerShadow)PlayerShadow->SetActorLocation(VillageVisualPoint(PlayerPos)+FVector(0,0,5));
        Panel.Empty();ToastTime=0;Wait=0;
    };
    const auto CheckProjection=[&](const TCHAR* Label){
        auto C=Camera->GetCameraComponent();
        Check(C->ProjectionMode==ECameraProjectionMode::Perspective && FMath::IsNearlyEqual(Camera->GetActorRotation().Pitch,-60.f,.01f) && FMath::IsNearlyEqual(C->FieldOfView,50.f,.01f),TEXT("camera_remains_actual_60_degree_perspective_HFOV50"));
        const double S=180./52,Sin=FMath::Sin(FMath::DegreesToRadians(48.)),Scale=VX*S/ViewWidth;
        const double CX=836-ReferenceCameraFocus.X/S,CY=470.5-ReferenceCameraFocus.Y*Sin/S;
        bool Projected=true,Affine=true;double Worst=0;
        const auto Project=[&](FVector2D P){
            FVector2D Screen;const FVector L=ReferencePoint(P.X,P.Y);
            const bool Hit=PC->ProjectWorldLocationToScreen(VillageVisualPoint(L),Screen);Projected &= Hit;
            const FVector2D Expected(VX*.5-(L.X-ReferenceCameraFocus.X)*VX/ViewWidth,VY*.5-(L.Y-ReferenceCameraFocus.Y)*Sin*VX/ViewWidth);
            if(Hit){const double Error=FVector2D::Distance(Screen,Expected);Worst=FMath::Max(Worst,Error);Affine &= Error<=1.5;
                Coverage+=FString::Printf(TEXT("%s,%.4f,%.4f,%.6f,%.6f,%.6f,%.6f,%.6f\n"),Label,P.X,P.Y,Screen.X,Screen.Y,Expected.X,Expected.Y,Error);}
            else Affine=false;
            return Screen;
        };
        bool Lengths=true,Angles=true;
        for(double DY:{-90.,0.,90.}){
            const FVector2D A=Project({CX-50,CY+DY-50}),B=Project({CX+50,CY+DY-50}),D=Project({CX-50,CY+DY+50});
            const FVector2D X=B-A,Y=D-A;
            Lengths &= FMath::Abs(X.Size()-100*Scale)<=1.5 && FMath::Abs(Y.Size()-100*Scale)<=1.5;
            Angles &= FMath::Abs(FVector2D::DotProduct(X.GetSafeNormal(),Y.GetSafeNormal()))<.005;
        }
        Project(Points[FMath::Clamp(Index,0,Points.Num()-1)]);
        Check(Projected && Affine,TEXT("logical_source_to_visual_projection_matches_stable_affine_artwork"));
        Check(Lengths && Angles,TEXT("source_100px_grid_preserves_lengths_and_right_angles_across_y"));
        const FVector RenderFoot=Player->GetActorLocation()+Player->GetActorRightVector()*CharacterAnimation.FootOffset()*VillageVisualScale(PlayerPos);
        Check(FVector::Dist(RenderFoot,VillageVisualPoint(PlayerPos))<1,TEXT("actual_player_render_foot_uses_visual_mapping"));
        Check(ReferencePerspectiveMaterials.Num()>0,TEXT("village_presentation_materials_active"));
        bool Modes=true;for(auto M:ReferencePerspectiveMaterials)Modes &= IsValid(M) && FMath::IsNearlyEqual(M->K2_GetScalarParameterValue(TEXT("VillagePerspective")),1.f,.001f);
        Check(Modes,TEXT("village_registered_material_mode_one"));
        UE_LOG(LogTemp,Display,TEXT("VILLAGE_PRESENTATION_GRID %s worst_error_px=%.6f scale=%.6f"),Label,Worst,Scale);
    };
    if(Phase<0){
        Res=FString::Printf(TEXT("%dx%d"),VX,VY);Coverage=TEXT("view,source_x,source_y,screen_x,screen_y,expected_x,expected_y,error_px\n");IFileManager::Get().MakeDirectory(*Dir,true);
        Check(bCapture,TEXT("isolated_capture_never_reads_or_writes_player_progress"));if(!bCapture){Finish();return true;}
        Progress=NewObject<UAlchemyProgress>(this);MigrateProgress(true);BuildScene(false);
        Check(bGreyfordReference && GreyfordStage==0 && !bCombat,TEXT("start_in_village_stage_zero"));
        Points={{843,480},{375,615},{119,690},{1513,432},{443,340}};Names={TEXT("spawn"),TEXT("bridge"),TEXT("pier_left"),TEXT("right_gate"),TEXT("workshop")};
        // Production Move sweeps must stop before a semantic well, house, or river target.
        TArray<TPair<FVector2D,FVector2D>> CollisionPairs;
        CollisionPairs.Emplace(FVector2D(780,486),FVector2D(775,434));
        CollisionPairs.Emplace(FVector2D(443,342),FVector2D(400,260));
        CollisionPairs.Emplace(FVector2D(375,615),FVector2D(400,699));
        for(const auto& Pair:CollisionPairs){
            const FVector A=ReferencePoint(Pair.Key.X,Pair.Key.Y),B=ReferencePoint(Pair.Value.X,Pair.Value.Y);
            Check(Walkable(A,45) && !Walkable(B,45),TEXT("collision_fixture_has_legal_start_and_blocked_target"));
            const FVector End=Move(A,B-A,45);bool Safe=Walkable(End,45) && FVector::Dist2D(End,B)>30;
            const int Steps=FMath::Max(1,FMath::CeilToInt(FVector::Dist2D(A,End)/5));for(int I=1;I<Steps;I++)Safe &= Walkable(FMath::Lerp(A,End,float(I)/Steps),45);
            Check(Safe,TEXT("production_Move_cannot_cross_well_house_or_river"));
        }
        const TArray<FVector2D> Bridge={{553,536},{498,568},{435,591},{375,615},{308,642},{256,660},{218,676}};
        FVector Cursor=ReferencePoint(Bridge[0].X,Bridge[0].Y);bool Crossed=Walkable(Cursor,45);
        for(int I=1;I<Bridge.Num();I++){
            const FVector Goal=ReferencePoint(Bridge[I].X,Bridge[I].Y);
            for(int Step=0;Step<500 && FVector::Dist2D(Cursor,Goal)>1;Step++){const FVector Next=Move(Cursor,(Goal-Cursor).GetClampedToMaxSize(10),45);if(Next.Equals(Cursor,.001)){Crossed=false;break;}Cursor=Next;}
            Crossed &= FVector::Dist2D(Cursor,Goal)<2;
        }
        Check(Crossed,TEXT("production_Move_continuously_crosses_both_bridge_landings"));
        for(int I=0;I<3;I++){TArray<FVector> Path;Check(Walkable(FacilityPosition(I),45) && FindPath(ReferencePoint(843,480),FacilityPosition(I),45,Path),TEXT("all_three_village_facilities_have_production_paths"));}
        Index=0;Pose();Phase=0;return true;
    }
    Wait+=Dt;
    if(Phase==0 && Wait>=.7f){
        Check(Walkable(PlayerPos,45),TEXT("landmark_player_ground_is_legal"));CheckProjection(*Names[Index]);
        Shot(FString::Printf(TEXT("%02d-%s"),Index+1,*Names[Index]));Phase=1;return true;
    }
    if(Phase==1 && Wait>=.7f){
        CheckLastShot();Index++;
        if(Index<Points.Num()){Pose();Phase=0;return true;}
        PlayerPos=ReferencePoint(800,480);UpdateCamera(0);UpdateCharacterVisual(0,false);MovingFrom=PlayerPos;
        FInputKeyEventArgs Key;Key.Key=EKeys::D;Key.Event=IE_Pressed;Key.AmountDepressed=1;PC->InputKey(Key);Phase=8;Wait=0;return false;
    }
    if(Phase==8){
        if(Wait<.35f)return false;
        FInputKeyEventArgs Key;Key.Key=EKeys::D;Key.Event=IE_Released;PC->InputKey(Key);
        Check(FVector::Dist2D(PlayerPos,MovingFrom)>20 && CharacterAnimation.Moving,TEXT("real_D_input_moves_hero_with_registered_follow_camera"));
        CheckProjection(TEXT("moving_camera"));Shot(TEXT("06-village-moving"));Phase=9;return true;
    }
    if(Phase==9 && Wait>=.7f){
        CheckLastShot();PlayerPos=FacilityPosition(2);UpdateCamera(0);UpdateCharacterVisual(0,false);
        FInputKeyEventArgs Key;Key.Key=EKeys::F;Key.Event=IE_Pressed;Key.AmountDepressed=1;PC->InputKey(Key);Phase=10;Wait=0;return false;
    }
    if(Phase==10){
        if(Wait<.1f)return false;
        FInputKeyEventArgs Key;Key.Key=EKeys::F;Key.Event=IE_Released;PC->InputKey(Key);
        Check(Panel==TEXT("level"),TEXT("real_F_at_village_gate_opens_departure_menu"));
        Progress->TutorialComplete=false;Action(TEXT("start"));Panel.Empty();ToastTime=0;UpdateCamera(0);UpdateCharacterVisual(0,false);Phase=2;Wait=0;return true;
    }
    if(Phase==2 && Wait>=.1f){
        Check(bCombat && GreyfordStage==1 && bBattleReference && !bGreyfordReference,TEXT("normal_StartRun_enters_registered_battle_stage"));
        Check(BattleCards.Num()==7 && BattleRegions.Num()==13,TEXT("battle_has_seven_cards_and_thirteen_regions"));
        Check(BattleWidget && BattleWidget->GetClass()->GetPathName().Contains(TEXT("WBP_BattleReference_C")) && BattleWidget->IsInViewport(),TEXT("native_editable_battle_HUD_exists_in_viewport"));
        bool Clean=true;for(auto M:ReferencePerspectiveMaterials)Clean &= !IsValid(M) || FMath::IsNearlyZero(M->K2_GetScalarParameterValue(TEXT("VillagePerspective")),.001f);
        for(auto Card:ReferencePerspectiveCards)if(IsValid(Card))Clean &= !Card->GetLevel()->bIsVisible;
        Check(Clean,TEXT("village_cards_are_hidden_and_mode_zero_after_battle_entry"));
        const FVector RenderFoot=Player->GetActorLocation()+Player->GetActorRightVector()*CharacterAnimation.FootOffset()*VillageVisualScale(PlayerPos);
        Check(FVector::Dist(RenderFoot,PlayerPos)<1,TEXT("battle_player_has_no_stale_village_visual_foot_mapping"));
        Shot(TEXT("07-entered-battle-0p1s"));Phase=11;return false;
    }
    if(Phase==11){if(Wait<.4f)return false;CheckLastShot();Shot(TEXT("08-entered-battle-0p5s"));Phase=12;return false;}
    if(Phase==12){if(Wait<1.5f)return false;CheckLastShot();Shot(TEXT("09-entered-battle-2s"));Phase=13;return true;}
    if(Phase==13 && Wait>=.7f){
        CheckLastShot();GreyfordPortalReady=true;GreyfordPortalPos=PlayerPos;
        Check(EnterGreyfordBoss(),TEXT("normal_boss_transition_succeeds"));UpdateCamera(0);UpdateCharacterVisual(0,false);Phase=14;Wait=0;return true;
    }
    if(Phase==14 && Wait>=.7f){
        Check(GreyfordStage==2 && !bBattleReference && !bGreyfordReference,TEXT("boss_uses_own_scene_without_village_or_battle_cards"));
        Check(bReferenceBossScene && BattleCards.Num()==7,TEXT("boss_reuses_registered_meadow_artwork_without_tiled_ground"));
        Shot(TEXT("10-boss-ground-and-HUD"));Phase=15;return true;
    }
    if(Phase==15 && Wait>=.7f){
        CheckLastShot();EndRun(false);Action(TEXT("village"));Panel.Empty();ToastTime=0;UpdateCamera(0);UpdateCharacterVisual(0,false);Index=0;Phase=4;Wait=0;return true;
    }
    if(Phase==4 && Wait>=.7f){
        Check(bGreyfordReference && GreyfordStage==0 && !bCombat && !bBattleReference,TEXT("normal_result_return_restores_village_presentation"));
        CheckProjection(TEXT("returned_village"));Shot(TEXT("11-returned-village"));Phase=6;return true;
    }
    if(Phase==6 && Wait>=.7f){CheckLastShot();Finish();return true;}
    return true;
}
