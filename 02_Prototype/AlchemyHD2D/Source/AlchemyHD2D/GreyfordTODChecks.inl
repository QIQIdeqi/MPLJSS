bool AAlchemyWorld::GreyfordTODCheck(float Dt){
    static int Phase=0;
    static float Wait=0, NoonLength=0, DuskOpacity=0, PausedAt=0, SavedOpacity=0;
    static FVector NoonDirection, MoveStart, PropFoot;
    static bool Passed=true;
    const FString Folder=FPaths::ProjectDir()/TEXT("Evidence/TOD_20261106/ArtMatch");
    const auto Check=[&](bool Valid,const TCHAR* Name){
        Passed &= Valid;
        UE_LOG(LogTemp,Display,TEXT("TOD_CHECK %s %s"),Name,Valid?TEXT("PASS"):TEXT("FAIL"));
    };
    const auto SetHour=[&](float Hour){
        RunTime=FMath::Fmod(Hour-TODSettings.StartHour+24.f,24.f)*TODSettings.CycleSeconds/24.f;
        UpdateCamera(0);UpdateCharacterVisual(0,false);
    };
    const auto PropProjection=[&](float& Length,float& Opacity){
        bool Found=false;
        for(TActorIterator<AStaticMeshActor> It(GetWorld());It;++It){
            if(It->IsHidden() || !It->ActorHasTag(TEXT("GreyfordTODShadow")))continue;
            auto* Mesh=It->GetStaticMeshComponent();
            auto* MID=Cast<UMaterialInstanceDynamic>(Mesh->GetMaterial(0));
            if(!MID)return false;
            const auto P=MID->K2_GetVectorParameterValue(TEXT("ShadowFoot"));
            const FVector Foot(P.R,P.G,P.B);
            const auto* Caster=TODPropCasters.FindByPredicate([&](const auto& C){return FVector::Dist2D(Foot,C.Foot)<1;});
            if(!Caster || MID->K2_GetTextureParameterValue(TEXT("ShadowTexture"))!=Caster->Texture.Get()
                || !FMath::IsNearlyEqual(MID->K2_GetScalarParameterValue(TEXT("ShadowFootFraction")),Caster->FootFraction,.001f))return false;
            if(FVector::Dist2D(Foot,PropFoot)>1)continue;
            Length=MID->K2_GetScalarParameterValue(TEXT("ShadowLength"));
            Opacity=MID->K2_GetScalarParameterValue(TEXT("ShadowOpacity"));
            const FVector Axis=It->GetActorForwardVector();
            const auto Shear=MID->K2_GetVectorParameterValue(TEXT("ShadowShear"));
            const FVector Base=It->GetActorRightVector()*Caster->Width+FVector(Shear.R,Shear.G,Shear.B);
            Found=Foot.Equals(PropFoot,.1) && Base.Equals(Caster->WidthAxis*Caster->Width,.1)
                && It->GetActorLocation().Equals(Foot+Axis*Length*.5,1)
                && Axis.Equals(GreyfordTOD.GetShadowDirection(),.01)
                && Mesh->GetCollisionEnabled()==ECollisionEnabled::NoCollision
                && !It->GetActorEnableCollision() && Mesh->TranslucencySortPriority<0;
        }
        return Found;
    };
    const auto Shot=[&](const TCHAR* Name){
        IFileManager::Get().MakeDirectory(*Folder,true);
        FScreenshotRequest::RequestScreenshot(Folder/Name,true,false);
    };
#if WITH_EDITOR
    if(GShaderCompilingManager && GShaderCompilingManager->IsCompiling()){
        GShaderCompilingManager->FinishAllCompilation();Wait=0;return true;
    }
#endif
    Wait+=Dt;
    if(Wait<.4f){
        if(Phase==6)Panel=TEXT("skills");
        return Phase!=6 && Phase!=7;
    }
    Wait=0;
    float Length=0,Opacity=0;
    switch(Phase++){
        case 0:{
            StartRun();
            ToastTime=0;
            Check(bRandomBattleScene && IsValid(TODShadowMaterial) && !TODPropCasters.IsEmpty(),TEXT("field_layout_and_shadow_material"));
            if(!bRandomBattleScene){FPlatformMisc::RequestExitWithStatus(false,1);return true;}
            float Best=1.e20f;
            for(TActorIterator<AAlchemyTileCell> It(GetWorld());It;++It){
                if(It->GetOwner()!=Designer || It->BrushName!=TEXT("Oak"))continue;
                const FVector C=It->GetActorLocation()+FVector(550,0,-It->GetActorLocation().Z);
                const float Cost=C.SizeSquared2D();
                if(Cost<Best && Walkable(C,45)){Best=Cost;PlayerPos=C;PropFoot=It->GetActorLocation();}
            }
            SetHour(13);break;
        }
        case 1:
            Check(PropProjection(NoonLength,Opacity) && Opacity>0,TEXT("only_props_cast_original_alpha_with_pinned_base"));
            NoonDirection=GreyfordTOD.GetShadowDirection();
            Check(FMath::IsNearlyEqual(GreyfordTOD.GetHour(),13.f,.01f),TEXT("afternoon_clock"));
            Shot(TEXT("01-field-1300.png"));break;
        case 2:
            SetHour(18);break;
        case 3:
            Check(PropProjection(Length,DuskOpacity) && Length>NoonLength*2 && Length<=TODSettings.MaxShadowLength,
                TEXT("low_sun_lengthens_prop_shadow_without_moving_base"));
            Check(!GreyfordTOD.GetShadowDirection().Equals(NoonDirection,.1)
                && GreyfordTOD.GetShadowDirection().X>.6 && GreyfordTOD.GetShadowDirection().Y<-.6,
                TEXT("shadow_rotates_with_sun_and_extends_down_left_at_dusk"));
            Shot(TEXT("02-field-1800.png"));break;
        case 4:
            SavedOpacity=TODSettings.ShadowOpacity;TODSettings.ShadowOpacity=0;UpdateCamera(0);break;
        case 5:
            Shot(TEXT("02a-field-1800-no-projection.png"));PausedAt=RunTime;break;
        case 6:
            Check(FMath::IsNearlyEqual(RunTime,PausedAt) && FMath::IsNearlyEqual(GreyfordTOD.GetHour(),18.f,.01f),TEXT("production_panel_freezes_clock"));
            TODSettings.ShadowOpacity=SavedOpacity;Panel.Empty();MoveStart=PlayerPos;
            GetWorld()->GetFirstPlayerController()->InputKey(FInputKeyParams(EKeys::D,IE_Pressed,1,false));break;
        case 7:
            Check(RunTime>PausedAt && GreyfordTOD.GetHour()>18.f,TEXT("production_clock_resumes"));
            GetWorld()->GetFirstPlayerController()->InputKey(FInputKeyParams(EKeys::D,IE_Released,0,false));
            Check(!PlayerPos.Equals(MoveStart,1) && PropProjection(Length,Opacity),TEXT("player_moves_without_casting_or_dragging_prop_shadows"));
            PlayerPos=MoveStart;
            SetHour(22);break;
        case 8:
            Check(PropProjection(Length,Opacity) && Opacity<DuskOpacity && GreyfordTOD.GetSceneTint().B>GreyfordTOD.GetSceneTint().R,
                TEXT("night_grade_and_fainter_shadows"));
            Shot(TEXT("03-field-2200.png"));break;
        case 9:{
            RunTime=300;UpdateGreyfordPortal();PlayerPos=GreyfordPortalPos;UpdateCamera(0);
            const float Hour=GreyfordTOD.GetHour();
            const bool Entered=EnterGreyfordBoss();
            Check(Entered && GreyfordStage==2 && FMath::IsNearlyEqual(Hour,GreyfordTOD.GetHour(),.01f)
                && GreyfordTOD.GetShadowCount()>1,TEXT("boss_inherits_time_and_rebuilds_shadows"));
            if(!Entered){FPlatformMisc::RequestExitWithStatus(false,1);return true;}
            break;
        }
        case 10:
            Shot(TEXT("04-boss-entry.png"));break;
        case 11:{
            GreyfordBossPreparation=0;
            auto& Boss=Enemies[0];Boss.DashDirection=(PlayerPos-Boss.Pos).GetSafeNormal2D();
            ShowPlannedBossLines(Boss,true,true);
            UpdateCamera(0);break;
        }
        case 12:
            Shot(TEXT("05-boss-warning.png"));break;
        default:
            BuildScene(false);
            Check(GreyfordStage==0 && GreyfordTOD.GetShadowCount()==0 && !Camera->GetCameraComponent()->PostProcessSettings.bOverride_ColorGain,
                TEXT("return_clears_shadows_and_grade"));
            UE_LOG(LogTemp,Display,TEXT("GREYFORD_TOD_%s"),Passed?TEXT("PASS"):TEXT("FAIL"));
            FPlatformMisc::RequestExitWithStatus(false,Passed?0:1);break;
    }
    return true;
}
