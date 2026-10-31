#include "PixelFXActor.h"
#include "AlchemyWorld.h"
#include "Camera/CameraActor.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/Texture2D.h"
#include "EngineUtils.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "UObject/ConstructorHelpers.h"

namespace {
struct FPreset {const TCHAR* Name;int W,H,OX,OY,Frames,Columns;float Units,Depth;};
constexpr FPreset Presets[]={{TEXT("Hit"),136,80,44,64,15,4,2.2f,0},
    {TEXT("Poison"),256,100,128,86,120,8,4.f,70},
    {TEXT("Portal"),152,116,76,106,72,8,4.2f,6}};
const TCHAR* LayerNames[]={TEXT("BackColor"),TEXT("BackLight"),TEXT("FrontColor"),TEXT("FrontLight")};
}
APixelFXActor::APixelFXActor() {
    PrimaryActorTick.bCanEverTick=true;PrimaryActorTick.TickGroup=TG_PostUpdateWork;
    RootComponent=CreateDefaultSubobject<USceneComponent>(TEXT("FootOrigin"));
    static ConstructorHelpers::FObjectFinder<UStaticMesh> Plane(TEXT("/Engine/BasicShapes/Plane.Plane"));
    for(const TCHAR* Name:LayerNames) {
        auto Card=CreateDefaultSubobject<UStaticMeshComponent>(Name);Card->SetupAttachment(RootComponent);
        Card->SetStaticMesh(Plane.Object);Card->SetCollisionEnabled(ECollisionEnabled::NoCollision);
        Card->SetGenerateOverlapEvents(false);Card->SetCastShadow(false);Card->SetCanEverAffectNavigation(false);
        Card->TranslucencySortPriority=0;Cards.Add(Card);
    }
}
void APixelFXActor::OnConstruction(const FTransform& Transform) {
    Super::OnConstruction(Transform);Materials.SetNum(4);
    const auto& P=Presets[static_cast<uint8>(Effect)];
    for(int I=0;I<4;I++) {
        const bool Enabled=(Effect!=EPixelFX::Hit || I>=2) && !(Effect==EPixelFX::Portal && I==1);Cards[I]->SetVisibility(Enabled);
        if(!Enabled){Materials[I]=nullptr;continue;}
        const FString Base=TEXT("/Game/VFX/PixelFX/M_PixelFX_")+FString(I%2?TEXT("Light"):TEXT("Color"));
        auto Mat=LoadObject<UMaterialInterface>(nullptr,*Base);
        auto Atlas=LoadObject<UTexture2D>(nullptr,*FString::Printf(TEXT("/Game/VFX/PixelFX/T_%s_%s"),P.Name,LayerNames[I]));
        if(!Mat || !Atlas){Materials[I]=nullptr;continue;}
        auto MID=UMaterialInstanceDynamic::Create(Mat,this);Materials[I]=MID;Cards[I]->SetMaterial(0,MID);
        MID->SetTextureParameterValue(TEXT("Atlas"),Atlas);
        MID->SetScalarParameterValue(TEXT("Columns"),P.Columns);MID->SetScalarParameterValue(TEXT("Rows"),FMath::DivideAndRoundUp(P.Frames,P.Columns));
    }
    UpdateCards();
}
void APixelFXActor::BeginPlay() {
    Super::BeginPlay();if(!IsReady())OnConstruction(GetActorTransform());Alchemy=Cast<AAlchemyWorld>(GetOwner());
    if(!IsReady())UE_LOG(LogTemp,Error,TEXT("PIXELFX_MISSING_ASSET kind=%d"),static_cast<uint8>(Effect));
}
bool APixelFXActor::IsReady() const {
    if(Materials.Num()!=4)return false;
    for(int I=0;I<4;I++)if(Cards[I]->IsVisible() && !Materials[I])return false;
    return true;
}
void APixelFXActor::SetPlaybackTime(float Seconds){Age=FMath::Max(0.f,Seconds);UpdateCards();}
void APixelFXActor::Tick(float Delta) {
    Super::Tick(Delta);
    if(!Alchemy.IsValid())for(TActorIterator<AAlchemyWorld> It(GetWorld());It;++It){Alchemy=*It;break;}
    if(!Alchemy.IsValid() || Alchemy->Panel.IsEmpty())Age+=Delta;
    const float End=Lifetime>0?Lifetime:(Effect==EPixelFX::Hit?.5f:0);
    if(End>0 && Age>=End){Destroy();return;}
    UpdateCards();
}
void APixelFXActor::UpdateCards() {
    const auto& P=Presets[static_cast<uint8>(Effect)];
    const FRotationMatrix View(Alchemy.IsValid() && Alchemy->Camera?Alchemy->Camera->GetActorRotation():FRotator(-48,90,0));
    const FVector Forward=View.GetUnitAxis(EAxis::X),Right=View.GetUnitAxis(EAxis::Y),Up=View.GetUnitAxis(EAxis::Z);
    const float S=P.Units*PixelScale*GetActorScale3D().GetAbsMax();
    const int Frame=Effect==EPixelFX::Hit?FMath::Min(P.Frames-1,FMath::FloorToInt(Age*30)):FMath::FloorToInt(Age*30)%P.Frames;
    for(int I=0;I<4;I++) {
        const float Depth=(I<2?P.Depth:-P.Depth)*(S/P.Units)-(I%2)*.25f;
        Cards[I]->SetWorldLocation(GetActorLocation()+Right*(P.W*.5f-P.OX)*S*(Mirror?-1:1)+Up*(P.OY-P.H*.5f)*S+Forward*Depth);
        Cards[I]->SetWorldRotation(FRotationMatrix::MakeFromXZ(Right,-Forward).Rotator());
        Cards[I]->SetWorldScale3D(FVector(P.W*S/100*(Mirror?-1:1),P.H*S/100,1));
        if(Materials.IsValidIndex(I) && Materials[I]) {
            Materials[I]->SetScalarParameterValue(TEXT("Frame"),Frame);
            Materials[I]->SetScalarParameterValue(TEXT("Opacity"),Opacity);
            Materials[I]->SetScalarParameterValue(TEXT("Strength"),I%2?GlowStrength:1);
        }
    }
}
