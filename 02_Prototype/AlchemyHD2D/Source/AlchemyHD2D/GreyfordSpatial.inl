// Spatial QA runs the shipped movement code and captures named art/ground contacts.
void AAlchemyWorld::GreyfordSpatialCheck(float Dt) {
    if(SpatialCase<0){
        FString Spec=FPaths::ProjectDir()/TEXT("Tools/GreyfordSpatial.json"),Text;
        FParse::Value(FCommandLine::Get(),TEXT("GreyfordSpatialSpec="),Spec);
        SpatialDir=FPaths::ProjectDir()/TEXT("Evidence/Greyford/Spatial/Runtime");FParse::Value(FCommandLine::Get(),TEXT("GreyfordSpatialOut="),SpatialDir);
        IFileManager::Get().MakeDirectory(*SpatialDir,true);
        FFileHelper::SaveStringToFile(TEXT(""),*(SpatialDir/TEXT("screen.csv")));
        TSharedPtr<FJsonObject> Data;
        if(!FFileHelper::LoadFileToString(Text,*Spec) || !FJsonSerializer::Deserialize(TJsonReaderFactory<>::Create(Text),Data)){
            UE_LOG(LogTemp,Error,TEXT("GREYFORD_SPATIAL missing fixture"));FPlatformMisc::RequestExitWithStatus(false,1);return;
        }
        FString Cases=TEXT("name,pixel_x,pixel_y,expected,actual\n");int Paths=0,PathFailures=0;
        for(const auto& V:Data->GetArrayField(TEXT("cases"))){
            const auto& A=V->AsArray();const FString Name=A[0]->AsString();const float X=A[1]->AsNumber(),Y=A[2]->AsNumber();
            const bool Expected=A[3]->AsBool(),Actual=Walkable(ReferencePoint(X,Y));SpatialOK &= Expected==Actual;
            Cases+=FString::Printf(TEXT("%s,%.1f,%.1f,%d,%d\n"),*Name,X,Y,Expected,Actual);
            UE_LOG(LogTemp,Display,TEXT("SPATIAL_CASE %s expected=%d actual=%d %s"),*Name,Expected,Actual,Expected==Actual?TEXT("PASS"):TEXT("FAIL"));
            if(Expected){
                const FVector Goal=ReferencePoint(X,Y);TArray<FVector> Path;bool Reached=FindPath(PlayerPos,Goal,45,Path);FVector P=PlayerPos;
                for(auto Target:Path){for(int I=0;I<1500 && FVector::Dist2D(P,Target)>1;I++){auto Next=Move(P,(Target-P).GetClampedToMaxSize(20));if(Next.Equals(P,.01)){Reached=false;break;}P=Next;}}
                Reached &= FVector::Dist2D(P,Goal)<2;Paths++;PathFailures+=!Reached;SpatialOK &= Reached;
                UE_LOG(LogTemp,Display,TEXT("SPATIAL_PATH %s %s"),*Name,Reached?TEXT("PASS"):TEXT("FAIL"));
                SpatialNames.Add(Name);SpatialPoints.Add(Goal);
            }
        }
        FFileHelper::SaveStringToFile(Cases,*(SpatialDir/TEXT("cases.csv")));
        FString Grid=TEXT("pixel_x,pixel_y,walkable\n");int GridCount=0,Open=0,Escapes=0,Probes=0;TSet<FIntPoint> OpenCells;
        for(int Y=4;Y<941;Y+=8)for(int X=4;X<1672;X+=8){
            const FVector Start=ReferencePoint(X,Y);const bool OK=Walkable(Start);GridCount++;Open+=OK;
            Grid+=FString::Printf(TEXT("%d,%d,%d\n"),X,Y,OK);
            if(OK)OpenCells.Add(FIntPoint(X,Y));
            if(OK)for(const FVector D:{FVector(1,0,0),FVector(-1,0,0),FVector(0,1,0),FVector(0,-1,0)})for(float Distance:{200.f,600.f}){
                const FVector End=Move(Start,D*Distance);Probes++;bool Valid=Walkable(End);
                const int N=FMath::CeilToInt(FVector::Dist2D(Start,End)/2);
                for(int I=1;I<N && Valid;I++)Valid=Walkable(FMath::Lerp(Start,End,float(I)/N));
                Escapes+=!Valid;
            }
        }
        int Components=0;
        while(!OpenCells.IsEmpty()){
            TArray<FIntPoint> Queue;Queue.Add(*OpenCells.CreateConstIterator());OpenCells.Remove(Queue[0]);Components++;
            for(int I=0;I<Queue.Num();I++)for(const FIntPoint D:{FIntPoint(8,0),FIntPoint(-8,0),FIntPoint(0,8),FIntPoint(0,-8)}){
                const FIntPoint A=Queue[I],B=A+D;
                if(OpenCells.Contains(B) && ReferenceSweep(ReferencePoint(A.X,A.Y),ReferencePoint(B.X,B.Y),45)){OpenCells.Remove(B);Queue.Add(B);}
            }
        }
        SpatialOK &= Escapes==0 && Components==1;
        FFileHelper::SaveStringToFile(Grid,*(SpatialDir/TEXT("grid.csv")));
        FFileHelper::SaveStringToFile(FString::Printf(TEXT("grid_points=%d\nwalkable=%d\nmovement_probes=%d\nswept_path_failures=%d\nconnected_components=%d\nlandmark_paths=%d\nlandmark_path_failures=%d\n"),GridCount,Open,Probes,Escapes,Components,Paths,PathFailures),*(SpatialDir/TEXT("coverage.txt")));
        SpatialCase=0;SpatialTime=0;
    }
    SpatialTime+=Dt;
    if(SpatialTime>=.25f){
        SpatialTime=0;
        if(SpatialCase>=SpatialPoints.Num()){
            FFileHelper::SaveStringToFile(SpatialOK?TEXT("PASS\n"):TEXT("FAIL\n"),*(SpatialDir/TEXT("result.txt")));
            UE_LOG(LogTemp,Display,TEXT("GREYFORD_SPATIAL_%s"),SpatialOK?TEXT("PASS"):TEXT("FAIL"));FPlatformMisc::RequestExitWithStatus(false,SpatialOK?0:1);return;
        }
        PlayerPos=SpatialPoints[SpatialCase];LastDirection=FVector(0,-1,0);UpdateCamera(0);UpdateCharacterVisual(0,false);
        PlayerShadow->SetActorLocation(VillageVisualPoint(PlayerPos+FVector(0,0,5)));
        const FString File=SpatialDir/FString::Printf(TEXT("%02d-%s.png"),SpatialCase,*SpatialNames[SpatialCase]);
        int VX=1280,VY=720;GetWorld()->GetFirstPlayerController()->GetViewportSize(VX,VY);
        FVector2D Screen(VX/2.f-(PlayerPos.X-ReferenceCameraFocus.X)*VX/ViewWidth,VY/2.f-(PlayerPos.Y-ReferenceCameraFocus.Y)*FMath::Sin(FMath::DegreesToRadians(48.f))*VX/ViewWidth);
        FString Row=FString::Printf(TEXT("%02d,%s,%.2f,%.2f\n"),SpatialCase,*SpatialNames[SpatialCase],Screen.X,Screen.Y);
        FFileHelper::SaveStringToFile(Row,*(SpatialDir/TEXT("screen.csv")),FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM,&IFileManager::Get(),FILEWRITE_Append);
        FTimerHandle Timer;GetWorld()->GetTimerManager().SetTimer(Timer,[File](){FScreenshotRequest::RequestScreenshot(File,false,false);},.1f,false);
        SpatialCase++;
    }
}
