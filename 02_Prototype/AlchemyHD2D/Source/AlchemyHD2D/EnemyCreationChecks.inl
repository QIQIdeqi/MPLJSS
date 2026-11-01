#if WITH_EDITOR
#include "AssetRegistry/AssetRegistryModule.h"
#include "Misc/PackageName.h"
#include "Misc/SecureHash.h"
#include "UObject/Package.h"
#include "Engine/DataTable.h"
#endif

bool AAlchemyWorld::EnemyCreationCheck(float Dt) {
    (void)Dt;
    static bool Finished=false;if(Finished)return true;Finished=true;
    bool OK=true;int Checks=0;FString Report;
    const auto Check=[&](bool Pass,const TCHAR* Name){
        OK &= Pass;Checks++;const FString Line=FString::Printf(TEXT("ENEMY_CREATION_CHECK %s %s"),Name,Pass?TEXT("PASS"):TEXT("FAIL"));
        Report+=Line+TEXT("\n");UE_LOG(LogTemp,Display,TEXT("%s"),*Line);
    };
#if WITH_EDITOR
    const FString Token=FGuid::NewGuid().ToString(EGuidFormats::Digits);
    const FString Evidence=FPaths::ConvertRelativePathToFull(FPaths::ProjectDir()/TEXT("Evidence/EnemyCreation_20261101"));
    const FString PackageFolder=Evidence/(TEXT("packages_")+Token);
    const FString Mount=TEXT("/EnemyCreation_")+Token+TEXT("/");
    IFileManager::Get().MakeDirectory(*PackageFolder,true);
    FPackageName::RegisterMountPoint(Mount,PackageFolder+TEXT("/"));
    auto& Registry=FModuleManager::LoadModuleChecked<FAssetRegistryModule>(TEXT("AssetRegistry")).Get();
    const auto ObjectPath=[&](const FString& Package){return Package+TEXT(".")+FPackageName::GetLongPackageAssetName(Package);};
    const auto Registered=[&](const FString& Package){return Registry.GetAssetByObjectPath(FSoftObjectPath(ObjectPath(Package))).IsValid();};
    const auto Exists=[&](const FString& Package){return FindObject<UObject>(nullptr,*ObjectPath(Package))!=nullptr;};
    const auto Filename=[&](const FString& Package){return FPaths::ConvertRelativePathToFull(FPackageName::LongPackageNameToFilename(Package,FPackageName::GetAssetPackageExtension()));};
    const auto FileHash=[&](const FString& File){
        TArray<uint8> Bytes;if(!FFileHelper::LoadFileToArray(Bytes,*File))return FString(TEXT("UNREADABLE"));
        return FSHA1::HashBuffer(Bytes.GetData(),uint64(Bytes.Num())).ToString();
    };
    const FString CSVFile=PackageFolder/TEXT("active.csv");
    FString GoodCSV;Check(FFileHelper::LoadFileToString(GoodCSV,*(FPaths::ProjectDir()/TEXT("Docs/DesignerCSV/DT_Enemies.csv"))),TEXT("read_default_seed_only"));
    auto* Seed=NewObject<UDataTable>(GetTransientPackage());Seed->RowStruct=FAlchemyEnemyRow::StaticStruct();
    const auto Problems=Seed->CreateTableFromCSVString(GoodCSV);
    auto* Row=Seed->FindRow<FAlchemyEnemyRow>(FName(TEXT("0")),TEXT("EnemyCreationFixture"),false);
    Check(Problems.IsEmpty() && Row,TEXT("parse_seed_into_transient_table"));
    if(Row && Problems.IsEmpty()){
        Row->HP=0;const FString BadCSV=Seed->GetTableAsCSV();
        const auto Write=[&](const FString& Text){const bool Saved=FFileHelper::SaveStringToFile(Text,*CSVFile);Check(Saved,TEXT("write_only_scratch_active_csv"));return Saved;};
        const auto Create=[&](const FString& Package,UDataTable*& Table,FString& Error){
            const bool Result=AlchemyDesign::CreateEnemyStarterTable(Package,CSVFile,Table,Error);
            Report+=FString::Printf(TEXT("helper package=%s result=%d error=%s\n"),*Package,Result,*Error);
            UE_LOG(LogTemp,Display,TEXT("ENEMY_CREATION_HELPER package=%s result=%d error=%s"),*Package,Result,*Error);return Result;
        };
        // Semantic failure must not poison a retry through a still-named in-memory object.
        const FString Semantic=Mount+TEXT("SemanticRetry");UDataTable* Table=nullptr;FString Error;
        if(Write(BadCSV)){
            const bool Created=Create(Semantic,Table,Error);
            Check(!Created,TEXT("invalid_semantics_rejected"));
            Check(!Exists(Semantic),TEXT("invalid_semantics_has_no_named_asset"));
            Check(!Registered(Semantic),TEXT("invalid_semantics_has_no_registry_asset"));
            Check(!IFileManager::Get().FileExists(*Filename(Semantic)),TEXT("invalid_semantics_has_no_disk_asset"));
        }
        if(Write(GoodCSV)){
            Table=nullptr;Error.Empty();const bool Created=Create(Semantic,Table,Error);
            Check(Created && Table,TEXT("semantic_same_package_retry_succeeds"));
            Check(IFileManager::Get().FileExists(*Filename(Semantic)),TEXT("semantic_retry_really_saved_file"));
        }
        // A regular file at the required parent path blocks SavePackage's child-directory creation.
        const FString SaveCase=Mount+TEXT("BlockedParent/SaveRetry"),SaveFile=Filename(SaveCase);
        const FString Blocker=FPaths::ConvertRelativePathToFull(PackageFolder/TEXT("BlockedParent"));
        const bool Safe=SaveFile==FPaths::ConvertRelativePathToFull(PackageFolder/TEXT("BlockedParent/SaveRetry.uasset"))
            && Blocker==FPaths::GetPath(SaveFile) && Blocker.StartsWith(PackageFolder+TEXT("/"));
        Check(Safe,TEXT("save_parent_blocker_resolves_inside_guid_scratch"));
        if(Safe && Write(GoodCSV)){
            const bool MadeBlocker=FFileHelper::SaveStringToFile(TEXT("GUID fixture: parent is deliberately a regular file"),*Blocker);
            const bool IsFile=IFileManager::Get().FileExists(*Blocker) && !IFileManager::Get().DirectoryExists(*Blocker);
            Check(MadeBlocker && IsFile,TEXT("create_owned_regular_file_as_parent_blocker"));
            if(MadeBlocker && IsFile){
                Table=nullptr;Error.Empty();UE_LOG(LogTemp,Display,TEXT("ENEMY_CREATION_EXPECTED_SAVE_FAILURE_BEGIN"));
                const bool Created=Create(SaveCase,Table,Error);
                UE_LOG(LogTemp,Display,TEXT("ENEMY_CREATION_EXPECTED_SAVE_FAILURE_END"));
                Check(!Created,TEXT("actual_save_failure_reported"));
                Check(!Exists(SaveCase),TEXT("save_failure_has_no_named_asset"));
                Check(!Registered(SaveCase),TEXT("save_failure_has_no_registry_asset"));
                Check(!IFileManager::Get().FileExists(*SaveFile),TEXT("save_failure_has_no_disk_file"));
                // GUID-owned absolute parent path was verified above. Delete this file only, never a directory/tree.
                const bool Removed=IFileManager::Get().Delete(*Blocker,true,false,false);
                Check(Removed && !IFileManager::Get().FileExists(*Blocker),TEXT("remove_only_owned_parent_blocker_file"));
                if(Removed){
                    Table=nullptr;Error.Empty();const bool Retried=Create(SaveCase,Table,Error);
                    Check(Retried && Table,TEXT("save_same_package_retry_succeeds"));
                    Check(IFileManager::Get().FileExists(*SaveFile),TEXT("save_retry_really_saved_file"));
                }
            }
        }

        // Independent success path: earlier failed retries must not skip author-data coverage.
        const FString AuthorPackage=Mount+TEXT("AuthorPreserve");
        if(Write(GoodCSV)){
            Table=nullptr;Error.Empty();const bool Created=Create(AuthorPackage,Table,Error);
            Check(Created && Table && IFileManager::Get().FileExists(*Filename(AuthorPackage)),TEXT("independent_author_fixture_saved"));
            if(Created && Table && IFileManager::Get().FileExists(*Filename(AuthorPackage))){
                auto* Author=Table->FindRow<FAlchemyEnemyRow>(FName(TEXT("0")),TEXT("AuthorEdit"),false);
                Check(Author!=nullptr,TEXT("author_row_exists"));
                if(Author){
                    Author->HP=77;Table->GetOutermost()->SetDirtyFlag(true);
                    Check(Table->GetOutermost()->IsDirty(),TEXT("author_dirty_fixture_setup_succeeded"));
                    const FString BeforeHash=FileHash(Filename(AuthorPackage));
                    if(Write(BadCSV)){
                        UDataTable* Existing=nullptr;Error.Empty();const bool Preserved=Create(AuthorPackage,Existing,Error);
                        Check(Preserved && Existing==Table && Author->HP==77,TEXT("existing_dirty_author_table_preserved"));
                        Check(Table->GetOutermost()->IsDirty(),TEXT("existing_author_dirty_state_preserved"));
                        Check(BeforeHash!=TEXT("UNREADABLE") && FileHash(Filename(AuthorPackage))==BeforeHash,TEXT("existing_author_disk_hash_unchanged"));
                    }
                }
            }
        }

    }
    // Scratch files remain as evidence; the process exit tears down the mount and transient packages.
    Report+=FString::Printf(TEXT("mount=%s\npackages=%s\n"),*Mount,*PackageFolder);
    Check(FFileHelper::SaveStringToFile(Report,*(PackageFolder/TEXT("checks.txt"))),TEXT("scratch_report_saved"));
#else
    Check(false,TEXT("editor_build_required_for_real_creator_and_SavePackage"));
#endif
    UE_LOG(LogTemp,Display,TEXT("ENEMY_CREATION_%s checks=%d"),OK?TEXT("PASS"):TEXT("FAIL"),Checks);
    FPlatformMisc::RequestExitWithStatus(false,OK?0:1);return true;
}
