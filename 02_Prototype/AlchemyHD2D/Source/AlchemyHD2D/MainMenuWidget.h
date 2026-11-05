#pragma once
#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "GameFramework/SaveGame.h"
#include "MainMenuWidget.generated.h"

class UCanvasPanel;
class UImage;
class UTextBlock;
class UButton;
class USlider;
class UCheckBox;
class UWidgetTree;
class AMainMenuWorld;

// 独立于游戏存档的用户设置（音量 + 画面选项），持久化到 MainMenuSettings 槽。
UCLASS()
class ALCHEMYHD2D_API UMainMenuSettings : public USaveGame {
    GENERATED_BODY()
public:
    UPROPERTY() float MasterVolume=1.0f;   // 0.0 ~ 1.0
    UPROPERTY() bool bPerspective=true;
    UPROPERTY() bool bLitSprites=false;
    UPROPERTY() bool bUprightSprites=false;
    UPROPERTY() bool bDepthOfField=false;
    UPROPERTY() float MediumTextScale=.9f;
    UPROPERTY() float LargeTextScale=.72f;
};

// 主界面 UMG Widget：全屏底图 + 四个菜单按钮（开始/继续互斥、设置、退出）+ 设置面板。
UCLASS()
class ALCHEMYHD2D_API UMainMenuWidget : public UUserWidget {
    GENERATED_BODY()
public:
    UFUNCTION(BlueprintCallable,Category="MainMenu") void InitializeForWorld(AMainMenuWorld* InWorld);
    // 主菜单按钮点击回调（由 MainMenuWorld 绑定）。
    void RefreshButtons(bool bHasSave);
    void ShowSettings(bool bShow);
    void SetVolumePercent(float Percent);
    float GetVolumePercent() const;
    // 同步设置面板控件到当前设置值（打开设置面板时调用）。
    void SyncSettingsToUI();
protected:
    virtual void NativeOnInitialized() override;
private:
    void BuildTree(UWidgetTree* Tree);
    void BindControls();
    void OnSettingsChanged();
    UFUNCTION() void OnStartClicked();
    UFUNCTION() void OnContinueClicked();
    UFUNCTION() void OnSettingsClicked();
    UFUNCTION() void OnQuitClicked();
    UFUNCTION() void OnVolumeChanged(float Value);
    UFUNCTION() void OnReturnClicked();
    UFUNCTION() void OnPerspectiveChanged(bool bChecked);
    UFUNCTION() void OnLitSpritesChanged(bool bChecked);
    UFUNCTION() void OnUprightChanged(bool bChecked);
    UFUNCTION() void OnDepthOfFieldChanged(bool bChecked);
    UFUNCTION() void OnMediumTextChanged(float Value);
    UFUNCTION() void OnLargeTextChanged(float Value);

    UPROPERTY() TObjectPtr<AMainMenuWorld> MenuWorld;
    // 主菜单控件。
    UPROPERTY(meta=(BindWidgetOptional)) TObjectPtr<UCanvasPanel> RootCanvas;
    UPROPERTY(meta=(BindWidgetOptional)) TObjectPtr<UButton> StartButton;
    UPROPERTY(meta=(BindWidgetOptional)) TObjectPtr<UButton> ContinueButton;
    UPROPERTY(meta=(BindWidgetOptional)) TObjectPtr<UButton> SettingsButton;
    UPROPERTY(meta=(BindWidgetOptional)) TObjectPtr<UButton> QuitButton;
    // 设置面板控件。
    UPROPERTY(meta=(BindWidgetOptional)) TObjectPtr<UCanvasPanel> SettingsPanel;
    UPROPERTY(meta=(BindWidgetOptional)) TObjectPtr<USlider> VolumeSlider;
    UPROPERTY(meta=(BindWidgetOptional)) TObjectPtr<UTextBlock> VolumeText;
    UPROPERTY(meta=(BindWidgetOptional)) TObjectPtr<UButton> ReturnButton;
    UPROPERTY(meta=(BindWidgetOptional)) TObjectPtr<UCheckBox> PerspectiveCheck;
    UPROPERTY(meta=(BindWidgetOptional)) TObjectPtr<UCheckBox> LitSpritesCheck;
    UPROPERTY(meta=(BindWidgetOptional)) TObjectPtr<UCheckBox> UprightCheck;
    UPROPERTY(meta=(BindWidgetOptional)) TObjectPtr<UCheckBox> DepthOfFieldCheck;
    UPROPERTY(meta=(BindWidgetOptional)) TObjectPtr<USlider> MediumTextSlider;
    UPROPERTY(meta=(BindWidgetOptional)) TObjectPtr<USlider> LargeTextSlider;
    UPROPERTY(meta=(BindWidgetOptional)) TObjectPtr<UTextBlock> MediumTextValue;
    UPROPERTY(meta=(BindWidgetOptional)) TObjectPtr<UTextBlock> LargeTextValue;
    bool bHasSave=false;
};
