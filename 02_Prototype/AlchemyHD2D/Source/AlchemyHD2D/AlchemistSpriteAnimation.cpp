#include "AlchemistSpriteAnimation.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/Texture2D.h"
#include "Materials/MaterialInstanceDynamic.h"

bool FAlchemistSpriteAnimation::Initialize(UObject* Owner,UStaticMeshComponent* Mesh) {
    auto Base=LoadObject<UMaterialInterface>(nullptr,TEXT("/Game/Characters/Alchemist/M_AlchemistSprite.M_AlchemistSprite"));
    if(!Base) return false;
    Atlases.Empty();
    for(const TCHAR* View:{TEXT("Side"),TEXT("Front"),TEXT("Back")}) {
        const FString Name=FString::Printf(TEXT("/Game/Characters/Alchemist/T_%s_Atlas.T_%s_Atlas"),View,View);
        auto Texture=LoadObject<UTexture2D>(nullptr,*Name);
        if(!Texture) return false;
        Atlases.Add(Texture);
    }
    Material=UMaterialInstanceDynamic::Create(Base,Owner);Mesh->SetMaterial(0,Material);
    Material->SetVectorParameterValue(TEXT("UVScale"),FLinearColor(1.f/6,1.f/5,0,0));
    Facing=1;Mirror=false;Reset();return true;
}
void FAlchemistSpriteAnimation::Face(FVector2D D) {
    if(Throwing || Hurting || Dead || D.IsNearlyZero()) return;
    Facing=FMath::Abs(D.X)>=FMath::Abs(D.Y)?0:(D.Y>0?2:1);
    Mirror=Facing==0 && D.X<0;
}
bool FAlchemistSpriteAnimation::Throw(FVector2D Direction) {
    // Moving keeps its gait and facing. Projectile aiming is independent in the combat world.
    if(Throwing || Moving || Hurting || Dead) return false;
    Face(Direction);Throwing=true;Time=0;Apply();return true;
}
void FAlchemistSpriteAnimation::Reset() {Time=0;Throwing=Moving=Hurting=Dead=false;Apply();}
void FAlchemistSpriteAnimation::Hit() {if(!Dead) {Hurting=true;Throwing=false;Time=0;Apply();}}
void FAlchemistSpriteAnimation::Die() {if(!Dead) {Dead=true;Hurting=Throwing=Moving=false;Time=0;Apply();}}
bool FAlchemistSpriteAnimation::Advance(float Delta,FVector2D Direction,bool IsMoving) {
    if(Dead) {Time=FMath::Min(.75f,Time+Delta);Apply();return false;}
    if(Hurting) {
        Time+=Delta;Moving=IsMoving;
        if(Time>=.4f) {Hurting=false;Time=0;}
        Apply();return false;
    }
    if(IsMoving && Throwing) {Throwing=false;Time=0;}
    Face(Direction);
    if(Moving!=IsMoving && !Throwing) Time=0;
    Moving=IsMoving;
    const float Before=Time;Time+=Delta;
    const bool Released=Throwing && Before<.25f && Time>=.25f;
    if(Throwing && Time>=.75f) {Throwing=false;Time=0;}
    Apply();return Released;
}
void FAlchemistSpriteAnimation::Apply() {
    Row=Dead?4:Hurting?3:Moving?1:Throwing?2:0;
    Frame=Dead?FMath::Min(5,FMath::FloorToInt(Time*8)):Hurting?FMath::Min(3,FMath::FloorToInt(Time*10)):Throwing?FMath::Min(5,FMath::FloorToInt(Time*8)):FMath::FloorToInt(Time*(Moving?8:4))%(Moving?6:4);
    if(Material && Atlases.IsValidIndex(Facing)) {
        Material->SetTextureParameterValue(TEXT("SpriteSheet"),Atlases[Facing]);
        Material->SetVectorParameterValue(TEXT("UVOffset"),FLinearColor(Frame/6.f,Row/5.f,0,0));
    }
}
