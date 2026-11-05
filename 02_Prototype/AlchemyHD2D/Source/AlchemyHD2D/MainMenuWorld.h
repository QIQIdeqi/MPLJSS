#pragma once
#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "Engine/Texture2D.h"
#include "Sound/SoundClass.h"
#include "Sound/SoundMix.h"
#include "MainMenuWorld.generated.h"

class UMainMenuWidget;
class UMainMenuSettings;

// 主菜单关卡 Actor：加载底图 UMG、判断存档、处理开始/继续/设置/退出与跳转。
UCLASS()
class ALCHEMYHD2D_API AMainMenuWorld : public AActor {
    GENERATED_BODY()
public:
    AMainMenuWorld();
    virtual void BeginPlay() override;

    // 是否存在有效存档（主槽或备份槽）。
    bool HasValidSave() const;
    void StartNewGame();
    void LoadGame();
    void QuitGame();

    // 设置读写。
    UMainMenuSettings* GetSettings() const { return Settings; }
    UTexture2D* GetBackgroundTexture() const { return BackgroundTexture.Get(); }
    void SetMasterVolume(float Volume);
    float GetMasterVolume() const;
    void SaveSettings();
    // 画面选项 + 字体缩放（写入独立用户设置并保存）。
    void SetPerspective(bool bOn);
    void SetLitSprites(bool bOn);
    void SetUprightSprites(bool bOn);
    void SetDepthOfField(bool bOn);
    void SetMediumTextScale(float Scale);
    void SetLargeTextScale(float Scale);

protected:
    UPROPERTY(EditAnywhere,Category="MainMenu") TObjectPtr<UTexture2D> BackgroundTexture;
    UPROPERTY(EditAnywhere,Category="MainMenu") TObjectPtr<USoundClass> MasterSoundClass;
    UPROPERTY(EditAnywhere,Category="MainMenu") TObjectPtr<USoundMix> MasterSoundMix;

private:
    void EnterGame(bool bContinue);
    void ApplyMasterVolume();
    UPROPERTY() TObjectPtr<UMainMenuSettings> Settings;
    UPROPERTY() TObjectPtr<UMainMenuWidget> MenuWidget;
};
