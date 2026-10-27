#if WITH_EDITOR
#include "Editor.h"
#endif
// Seed tables from the documented prototype once. Saved tables are authoritative thereafter.
bool AAlchemyWorld::CreateDesignTables() {
#if WITH_EDITOR
    auto Table=[](const TCHAR* Name,UScriptStruct* Struct,bool& Created) {
        const FString Path=FString(TEXT("/Game/Design/"))+Name;
        if(auto* Existing=LoadObject<UDataTable>(nullptr,*(Path+TEXT(".")+Name))) {Created=false;return Existing;}
        auto* P=CreatePackage(*Path);P->FullyLoad();auto* T=NewObject<UDataTable>(P,Name,RF_Public|RF_Standalone);T->RowStruct=Struct;Created=true;FAssetRegistryModule::AssetCreated(T);return T;
    };
    auto Save=[](UDataTable* T) {T->MarkPackageDirty();FSavePackageArgs A;A.TopLevelFlags=RF_Public|RF_Standalone;return UPackage::SavePackage(T->GetOutermost(),T,*FPackageName::LongPackageNameToFilename(T->GetOutermost()->GetName(),FPackageName::GetAssetPackageExtension()),A);};
    auto* Hit=LoadObject<UNiagaraSystem>(nullptr,TEXT("/Game/VFX/NS_AlchemyImpact.NS_AlchemyImpact"));
    auto* Blast=LoadObject<UNiagaraSystem>(nullptr,TEXT("/Game/VFX/NS_AlchemyBlast.NS_AlchemyBlast"));
    auto* Trail=LoadObject<UNiagaraSystem>(nullptr,TEXT("/Game/VFX/NS_AlchemyTrail.NS_AlchemyTrail"));bool New=false,OK=true;
    auto* ST=Table(TEXT("DT_Skills"),FAlchemySkillRow::StaticStruct(),New);
    if(New) {for(int I=0;I<UE_ARRAY_COUNT(Skills);I++) {const auto& K=Skills[I];FAlchemySkillRow R;R.Name=SkillNames[I];R.Damage=K.Damage;R.CD=K.CD;R.Range=K.Range;R.Radius=K.Radius;R.Slow=K.Slow;R.Factor=K.Factor;R.Cast=EAlchemyCast(K.Cast);R.Targets=K.Targets;
        R.Color=(I==1||I==6||I==10||I==11||I==12||I==19||I==20)?FLinearColor(1,.25f,.035f):(I==2||I==13||I==14||I==15||I==21||I==22)?FLinearColor(.15f,.65f,1):(I==4||I==23||I==24)?FLinearColor(.3f,1,.2f):FLinearColor(.65f,.3f,1);
        R.HitEffect=Hit;R.CastEffect=Blast;R.TrailEffect=Trail;R.Notes=TEXT("来源：ALCH-002_技能分配草案；距离单位cm；数值仍待实战平衡。行名是稳定技能ID，不要重排。");ST->AddRow(FName(*FString::FromInt(I)),R);} OK &= Save(ST);}
    auto* RT=Table(TEXT("DT_Recipes"),FAlchemyRecipeRow::StaticStruct(),New);
    if(New) {for(int I=0;I<7;I++) {FAlchemyRecipeRow R;R.Name=CombinationNames[I];R.Mask=CombinationMasks[I];R.LowSkill=CombinationSkills[I][0];R.MidSkill=CombinationSkills[I][1];R.HighSkill=CombinationSkills[I][2];RT->AddRow(FName(*FString::FromInt(I)),R);}
        for(int I=7;I<=9;I++) {FAlchemyRecipeRow R;R.Name=SkillNames[I];R.bElite=true;R.LowSkill=I;for(int M=0;M<6;M++) R.Costs[M]=Recipes[I][M];RT->AddRow(FName(*FString::FromInt(I)),R);} OK &= Save(RT);}
    auto* CT=Table(TEXT("DT_Chains"),FAlchemyChainRow::StaticStruct(),New);
    if(New) {for(int I=0;I<UE_ARRAY_COUNT(Chains);I++) {const auto& K=Chains[I];FAlchemyChainRow R;R.Name=K.Name;R.A=K.A;R.B=K.B;R.CD=K.CD;R.Damage=K.Damage;R.Radius=K.Radius;R.Slow=K.Slow;R.Factor=K.Factor;R.Targets=K.Targets;R.CastEffect=Blast;R.HitEffect=Hit;CT->AddRow(FName(*FString::FromInt(I)),R);} OK &= Save(CT);}
    auto* QT=Table(TEXT("DT_Quality"),FAlchemyQualityRow::StaticStruct(),New);
    if(New) {for(int I=0;I<8;I++) {FAlchemyQualityRow R;R.Low=QualityWeights[I][0];R.Mid=QualityWeights[I][1];R.High=QualityWeights[I][2];QT->AddRow(FName(*FString::FromInt(I)),R);} OK &= Save(QT);}
    UE_LOG(LogTemp,Display,TEXT("ALCHEMY_DESIGN_TABLES_%s"),OK?TEXT("PASS"):TEXT("FAIL"));return OK;
#else
    return false;
#endif
}
bool AAlchemyWorld::LoadDesignConfig() {
    for(TActorIterator<AAlchemyLevelDesigner> It(GetWorld());It;++It) {Designer=*It;break;}
    SkillTable=Designer?Designer->SkillTable.Get():nullptr;RecipeTable=Designer?Designer->RecipeTable.Get():nullptr;ChainTable=Designer?Designer->ChainTable.Get():nullptr;QualityTable=Designer?Designer->QualityTable.Get():nullptr;
    if(!SkillTable) SkillTable=LoadObject<UDataTable>(nullptr,TEXT("/Game/Design/DT_Skills.DT_Skills"));
    if(!RecipeTable) RecipeTable=LoadObject<UDataTable>(nullptr,TEXT("/Game/Design/DT_Recipes.DT_Recipes"));
    if(!ChainTable) ChainTable=LoadObject<UDataTable>(nullptr,TEXT("/Game/Design/DT_Chains.DT_Chains"));
    if(!QualityTable) QualityTable=LoadObject<UDataTable>(nullptr,TEXT("/Game/Design/DT_Quality.DT_Quality"));
    FString Error;
    if(!AlchemyDesign::ReadTables(SkillTable,RecipeTable,ChainTable,QualityTable,RuntimeSkills,RuntimeRecipes,RuntimeChains,RuntimeQuality,Error)) {UE_LOG(LogTemp,Error,TEXT("ALCHEMY_DESIGN_LOAD_FAIL %s"),*Error);return false;}
    SkillCD.Init(0,NumSkills());ChainCD.Init(0,NumChains());if(Designer && Designer->bUseInGame) CombatHalfSize=Designer->PlayHalfSize;
    UE_LOG(LogTemp,Display,TEXT("ALCHEMY_DESIGN_LOADED skills=%d chains=%d recipes=%d authored_map=%d"),NumSkills(),NumChains(),RuntimeRecipes.Num(),Designer!=nullptr);return true;
}
int32 AAlchemyWorld::RecipeCost(int32 Skill,int32 M) const {
    for(int I=7;I<RuntimeRecipes.Num();I++) if(RuntimeRecipes[I].LowSkill==Skill) return RuntimeRecipes[I].Costs.IsValidIndex(M)?RuntimeRecipes[I].Costs[M]:0;
    return Skill>=0 && Skill<10 && M>=0 && M<6?Recipes[Skill][M]:0;
}
