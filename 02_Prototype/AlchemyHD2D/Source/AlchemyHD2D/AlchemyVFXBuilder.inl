// Editor-only asset authoring. Engine templates are duplicated into /Game/VFX, never edited in place.
#if WITH_EDITOR
#include "NiagaraEmitter.h"
#include "NiagaraEmitterHandle.h"
#include "NiagaraSystemFactoryNew.h"
#include "NiagaraEditorUtilities.h"
#include "NiagaraSpriteRendererProperties.h"
#include "NiagaraRibbonRendererProperties.h"
#include "NiagaraScript.h"
#include "AssetRegistry/AssetRegistryModule.h"
#include "AssetCompilingManager.h"
#include "UObject/SavePackage.h"
#include "Misc/PackageName.h"
#include "Materials/Material.h"
#include "Materials/MaterialExpressionTextureCoordinate.h"
#include "Materials/MaterialExpressionSubtract.h"
#include "Materials/MaterialExpressionDotProduct.h"
#include "Materials/MaterialExpressionMultiply.h"
#include "Materials/MaterialExpressionOneMinus.h"
#include "Materials/MaterialExpressionSaturate.h"
#include "Materials/MaterialExpressionPower.h"
#include "Materials/MaterialExpressionParticleColor.h"
#include "Materials/MaterialExpressionVectorParameter.h"

namespace AlchemyVFXBuilder {
template<class T> T* Node(UMaterial* M,int X,int Y) {
    auto* N=NewObject<T>(M);N->MaterialExpressionEditorX=X;N->MaterialExpressionEditorY=Y;M->GetExpressionCollection().AddExpression(N);return N;
}
bool Save(UObject* Asset) {
    Asset->MarkPackageDirty();FSavePackageArgs Args;Args.TopLevelFlags=RF_Public|RF_Standalone;
    const FString File=FPackageName::LongPackageNameToFilename(Asset->GetOutermost()->GetName(),FPackageName::GetAssetPackageExtension());
    return UPackage::SavePackage(Asset->GetOutermost(),Asset,*File,Args);
}
bool Build() {
    auto* MP=CreatePackage(TEXT("/Game/VFX/M_AlchemyParticle"));
    MP->FullyLoad();
    auto* M=NewObject<UMaterial>(MP,TEXT("M_AlchemyParticle"),RF_Public|RF_Standalone);
    M->BlendMode=BLEND_Additive;M->SetShadingModel(MSM_Unlit);M->TwoSided=true;M->bUsedWithNiagaraSprites=true;M->bUsedWithNiagaraRibbons=true;
    auto* UV=Node<UMaterialExpressionTextureCoordinate>(M,-900,200);
    auto* Center=Node<UMaterialExpressionSubtract>(M,-700,200);Center->A.Connect(0,UV);Center->ConstB=.5f;
    auto* Dot=Node<UMaterialExpressionDotProduct>(M,-500,200);Dot->A.Connect(0,Center);Dot->B.Connect(0,Center);
    auto* Radius=Node<UMaterialExpressionMultiply>(M,-300,200);Radius->A.Connect(0,Dot);Radius->ConstB=4;
    auto* Invert=Node<UMaterialExpressionOneMinus>(M,-100,200);Invert->Input.Connect(0,Radius);
    auto* Clamp=Node<UMaterialExpressionSaturate>(M,100,200);Clamp->Input.Connect(0,Invert);
    auto* Soft=Node<UMaterialExpressionPower>(M,300,200);Soft->Base.Connect(0,Clamp);Soft->ConstExponent=3;
    auto* Particle=Node<UMaterialExpressionParticleColor>(M,100,450);
    auto* Alpha=Node<UMaterialExpressionMultiply>(M,500,200);Alpha->A.Connect(0,Soft);Alpha->B.Connect(4,Particle);
    auto* Tint=Node<UMaterialExpressionVectorParameter>(M,-200,-200);Tint->ParameterName=TEXT("Tint");Tint->DefaultValue=FLinearColor(.2f,.8f,1,1);
    auto* Glow=Node<UMaterialExpressionMultiply>(M,300,-200);Glow->A.Connect(0,Tint);Glow->ConstB=2;
    M->GetEditorOnlyData()->EmissiveColor.Connect(0,Glow);M->GetEditorOnlyData()->Opacity.Connect(0,Alpha);M->PostEditChange();
    FAssetRegistryModule::AssetCreated(M);bool OK=Save(M);FString Report;
    const TCHAR* Names[]={TEXT("NS_AlchemyImpact"),TEXT("NS_AlchemyBlast"),TEXT("NS_AlchemyTrail")};
    for(int I=0;I<3;I++) {
        auto* Package=CreatePackage(*(FString(TEXT("/Game/VFX/"))+Names[I]));Package->FullyLoad();UNiagaraSystem* S=nullptr;
        if(I<2) {
            const TCHAR* Source=I==0?TEXT("/Niagara/DefaultAssets/Templates/Systems/RadialBurst.RadialBurst"):TEXT("/Niagara/DefaultAssets/Templates/Systems/SimpleExplosion.SimpleExplosion");
            auto* Template=LoadObject<UNiagaraSystem>(nullptr,Source);if(!Template) return false;
            Template->WaitForCompilationComplete();S=DuplicateObject<UNiagaraSystem>(Template,Package,Names[I]);S->SetFlags(RF_Public|RF_Standalone);
        } else {
            S=NewObject<UNiagaraSystem>(Package,Names[I],RF_Public|RF_Standalone);UNiagaraSystemFactoryNew::InitializeSystem(S,true);
            auto* E=LoadObject<UNiagaraEmitter>(nullptr,TEXT("/Niagara/DefaultAssets/Templates/Emitters/Fountain.Fountain"));if(!E) return false;
            FNiagaraEditorUtilities::AddEmitterToSystem(*S,*E,E->GetExposedVersion().VersionGuid,true);
        }
        FNiagaraVariable MaterialVar(FNiagaraTypeDefinition(UMaterialInterface::StaticClass()),TEXT("User.FXMaterial"));
        S->GetExposedParameters().AddParameter(MaterialVar);S->GetExposedParameters().SetUObject(M,MaterialVar);
        for(auto& H:S->GetEmitterHandles()) {
            auto* D=H.GetInstance().GetEmitterData();if(!D) {OK=false;continue;}
            for(auto* Renderer:D->GetRenderers()) {
                if(auto* Sprite=Cast<UNiagaraSpriteRendererProperties>(Renderer)) {Sprite->Material=M;Sprite->MaterialUserParamBinding.Parameter=MaterialVar;}
                else if(auto* Ribbon=Cast<UNiagaraRibbonRendererProperties>(Renderer)) {Ribbon->Material=M;Ribbon->MaterialUserParamBinding.Parameter=MaterialVar;}
                else Renderer->SetIsEnabled(false);
            }
            if(I<2) for(auto* Script:{D->SpawnScriptProps.Script.Get(),D->UpdateScriptProps.Script.Get()}) if(Script) {
                TArray<FNiagaraVariable> Params;Script->RapidIterationParameters.GetParameters(Params);
                for(const auto& Param:Params) if(Param.GetType()==FNiagaraTypeDefinition::GetFloatDef() && Param.GetName().ToString().Contains(TEXT("Sprite Size"))) {
                    if(const uint8* Data=Script->RapidIterationParameters.GetParameterData(Param)) {
                        float Value=0;FMemory::Memcpy(&Value,Data,sizeof(float));
                        Script->RapidIterationParameters.SetParameterValue(Value*(I==0?3.f:1.5f),Param);
                    }
                }
            }
            if(I==2) for(auto* Script:{D->EmitterUpdateScriptProps.Script.Get(),D->SpawnScriptProps.Script.Get(),D->UpdateScriptProps.Script.Get()}) {
                if(!Script) continue;
                const TPair<const TCHAR*,float> Floats[]={
                    {TEXT("Constants.Fountain.SpawnRate.SpawnRate"),55},
                    {TEXT("Constants.Fountain.InitializeParticle.Lifetime Min"),.12f},{TEXT("Constants.Fountain.InitializeParticle.Lifetime Max"),.24f},
                    {TEXT("Constants.Fountain.InitializeParticle.Uniform Sprite Size Min"),7},{TEXT("Constants.Fountain.InitializeParticle.Uniform Sprite Size Max"),14},
                    {TEXT("Constants.Fountain.ShapeLocation.Sphere Radius"),3}
                };
                for(const auto& V:Floats) Script->RapidIterationParameters.SetParameterValue(V.Value,FNiagaraVariable(FNiagaraTypeDefinition::GetFloatDef(),V.Key));
            }
        }
        S->PostEditChange();S->RequestCompile(true);S->WaitForCompilationComplete(true);FAssetCompilingManager::Get().FinishAllCompilation();
        const bool Ready=S->IsReadyToRun();OK &= Ready;FAssetRegistryModule::AssetCreated(S);OK &= Save(S);
        Report+=FString::Printf(TEXT("%s ready=%d emitters=%d\n"),Names[I],Ready,S->GetEmitterHandles().Num());
    }
    FAssetCompilingManager::Get().FinishAllCompilation();FFileHelper::SaveStringToFile(Report,*(FPaths::ProjectDir()/TEXT("Evidence/niagara-build.txt")));
    UE_LOG(LogTemp,Display,TEXT("ALCHEMY_VFX_BUILD_%s"),OK?TEXT("PASS"):TEXT("FAIL"));return OK;
}
}
#endif


