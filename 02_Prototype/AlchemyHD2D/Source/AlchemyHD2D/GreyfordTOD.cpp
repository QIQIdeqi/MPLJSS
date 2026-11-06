#include "GreyfordTOD.h"

#include "Components/LightComponent.h"
#include "Components/SkyLightComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/DirectionalLight.h"
#include "Engine/SkyLight.h"
#include "Engine/StaticMesh.h"
#include "Engine/StaticMeshActor.h"
#include "Engine/Texture2D.h"
#include "Engine/World.h"
#include "Materials/MaterialInstanceDynamic.h"

void FGreyfordTOD::BindLights(ADirectionalLight* InSun, ASkyLight* InSky) {
    if (Sun.Get()==InSun && Sky.Get()==InSky) return;
    RestoreLights();
    Sun=InSun;
    Sky=InSky;
    if (auto* Light=InSun ? InSun->GetLightComponent() : nullptr) {
        SavedSunRotation=InSun->GetActorRotation();
        SavedSun={Light->Intensity, Light->GetLightColor(), Light->Mobility.GetValue()};
        if (Light->Mobility!=EComponentMobility::Movable) Light->SetMobility(EComponentMobility::Movable);
    }
    if (auto* Light=InSky ? InSky->GetLightComponent() : nullptr) {
        SavedSky={Light->Intensity, Light->GetLightColor(), Light->Mobility.GetValue()};
        if (Light->Mobility!=EComponentMobility::Movable) Light->SetMobility(EComponentMobility::Movable);
    }
}

void FGreyfordTOD::RestoreLights() {
    if (auto* Actor=Sun.Get(); Actor && Actor->GetWorld()) {
        if (auto* Light=Actor->GetLightComponent()) {
            Actor->SetActorRotation(SavedSunRotation);
            Light->SetIntensity(SavedSun.Intensity);
            Light->SetLightColor(SavedSun.Color);
            if (Light->Mobility!=SavedSun.Mobility) Light->SetMobility(SavedSun.Mobility);
        }
    }
    if (auto* Actor=Sky.Get(); Actor && Actor->GetWorld()) {
        if (auto* Light=Actor->GetLightComponent()) {
            Light->SetIntensity(SavedSky.Intensity);
            Light->SetLightColor(SavedSky.Color);
            if (Light->Mobility!=SavedSky.Mobility) Light->SetMobility(SavedSky.Mobility);
        }
    }
    Sun.Reset();
    Sky.Reset();
}

void FGreyfordTOD::Update(float RunTime, const FGreyfordTODSettings& Settings) {
    const float DaySeconds=FMath::Max(1.f, Settings.CycleSeconds);
    Hour=FMath::Fmod(Settings.StartHour+24.f*RunTime/DaySeconds, 24.f);
    if (Hour<0.f) Hour+=24.f;

    const float SolarArc=FMath::Sin((Hour-6.f)*UE_PI/12.f);
    const float Daylight=FMath::SmoothStep(-.22f, .42f, SolarArc);
    const float Warmth=FMath::SmoothStep(-.25f,.02f,SolarArc)*(1.f-FMath::SmoothStep(.08f,.62f,SolarArc));
    const float LowElevation=FMath::Clamp(Settings.MinSunElevation, 1.f, 89.f);
    const float HighElevation=FMath::Clamp(Settings.MaxSunElevation, LowElevation, 89.f);
    SunElevation=FMath::Lerp(LowElevation, HighElevation, FMath::Max(0.f, SolarArc));
    const FRotator Rotation(-SunElevation, Hour*15.f+Settings.SunAzimuthOffset, 0);
    ShadowDirection=Rotation.Vector().GetSafeNormal2D();

    const auto SunColor=FMath::Lerp(FMath::Lerp(FLinearColor(.46f,.60f,1.f), FLinearColor(1.f,.98f,.92f), Daylight),
                                    FLinearColor(1.f,.61f,.36f), Warmth);
    const auto SkyColor=FMath::Lerp(FLinearColor(.48f,.63f,1.f), FLinearColor(.80f,.88f,1.f), Daylight);
    SceneTint=FMath::Lerp(FMath::Lerp(FLinearColor(.60f,.71f,.92f), FLinearColor::White, Daylight),
                          FLinearColor(1.f,.83f,.66f), Warmth);
    ShadowColor=FMath::Lerp(FLinearColor(.025f,.043f,.087f), FLinearColor(.044f,.036f,.027f), Daylight);
    ShadowOpacity=FMath::Clamp(Settings.ShadowOpacity,0.f,1.f)*FMath::Lerp(.46f,1.f,FMath::Max(Daylight,Warmth));
    MinShadowLength=FMath::Max(1.f, Settings.MinShadowLength);
    MaxShadowLength=FMath::Max(MinShadowLength, Settings.MaxShadowLength);
    GroundLift=FMath::Max(0.f, Settings.GroundLift);

    if (auto* Actor=Sun.Get()) {
        if (auto* Light=Actor->GetLightComponent()) {
            Actor->SetActorRotation(Rotation);
            Light->SetLightColor(SunColor);
            Light->SetIntensity(FMath::Lerp(.24f, 3.2f, Daylight));
        }
    }
    if (auto* Actor=Sky.Get()) {
        if (auto* Light=Actor->GetLightComponent()) {
            Light->SetLightColor(SkyColor);
            Light->SetIntensity(FMath::Lerp(.44f, .90f, Daylight));
        }
    }
}

void FGreyfordTOD::UpdateShadows(UWorld* World, UMaterialInterface* Material, TConstArrayView<FGreyfordTODCaster> Casters) {
    if (!World || !IsValid(Material) || ShadowOpacity<=0.f) {
        ClearShadows();
        return;
    }
    if (ShadowParent.Get()!=Material) {
        ClearShadows();
        ShadowParent=Material;
    }
    if (!Plane.IsValid()) Plane=LoadObject<UStaticMesh>(nullptr, TEXT("/Engine/BasicShapes/Plane.Plane"));
    if (!Plane.IsValid()) return;

    // Keep shorter props shorter at sunset instead of clamping every caster to the same length.
    const float Stretch=1.f/FMath::Max(FMath::Tan(FMath::DegreesToRadians(SunElevation)),.42f);
    const FRotator Rotation=ShadowDirection.Rotation();
    const FVector PlaneWidthAxis=FVector::CrossProduct(FVector::UpVector, ShadowDirection);
    ActiveShadows=0;
    for (const FGreyfordTODCaster& Caster:Casters) {
        UTexture2D* Texture=Caster.Texture.Get();
        if (!Texture || Caster.Foot.ContainsNaN() || Caster.WidthAxis.ContainsNaN() ||
            !FMath::IsFinite(Caster.Width+Caster.Height+Caster.Strength+Caster.FootFraction) ||
            Caster.Width<=0.f || Caster.Height<=0.f || Caster.Strength<=0.f || Caster.FootFraction<=0.f) continue;

        const FVector WidthAxis=Caster.WidthAxis.GetSafeNormal2D();
        const double AcrossLight=FMath::Abs(FVector::DotProduct(WidthAxis, PlaneWidthAxis));
        // A plane projects to a line when its width is parallel to the light. Fade that singularity without rotating the foot.
        const float FacingFade=float(FMath::SmoothStep(.03, .18, AcrossLight));
        if (FacingFade<=0.f) continue;
        const FVector Shear=Caster.Width*(WidthAxis-PlaneWidthAxis);

        if (ActiveShadows==Shadows.Num()) Shadows.AddDefaulted();
        auto& Entry=Shadows[ActiveShadows];
        auto* Actor=Entry.Actor.Get();
        auto* MID=Entry.Material.Get();
        if (!Actor || !MID) {
            if (Actor) Actor->Destroy();
            FActorSpawnParameters Params;
            Params.ObjectFlags|=RF_Transient;
            Params.SpawnCollisionHandlingOverride=ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
            Actor=World->SpawnActor<AStaticMeshActor>(Caster.Foot, Rotation, Params);
            if (!Actor) break;
            Actor->Tags.Add(TEXT("GreyfordTODShadow"));
            Actor->SetActorTickEnabled(false);
            Actor->SetActorEnableCollision(false);
            auto* Mesh=Actor->GetStaticMeshComponent();
            Mesh->SetMobility(EComponentMobility::Movable);
            Mesh->TranslucencySortPriority=-10;
            Mesh->SetStaticMesh(Plane.Get());
            Mesh->SetCollisionEnabled(ECollisionEnabled::NoCollision);
            Mesh->SetGenerateOverlapEvents(false);
            Mesh->SetCanEverAffectNavigation(false);
            Mesh->SetCastShadow(false);
            Mesh->SetReceivesDecals(false);
            MID=UMaterialInstanceDynamic::Create(Material, Mesh);
            if (!MID) {
                Actor->Destroy();
                break;
            }
            Mesh->SetMaterial(0, MID);
            Entry={Actor, MID};
        }

        const float Length=FMath::Clamp(Caster.Height*Stretch, MinShadowLength, MaxShadowLength);
        const FVector Foot=Caster.Foot+FVector(0,0,GroundLift);
        const FVector Center=Foot+ShadowDirection*(Length*.5f);
        Actor->SetActorTransform(FTransform(Rotation, Center, FVector(Length/100.f,Caster.Width/100.f,1.f)));
        // Vertex offsets reach half the shear vector. Expanding by the smaller plane span covers this in every orientation.
        auto* Mesh=Actor->GetStaticMeshComponent();
        const float RequiredBoundsScale=1.f+float(Shear.Size())/FMath::Min(Length,Caster.Width);
        if (Mesh->BoundsScale<RequiredBoundsScale || Mesh->BoundsScale>RequiredBoundsScale+.1f) {
            Mesh->SetBoundsScale(RequiredBoundsScale+.04f);
        }
        Actor->SetActorHiddenInGame(false);
        MID->SetTextureParameterValue(TEXT("ShadowTexture"), Texture);
        MID->SetScalarParameterValue(TEXT("ShadowFootFraction"), FMath::Clamp(Caster.FootFraction,0.f,1.f));
        MID->SetVectorParameterValue(TEXT("ShadowShear"), FLinearColor(float(Shear.X),float(Shear.Y),0.f,0.f));
        MID->SetVectorParameterValue(TEXT("ShadowFoot"), FLinearColor(float(Foot.X),float(Foot.Y),float(Foot.Z),1.f));
        MID->SetVectorParameterValue(TEXT("ShadowDirection"), FLinearColor(float(ShadowDirection.X),float(ShadowDirection.Y),0.f,0.f));
        MID->SetScalarParameterValue(TEXT("ShadowLength"), Length);
        MID->SetScalarParameterValue(TEXT("ShadowOpacity"), ShadowOpacity*FMath::Clamp(Caster.Strength,0.f,1.f)*FacingFade);
        MID->SetVectorParameterValue(TEXT("ShadowColor"), ShadowColor);
        ++ActiveShadows;
    }
    for (int32 Index=ActiveShadows; Index<Shadows.Num(); ++Index) {
        if (auto* Actor=Shadows[Index].Actor.Get()) Actor->SetActorHiddenInGame(true);
    }
}

void FGreyfordTOD::ClearShadows() {
    for (const auto& Entry:Shadows) {
        if (auto* Actor=Entry.Actor.Get(); Actor && Actor->GetWorld()) Actor->Destroy();
    }
    Shadows.Reset();
    ShadowParent.Reset();
    ActiveShadows=0;
}

void FGreyfordTOD::Clear() {
    ClearShadows();
    RestoreLights();
}
