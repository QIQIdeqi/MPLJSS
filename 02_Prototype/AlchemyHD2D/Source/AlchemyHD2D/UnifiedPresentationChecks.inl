#include "Components/StaticMeshComponent.h"
#include "Engine/StaticMeshActor.h"

// Isolated rendered fixture for the shared close camera, registered art and normal stage transitions.
bool AAlchemyWorld::UnifiedPresentationCheck(float Dt){
    static int32 Phase=-1,FieldIndex=0;
    static float Wait=0;
    static bool OK=true;
    static FString Res,CSV;
    static double VillageHeight=0,FieldHeight=0;
    static TArray<FVector> FieldPoints;
    static TArray<FString> FieldNames,Files,FieldMaterials;
    static TArray<FTransform> FieldTransforms;
    static FVector2D FirstOffset=FVector2D::ZeroVector;
    const FString Dir=FPaths::ProjectDir()/TEXT("Evidence/UnifiedPresentation_20261031");
    auto* PC=GetWorld()->GetFirstPlayerController();
    const auto Check=[&](bool Pass,const TCHAR* Name){OK &= Pass;UE_LOG(LogTemp,Display,TEXT("UNIFIED_PRESENTATION_CHECK %s %s"),Name,Pass?TEXT("PASS"):TEXT("FAIL"));};
    const auto Finish=[&](){
        FFileHelper::SaveStringToFile(CSV,*(Dir/FString::Printf(TEXT("camera_%s.csv"),*Res)),FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM);
        FFileHelper::SaveStringToFile(FString::Printf(TEXT("{\"result\":\"%s\",\"resolution\":\"%s\",\"screenshots\":%d,\"village_canvas_height_px\":%.5f,\"field_canvas_height_px\":%.5f}\n"),OK?TEXT("PASS"):TEXT("FAIL"),*Res,Files.Num(),VillageHeight,FieldHeight),*(Dir/FString::Printf(TEXT("verification_%s.json"),*Res)));
        UE_LOG(LogTemp,Display,TEXT("UNIFIED_PRESENTATION_%s resolution=%s screenshots=%d"),OK?TEXT("PASS"):TEXT("FAIL"),*Res,Files.Num());
        Phase=20;FPlatformMisc::RequestExitWithStatus(false,OK?0:1);
    };
    if(Phase==20)return true;
    if(!PC){Check(false,TEXT("controller_exists"));Finish();return true;}
    int VX=0,VY=0;PC->GetViewportSize(VX,VY);if(VX<=0 || VY<=0)return true;
    const float AdaptedWidth=2400.f*float(VX)/VY/(16.f/9);
    const auto Shot=[&](const FString& Name){const FString File=Dir/(Name+TEXT("_")+Res+TEXT(".png"));Files.Add(File);FScreenshotRequest::RequestScreenshot(File,true,false);Wait=0;};
    const auto Written=[&](){Check(!Files.IsEmpty() && IFileManager::Get().FileSize(*Files.Last())>0,TEXT("show_UI_native_screenshot_written"));};
    const auto Bounds=[&](AActor* Body){
        FBox2D Result(ForceInit);if(!IsValid(Body))return Result;
        const FBox Box=Body->GetComponentsBoundingBox(true);
        for(int I=0;I<8;I++){FVector2D P;const FVector W((I&1)?Box.Max.X:Box.Min.X,(I&2)?Box.Max.Y:Box.Min.Y,(I&4)?Box.Max.Z:Box.Min.Z);if(PC->ProjectWorldLocationToScreen(W,P))Result+=P;}
        return Result;
    };
    const auto InView=[&](const FBox2D& B){return B.bIsValid && B.Min.X>=-2 && B.Min.Y>=-2 && B.Max.X<=VX+2 && B.Max.Y<=VY+2;};
    const auto Measure=[&](const TCHAR* Name){
        const double Scale=VillageVisualScale(PlayerPos),Size=CharacterAnimation.SheetWorldSize()*Scale;
        const FVector Center=Player->GetActorLocation(),Up=Player->GetActorRightVector();FVector2D Top,Bottom;
        const bool P=PC->ProjectWorldLocationToScreen(Center-Up*Size*.5,Top) && PC->ProjectWorldLocationToScreen(Center+Up*Size*.5,Bottom);
        const double Height=P?FVector2D::Distance(Top,Bottom):0;
        auto C=Cast<UAlchemyCameraComponent>(Camera->GetCameraComponent());FMinimalViewInfo View;if(C)C->GetCameraView(0,View);
        Check(P && Height>0 && C && C->ProjectionMode==ECameraProjectionMode::Perspective && FMath::IsNearlyEqual(Camera->GetActorRotation().Pitch,-60.f,.01f),TEXT("native_projection_and_hero_canvas_are_measurable_at_pitch60"));
        Check(C && View.OffCenterProjectionOffset.Equals(C->ProjectionOffset,.0001),TEXT("actual_GetCameraView_contains_component_projection_offset"));
        Check(InView(Bounds(Player)),TEXT("complete_live_hero_canvas_is_inside_actual_viewport"));
        CSV+=FString::Printf(TEXT("%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n"),Name,Height,Height*320/512,ViewWidth,C?C->FieldOfView:0,C?C->ProjectionOffset.X:0,C?C->ProjectionOffset.Y:0,PlayerPos.X,PlayerPos.Y,Scale);
        return Height;
    };
    const auto PrepareFieldPoint=[&](){PlayerPos=FieldPoints[FieldIndex];Check(Walkable(PlayerPos,45),TEXT("selected_semantic_field_point_is_legal"));UpdateCharacterVisual(0,false);Wait=0;};
    if(Phase<0){
        Res=FString::Printf(TEXT("%dx%d"),VX,VY);CSV=TEXT("view,canvas_height_px,visible_body_height_px,view_width_cm,hfov,offset_x,offset_y,logical_x,logical_y,village_visual_scale\n");IFileManager::Get().MakeDirectory(*Dir,true);
        Check(bCapture,TEXT("fixture_has_isolated_no_save_progress"));if(!bCapture){Finish();return true;}
        Progress=NewObject<UAlchemyProgress>(this);MigrateProgress(true);BuildScene(false);PlayerPos=ReferencePoint(843,480);ReferenceCameraReady=false;UpdateCamera(0);UpdateCharacterVisual(0,false);Panel.Empty();ToastTime=0;
        Check(GreyfordStage==0 && bGreyfordReference,TEXT("normal_village_is_first_stage"));Phase=0;Wait=0;return true;
    }
    Wait+=Dt;
    if(Phase==0 && Wait>=.7f){
        Check(FMath::IsNearlyEqual(ViewWidth,AdaptedWidth,2.f) && FMath::IsNearlyEqual(Camera->GetCameraComponent()->FieldOfView,50.f,.01f),TEXT("village_uses_adapted_close_reference_and_HFOV50"));
        VillageHeight=Measure(TEXT("village"));Shot(TEXT("01-village-close"));Phase=1;return true;
    }
    if(Phase==1 && Wait>=.7f){
        Written();StartRun();Panel.Empty();ToastTime=0;
        TSharedPtr<FJsonObject> Spec;FString Input;
        const bool Loaded=FFileHelper::LoadFileToString(Input,*(FPaths::ProjectContentDir()/TEXT("Reference/BattleReferenceSpec.json"))) && FJsonSerializer::Deserialize(TJsonReaderFactory<>::Create(Input),Spec) && Spec.IsValid();Check(Loaded,TEXT("cooked_field_semantic_spec_loaded"));
        if(!Loaded){Finish();return true;}
        for(const TCHAR* Name:{TEXT("player_spawn"),TEXT("upper_meadow"),TEXT("cart_approach")})for(const auto& V:Spec->GetArrayField(TEXT("semantic_checks"))){const auto Row=V->AsObject();if(Row->GetStringField(TEXT("name"))!=Name || !Row->GetBoolField(TEXT("walkable")))continue;const auto& P=Row->GetArrayField(TEXT("pixel"));FieldPoints.Add(BattleReferencePoint({P[0]->AsNumber(),P[1]->AsNumber()}));FieldNames.Add(Name);break;}
        Check(FieldPoints.Num()==3,TEXT("three_legal_center_and_edge_points_selected_from_semantic_spec"));
        if(FieldPoints.Num()!=3){Finish();return true;}
        for(auto Card:BattleCards){auto Mesh=Card->FindComponentByClass<UStaticMeshComponent>();FieldMaterials.Add(GetPathNameSafe(Mesh?Mesh->GetMaterial(0):nullptr));FieldTransforms.Add(Card->GetActorTransform());}
        PrepareFieldPoint();Phase=2;return true;
    }
    if(Phase==2){
        UpdateCamera(Dt);UpdateCharacterVisual(0,false);
        if(Wait<.7f)return true;
        Check(GreyfordStage==1 && bBattleReference && !bReferenceBossScene && BattleCards.Num()==7 && BattleRegions.Num()==13,TEXT("field_still_has_registered_seven_cards_thirteen_regions"));
        const double Height=Measure(*FieldNames[FieldIndex]);
        Check(VillageHeight>0 && FMath::Abs(Height/VillageHeight-1)<.15,TEXT("field_close_hero_canvas_matches_village_within_15_percent"));
        Check(FMath::IsNearlyEqual(ViewWidth,AdaptedWidth,1.f),TEXT("field_uses_same_adapted_character_scale"));
        Check(FVector::Dist(Camera->GetActorLocation(),BattleCameraPosition())<1,TEXT("field_fixed_calibration_eye_prevents_depth_card_registration_drift"));
        auto C=CastChecked<UAlchemyCameraComponent>(Camera->GetCameraComponent());
        if(FieldIndex==0){FieldHeight=Height;FirstOffset=C->ProjectionOffset;}
        else Check(FVector2D::Distance(FirstOffset,C->ProjectionOffset)>.02,TEXT("off_axis_framing_follows_separate_field_positions"));
        bool Stable=BattleCards.Num()==FieldTransforms.Num();for(int I=0;I<BattleCards.Num() && I<FieldTransforms.Num();I++)Stable &= BattleCards[I]->GetActorTransform().Equals(FieldTransforms[I],.01);
        Check(Stable,TEXT("follow_does_not_move_or_rescale_registered_field_layers"));
        Check(BattleWidget && BattleWidget->IsInViewport(),TEXT("real_battle_UMG_remains_in_viewport"));
        Shot(FString::Printf(TEXT("%02d-field-%s"),FieldIndex+2,*FieldNames[FieldIndex]));Phase=3;return true;
    }
    if(Phase==3 && Wait>=.7f){
        Written();FieldIndex++;if(FieldIndex<FieldPoints.Num()){PrepareFieldPoint();Phase=2;return true;}
        RunTime=300;UpdateGreyfordPortal();Check(GreyfordPortalReady,TEXT("normal_five_minute_portal_opens"));
        if(!GreyfordPortalReady){Finish();return true;}
        PlayerPos=GreyfordPortalPos;Panel=TEXT("bossportal");Action(TEXT("enterboss"));
        Check(GreyfordStage==2 && bReferenceBossScene && !bBattleReference && Enemies.Num()==1,TEXT("normal_portal_enters_reference_Boss_without_field_collision_mode"));
        if(Enemies.IsEmpty()){Finish();return true;}
        Check(FMath::IsNearlyEqual(FVector::Dist2D(PlayerPos,Enemies[0].Pos),1000.f,.1f) && FMath::IsNearlyEqual(GreyfordBossPreparation,2.f,.001f),TEXT("Boss_keeps_ten_meter_spacing_and_two_second_preparation"));
        Phase=4;Wait=0;return true;
    }
    if(Phase==4){
        UpdateCamera(Dt);UpdateCharacterVisual(0,false);if(Wait<.7f)return true;
        Measure(TEXT("boss_preparation"));Check(InView(Bounds(Player)) && InView(Bounds(Enemies[0].Body)),TEXT("preparation_frames_both_complete_characters_inside_viewport"));
        Check(CombatHalfSize==FVector2D(1600,1300) && Walkable({0,0,0},45) && Walkable({1500,0,0},45) && Walkable({0,1200,0},45) && !Walkable({1601,0,0},45) && !Walkable({0,1301,0},45) && !Walkable({1400,1000,0},45),TEXT("Boss_playable_32x26m_ellipse_is_unchanged"));
        bool Art=BattleCards.Num()==7 && FieldMaterials.Num()==7;
        for(int I=0;I<BattleCards.Num() && I<FieldMaterials.Num();I++){auto Mesh=BattleCards[I]->FindComponentByClass<UStaticMeshComponent>();Art &= Mesh && GetPathNameSafe(Mesh->GetMaterial(0))==FieldMaterials[I] && BattleCards[I]->GetActorScale3D().Equals(FVector(FieldTransforms[I].GetScale3D().X*1.75,FieldTransforms[I].GetScale3D().Y*1.75,FieldTransforms[I].GetScale3D().Z),.01);}
        Check(Art,TEXT("Boss_reuses_same_seven_art_materials_at_1_point_75_scale"));
        bool NoOldGround=true;for(TActorIterator<AStaticMeshActor> It(GetWorld());It;++It)if(It->GetLevel()==GreyfordActiveLevel && !It->IsHidden())NoOldGround &= !GetPathNameSafe(It->GetStaticMeshComponent()->GetMaterial(0)).Contains(TEXT("M_BossMeadow"));
        Check(NoOldGround,TEXT("old_large_flower_tiled_Boss_ground_is_not_visible"));
        Shot(TEXT("05-boss-preparation"));Phase=5;return true;
    }
    if(Phase==5 && Wait>=.7f){Written();Phase=6;Wait=0;return false;}
    if(Phase==6){
        if(GreyfordBossPreparation>0)return false;
        Check(!bRunEnded && GreyfordBossPreparation==0,TEXT("normal_production_Tick_completes_Boss_preparation"));
        PlayerPos={350,-200,0};Check(Walkable(PlayerPos,45),TEXT("Boss_close_follow_fixture_uses_legal_ground"));UpdateCharacterVisual(0,false);Phase=7;Wait=0;return true;
    }
    if(Phase==7){
        UpdateCamera(Dt);UpdateCharacterVisual(0,false);if(Wait<.7f)return true;
        const double Height=Measure(TEXT("boss_close"));
        Check(InView(Bounds(Player)) && InView(Bounds(Enemies[0].Body)),TEXT("active_close_Boss_and_hero_remain_inside_viewport"));
        Check(FieldHeight>0 && FMath::Abs(Height/FieldHeight-1)<.15,TEXT("Boss_close_character_canvas_matches_field_within_15_percent"));
        Check(FMath::IsNearlyEqual(ViewWidth,AdaptedWidth,1.f) && FVector::Dist(Camera->GetActorLocation(),BattleCameraPosition()*1.75)<1,TEXT("Boss_uses_adapted_close_scale_and_scaled_fixed_eye"));
        Shot(TEXT("06-boss-close-follow"));Phase=8;return true;
    }
    if(Phase==8 && Wait>=.7f){Written();EndRun(false);Action(TEXT("village"));Panel.Empty();ToastTime=0;UpdateCamera(0);UpdateCharacterVisual(0,false);Phase=9;Wait=0;return true;}
    if(Phase==9 && Wait>=.7f){
        Check(GreyfordStage==0 && bGreyfordReference && !bBattleReference && !bReferenceBossScene && BattleCards.IsEmpty(),TEXT("normal_result_return_clears_combat_art_and_restores_village"));
        const double Height=Measure(TEXT("returned_village"));Check(VillageHeight>0 && FMath::Abs(Height/VillageHeight-1)<.03,TEXT("return_preserves_village_close_character_scale"));
        Shot(TEXT("07-returned-village"));Phase=10;return true;
    }
    if(Phase==10 && Wait>=.7f){Written();Finish();return true;}
    return true;
}
