#include "AlchemistSpriteLab.h"
#include "Camera/CameraComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/StaticMesh.h"
#include "Engine/Texture2D.h"
#include "Engine/Canvas.h"
#include "GameFramework/PlayerController.h"
#include "GameFramework/PlayerInput.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "Misc/CommandLine.h"
#include "Misc/Parse.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "HAL/PlatformFileManager.h"
#include "HAL/FileManager.h"
#include "Kismet/GameplayStatics.h"
#include "UnrealClient.h"

AAlchemistSpriteLabPawn::AAlchemistSpriteLabPawn() {
    PrimaryActorTick.bCanEverTick=true;
    RootComponent=CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
    Sprite=CreateDefaultSubobject<UStaticMeshComponent>(TEXT("AnimatedSprite"));
    Sprite->SetupAttachment(RootComponent);
    Sprite->SetCollisionEnabled(ECollisionEnabled::NoCollision);
    Sprite->SetCastShadow(false);
    Sprite->SetStaticMesh(LoadObject<UStaticMesh>(nullptr,TEXT("/Engine/BasicShapes/Plane.Plane")));
    Sprite->SetRelativeLocation(FVector(0,0,104));
    Sprite->SetRelativeScale3D(FVector(5.12f,5.12f,1));
    Camera=CreateDefaultSubobject<UCameraComponent>(TEXT("TestCamera"));
    Camera->SetupAttachment(RootComponent);
    Camera->SetAbsolute(true,true,false);
    Camera->SetWorldLocation(FVector(0,-1100,950));
    Camera->SetWorldRotation(FRotator(-40,90,0));
    Camera->ProjectionMode=ECameraProjectionMode::Orthographic;
    Camera->OrthoWidth=1900;
    AutoPossessPlayer=EAutoReceiveInput::Player0;
}

void AAlchemistSpriteLabPawn::BeginPlay() {
    Super::BeginPlay();
    Sprite->SetWorldRotation(FRotationMatrix::MakeFromXZ(Camera->GetRightVector(),-Camera->GetForwardVector()).Rotator());
    // All generated cells place the ground line at y=232: anchor it to the pawn's origin.
    Sprite->SetRelativeLocation(Camera->GetUpVector()*208.f);
    const bool Ready=Playback.Initialize(this,Sprite);
    ensureMsgf(Ready,TEXT("Import the alchemist character assets before playing."));
    Material=Playback.Material;
    bSmoke=FParse::Param(FCommandLine::Get(),TEXT("SpriteLabSmoke"));
    TestStart=GetActorLocation();
    UpdateFrame();
    UE_LOG(LogTemp,Display,TEXT("SPRITE_LAB_READY atlases=%d material=%d possessed=%d"),Atlases.Num(),Material!=nullptr,GetController()!=nullptr);
}

void AAlchemistSpriteLabPawn::SetFacing(int32 Direction,bool Mirror) {
    if(Playback.Throwing || Playback.Hurting || Playback.Dead) return;
    if(Playback.Facing!=Direction || Playback.Mirror!=Mirror) Playback.Time=0;
    Playback.Facing=FMath::Clamp(Direction,0,2);Playback.Mirror=Mirror;
    UpdateFrame();
}
void AAlchemistSpriteLabPawn::Attack() {
    const FVector2D Aim=Facing==1?FVector2D(0,-1):Facing==2?FVector2D(0,1):FVector2D(bMirror?-1:1,0);
    Playback.Throw(Aim);UpdateFrame();
    UE_LOG(LogTemp,Display,TEXT("SPRITE_LAB_ATTACK facing=%d"),Facing);
}
void AAlchemistSpriteLabPawn::UpdateFrame() {
    Playback.Apply();Facing=Playback.Facing;Frame=Playback.Frame;bAttacking=Playback.Throwing;bMirror=Playback.Mirror;
    Sprite->SetRelativeScale3D(FVector(bMirror?-5.12f:5.12f,5.12f,1));
}

void AAlchemistSpriteLabPawn::Tick(float Delta) {
    Super::Tick(Delta);
    auto PC=Cast<APlayerController>(GetController());
    if(!PC) return;
    if(bSmoke) Smoke(Delta);
    if(PC->WasInputKeyJustPressed(EKeys::H)) Playback.Hit();
    if(PC->WasInputKeyJustPressed(EKeys::J)) Playback.Die();
    if(PC->WasInputKeyJustPressed(EKeys::R)) Playback.Reset();
    if(PC->WasInputKeyJustPressed(EKeys::One)) SetFacing(1);
    if(PC->WasInputKeyJustPressed(EKeys::Two)) SetFacing(2);
    if(PC->WasInputKeyJustPressed(EKeys::Three)) SetFacing(0);
    if(PC->WasInputKeyJustPressed(EKeys::Four)) SetFacing(0,true);
    if(PC->WasInputKeyJustPressed(EKeys::SpaceBar) || PC->WasInputKeyJustPressed(EKeys::LeftMouseButton)) Attack();
    FVector Move((PC->IsInputKeyDown(EKeys::D)||PC->IsInputKeyDown(EKeys::Right))-(PC->IsInputKeyDown(EKeys::A)||PC->IsInputKeyDown(EKeys::Left)),
                 (PC->IsInputKeyDown(EKeys::W)||PC->IsInputKeyDown(EKeys::Up))-(PC->IsInputKeyDown(EKeys::S)||PC->IsInputKeyDown(EKeys::Down)),0);
    if(!Playback.Dead && !Move.IsNearlyZero()) {
        if(FMath::Abs(Move.Y)>FMath::Abs(Move.X)) SetFacing(Move.Y>0?2:1);
        else SetFacing(0,Move.X<0);
        const FVector P=GetActorLocation()+Move.GetSafeNormal()*MoveSpeed*Delta;
        SetActorLocation(FVector(FMath::Clamp(P.X,-760.f,760.f),FMath::Clamp(P.Y,-540.f,540.f),0));
    }
    Playback.Advance(Delta,FVector2D(Move.X,Move.Y),!Move.IsNearlyZero());
    UpdateFrame();
}

void AAlchemistSpriteLabPawn::Smoke(float Delta) {
    TestTime+=Delta;
    auto PC=CastChecked<APlayerController>(GetController());
    auto Key=[PC](FKey K,EInputEvent E){PC->InputKey(FInputKeyEventArgs(nullptr,INPUTDEVICEID_NONE,K,E,E==IE_Pressed?1.f:0.f,false,FPlatformTime::Cycles64()));};
    auto Capture=[this](const TCHAR* Name){
        if(!FParse::Param(FCommandLine::Get(),TEXT("nullrhi"))) {
            const FString Folder=FPaths::ProjectDir()/TEXT("Evidence/SpriteLab");
            IFileManager::Get().MakeDirectory(*Folder,true);
            FScreenshotRequest::RequestScreenshot(Folder/Name,false,false);
        }
    };
    switch(TestStep) {
    case 0: if(TestTime>.5f) {check(Material && Atlases.Num()==3);Key(EKeys::D,IE_Pressed);TestStep++;} break;
    case 1: if(TestTime>1.f) {check(Playback.Row==1 && Playback.Frame>0);Key(EKeys::D,IE_Released);check(GetActorLocation().X>TestStart.X+30);SetFacing(1);Capture(TEXT("Front.png"));TestStep++;} break;
    case 2: if(TestTime>1.5f) {SetFacing(2);Capture(TEXT("Back.png"));TestStep++;} break;
    case 3: if(TestTime>2.f) {Key(EKeys::SpaceBar,IE_Pressed);TestStep++;} break;
    case 4: if(bAttacking && Frame>=2) {Key(EKeys::SpaceBar,IE_Released);Capture(TEXT("BackAttack.png"));TestStep++;} break;
    case 5: if(TestTime>3.1f) {check(!bAttacking);SetFacing(1);Attack();TestStep++;} break;
    case 6: if(bAttacking && Frame>=2) {Capture(TEXT("FrontAttack.png"));TestStep++;} break;
    case 7: if(TestTime>4.2f) {check(!bAttacking);SetFacing(0);Attack();TestStep++;} break;
    case 8: if(bAttacking && Frame>=2) {Capture(TEXT("SideAttack.png"));TestStep++;} break;
    case 9: if(TestTime>5.3f) {
        check(!bAttacking);SetFacing(0,true);check(Sprite->GetRelativeScale3D().X<0);
        const FString Proof=FString::Printf(TEXT("{\"result\":\"PASS\",\"keyboard_movement\":true,\"space_attack\":true,\"attack_return\":true,\"directions\":3,\"left_mirror\":true,\"delta_x\":%.2f}"),GetActorLocation().X-TestStart.X);
        const FString Folder=FPaths::ProjectDir()/TEXT("Evidence/SpriteLab");IFileManager::Get().MakeDirectory(*Folder,true);
        FFileHelper::SaveStringToFile(Proof,*(Folder/TEXT("runtime-check.json")));
        UE_LOG(LogTemp,Display,TEXT("SPRITE_LAB_SMOKE_PASS %s"),*Proof);TestStep++;
    } break;
    case 10: if(TestTime>6) {FPlatformMisc::RequestExit(false);} break;
    }
    if(TestTime>15) {UE_LOG(LogTemp,Error,TEXT("SPRITE_LAB_SMOKE_FAIL timeout step=%d"),TestStep);FPlatformMisc::RequestExitWithStatus(false,1);}
}

void AAlchemistSpriteLabHUD::DrawHUD() {
    Super::DrawHUD();
    DrawText(TEXT("ALCHEMIST SPRITE LAB"),FLinearColor(.9f,.75f,.35f),28,22,nullptr,1.4f);
    DrawText(TEXT("WASD / Arrows: move    Space / LMB: attack    1: front  2: back  3: right  4: left"),FLinearColor::White,28,58);
    DrawText(TEXT("H: hurt / J: death / R: reset. Moving keeps walking; stationary Space plays throw."),FLinearColor(.65f,.75f,.8f),28,82);
    if(auto P=Cast<AAlchemistSpriteLabPawn>(UGameplayStatics::GetPlayerPawn(GetWorld(),0)))
        DrawText(FString::Printf(TEXT("View: %s    State: %s    Frame: %d"),P->Facing==0?TEXT("SIDE"):P->Facing==1?TEXT("FRONT"):TEXT("BACK"),P->AnimationRow()==4?TEXT("DEATH"):P->AnimationRow()==3?TEXT("HURT"):P->AnimationRow()==2?TEXT("THROW"):P->AnimationRow()==1?TEXT("WALK"):TEXT("IDLE"),P->Frame+1),FLinearColor::White,28,110);
}

AAlchemistSpriteLabMode::AAlchemistSpriteLabMode() {
    DefaultPawnClass=nullptr;
    HUDClass=AAlchemistSpriteLabHUD::StaticClass();
}

