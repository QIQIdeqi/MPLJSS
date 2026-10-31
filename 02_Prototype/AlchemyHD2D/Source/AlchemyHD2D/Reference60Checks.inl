#include "Components/ProgressBar.h"
#include "Components/TextBlock.h"
#include "InputKeyEventArgs.h"

// Native rendered fixture. true freezes simulation; false lets the injected controller key run production Tick.
bool AAlchemyWorld::Reference60Check(float Dt) {
    static bool RefQAOK=true;
    static FVector RefMovementStart=FVector::ZeroVector;
    static float RefOriginalHP=0;
    const FString Dir=FPaths::ProjectDir()/TEXT("Evidence/Reference60_20261031");
    auto* PC=GetWorld()->GetFirstPlayerController();
    const auto Check=[&](bool Pass,const TCHAR* Name){RefQAOK &= Pass;UE_LOG(LogTemp,Display,TEXT("REFERENCE60_CHECK %s %s"),Name,Pass?TEXT("PASS"):TEXT("FAIL"));};
    const auto Key=[&](FKey Value,bool Pressed){FInputKeyEventArgs Event;Event.Key=Value;Event.Event=Pressed?IE_Pressed:IE_Released;Event.AmountDepressed=Pressed?1:0;PC->InputKey(Event);};
    const auto Shot=[&](const TCHAR* Name){Player->SetActorHiddenInGame(false);FScreenshotRequest::RequestScreenshot(Dir/Name,true,false);};
    const auto Next=[&](int32 Step){CaptureStep=Step;SmokeTime=0;};
    const auto Finish=[&](){for(const FKey K:{EKeys::D,EKeys::W,EKeys::S})Key(K,false);UE_LOG(LogTemp,Display,TEXT("REFERENCE60_%s"),RefQAOK?TEXT("PASS"):TEXT("FAIL"));FPlatformMisc::RequestExitWithStatus(false,RefQAOK?0:1);};
    if(CaptureStep==0) {
        RefQAOK=true;Check(bCapture,TEXT("isolated_fixture_never_reads_or_writes_player_save"));
        if(!bCapture){Finish();return true;}
        IFileManager::Get().MakeDirectory(*Dir,true);
        Progress=NewObject<UAlchemyProgress>(this);MigrateProgress(true);StartRun();
        for(auto& E:Enemies){if(IsValid(E.Body))E.Body->Destroy();if(IsValid(E.Shadow))E.Shadow->Destroy();}Enemies.Empty();
        if(!bBattleReference)Check(BuildBattleReferenceScene(),TEXT("reference_scene_built"));
        Check(bBattleReference && BattleCards.Num()>0 && ReferenceRegions.Num()>0,TEXT("registered_scene_and_collision_active"));
        if(!bBattleReference){Finish();return true;}
        PlayerPos=BattleReferencePoint({846,495});LastDirection=-Camera->GetActorForwardVector().GetSafeNormal2D();
        UpdateCamera(0);UpdateCharacterVisual(0,false);
        MaxHP=HP=320;RunLevel=12;RunXP=RequiredXP(RunLevel)*.77f;RunTime=328;RunCoins=1240;Kills=532;
        DodgeCD=1.2f;SpawnCD=NextElite=NextMerchantTime=10000;CloseMerchant();ToastTime=0;Panel.Empty();
        Equipped={0,1,2,3};Levels[0]=3;Levels[1]=2;Levels[2]=4;Levels[3]=1;for(float& CD:SkillCD)CD=10000;
        Check(CharacterAnimation.HasRoseMotion(),TEXT("authored_three_direction_motion_atlases_loaded"));
        TSharedPtr<FJsonObject> Spec;FString Input;
        Check(FFileHelper::LoadFileToString(Input,*(FPaths::ProjectContentDir()/TEXT("Reference/BattleReferenceSpec.json"))) && FJsonSerializer::Deserialize(TJsonReaderFactory<>::Create(Input),Spec),TEXT("cooked_semantic_fixture_loaded"));
        if(Spec.IsValid()) {
            double Worst=0;int Vertices=0,Paths=0;bool Semantic=true,Routes=true,Sweeps=true;
            for(const TCHAR* Group:{TEXT("walk"),TEXT("blocked")})for(const auto& Region:Spec->GetArrayField(Group))for(const auto& Value:Region->AsObject()->GetArrayField(TEXT("points"))){
                const auto& A=Value->AsArray();const FVector2D Pixel(A[0]->AsNumber(),A[1]->AsNumber());Worst=FMath::Max(Worst,FVector2D::Distance(Pixel,BattleReferencePixel(BattleReferencePoint(Pixel))));Vertices++;
            }
            for(const auto& Value:Spec->GetArrayField(TEXT("semantic_checks"))) {
                const auto Item=Value->AsObject();const auto& A=Item->GetArrayField(TEXT("pixel"));const FVector Goal=BattleReferencePoint({A[0]->AsNumber(),A[1]->AsNumber()});
                const bool Expected=Item->GetBoolField(TEXT("walkable")),Actual=Walkable(Goal,45);Semantic &= Expected==Actual;
                UE_LOG(LogTemp,Display,TEXT("REFERENCE60_SEMANTIC %s expected=%d actual=%d"),*Item->GetStringField(TEXT("name")),Expected,Actual);
                if(!Expected || !Actual)continue;
                TArray<FVector> Route;bool Reach=FindPath(PlayerPos,Goal,45,Route);FVector Cursor=PlayerPos;
                for(auto Target:Route)for(int I=0;I<1500 && FVector::Dist2D(Cursor,Target)>1;I++){const FVector End=Move(Cursor,(Target-Cursor).GetClampedToMaxSize(20),45);if(End.Equals(Cursor,.01)){Reach=false;break;}Cursor=End;}
                Routes &= Reach && FVector::Dist2D(Cursor,Goal)<2;Paths++;
                for(const FVector D:{FVector(1,0,0),FVector(-1,0,0),FVector(0,1,0),FVector(0,-1,0)})for(float Travel:{200.f,600.f}) {
                    const FVector End=Move(Goal,D*Travel,45);Sweeps &= Walkable(End,45);
                    const int N=FMath::Max(1,FMath::CeilToInt(FVector::Dist2D(Goal,End)/5));for(int I=1;I<N;I++)Sweeps &= Walkable(FMath::Lerp(Goal,End,float(I)/N),45);
                }
            }
            Check(Vertices>0 && Worst<=2,TEXT("all_authored_vertices_source_world_roundtrip_within_2px"));Check(Semantic,TEXT("all_semantic_walk_and_block_points"));
            Check(Paths>0 && Routes,TEXT("semantic_paths_use_production_move"));Check(Sweeps,TEXT("production_sweeps_stay_on_authored_ground"));
            UE_LOG(LogTemp,Display,TEXT("REFERENCE60_COVERAGE vertices=%d worst_source_error=%.6f paths=%d"),Vertices,Worst,Paths);
        }
        Next(1);return true;
    }
    SmokeTime+=Dt;
    if(CaptureStep==1 && SmokeTime>1.2f) {
        auto C=Camera->GetCameraComponent();Check(C->ProjectionMode==ECameraProjectionMode::Perspective && FMath::IsNearlyEqual(Camera->GetActorRotation().Pitch,-60.f,.01f) && C->FieldOfView>10 && C->FieldOfView<60,TEXT("native_camera_perspective_pitch60_registered_near_frustum"));
        Check(BattleWidget && BattleWidget->GetClass()->GetPathName().Contains(TEXT("WBP_BattleReference_C")),TEXT("editable_WBP_loaded_in_actual_viewport"));
        if(BattleWidget) {
            auto H=Cast<UProgressBar>(BattleWidget->GetWidgetFromName(TEXT("HPBar")));auto T=Cast<UTextBlock>(BattleWidget->GetWidgetFromName(TEXT("HPText")));auto K=Cast<UTextBlock>(BattleWidget->GetWidgetFromName(TEXT("KillText")));auto Coin=Cast<UTextBlock>(BattleWidget->GetWidgetFromName(TEXT("CoinText")));
            Check(H && T && K && Coin && FMath::IsNearlyEqual(H->GetPercent(),1) && T->GetText().ToString().Contains(TEXT("320")) && K->GetText().ToString()==FText::AsNumber(Kills).ToString() && Coin->GetText().ToString()==FText::AsNumber(RunCoins).ToString(),TEXT("real_HP_and_numeric_state_bound_after_render_frame"));
            auto Root=BattleWidget->GetWidgetFromName(TEXT("ReferenceCanvas"));auto Frame=BattleWidget->GetWidgetFromName(TEXT("HPFrame"));
            if(Root && Frame){const auto G=Root->GetCachedGeometry();const auto FG=Frame->GetCachedGeometry();const auto P=G.AbsoluteToLocal(FG.LocalToAbsolute(FVector2D::ZeroVector));int VX=0,VY=0;PC->GetViewportSize(VX,VY);
                const auto Size=G.GetAbsoluteSize();Check(FVector2D::Distance(P,{197,27})<=2 && Size.X>0 && Size.Y>0 && Size.X<=VX+2 && Size.Y<=VY+2 && FMath::Abs(Size.X/Size.Y-1672./940)<.003,TEXT("actual_UMG_geometry_keeps_reference_anchor_uniform_fit"));
                UE_LOG(LogTemp,Display,TEXT("REFERENCE60_UI viewport=%dx%d artwork=%.2fx%.2f hp_anchor=%.2f,%.2f"),VX,VY,Size.X,Size.Y,P.X,P.Y);
            }else Check(false,TEXT("editable_reference_layout_nodes_exist"));
        }
        for(int Definition:{0,7}){const int Before=Enemies.Num();SpawnEnemy(Definition);const bool Added=Enemies.Num()==Before+1;
            Check(Added,Definition==0?TEXT("normal_spawn_available"):TEXT("elite_spawn_available"));
            if(Added){auto& E=Enemies.Last();FBox2D Bounds(ForceInit);const auto& Def=EnemyDefinition(E);for(int X:{-1,1})for(int Y:{-1,1}){FVector2D P;PC->ProjectWorldLocationToScreen(E.Body->GetActorLocation()+E.Body->GetActorForwardVector()*(X*Def.VisualSize.X*.5)+E.Body->GetActorRightVector()*(Y*Def.VisualSize.Y*.5),P);Bounds+=P;}
                int VX=0,VY=0;PC->GetViewportSize(VX,VY);const double Fit=FMath::Min(double(VX)/1672,double(VY)/941),L=(VX-1672*Fit)/2,Top=(VY-941*Fit)/2;
                Check(Bounds.bIsValid && (Bounds.Max.X<L || Bounds.Min.X>L+1672*Fit || Bounds.Max.Y<Top || Bounds.Min.Y>Top+941*Fit),Definition==0?TEXT("normal_actual_sprite_projected_offscreen"):TEXT("elite_actual_sprite_projected_offscreen"));
                E.Pos=PlayerPos+Camera->GetActorRightVector().GetSafeNormal2D()*(Definition==0?-550:550);E.Speed=0;UpdateEnemyVisual(E);
            }
        }
        Next(14);return true;
    }
    if(CaptureStep==14 && SmokeTime>.6f){Shot(TEXT("01-field-reference-ui.png"));Next(2);return true;}
    if(CaptureStep==2 && SmokeTime>.3f){RefMovementStart=PlayerPos;Key(EKeys::D,true);Next(3);return false;}
    if(CaptureStep==3){if(SmokeTime<.32f)return false;Key(EKeys::D,false);Check(FVector::Dist2D(PlayerPos,RefMovementStart)>40 && CharacterAnimation.Moving && CharacterAnimation.Row==1 && CharacterAnimation.Facing==0 && CharacterAnimation.Frame>0,TEXT("injected_D_runs_production_movement_side_pose"));Shot(TEXT("02-running-side.png"));Next(4);return true;}
    if(CaptureStep==4 && SmokeTime>.3f){RefMovementStart=PlayerPos;Key(EKeys::W,true);Next(5);return false;}
    if(CaptureStep==5){if(SmokeTime<.32f)return false;Key(EKeys::W,false);Check(FVector::Dist2D(PlayerPos,RefMovementStart)>40 && CharacterAnimation.Moving && CharacterAnimation.Facing==2,TEXT("injected_W_runs_production_back_pose"));Shot(TEXT("03-running-back.png"));Next(6);return true;}
    if(CaptureStep==6 && SmokeTime>.3f){RefMovementStart=PlayerPos;Key(EKeys::S,true);Next(7);return false;}
    if(CaptureStep==7){if(SmokeTime<.32f)return false;Key(EKeys::S,false);Check(FVector::Dist2D(PlayerPos,RefMovementStart)>40 && CharacterAnimation.Moving && CharacterAnimation.Facing==1,TEXT("injected_S_runs_production_front_pose"));Shot(TEXT("04-running-front.png"));Next(8);return true;}
    if(CaptureStep==8 && SmokeTime>.3f){RefOriginalHP=HP;HurtInv=DodgeInv=0;Hurt(24);Check(HP<RefOriginalHP && CharacterAnimation.Hurting,TEXT("real_Hurt_enters_authored_hurt_state"));Next(9);return true;}
    if(CaptureStep==9){UpdateCharacterVisual(Dt,false);if(SmokeTime<.15f)return true;
        Check(CharacterAnimation.Row==3 && CharacterAnimation.Frame>0,TEXT("hurt_motion_frames_advance"));
        if(BattleWidget){auto H=Cast<UProgressBar>(BattleWidget->GetWidgetFromName(TEXT("HPBar")));auto T=Cast<UTextBlock>(BattleWidget->GetWidgetFromName(TEXT("HPText")));Check(H && T && FMath::IsNearlyEqual(H->GetPercent(),HP/MaxHP,.001f) && T->GetText().ToString().Contains(FString::Printf(TEXT("%.0f"),HP)),TEXT("UMG_HP_binding_changes_after_real_damage"));}
        Shot(TEXT("05-hurt-frame.png"));Next(10);return true;
    }
    if(CaptureStep==10 && SmokeTime>.3f){for(auto& FX:Effects)if(IsValid(FX.Body))FX.Body->Destroy();Effects.Empty();HurtInv=DodgeInv=0;Hurt(10000);Check(HP<=0 && bRunEnded && CharacterAnimation.Dead,TEXT("real_lethal_Hurt_enters_defeat_and_death_motion"));Next(11);return true;}
    if(CaptureStep==11){UpdateCharacterVisual(Dt,false);if(SmokeTime<.15f)return true;Check(CharacterAnimation.Row==4 && CharacterAnimation.Frame>0,TEXT("death_motion_early_frame"));Shot(TEXT("06-death-early.png"));Next(12);return true;}
    if(CaptureStep==12){UpdateCharacterVisual(Dt,false);if(SmokeTime<.49f)return true;Check(CharacterAnimation.Frame>=4,TEXT("death_motion_late_distinct_frame"));Shot(TEXT("07-death-late.png"));Next(13);return true;}
    if(CaptureStep==13 && SmokeTime>.7f){
        for(const TCHAR* Name:{TEXT("01-field-reference-ui.png"),TEXT("02-running-side.png"),TEXT("03-running-back.png"),TEXT("04-running-front.png"),TEXT("05-hurt-frame.png"),TEXT("06-death-early.png"),TEXT("07-death-late.png")})Check(IFileManager::Get().FileSize(*(Dir/Name))>0,TEXT("native_screenshot_written"));
        Finish();return true;
    }
    return true;
}
