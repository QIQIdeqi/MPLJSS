#include "AlchemyEnemyDefinitions.h"
#include "Materials/MaterialInterface.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "Components/SceneComponent.h"
#if WITH_EDITOR
#include "Editor.h"
#include "AssetRegistry/AssetRegistryModule.h"
#include "Subsystems/AssetEditorSubsystem.h"
#include "Misc/PackageName.h"
#include "UObject/SavePackage.h"
#endif

bool AlchemyDesign::ReadEnemyDefinitions(UDataTable* Table,TArray<FAlchemyEnemyRow>& Rows,FString& Error) {
    Rows.Empty();
    if(!Table || Table->GetRowStruct()!=FAlchemyEnemyRow::StaticStruct() || Table->GetRowMap().Num()<11) {
        Error=TEXT("怪物表缺失、行结构错误或少于原有11行");return false;
    }
    for(int32 I=0;I<Table->GetRowMap().Num();I++) {
        const auto* R=Table->FindRow<FAlchemyEnemyRow>(FName(*FString::FromInt(I)),TEXT("EnemyDefinitions"),false);
        const auto Fail=[&](const TCHAR* Why){Error=FString::Printf(TEXT("怪物行%d：%s"),I,Why);Rows.Empty();return false;};
        if(!R)return Fail(TEXT("行ID须从0连续追加，不能重排或删空原有行"));
        if(R->Name.IsEmpty() || R->Archetype<0 || R->Archetype>10 || (I<11 && R->Archetype!=I))return Fail(TEXT("名称/兼容模板非法；原0–10行须保持同号模板"));
        for(float V:{R->TunedHP,R->TunedContactDamage,R->TunedAreaDamage,R->TunedRangedDamage})if(!FMath::IsFinite(V) || (V<0 && V!=-1))return Fail(TEXT("调参B覆盖须为-1或有限非负数"));
        if(R->TunedHP==0)return Fail(TEXT("调参B生命不能为0"));
        if(uint8(R->Behavior)>uint8(EAlchemyEnemyBehavior::Boss) || (R->Archetype==10)!=(R->Behavior==EAlchemyEnemyBehavior::Boss))return Fail(TEXT("现有Boss行为仅适用于模板10，模板10必须使用Boss行为"));
        for(float V:{R->HP,R->Speed,R->ContactDamage,R->HPPerMinute,R->SpeedPerMinute,R->CollisionRadius,float(R->VisualSize.X),float(R->VisualSize.Y),R->EliteWeight,R->AreaTrigger,R->AreaRadius,R->AreaDamage,R->AreaWindup,R->AreaCD,R->RangedMin,R->RangedMax,R->RangedKeepDistance,R->RangedDamage,R->RangedSpeed,R->RangedCD})if(!FMath::IsFinite(V) || V<0)return Fail(TEXT("数值须有限且非负"));
        if(R->HP<=0 || R->CollisionRadius<=0 || R->VisualSize.X<=0 || R->VisualSize.Y<=0 || R->AreaRadius<=0 || R->AreaWindup<=0 || R->AreaCD<=0 || R->RangedSpeed<=0 || R->RangedCD<=0 || R->HPMinuteCap<0 || R->SpeedMinuteCap<0)return Fail(TEXT("生命/尺寸/半径/攻击间隔须为正，成长上限不能为负"));
        if(R->RangedMax<=R->RangedMin || R->RangedKeepDistance<R->RangedMin || R->RangedKeepDistance>R->RangedMax)return Fail(TEXT("远程距离须满足最小≤保持距离≤最大，且最大>最小"));
        if(R->SpawnWeights.Num()!=6)return Fail(TEXT("普通波次权重必须恰好六档"));
        for(float W:R->SpawnWeights)if(!FMath::IsFinite(W) || W<0 || (R->Archetype>=7 && W>0))return Fail(TEXT("波次权重须有限非负，精英与Boss不能加入普通波次"));
        if(R->EliteWeight>0 && (R->Archetype<7 || R->Archetype>9))return Fail(TEXT("仅模板7–9能加入精英轮换"));
        bool SpriteOK=!R->SpriteKey.IsEmpty();for(TCHAR Ch:R->SpriteKey)SpriteOK &= FChar::IsAlnum(Ch) || Ch==TEXT('_');
        if(!R->MaterialOverride && !SpriteOK)return Fail(TEXT("指定材质覆盖，或填写仅含字母/数字/下划线的素材键"));
        Rows.Add(*R);
    }
    Error.Empty();return true;
}

AAlchemyEnemyDesigner::AAlchemyEnemyDesigner() {
    RootComponent=CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
    PrimaryActorTick.bCanEverTick=false;
}

bool AAlchemyEnemyDesigner::ValidateEnemies() {
    if(!EnemyTable)EnemyTable=LoadObject<UDataTable>(nullptr,TEXT("/Game/Design/DT_Enemies.DT_Enemies"));
    TArray<FAlchemyEnemyRow> Rows;FString Error;
    const bool OK=AlchemyDesign::ReadEnemyDefinitions(EnemyTable,Rows,Error);
    Status=OK?FString::Printf(TEXT("怪物配置通过：%d行；新增行为仍需程序支持"),Rows.Num()):Error;
    UE_LOG(LogTemp,Display,TEXT("ENEMY_DEFINITIONS_%s %s"),OK?TEXT("PASS"):TEXT("FAIL"),*Status);return OK;
}

void AAlchemyEnemyDesigner::OpenEnemies() {
    if(!EnemyTable)EnemyTable=LoadObject<UDataTable>(nullptr,TEXT("/Game/Design/DT_Enemies.DT_Enemies"));
#if WITH_EDITOR
    if(EnemyTable && GEditor)GEditor->GetEditorSubsystem<UAssetEditorSubsystem>()->OpenEditorForAsset(EnemyTable);
#endif
    ValidateEnemies();
}

bool AAlchemyEnemyDesigner::CreateStarterTable() {
#if WITH_EDITOR
    const TCHAR* Path=TEXT("/Game/Design/DT_Enemies");
    if(auto* Existing=LoadObject<UDataTable>(nullptr,TEXT("/Game/Design/DT_Enemies.DT_Enemies"))){EnemyTable=Existing;return ValidateEnemies();}
    FString CSV;
    if(!FFileHelper::LoadFileToString(CSV,*(FPaths::ProjectDir()/TEXT("Docs/DesignerCSV/DT_Enemies.csv")))){Status=TEXT("默认怪物CSV缺失");return false;}
    auto* Package=CreatePackage(Path);Package->FullyLoad();
    auto* Table=NewObject<UDataTable>(Package,TEXT("DT_Enemies"),RF_Public|RF_Standalone);Table->RowStruct=FAlchemyEnemyRow::StaticStruct();
    const auto Problems=Table->CreateTableFromCSVString(CSV);TArray<FAlchemyEnemyRow> Rows;FString Error;
    if(!Problems.IsEmpty() || !AlchemyDesign::ReadEnemyDefinitions(Table,Rows,Error)){Status=Problems.IsEmpty()?Error:FString::Join(Problems,TEXT("; "));return false;}
    FAssetRegistryModule::AssetCreated(Table);Table->MarkPackageDirty();
    FSavePackageArgs Args;Args.TopLevelFlags=RF_Public|RF_Standalone;
    if(!UPackage::SavePackage(Package,Table,*FPackageName::LongPackageNameToFilename(Path,FPackageName::GetAssetPackageExtension()),Args)){Status=TEXT("保存怪物表失败");return false;}
    EnemyTable=Table;MarkPackageDirty();return ValidateEnemies();
#else
    Status=TEXT("创建默认表仅可在编辑器执行");return false;
#endif
}
