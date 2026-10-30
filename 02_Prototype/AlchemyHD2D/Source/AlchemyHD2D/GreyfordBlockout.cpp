#include "GreyfordBlockout.h"
#include "AlchemyWorld.h"
#include "Components/SphereComponent.h"
#include "Components/StaticMeshComponent.h"
#include "GameFramework/FloatingPawnMovement.h"
#include "GameFramework/PlayerController.h"
#include "Camera/CameraComponent.h"
#include "Camera/CameraTypes.h"
#include "Engine/StaticMeshActor.h"
#include "Engine/TargetPoint.h"
#include "EngineUtils.h"
#include "Engine/World.h"
#include "UnrealClient.h"
#include "Misc/Paths.h"
#include "Misc/FileHelper.h"
#include "HAL/FileManager.h"
#include "UObject/ConstructorHelpers.h"

AGreyfordBlockoutMode::AGreyfordBlockoutMode() {DefaultPawnClass=AGreyfordBlockoutPawn::StaticClass();}
AGreyfordCombatMode::AGreyfordCombatMode() {DefaultPawnClass=nullptr;HUDClass=AAlchemyHUD::StaticClass();}
void AGreyfordCombatMode::StartPlay() {
    Super::StartPlay();
    auto* Combat=GetWorld()->SpawnActorDeferred<AAlchemyWorld>(AAlchemyWorld::StaticClass(),FTransform::Identity);
    Combat->bGreyfordScene=true;Combat->FinishSpawning(FTransform::Identity);
}

AGreyfordBlockoutPawn::AGreyfordBlockoutPawn() {
    PrimaryActorTick.bCanEverTick=true;
    Body=CreateDefaultSubobject<USphereComponent>(TEXT("Body"));RootComponent=Body;
    Body->InitSphereRadius(35);Body->SetCollisionProfileName(TEXT("Pawn"));
    auto* Marker=CreateDefaultSubobject<UStaticMeshComponent>(TEXT("ScaleMarker"));Marker->SetupAttachment(Body);
    static ConstructorHelpers::FObjectFinder<UStaticMesh> Sphere(TEXT("/Engine/BasicShapes/Sphere.Sphere"));
    Marker->SetStaticMesh(Sphere.Object);Marker->SetRelativeScale3D(FVector(.7,.7,.7));
    Marker->SetCollisionEnabled(ECollisionEnabled::NoCollision);
    Movement=CreateDefaultSubobject<UFloatingPawnMovement>(TEXT("Movement"));Movement->SetUpdatedComponent(Body);
    Movement->MaxSpeed=500;Movement->Acceleration=10000;Movement->Deceleration=10000;
    Movement->SetPlaneConstraintEnabled(true);Movement->SetPlaneConstraintNormal(FVector::UpVector);
    Camera=CreateDefaultSubobject<UCameraComponent>(TEXT("Camera"));Camera->SetupAttachment(Body);
    Camera->ProjectionMode=ECameraProjectionMode::Orthographic;Camera->OrthoWidth=2844;
    Camera->SetRelativeLocation(FVector(0,-3500,3887));Camera->SetRelativeRotation(FRotator(-48,90,0));
}

void AGreyfordBlockoutPawn::SetOverview(bool Value) {
    Overview=Value;
    Camera->SetUsingAbsoluteLocation(Value);Camera->SetUsingAbsoluteRotation(true);
    Camera->SetWorldRotation(FRotator(Value?-90:-48,90,0));
    Camera->OrthoWidth=Value?21000:2844;
    if(Value) Camera->SetWorldLocation(FVector(0,0,16000));
    else Camera->SetRelativeLocation(FVector(0,-3500,3887));
}

bool AGreyfordBlockoutPawn::VerifyCollision() {
    bool OK=true;int32 SpawnCount=0;
    const FVector Original=GetActorLocation();
    for(TActorIterator<ATargetPoint> It(GetWorld());It;++It) {
        if(!It->ActorHasTag(TEXT("GreyfordSpawn")))continue;
        ++SpawnCount;
        const FVector P=It->GetActorLocation();
        const bool Free=!GetWorld()->OverlapBlockingTestByChannel(P,FQuat::Identity,ECC_Pawn,FCollisionShape::MakeSphere(35),FCollisionQueryParams(NAME_None,false,this));
        OK &= Free;UE_LOG(LogTemp,Display,TEXT("GREYFORD_CHECK spawn_clear=%d %s"),Free,*It->GetName());
    }
    bool TestedBlock=false;
    for(TActorIterator<AStaticMeshActor> It(GetWorld());It;++It) {
        if(!It->ActorHasTag(TEXT("GreyfordBlocker")))continue;
        FVector Center,Extent;It->GetActorBounds(true,Center,Extent);
        const FVector Start(Center.X-Extent.X-100,Center.Y,Original.Z);
        SetActorLocation(Start,false,nullptr,ETeleportType::TeleportPhysics);
        FHitResult Hit;AddActorWorldOffset(FVector(Extent.X*2+200,0,0),true,&Hit);
        TestedBlock=Hit.bBlockingHit && GetActorLocation().X<Center.X;
        OK &= TestedBlock;break;
    }
    SetActorLocation(Original,false,nullptr,ETeleportType::TeleportPhysics);
    OK &= SpawnCount>0 && TestedBlock;
    UE_LOG(LogTemp,Display,TEXT("GREYFORD_CHECK sweep_blocks=%d spawns=%d"),TestedBlock,SpawnCount);
    const FString Dir=FPaths::ProjectDir()/TEXT("Evidence/Greyford");IFileManager::Get().MakeDirectory(*Dir,true);
    FFileHelper::SaveStringToFile(FString::Printf(TEXT("map=%s\nspawn_count=%d\nsweep_blocks=%d\nresult=%s\n"),*GetWorld()->GetMapName(),SpawnCount,TestedBlock,OK?TEXT("PASS"):TEXT("FAIL")),*(Dir/GetWorld()->GetMapName()+TEXT("-runtime.txt")));
    UE_LOG(LogTemp,Display,TEXT("GREYFORD_RUNTIME_%s"),OK?TEXT("PASS"):TEXT("FAIL"));return OK;
}

void AGreyfordBlockoutPawn::BeginPlay() {
    Super::BeginPlay();
    auto* PC=Cast<APlayerController>(GetController());if(PC){PC->SetViewTarget(this);PC->bShowMouseCursor=true;}
    const bool Smoke=FParse::Param(FCommandLine::Get(),TEXT("GreyfordSmoke"));
    Capture=FParse::Param(FCommandLine::Get(),TEXT("GreyfordCapture"));
    WalkAutoExit=FParse::Param(FCommandLine::Get(),TEXT("GreyfordWalkTest"));
    if(Smoke || Capture){const bool OK=VerifyCollision();if(Smoke || !OK)FPlatformMisc::RequestExitWithStatus(false,OK?0:1);}
    if(WalkAutoExit)StartWalk();
    if(PC)PC->ClientMessage(TEXT("Greyford blockout: WASD move / TAB top view / R route check / native collision, 500 cm/s. No production save."),NAME_None,20);
}

void AGreyfordBlockoutPawn::StartWalk() {
    TArray<TPair<int32,FVector>> Points;
    for(TActorIterator<ATargetPoint> It(GetWorld());It;++It)for(const FName Tag:It->Tags) {
        const FString S=Tag.ToString();
        if(S.StartsWith(TEXT("GreyfordWalk_")))Points.Emplace(FCString::Atoi(*S.RightChop(13)),It->GetActorLocation());
    }
    Points.Sort([](const auto& A,const auto& B){return A.Key<B.Key;});
    WalkRoute.Empty();for(const auto& P:Points)WalkRoute.Add(P.Value);
    if(WalkRoute.Num()<2){UE_LOG(LogTemp,Error,TEXT("GREYFORD_WALK_FAIL missing route"));if(WalkAutoExit)FPlatformMisc::RequestExitWithStatus(false,1);return;}
    Movement->StopMovementImmediately();SetActorLocation(WalkRoute[0],false,nullptr,ETeleportType::TeleportPhysics);
    WalkIndex=1;WalkSeconds=SegmentSeconds=0;SegmentLimit=FVector::Dist2D(WalkRoute[0],WalkRoute[1])/500+5;
    Walking=true;WalkLog=TEXT("point,seconds,x_cm,y_cm\n");
}

void AGreyfordBlockoutPawn::FinishWalk(bool OK) {
    Walking=false;Movement->StopMovementImmediately();
    const FString Dir=FPaths::ProjectDir()/TEXT("Evidence/Greyford/P1");IFileManager::Get().MakeDirectory(*Dir,true);
    const FString Label=WalkAutoExit?(FParse::Param(FCommandLine::Get(),TEXT("GreyfordAfter"))?TEXT("after"):TEXT("before")):TEXT("manual");
    FFileHelper::SaveStringToFile(WalkLog,*(Dir/(TEXT("walk-")+Label+TEXT(".csv"))));
    FFileHelper::SaveStringToFile(FString::Printf(TEXT("result=%s\nreached=%d\ntotal=%d\nseconds=%.3f\nmethod=native FloatingPawnMovement, automated route, not human combat playtest\n"),OK?TEXT("PASS"):TEXT("FAIL"),WalkIndex-1,WalkRoute.Num()-1,WalkSeconds),*(Dir/(TEXT("walk-")+Label+TEXT(".txt"))));
    UE_LOG(LogTemp,Display,TEXT("GREYFORD_WALK_%s reached=%d seconds=%.3f"),OK?TEXT("PASS"):TEXT("FAIL"),WalkIndex-1,WalkSeconds);
    if(WalkAutoExit)FPlatformMisc::RequestExitWithStatus(false,OK?0:1);
}

void AGreyfordBlockoutPawn::UpdateWalk(float Dt) {
    WalkSeconds+=Dt;SegmentSeconds+=Dt;
    const FVector Delta=WalkRoute[WalkIndex]-GetActorLocation();
    if(Delta.Size2D()<60) {
        const FVector P=GetActorLocation();WalkLog+=FString::Printf(TEXT("%d,%.3f,%.2f,%.2f\n"),WalkIndex,WalkSeconds,P.X,P.Y);
        if(WalkIndex==1 || WalkIndex==5) {
            const FString Label=WalkAutoExit?(FParse::Param(FCommandLine::Get(),TEXT("GreyfordAfter"))?TEXT("after"):TEXT("before")):TEXT("manual");
            FScreenshotRequest::RequestScreenshot(FPaths::ConvertRelativePathToFull(FPaths::ProjectDir()/TEXT("Evidence/Greyford/P1")/(TEXT("walk-")+Label+FString::Printf(TEXT("-%d.png"),WalkIndex))),false,false);
        }
        ++WalkIndex;
        if(WalkIndex==WalkRoute.Num()){FinishWalk(true);return;}
        SegmentLimit=FVector::Dist2D(P,WalkRoute[WalkIndex])/500+5;SegmentSeconds=0;
    }
    else if(SegmentSeconds>SegmentLimit){FinishWalk(false);return;}
    AddMovementInput((WalkRoute[WalkIndex]-GetActorLocation()).GetSafeNormal2D());
}

void AGreyfordBlockoutPawn::Tick(float Dt) {
    Super::Tick(Dt);Elapsed+=Dt;
    auto* PC=Cast<APlayerController>(GetController());
    if(PC && !Capture) {
        if(PC->WasInputKeyJustPressed(EKeys::Tab))SetOverview(!Overview);
        const FVector Input((PC->IsInputKeyDown(EKeys::A)?1.f:0.f)-(PC->IsInputKeyDown(EKeys::D)?1.f:0.f),
            (PC->IsInputKeyDown(EKeys::W)?1.f:0.f)-(PC->IsInputKeyDown(EKeys::S)?1.f:0.f),0);
        if(PC->WasInputKeyJustPressed(EKeys::R))StartWalk();
        if(!Input.IsNearlyZero())Walking=false;
        if(Walking)UpdateWalk(Dt);else AddMovementInput(Input.GetSafeNormal());
    }
    if(Capture) {
        const FString Dir=FPaths::ConvertRelativePathToFull(FPaths::ProjectDir()/TEXT("Evidence/Greyford"));
        if(CaptureStage==0 && Elapsed>2){FScreenshotRequest::RequestScreenshot(Dir/GetWorld()->GetMapName()+TEXT("-view.png"),false,false);CaptureStage=1;}
        else if(CaptureStage==1 && Elapsed>3){SetOverview(true);CaptureStage=2;}
        else if(CaptureStage==2 && Elapsed>4){FScreenshotRequest::RequestScreenshot(Dir/GetWorld()->GetMapName()+TEXT("-overview.png"),false,false);CaptureStage=3;}
        else if(CaptureStage==3 && Elapsed>5)FPlatformMisc::RequestExitWithStatus(false,0);
    }
}
