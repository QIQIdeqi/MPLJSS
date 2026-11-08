#include "AlchemyFurnaceFX.h"

#include "Blueprint/WidgetTree.h"
#include "Components/Widget.h"
#include "NiagaraComponent.h"
#include "NiagaraEmitterInstance.h"
#include "Misc/CommandLine.h"
#include "Misc/Parse.h"
#include "NiagaraSystem.h"
#include "NiagaraSystemInstanceController.h"
#include "UObject/UnrealType.h"

#if WITH_EDITOR
#include "Misc/App.h"
#include "AssetRegistry/AssetRegistryModule.h"
#include "Materials/Material.h"
#include "Materials/MaterialExpressionConstant3Vector.h"
#include "Materials/MaterialExpressionDotProduct.h"
#include "Materials/MaterialExpressionMultiply.h"
#include "Materials/MaterialExpressionOneMinus.h"
#include "Materials/MaterialExpressionPower.h"
#include "Materials/MaterialExpressionSaturate.h"
#include "Materials/MaterialExpressionSubtract.h"
#include "Materials/MaterialExpressionTextureCoordinate.h"
#include "Materials/MaterialExpressionVertexColor.h"
#include "Misc/PackageName.h"
#include "NiagaraEmitter.h"
#include "NiagaraEmitterHandle.h"
#include "NiagaraRendererProperties.h"
#include "NiagaraScript.h"
#include "UObject/SavePackage.h"
#endif

namespace {
constexpr auto FurnaceSystemPath=TEXT("/Game/VFX/NS_AlchemyFurnaceUI.NS_AlchemyFurnaceUI");
constexpr auto FurnaceMaterialPath=TEXT("/Game/VFX/M_AlchemyFurnaceUI.M_AlchemyFurnaceUI");

// The installed Epic plugin does not export its concrete C++ classes. Its reflected classes and fields remain usable.
bool SetObjectField(UObject* Object, FName Name, UObject* Value)
{
    auto* Field=FindFProperty<FObjectPropertyBase>(Object->GetClass(),Name);
    if(!Field || (Value && !Value->IsA(Field->PropertyClass))) return false;
    Field->SetObjectPropertyValue_InContainer(Object,Value);
    return true;
}

bool SetEnumField(UObject* Object, FName Name, const TCHAR* Enumerator)
{
    auto* Field=FindFProperty<FProperty>(Object->GetClass(),Name);
    if(auto* EnumField=CastField<FEnumProperty>(Field)) {
        const int64 Value=EnumField->GetEnum()->GetValueByNameString(Enumerator);
        if(Value==INDEX_NONE) return false;
        EnumField->GetUnderlyingProperty()->SetIntPropertyValue(EnumField->ContainerPtrToValuePtr<void>(Object),Value);
        return true;
    }
    if(auto* ByteField=CastField<FByteProperty>(Field); ByteField && ByteField->Enum) {
        const int64 Value=ByteField->Enum->GetValueByNameString(Enumerator);
        if(Value==INDEX_NONE) return false;
        ByteField->SetPropertyValue_InContainer(Object,uint8(Value));
        return true;
    }
    return false;
}

#if WITH_EDITOR
template<class T> T* FurnaceNode(UMaterial* Material,int32 X,int32 Y)
{
    auto* Node=NewObject<T>(Material);
    Node->MaterialExpressionEditorX=X;
    Node->MaterialExpressionEditorY=Y;
    Material->GetExpressionCollection().AddExpression(Node);
    return Node;
}

bool SaveFurnaceAsset(UObject* Asset)
{
    FSavePackageArgs Args;
    Args.TopLevelFlags=RF_Public|RF_Standalone;
    Args.SaveFlags=SAVE_NoError;
    auto* Package=Asset->GetOutermost();
    Asset->MarkPackageDirty();
    const FString File=FPackageName::LongPackageNameToFilename(Package->GetName(),FPackageName::GetAssetPackageExtension());
    return UPackage::SavePackage(Package,Asset,*File,Args);
}

UMaterial* BuildFurnaceMaterial()
{
    if(auto* Existing=LoadObject<UMaterial>(nullptr,FurnaceMaterialPath)) return Existing->MaterialDomain==MD_UI?Existing:nullptr;
    auto* Package=CreatePackage(TEXT("/Game/VFX/M_AlchemyFurnaceUI"));
    auto* Material=NewObject<UMaterial>(Package,TEXT("M_AlchemyFurnaceUI"),RF_Public|RF_Standalone);
    Material->MaterialDomain=MD_UI;
    Material->BlendMode=BLEND_Translucent;
    auto* UV=FurnaceNode<UMaterialExpressionTextureCoordinate>(Material,-900,0);
    auto* Center=FurnaceNode<UMaterialExpressionSubtract>(Material,-720,0);
    Center->A.Connect(0,UV);Center->ConstB=.5f;
    auto* Dot=FurnaceNode<UMaterialExpressionDotProduct>(Material,-540,0);
    Dot->A.Connect(0,Center);Dot->B.Connect(0,Center);
    auto* Radius=FurnaceNode<UMaterialExpressionMultiply>(Material,-360,0);
    Radius->A.Connect(0,Dot);Radius->ConstB=4.f;
    auto* Invert=FurnaceNode<UMaterialExpressionOneMinus>(Material,-180,0);
    Invert->Input.Connect(0,Radius);
    auto* Clamp=FurnaceNode<UMaterialExpressionSaturate>(Material,0,0);
    Clamp->Input.Connect(0,Invert);
    auto* Soft=FurnaceNode<UMaterialExpressionPower>(Material,180,0);
    Soft->Base.Connect(0,Clamp);Soft->ConstExponent=2.f;
    auto* VertexColor=FurnaceNode<UMaterialExpressionVertexColor>(Material,0,210);
    auto* Alpha=FurnaceNode<UMaterialExpressionMultiply>(Material,380,0);
    Alpha->A.Connect(0,Soft);Alpha->B.Connect(4,VertexColor);
    auto* Color=FurnaceNode<UMaterialExpressionConstant3Vector>(Material,380,-180);
    Color->Constant=FLinearColor(1.f,.48f,.09f);
    Material->GetEditorOnlyData()->EmissiveColor.Connect(0,Color);
    Material->GetEditorOnlyData()->Opacity.Connect(0,Alpha);
    Material->PostEditChange();
    FAssetRegistryModule::AssetCreated(Material);
    return SaveFurnaceAsset(Material)?Material:nullptr;
}
#endif
}

UWidget* UAlchemyFurnaceFXLibrary::Create(UWidgetTree* Tree, FName Name)
{
    if(!Tree) return nullptr;
    auto* System=LoadObject<UNiagaraSystem>(nullptr,FurnaceSystemPath);
    auto* WidgetClass=LoadClass<UWidget>(nullptr,TEXT("/Script/NiagaraUIRenderer.NiagaraUIWidget"));
    if(!System || !WidgetClass) return nullptr;
    auto* Widget=Tree->ConstructWidget<UWidget>(WidgetClass,Name);
    const bool SystemAssigned=SetObjectField(Widget,TEXT("NiagaraSystem"),System);
    const bool PlaneAssigned=SetEnumField(Widget,TEXT("WorldToScreenPlane"),TEXT("XZ"));
    const bool AlignmentAssigned=SetEnumField(Widget,TEXT("VerticalAlignment"),TEXT("VAlign_Bottom"));
    if(!SystemAssigned || !PlaneAssigned || !AlignmentAssigned) {
        UE_LOG(LogTemp,Warning,TEXT("ALCHEMY_UI_NIAGARA widget setup failed: system=%d plane=%d alignment=%d"),SystemAssigned,PlaneAssigned,AlignmentAssigned);
        return nullptr;
    }
    Widget->SetVisibility(ESlateVisibility::HitTestInvisible);
    Widget->SetClipping(EWidgetClipping::ClipToBounds);
    return Widget;
}

UNiagaraComponent* UAlchemyFurnaceFXLibrary::GetComponent(const UWidget* Widget)
{
    if(!Widget) return nullptr;
    const auto* Field=FindFProperty<FObjectPropertyBase>(Widget->GetClass(),TEXT("NiagaraComponent"));
    return Field?Cast<UNiagaraComponent>(Field->GetObjectPropertyValue_InContainer(Widget)):nullptr;
}

void UAlchemyFurnaceFXLibrary::SetPaused(UWidget* Widget, bool bPaused)
{
    if(auto* Component=GetComponent(Widget)) {
        // Epic's UI component opts out of auto-activation; Slate only ticks it after it starts.
        if(!bPaused && !Component->IsActive()) {
            Component->Activate(false);
            Component->SetComponentTickEnabled(false); // Slate drives the UI simulation.
        }
        if(Component->IsPaused()!=bPaused) {
            Component->SetPaused(bPaused);
            if(auto Controller=Component->GetSystemInstanceController()) Controller->SetPaused(bPaused);
        }
#if !UE_BUILD_SHIPPING
        static const bool bCapture=FParse::Param(FCommandLine::Get(),TEXT("BrewV02FurnaceVisual"));
        if(bCapture && GFrameCounter%10==0) {
            const auto Controller=Component->GetSystemInstanceController();
            const auto* Instance=Controller?Controller->GetSystemInstance_Unsafe():nullptr;
            int32 Particles=0;
            if(Instance) for(const auto& Emitter:Instance->GetEmitters())Particles+=Emitter->GetNumParticles();
            UE_LOG(LogTemp,Display,TEXT("ALCHEMY_UI_NIAGARA active=%d particles=%d"),Component->IsActive(),Particles);
        }
#endif
    }
}

void UAlchemyFurnaceFXLibrary::Release(UWidget* Widget)
{
    if(!Widget) return;
    // Slate keeps a weak reference to the component. Releasing the native widget also destroys it.
    Widget->RemoveFromParent();
    Widget->ReleaseSlateResources(true);
}

bool UAlchemyFurnaceFXLibrary::BuildAssets()
{
#if WITH_EDITOR
    auto* RendererClass=LoadClass<UNiagaraRendererProperties>(nullptr,TEXT("/Script/NiagaraUIRenderer.NiagaraUISpriteRendererProperties"));
    if(!RendererClass) return false;
    if(auto* Existing=LoadObject<UNiagaraSystem>(nullptr,FurnaceSystemPath)) {
        Existing->WaitForCompilationComplete(true);
        if(Existing->GetEmitterHandles().Num()!=1) return false;
        const auto* Data=Existing->GetEmitterHandles()[0].GetInstance().GetEmitterData();
        return Data && Data->SimTarget==ENiagaraSimTarget::CPUSim && Data->GetRenderers().Num()==1 &&
            Data->GetRenderers()[0]->IsA(RendererClass) && Existing->IsValid() && (!FApp::CanEverRender() || Existing->IsReadyToRun());
    }
    auto* Template=LoadObject<UNiagaraSystem>(nullptr,TEXT("/Game/VFX/NS_AlchemyTrail.NS_AlchemyTrail"));
    if(!Template || Template->GetEmitterHandles().Num()!=1) return false;
    Template->WaitForCompilationComplete(true);
    auto* Material=BuildFurnaceMaterial();
    if(!Material) return false;

    auto* Package=CreatePackage(TEXT("/Game/VFX/NS_AlchemyFurnaceUI"));
    auto* System=DuplicateObject<UNiagaraSystem>(Template,Package,TEXT("NS_AlchemyFurnaceUI"));
    System->SetFlags(RF_Public|RF_Standalone);
    auto Emitter=System->GetEmitterHandles()[0].GetInstance();
    auto* Data=Emitter.GetEmitterData();
    if(!Data || !Emitter.Emitter) return false;
    Data->bLocalSpace=true;
    Data->SimTarget=ENiagaraSimTarget::CPUSim;
    const auto OldRenderers=Data->GetRenderers();
    for(auto* Renderer:OldRenderers) Emitter.Emitter->RemoveRenderer(Renderer,Emitter.Version);
    auto* Renderer=NewObject<UNiagaraRendererProperties>(Emitter.Emitter,RendererClass);
    if(!SetObjectField(Renderer,TEXT("Material"),Material)) return false;
    Emitter.Emitter->AddRenderer(Renderer,Emitter.Version);

    const auto SetInput=[&](const TCHAR* Suffix,const FNiagaraTypeDefinition& Type,auto Value) {
        bool Found=false;
        for(auto* Script:{Data->EmitterUpdateScriptProps.Script.Get(),Data->SpawnScriptProps.Script.Get(),Data->UpdateScriptProps.Script.Get()}) {
            if(!Script) continue;
            TArray<FNiagaraVariable> Inputs;
            Script->RapidIterationParameters.GetParameters(Inputs);
            for(const auto& Input:Inputs) if(Input.GetType()==Type && Input.GetName().ToString().EndsWith(Suffix)) {
                Found |= Script->RapidIterationParameters.SetParameterValue(Value,Input);
            }
        }
        return Found;
    };
    const auto SetFloat=[&](const TCHAR* Suffix,float Value){return SetInput(Suffix,FNiagaraTypeDefinition::GetFloatDef(),Value);};
    bool Tuned=SetFloat(TEXT(".SpawnRate.SpawnRate"),38.f);
    Tuned &= SetFloat(TEXT(".InitializeParticle.Lifetime Min"),.45f);
    Tuned &= SetFloat(TEXT(".InitializeParticle.Lifetime Max"),.85f);
    Tuned &= SetFloat(TEXT(".InitializeParticle.Uniform Sprite Size Min"),5.f);
    Tuned &= SetFloat(TEXT(".InitializeParticle.Uniform Sprite Size Max"),13.f);
    Tuned &= SetFloat(TEXT(".ShapeLocation.Sphere Radius"),10.f);
    Tuned &= SetFloat(TEXT(".AddVelocity.Cone Angle"),23.f);
    Tuned &= SetInput(TEXT(".AddVelocity.Cone Axis"),FNiagaraTypeDefinition::GetVec3Def(),FVector3f(0,0,1));
    Tuned &= SetInput(TEXT(".GravityForce.Gravity"),FNiagaraTypeDefinition::GetVec3Def(),FVector3f::ZeroVector);
    const bool FixedSpeed=SetFloat(TEXT(".AddVelocity.Velocity Speed Scale"),92.f);
    const bool MinSpeed=SetFloat(TEXT(".RandomRangeFloat.Minimum"),65.f);
    const bool MaxSpeed=SetFloat(TEXT(".RandomRangeFloat.Maximum"),115.f);
    if(!Tuned || !(FixedSpeed || (MinSpeed && MaxSpeed))) {
        UE_LOG(LogTemp,Error,TEXT("ALCHEMY_FURNACE_NIAGARA_UI unexpected Fountain input layout"));
        return false;
    }

    System->PostEditChange();
    System->RequestCompile(true);
    System->WaitForCompilationComplete(true);
    if(!System->IsValid() || (FApp::CanEverRender() && !System->IsReadyToRun())) return false;
    FAssetRegistryModule::AssetCreated(System);
    return SaveFurnaceAsset(System);
#else
    return false;
#endif
}
