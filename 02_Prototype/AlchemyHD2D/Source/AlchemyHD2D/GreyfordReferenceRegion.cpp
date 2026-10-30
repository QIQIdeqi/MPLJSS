#include "GreyfordReferenceRegion.h"
#include "DrawDebugHelpers.h"
#include "EngineUtils.h"
#if WITH_EDITOR
#include "Editor.h"
#include "LevelEditorViewport.h"
#include "Camera/CameraActor.h"
#include "Camera/CameraComponent.h"
#include "Dom/JsonObject.h"
#include "Serialization/JsonSerializer.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#endif

AGreyfordReferenceRegion::AGreyfordReferenceRegion(){
    RootComponent=CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
    Outline=CreateDefaultSubobject<USplineComponent>(TEXT("CollisionOutline"));Outline->SetupAttachment(RootComponent);Outline->SetHiddenInGame(true);
    Outline->ClearSplinePoints(false);Outline->SetClosedLoop(true,false);Outline->SetCollisionEnabled(ECollisionEnabled::NoCollision);
    Vertices={FVector(-100,-100,0),FVector(100,-100,0),FVector(100,100,0),FVector(-100,100,0)};
    Tags.Add(TEXT("GreyfordReference"));
#if WITH_EDITOR
    PrimaryActorTick.bCanEverTick=true;
    Outline->bInputSplinePointsToConstructionScript=true;
#endif
}

void AGreyfordReferenceRegion::PostLoad(){Super::PostLoad();InitializeOutline();}
void AGreyfordReferenceRegion::OnConstruction(const FTransform& Transform){Super::OnConstruction(Transform);InitializeOutline();}
void AGreyfordReferenceRegion::InitializeOutline(){
    if(!Outline->GetNumberOfSplinePoints()){
        FVector Center=FVector::ZeroVector;for(auto P:Vertices)Center+=P;if(Vertices.Num())Center/=Vertices.Num();
        TArray<FVector> Local;for(auto P:Vertices)Local.Add(P-Center);
        SetActorLocation(GetActorTransform().TransformPosition(Center));Outline->SetSplinePoints(Local,ESplineCoordinateSpace::Local,false);
    }
    for(int I=0;I<Outline->GetNumberOfSplinePoints();I++){
        FVector P=Outline->GetLocationAtSplinePoint(I,ESplineCoordinateSpace::Local);P.Z=0;
        Outline->SetLocationAtSplinePoint(I,P,ESplineCoordinateSpace::Local,false);
        Outline->SetSplinePointType(I,ESplinePointType::Linear,false);
    }
    Outline->SetClosedLoop(true,false);Outline->UpdateSpline();
#if WITH_EDITOR
    const FLinearColor Color=bBlocked?FLinearColor(1,.12f,.08f):FLinearColor(.05f,1,.35f);
    Outline->SetUnselectedSplineSegmentColor(Color);Outline->SetSelectedSplineSegmentColor(Color);
    Outline->SetDrawDebug(bShowOutline);
#endif
}

TArray<FVector> AGreyfordReferenceRegion::GetWorldVertices() const {
    TArray<FVector> Points;
    for(int I=0;I<Outline->GetNumberOfSplinePoints();I++){
        FVector P=Outline->GetLocationAtSplinePoint(I,ESplineCoordinateSpace::World);P.Z=0;Points.Add(P);
    }
    return Points;
}
bool AGreyfordReferenceRegion::Contains(FVector P) const {
    // Avoid an allocation in the per-movement collision query.
    bool Inside=false;
    for(int I=0,J=Outline->GetNumberOfSplinePoints()-1;I<Outline->GetNumberOfSplinePoints();J=I++){
        const FVector A=Outline->GetLocationAtSplinePoint(I,ESplineCoordinateSpace::World),B=Outline->GetLocationAtSplinePoint(J,ESplineCoordinateSpace::World);
        if((A.Y>P.Y)!=(B.Y>P.Y) && P.X<(B.X-A.X)*(P.Y-A.Y)/(B.Y-A.Y)+A.X)Inside=!Inside;
    }
    return Inside;
}
void AGreyfordReferenceRegion::Tick(float Dt){
    Super::Tick(Dt);
#if WITH_EDITOR
    if(GetWorld() && !GetWorld()->IsGameWorld()){
        const auto Points=GetWorldVertices();const FColor Color=bBlocked?FColor(255,50,35):FColor(30,255,100);
        // Native spline undo can restore a clean package flag after a save. Keep reverted geometry saveable.
        if(bEditorPointsKnown && Points!=LastEditorPoints)MarkPackageDirty();
        LastEditorPoints=Points;bEditorPointsKnown=true;
        if(bShowOutline)for(int I=0;I<Points.Num();I++)DrawDebugLine(GetWorld(),Points[I],Points[(I+1)%Points.Num()],Color,false,0,SDPG_Foreground,IsSelected()?3.f:1.5f);
    }
#endif
}
void AGreyfordReferenceRegion::AlignReferenceView(){
#if WITH_EDITOR
    if(!GEditor || !GEditor->GetActiveViewport() || GetWorld()->IsGameWorld())return;
    ACameraActor* Camera=nullptr;
    for(TActorIterator<ACameraActor> It(GetWorld());It;++It)if(It->ActorHasTag(TEXT("GreyfordCollisionEditorCamera"))){Camera=*It;break;}
    if(!Camera){Camera=GetWorld()->SpawnActor<ACameraActor>();Camera->Tags.Add(TEXT("GreyfordCollisionEditorCamera"));Camera->bIsEditorOnlyActor=true;Camera->SetActorLabel(TEXT("CollisionEditorCamera"));Camera->SetFolderPath(TEXT("Greyford/Reference/Editor"));}
    const FRotator Rotation(-48,90,0);Camera->SetActorLocationAndRotation(-Rotation.Vector()*10000,Rotation);
    const FIntPoint Size=GEditor->GetActiveViewport()->GetSizeXY();
    auto C=Camera->GetCameraComponent();C->ProjectionMode=ECameraProjectionMode::Orthographic;C->OrthoWidth=1672.f*180/52*FMath::Max(1.f,Size.X/FMath::Max(1.f,float(Size.Y))/(1672.f/941));C->bConstrainAspectRatio=false;
    C->PostProcessSettings.bOverride_ToneCurveAmount=true;C->PostProcessSettings.ToneCurveAmount=0;
    auto* View=static_cast<FLevelEditorViewportClient*>(GEditor->GetActiveViewport()->GetClient());View->SetActorLock(Camera);View->UpdateViewForLockedActor();View->SetRealtime(true);View->Invalidate();
#endif
}
void AGreyfordReferenceRegion::SaveCollisionLayout(){
#if WITH_EDITOR
    if(GetWorld()->IsGameWorld())return;
    const FString Path=FPaths::ProjectDir()/TEXT("Tools/GreyfordReference.json");FString Text;TSharedPtr<FJsonObject> Data;
    if(!FFileHelper::LoadFileToString(Text,*Path) || !FJsonSerializer::Deserialize(TJsonReaderFactory<>::Create(Text),Data)){EditorStatus=TEXT("读取源数据失败，未写入");return;}
    TArray<TSharedPtr<FJsonValue>> Walk,Blocked;
    for(TActorIterator<AGreyfordReferenceRegion> It(GetWorld());It;++It)if(It->GetLevel()==GetLevel()){
        const auto Points=It->GetWorldVertices();if(Points.Num()<3){EditorStatus=TEXT("存在不足三个顶点的区域，未写入");return;}
        TSharedPtr<FJsonObject> Region=MakeShared<FJsonObject>();FString Name=It->GetActorLabel();Name.RemoveFromStart(TEXT("Reference_blocked_"));Name.RemoveFromStart(TEXT("Reference_walk_"));Region->SetStringField(TEXT("name"),Name);
        TArray<TSharedPtr<FJsonValue>> Pixels;
        for(auto P:Points){TArray<TSharedPtr<FJsonValue>> XY;XY.Add(MakeShared<FJsonValueNumber>(FMath::RoundToDouble((836-P.X/(180./52))*1000)/1000));XY.Add(MakeShared<FJsonValueNumber>(FMath::RoundToDouble((470.5-P.Y*FMath::Sin(FMath::DegreesToRadians(48.))/(180./52))*1000)/1000));Pixels.Add(MakeShared<FJsonValueArray>(XY));}
        Region->SetArrayField(TEXT("points"),Pixels);(It->bBlocked?Blocked:Walk).Add(MakeShared<FJsonValueObject>(Region));
    }
    Data->SetArrayField(TEXT("walk"),Walk);Data->SetArrayField(TEXT("blocked"),Blocked);Text.Empty();FJsonSerializer::Serialize(Data.ToSharedRef(),TJsonWriterFactory<>::Create(&Text));
    EditorStatus=FFileHelper::SaveStringToFile(Text,*Path,FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM)?FString::Printf(TEXT("已导出 %d 个通行区、%d 个阻挡区；请 Ctrl+S 保存关卡"),Walk.Num(),Blocked.Num()):TEXT("写入失败");
    UE_LOG(LogTemp,Display,TEXT("GREYFORD_COLLISION_EXPORT %s"),*EditorStatus);
#endif
}
