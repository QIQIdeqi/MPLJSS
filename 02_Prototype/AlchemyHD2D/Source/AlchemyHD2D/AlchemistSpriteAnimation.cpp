#include "AlchemistSpriteAnimation.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/Texture2D.h"
#include "Materials/MaterialInstanceDynamic.h"

bool FAlchemistSpriteAnimation::Initialize(UObject* Owner,UStaticMeshComponent* Mesh) {
    RoseMage=false;RoseMotionAtlases.Empty();RoseAttackAtlases.Empty();
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
bool FAlchemistSpriteAnimation::InitializeRoseMage(UObject* Owner,UStaticMeshComponent* Mesh) {
    RoseAttackAtlases.Empty();
    auto Base=LoadObject<UMaterialInterface>(nullptr,TEXT("/Game/Characters/RoseMage/M_RoseMage.M_RoseMage"));
    if(!Base)return false;
    Atlases.Empty();
    for(const TCHAR* View:{TEXT("Side"),TEXT("Front"),TEXT("Back"),TEXT("Attack")}) {
        const FString Name=FString::Printf(TEXT("/Game/Characters/RoseMage/T_RoseMage%s.T_RoseMage%s"),View,View);
        auto Texture=LoadObject<UTexture2D>(nullptr,*Name);if(!Texture)return false;Atlases.Add(Texture);
    }
    RoseMotionAtlases.Empty();
    for(const TCHAR* View:{TEXT("Side"),TEXT("Front"),TEXT("Back")}) {
        const FString Name=FString::Printf(TEXT("/Game/Characters/RoseMage/T_RoseMage%sMotion.T_RoseMage%sMotion"),View,View);
        auto Texture=LoadObject<UTexture2D>(nullptr,*Name);if(!Texture){RoseMotionAtlases.Empty();break;}RoseMotionAtlases.Add(Texture);
    }
    auto SideAttack=LoadObject<UTexture2D>(nullptr,TEXT("/Game/Characters/RoseMage/T_RoseMageSideAttack.T_RoseMageSideAttack"));
    auto BackAttack=LoadObject<UTexture2D>(nullptr,TEXT("/Game/Characters/RoseMage/T_RoseMageBackAttack.T_RoseMageBackAttack"));
    if(SideAttack && BackAttack)RoseAttackAtlases={SideAttack,Atlases[3],BackAttack};
    RoseMage=true;Material=UMaterialInstanceDynamic::Create(Base,Owner);Mesh->SetMaterial(0,Material);
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
    const bool Released=Throwing && Before<ReleaseTime() && Time>=ReleaseTime();
    if(Throwing && Time>=(RoseMage?.8f:.75f)) {Throwing=false;Time=0;}
    Apply();return Released;
}
void FAlchemistSpriteAnimation::Apply() {
    if(RoseMage && Material && Atlases.Num()==4) {
        if(HasRoseMotion() && (Dead || Hurting || Moving)) {
            Row=Dead?4:Hurting?3:1;
            Frame=Dead?FMath::Min(5,FMath::FloorToInt(Time*8)):Hurting?FMath::Min(3,FMath::FloorToInt(Time*10)):FMath::FloorToInt(Time*8)%6;
            const int MotionRow=Dead?2:Hurting?1:0;
            Material->SetTextureParameterValue(TEXT("SpriteSheet"),RoseMotionAtlases[Facing]);
            Material->SetVectorParameterValue(TEXT("UVScale"),FLinearColor(1.f/6,1.f/3,0,0));
            Material->SetVectorParameterValue(TEXT("UVOffset"),FLinearColor(Frame/6.f,MotionRow/3.f,0,0));
            Material->SetVectorParameterValue(TEXT("SpriteTint"),FLinearColor::White);
            return;
        }
        // Static/attack art remains available if the optional authored motion pack is absent.
        const bool Attack=Throwing && !Hurting && !Dead && !Moving;
        Row=Attack?2:Dead?4:Hurting?3:Moving?1:0;
        Frame=Attack?FMath::Min(7,FMath::FloorToInt(Time*10)):0;
        Material->SetTextureParameterValue(TEXT("SpriteSheet"),Attack && HasRoseAttack()?RoseAttackAtlases[Facing]:Atlases[Attack?3:Facing]);
        Material->SetVectorParameterValue(TEXT("UVScale"),FLinearColor(Attack?1.f/8:1,1,0,0));
        Material->SetVectorParameterValue(TEXT("UVOffset"),FLinearColor(Attack?Frame/8.f:0,0,0,0));
        const float Alpha=Dead?1-FMath::Clamp(Time/.75f,0.f,1.f):1;
        Material->SetVectorParameterValue(TEXT("SpriteTint"),Hurting?FLinearColor(1,.45f,.45f,Alpha):FLinearColor(1,1,1,Alpha));
        return;
    }
    Row=Dead?4:Hurting?3:Moving?1:Throwing?2:0;
    Frame=Dead?FMath::Min(5,FMath::FloorToInt(Time*8)):Hurting?FMath::Min(3,FMath::FloorToInt(Time*10)):Throwing?FMath::Min(5,FMath::FloorToInt(Time*8)):FMath::FloorToInt(Time*(Moving?8:4))%(Moving?6:4);
    if(Material && Atlases.IsValidIndex(Facing)) {
        Material->SetTextureParameterValue(TEXT("SpriteSheet"),Atlases[Facing]);
        Material->SetVectorParameterValue(TEXT("UVOffset"),FLinearColor(Frame/6.f,Row/5.f,0,0));
    }
}
