#include "MainMenuWorld.h"
#include "MainMenuWidget.h"
#include "GameAudio.h"
#include "Engine/Texture2D.h"
#include "Kismet/GameplayStatics.h"
#include "Kismet/KismetSystemLibrary.h"
#include "Blueprint/UserWidget.h"
#include "Engine/World.h"
#include "GameFramework/PlayerController.h"

AMainMenuWorld::AMainMenuWorld() {
    PrimaryActorTick.bCanEverTick=false;
}

void AMainMenuWorld::BeginPlay() {
    Super::BeginPlay();
    auto PC=GetWorld()->GetFirstPlayerController();
    // 主菜单用纯屏幕空间 UI，显示鼠标，不锁定鼠标。
    if(PC) {
        PC->bShowMouseCursor=true;
        PC->bEnableClickEvents=true;
        PC->bEnableMouseOverEvents=true;
        FInputModeGameAndUI Mode; Mode.SetHideCursorDuringCapture(false); Mode.SetLockMouseToViewportBehavior(EMouseLockMode::DoNotLock);
        PC->SetInputMode(Mode);
    }
    // 加载独立用户设置。
    Settings=Cast<UMainMenuSettings>(UGameplayStatics::LoadGameFromSlot(TEXT("MainMenuSettings"),0));
    if(!Settings) Settings=NewObject<UMainMenuSettings>(this);
    ApplyMasterVolume();
    AlchemyGameAudio::SetMusic(this,TEXT("Music_Menu"));
    // 创建并显示主菜单 Widget。
    MenuWidget=CreateWidget<UMainMenuWidget>(PC,UMainMenuWidget::StaticClass());
    if(MenuWidget) {
        MenuWidget->InitializeForWorld(this);
        MenuWidget->AddToViewport(0);
        MenuWidget->RefreshButtons(HasValidSave());
    }
}

bool AMainMenuWorld::HasValidSave() const {
    // 以存档文件实际存在为准（主槽或备份槽）。
    if(UGameplayStatics::DoesSaveGameExist(TEXT("GreyfordDemo_v1"),0)) return true;
    if(UGameplayStatics::DoesSaveGameExist(TEXT("AlchemyResearch_v1"),0)) return true;
    if(UGameplayStatics::DoesSaveGameExist(TEXT("GreyfordDemo_backup"),0)) return true;
    if(UGameplayStatics::DoesSaveGameExist(TEXT("AlchemyResearch_backup"),0)) return true;
    return false;
}

void AMainMenuWorld::StartNewGame() { EnterGame(false); }
void AMainMenuWorld::LoadGame() { EnterGame(true); }
void AMainMenuWorld::QuitGame() {
    AlchemyGameAudio::Play(this,TEXT("UICancel"));
    UKismetSystemLibrary::QuitGame(this,nullptr,EQuitPreference::Quit,false);
}

void AMainMenuWorld::EnterGame(bool bContinue) {
    // 进入战斗关卡 Greyford_Flow，由关卡内的 AAlchemyWorld 处理存档。
    AlchemyGameAudio::Play(this,TEXT("UIConfirm"));
    UGameplayStatics::OpenLevel(this,FName(TEXT("Greyford_Flow")));
}

void AMainMenuWorld::SetMasterVolume(float Volume) {
    if(!Settings) return;
    Settings->MasterVolume=FMath::Clamp(Volume,0.f,1.f);
    ApplyMasterVolume();
    SaveSettings();
}

float AMainMenuWorld::GetMasterVolume() const {
    return Settings?Settings->MasterVolume:1.f;
}

void AMainMenuWorld::ApplyMasterVolume() {
    AlchemyGameAudio::ApplyVolume(this,GetMasterVolume());
}

void AMainMenuWorld::SaveSettings() {
    if(Settings) UGameplayStatics::SaveGameToSlot(Settings,TEXT("MainMenuSettings"),0);
}

void AMainMenuWorld::SetPerspective(bool bOn) { if(!Settings) return; Settings->bPerspective=bOn; SaveSettings(); }
void AMainMenuWorld::SetLitSprites(bool bOn) { if(!Settings) return; Settings->bLitSprites=bOn; SaveSettings(); }
void AMainMenuWorld::SetUprightSprites(bool bOn) { if(!Settings) return; Settings->bUprightSprites=bOn; SaveSettings(); }
void AMainMenuWorld::SetDepthOfField(bool bOn) { if(!Settings) return; Settings->bDepthOfField=bOn; SaveSettings(); }
void AMainMenuWorld::SetMediumTextScale(float Scale) { if(!Settings) return; Settings->MediumTextScale=FMath::Clamp(Scale,.5f,1.2f); SaveSettings(); }
void AMainMenuWorld::SetLargeTextScale(float Scale) { if(!Settings) return; Settings->LargeTextScale=FMath::Clamp(Scale,.5f,1.2f); SaveSettings(); }
