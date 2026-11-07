#include "MainMenuWidget.h"
#include "MainMenuWorld.h"
#include "GameAudio.h"
#include "Blueprint/WidgetTree.h"
#include "Components/CanvasPanel.h"
#include "Components/CanvasPanelSlot.h"
#include "Components/Image.h"
#include "Components/TextBlock.h"
#include "Components/Button.h"
#include "Components/Slider.h"
#include "Components/CheckBox.h"
#include "Components/ScaleBox.h"
#include "Components/ScaleBoxSlot.h"
#include "Components/SizeBox.h"
#include "Components/Border.h"
#include "Components/HorizontalBox.h"
#include "Components/HorizontalBoxSlot.h"
#include "Components/Overlay.h"
#include "Components/OverlaySlot.h"
#include "Engine/Texture2D.h"
#include "Engine/Font.h"
#include "Misc/Paths.h"
#include "Styling/SlateColor.h"

namespace MainMenu {
constexpr float DesignW=2560.f,DesignH=1440.f;

FSlateBrush ColorBrush(const FLinearColor& C) {
    FSlateBrush B; B.DrawAs=ESlateBrushDrawType::Box;
    B.TintColor=FSlateColor(C);
    return B;
}

// 深色半透明底 + 金色细边框的按钮样式。
FButtonStyle MenuButtonStyle() {
    FButtonStyle S;
    const FLinearColor Base(.04f,.05f,.06f,.82f), Hover(.08f,.09f,.11f,.88f), Sel(.12f,.10f,.05f,.92f);
    S.Normal=ColorBrush(Base);
    S.Hovered=ColorBrush(Hover);
    S.Pressed=ColorBrush(Sel);
    // 金色细边框：Normal 用细金线，Pressed 用高亮金线。
    S.Normal.OutlineSettings.Color=FLinearColor(.75f,.6f,.3f,.9f);
    S.Normal.OutlineSettings.Width=2.f;
    S.Hovered.OutlineSettings=S.Normal.OutlineSettings;
    S.Pressed.OutlineSettings=S.Normal.OutlineSettings;
    S.Pressed.OutlineSettings.Color=FLinearColor(1.f,.85f,.4f,1.f);
    return S;
}

void Place(UCanvasPanel* Parent,UWidget* Child,FVector2D Position,FVector2D Size){
    auto Slot=Parent->AddChildToCanvas(Child);Slot->SetPosition(Position);Slot->SetSize(Size);
}

UImage* Image(UWidgetTree* Tree,UCanvasPanel* Parent,const TCHAR* Name,UTexture2D* Tex,FVector2D Position,FVector2D Size){
    auto R=Tree->ConstructWidget<UImage>(UImage::StaticClass(),Name);
    if(Tex){FSlateBrush B; B.SetResourceObject(Tex); B.DrawAs=ESlateBrushDrawType::Image; R->SetBrush(B);}
    R->SetVisibility(ESlateVisibility::HitTestInvisible); if(Parent)Place(Parent,R,Position,Size); return R;
}

UTextBlock* Text(UWidgetTree* Tree,UCanvasPanel* Parent,const TCHAR* Name,FVector2D Position,FVector2D Size,int32 FontSize,FLinearColor Color=FLinearColor(.96f,.9f,.7f)){
    auto R=Tree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass(),Name);
    R->SetFont(FSlateFontInfo(FPaths::EngineContentDir()/TEXT("Slate/Fonts/DroidSansFallback.ttf"),FontSize));
    R->SetColorAndOpacity(FSlateColor(Color));R->SetShadowOffset(FVector2D(1,2));R->SetShadowColorAndOpacity(FLinearColor(0,0,0,.9f));
    R->SetVisibility(ESlateVisibility::HitTestInvisible); if(Parent)Place(Parent,R,Position,Size); return R;
}
}

void UMainMenuWidget::NativeOnInitialized() {
    Super::NativeOnInitialized();
    // 由 InitializeForWorld 触发构建（工程惯例：代码构建 WidgetTree）。
}

void UMainMenuWidget::InitializeForWorld(AMainMenuWorld* InWorld) {
    MenuWorld=InWorld;
    BuildTree(WidgetTree);
    BindControls();
    if(MenuWorld) SetVolumePercent(MenuWorld->GetMasterVolume()*100.f);
}

void UMainMenuWidget::BuildTree(UWidgetTree* Tree) {
    using namespace MainMenu;
    // 全屏缩放：2560×1440 设计稿，ScaleToFit 保持 16:9 不拉伸。
    auto Scale=Tree->ConstructWidget<UScaleBox>(UScaleBox::StaticClass(),TEXT("MenuScale"));
    Scale->SetStretch(EStretch::ScaleToFit);Scale->SetStretchDirection(EStretchDirection::Both);Tree->RootWidget=Scale;
    auto Design=Tree->ConstructWidget<USizeBox>(USizeBox::StaticClass(),TEXT("MenuSize_2560x1440"));
    Design->SetWidthOverride(DesignW);Design->SetHeightOverride(DesignH);
    auto ScaleSlot=Cast<UScaleBoxSlot>(Scale->AddChild(Design));ScaleSlot->SetHorizontalAlignment(HAlign_Center);ScaleSlot->SetVerticalAlignment(VAlign_Center);
    RootCanvas=Tree->ConstructWidget<UCanvasPanel>(UCanvasPanel::StaticClass(),TEXT("RootCanvas"));
    Design->AddChild(RootCanvas);
    RootCanvas->SetVisibility(ESlateVisibility::SelfHitTestInvisible);

    // 全屏背景图。
    UTexture2D* BG=MenuWorld?MenuWorld->GetBackgroundTexture():nullptr;
    if(!BG) BG=LoadObject<UTexture2D>(nullptr,TEXT("/Game/UI/MainMenu/T_StartScreen.T_StartScreen"));
    Image(Tree,RootCanvas,TEXT("Background"),BG,{0,0},{DesignW,DesignH});

    // 按钮区域：右下角草地，往右下移动后的位置。
    const float BtnX=1720.f, BtnW=420.f, BtnH=76.f, BtnGap=16.f;
    const float BtnY=820.f; // 垂直约 57%，更靠右下
    const FButtonStyle Style=MenuButtonStyle();
    // 按钮 = UButton + 内部 Overlay（左图标占位 + 居中文字）。返回按钮。
    auto AddButton=[&](const TCHAR* Name,const TCHAR* Label,float Y)->UButton*{
        auto B=Tree->ConstructWidget<UButton>(UButton::StaticClass(),Name);
        B->SetStyle(Style);Place(RootCanvas,B,{BtnX,Y},{BtnW,BtnH});
        auto Overlay=Tree->ConstructWidget<UOverlay>(UOverlay::StaticClass(),*FString::Printf(TEXT("%sOverlay"),Name));
        B->AddChild(Overlay);
        // 左侧图标占位（正方形，带金色细边框）。
        auto Icon=Tree->ConstructWidget<UImage>(UImage::StaticClass(),*FString::Printf(TEXT("%sIcon"),Name));
        FSlateBrush IB=ColorBrush(FLinearColor(.22f,.2f,.1f,.7f));IB.OutlineSettings.Color=FLinearColor(.8f,.65f,.35f,.7f);IB.OutlineSettings.Width=1.f;
        Icon->SetBrush(IB);Icon->SetVisibility(ESlateVisibility::HitTestInvisible);
        auto OS=Cast<UOverlaySlot>(Overlay->AddChild(Icon));
        OS->SetHorizontalAlignment(HAlign_Left);OS->SetVerticalAlignment(VAlign_Center);
        // 文字（居中）。
        auto T=Tree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass(),*FString::Printf(TEXT("%sText"),Name));
        T->SetFont(FSlateFontInfo(FPaths::EngineContentDir()/TEXT("Slate/Fonts/DroidSansFallback.ttf"),34));
        T->SetColorAndOpacity(FSlateColor(FLinearColor(.96f,.9f,.7f)));
        T->SetShadowOffset(FVector2D(1,2));T->SetShadowColorAndOpacity(FLinearColor(0,0,0,.9f));
        T->SetText(FText::FromString(Label));T->SetVisibility(ESlateVisibility::HitTestInvisible);
        auto TS=Cast<UOverlaySlot>(Overlay->AddChild(T));TS->SetHorizontalAlignment(HAlign_Center);TS->SetVerticalAlignment(VAlign_Center);
        return B;
    };

    // 四个按钮（开始/继续互斥，逻辑层 RefreshButtons 控制可见性）。
    StartButton=AddButton(TEXT("StartButton"),TEXT("开始游戏"),BtnY);
    ContinueButton=AddButton(TEXT("ContinueButton"),TEXT("继续游戏"),BtnY);
    SettingsButton=AddButton(TEXT("SettingsButton"),TEXT("设置"),BtnY+BtnH+BtnGap);
    QuitButton=AddButton(TEXT("QuitButton"),TEXT("退出游戏"),BtnY+2*(BtnH+BtnGap));

    // 设置面板（屏幕中央，扩展为 800×760 容纳画面选项 + 字体缩放）。
    const float PanelW=800.f, PanelH=760.f;
    SettingsPanel=Tree->ConstructWidget<UCanvasPanel>(UCanvasPanel::StaticClass(),TEXT("SettingsPanel"));
    Place(RootCanvas,SettingsPanel,{(DesignW-PanelW)/2,(DesignH-PanelH)/2},{PanelW,PanelH});
    SettingsPanel->SetVisibility(ESlateVisibility::Collapsed);
    // 面板底板。
    auto PanelBG=Tree->ConstructWidget<UImage>(UImage::StaticClass(),TEXT("SettingsBG"));
    FSlateBrush PB=ColorBrush(FLinearColor(.03f,.04f,.05f,.95f));PB.OutlineSettings.Color=FLinearColor(.75f,.6f,.3f,.9f);PB.OutlineSettings.Width=2.f;
    PanelBG->SetBrush(PB);PanelBG->SetVisibility(ESlateVisibility::HitTestInvisible);
    Place(SettingsPanel,PanelBG,{0,0},{PanelW,PanelH});
    auto TitleText=Text(Tree,SettingsPanel,TEXT("SettingsTitle"),{0,24},{PanelW,48},36,FLinearColor(.96f,.9f,.7f));
    TitleText->SetJustification(ETextJustify::Center);TitleText->SetText(FText::FromString(TEXT("设置")));

    // 音量（第一区）。
    Text(Tree,SettingsPanel,TEXT("VolumeLabel"),{60,110},{200,40},26)->SetText(FText::FromString(TEXT("总音量")));
    VolumeSlider=Tree->ConstructWidget<USlider>(USlider::StaticClass(),TEXT("VolumeSlider"));
    Place(SettingsPanel,VolumeSlider,{60,166},{520,40});
    VolumeSlider->SetMinValue(0.f);VolumeSlider->SetMaxValue(100.f);VolumeSlider->SetStepSize(1.f);
    VolumeText=Text(Tree,SettingsPanel,TEXT("VolumeText"),{600,162},{120,44},28);
    VolumeText->SetText(FText::FromString(TEXT("100%")));

    // 画面选项（第二区，四个复选框）。
    Text(Tree,SettingsPanel,TEXT("DisplayLabel"),{60,240},{300,36},24,FLinearColor(.8f,.72f,.5f))->SetText(FText::FromString(TEXT("画面选项")));
    auto AddCheck=[&](const TCHAR* Name,const TCHAR* Label,float X,float Y)->UCheckBox*{
        auto CB=Tree->ConstructWidget<UCheckBox>(UCheckBox::StaticClass(),Name);
        CB->SetCheckedState(ECheckBoxState::Unchecked);
        Place(SettingsPanel,CB,{X,Y},{36,36});
        auto L=Text(Tree,SettingsPanel,*FString::Printf(TEXT("%sLabel"),Name),{X+50,Y-6},{260,44},24);
        L->SetText(FText::FromString(Label));
        return CB;
    };
    PerspectiveCheck=AddCheck(TEXT("PerspectiveCheck"),TEXT("透视镜头"),60,300);
    LitSpritesCheck=AddCheck(TEXT("LitSpritesCheck"),TEXT("角色接受光照"),420,300);
    UprightCheck=AddCheck(TEXT("UprightCheck"),TEXT("角色竖直"),60,370);
    DepthOfFieldCheck=AddCheck(TEXT("DepthOfFieldCheck"),TEXT("景深效果"),420,370);

    // 字体缩放（第三区，两个滑块）。
    Text(Tree,SettingsPanel,TEXT("FontLabel"),{60,440},{300,36},24,FLinearColor(.8f,.72f,.5f))->SetText(FText::FromString(TEXT("字体大小")));
    Text(Tree,SettingsPanel,TEXT("MediumLabel"),{60,496},{240,36},22)->SetText(FText::FromString(TEXT("普通文字")));
    MediumTextSlider=Tree->ConstructWidget<USlider>(USlider::StaticClass(),TEXT("MediumTextSlider"));
    Place(SettingsPanel,MediumTextSlider,{60,540},{260,36});
    MediumTextSlider->SetMinValue(.5f);MediumTextSlider->SetMaxValue(1.2f);MediumTextSlider->SetStepSize(.01f);
    MediumTextValue=Text(Tree,SettingsPanel,TEXT("MediumTextValue"),{330,536},{80,40},22);
    Text(Tree,SettingsPanel,TEXT("LargeLabel"),{440,496},{240,36},22)->SetText(FText::FromString(TEXT("大字/标题")));
    LargeTextSlider=Tree->ConstructWidget<USlider>(USlider::StaticClass(),TEXT("LargeTextSlider"));
    Place(SettingsPanel,LargeTextSlider,{440,540},{260,36});
    LargeTextSlider->SetMinValue(.5f);LargeTextSlider->SetMaxValue(1.2f);LargeTextSlider->SetStepSize(.01f);
    LargeTextValue=Text(Tree,SettingsPanel,TEXT("LargeTextValue"),{710,536},{80,40},22);

    // 返回按钮。
    ReturnButton=Tree->ConstructWidget<UButton>(UButton::StaticClass(),TEXT("ReturnButton"));
    ReturnButton->SetStyle(Style);Place(SettingsPanel,ReturnButton,{(PanelW-260)/2,680},{260,56});
    auto ROverlay=Tree->ConstructWidget<UOverlay>(UOverlay::StaticClass(),TEXT("ReturnOverlay"));ReturnButton->AddChild(ROverlay);
    auto RText=Tree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass(),TEXT("ReturnText"));
    RText->SetFont(FSlateFontInfo(FPaths::EngineContentDir()/TEXT("Slate/Fonts/DroidSansFallback.ttf"),26));
    RText->SetColorAndOpacity(FSlateColor(FLinearColor(.96f,.9f,.7f)));RText->SetText(FText::FromString(TEXT("返回")));RText->SetVisibility(ESlateVisibility::HitTestInvisible);
    auto RSlot=Cast<UOverlaySlot>(ROverlay->AddChild(RText));RSlot->SetHorizontalAlignment(HAlign_Center);RSlot->SetVerticalAlignment(VAlign_Center);
}

void UMainMenuWidget::BindControls() {
    if(StartButton) StartButton->OnClicked.AddDynamic(this,&UMainMenuWidget::OnStartClicked);
    if(ContinueButton) ContinueButton->OnClicked.AddDynamic(this,&UMainMenuWidget::OnContinueClicked);
    if(SettingsButton) SettingsButton->OnClicked.AddDynamic(this,&UMainMenuWidget::OnSettingsClicked);
    if(QuitButton) QuitButton->OnClicked.AddDynamic(this,&UMainMenuWidget::OnQuitClicked);
    if(VolumeSlider) VolumeSlider->OnValueChanged.AddDynamic(this,&UMainMenuWidget::OnVolumeChanged);
    if(ReturnButton) ReturnButton->OnClicked.AddDynamic(this,&UMainMenuWidget::OnReturnClicked);
    if(PerspectiveCheck) PerspectiveCheck->OnCheckStateChanged.AddDynamic(this,&UMainMenuWidget::OnPerspectiveChanged);
    if(LitSpritesCheck) LitSpritesCheck->OnCheckStateChanged.AddDynamic(this,&UMainMenuWidget::OnLitSpritesChanged);
    if(UprightCheck) UprightCheck->OnCheckStateChanged.AddDynamic(this,&UMainMenuWidget::OnUprightChanged);
    if(DepthOfFieldCheck) DepthOfFieldCheck->OnCheckStateChanged.AddDynamic(this,&UMainMenuWidget::OnDepthOfFieldChanged);
    if(MediumTextSlider) MediumTextSlider->OnValueChanged.AddDynamic(this,&UMainMenuWidget::OnMediumTextChanged);
    if(LargeTextSlider) LargeTextSlider->OnValueChanged.AddDynamic(this,&UMainMenuWidget::OnLargeTextChanged);
}

void UMainMenuWidget::RefreshButtons(bool InHasSave) {
    bHasSave=InHasSave;
    // 开始/继续互斥：有存档显示继续，无存档显示开始。
    if(StartButton) StartButton->SetVisibility(bHasSave?ESlateVisibility::Collapsed:ESlateVisibility::Visible);
    if(ContinueButton) ContinueButton->SetVisibility(bHasSave?ESlateVisibility::Visible:ESlateVisibility::Collapsed);
}

void UMainMenuWidget::ShowSettings(bool bShow) {
    if(SettingsPanel) SettingsPanel->SetVisibility(bShow?ESlateVisibility::Visible:ESlateVisibility::Collapsed);
    // 打开设置时，四个主按钮隐藏或禁用避免误触。
    if(StartButton) StartButton->SetVisibility(bShow?ESlateVisibility::Collapsed:(bHasSave?ESlateVisibility::Collapsed:ESlateVisibility::Visible));
    if(ContinueButton) ContinueButton->SetVisibility(bShow?ESlateVisibility::Collapsed:(bHasSave?ESlateVisibility::Visible:ESlateVisibility::Collapsed));
    if(SettingsButton) SettingsButton->SetVisibility(bShow?ESlateVisibility::Collapsed:ESlateVisibility::Visible);
    if(QuitButton) QuitButton->SetVisibility(bShow?ESlateVisibility::Collapsed:ESlateVisibility::Visible);
}

void UMainMenuWidget::SetVolumePercent(float Percent) {
    if(VolumeSlider) VolumeSlider->SetValue(Percent);
    if(VolumeText) VolumeText->SetText(FText::FromString(FString::Printf(TEXT("%.0f%%"),Percent)));
}

float UMainMenuWidget::GetVolumePercent() const {
    return VolumeSlider?VolumeSlider->GetValue():100.f;
}

void UMainMenuWidget::OnStartClicked() { if(MenuWorld) MenuWorld->StartNewGame(); }
void UMainMenuWidget::OnContinueClicked() { if(MenuWorld) MenuWorld->LoadGame(); }
void UMainMenuWidget::OnSettingsClicked() {
    if(MenuWorld) AlchemyGameAudio::Play(MenuWorld,TEXT("UISelect"));
    SyncSettingsToUI();
    ShowSettings(true);
}
void UMainMenuWidget::OnQuitClicked() { if(MenuWorld) MenuWorld->QuitGame(); }
void UMainMenuWidget::OnVolumeChanged(float Value) {
    if(VolumeText) VolumeText->SetText(FText::FromString(FString::Printf(TEXT("%.0f%%"),Value)));
    if(MenuWorld) MenuWorld->SetMasterVolume(Value/100.f);
}
void UMainMenuWidget::OnReturnClicked() {
    if(MenuWorld) AlchemyGameAudio::Play(MenuWorld,TEXT("UICancel"));
    ShowSettings(false);
}

void UMainMenuWidget::SyncSettingsToUI() {
    if(!MenuWorld || !MenuWorld->GetSettings()) return;
    const UMainMenuSettings* S=MenuWorld->GetSettings();
    if(VolumeSlider) VolumeSlider->SetValue(S->MasterVolume*100.f);
    if(VolumeText) VolumeText->SetText(FText::FromString(FString::Printf(TEXT("%.0f%%"),S->MasterVolume*100.f)));
    if(PerspectiveCheck) PerspectiveCheck->SetCheckedState(S->bPerspective?ECheckBoxState::Checked:ECheckBoxState::Unchecked);
    if(LitSpritesCheck) LitSpritesCheck->SetCheckedState(S->bLitSprites?ECheckBoxState::Checked:ECheckBoxState::Unchecked);
    if(UprightCheck) UprightCheck->SetCheckedState(S->bUprightSprites?ECheckBoxState::Checked:ECheckBoxState::Unchecked);
    if(DepthOfFieldCheck) DepthOfFieldCheck->SetCheckedState(S->bDepthOfField?ECheckBoxState::Checked:ECheckBoxState::Unchecked);
    if(MediumTextSlider) MediumTextSlider->SetValue(S->MediumTextScale);
    if(MediumTextValue) MediumTextValue->SetText(FText::FromString(FString::Printf(TEXT("%.0f%%"),S->MediumTextScale*100.f)));
    if(LargeTextSlider) LargeTextSlider->SetValue(S->LargeTextScale);
    if(LargeTextValue) LargeTextValue->SetText(FText::FromString(FString::Printf(TEXT("%.0f%%"),S->LargeTextScale*100.f)));
}

void UMainMenuWidget::OnPerspectiveChanged(bool bChecked) { if(MenuWorld) MenuWorld->SetPerspective(bChecked); }
void UMainMenuWidget::OnLitSpritesChanged(bool bChecked) { if(MenuWorld) MenuWorld->SetLitSprites(bChecked); }
void UMainMenuWidget::OnUprightChanged(bool bChecked) { if(MenuWorld) MenuWorld->SetUprightSprites(bChecked); }
void UMainMenuWidget::OnDepthOfFieldChanged(bool bChecked) { if(MenuWorld) MenuWorld->SetDepthOfField(bChecked); }
void UMainMenuWidget::OnMediumTextChanged(float Value) {
    if(MediumTextValue) MediumTextValue->SetText(FText::FromString(FString::Printf(TEXT("%.0f%%"),Value*100.f)));
    if(MenuWorld) MenuWorld->SetMediumTextScale(Value);
}
void UMainMenuWidget::OnLargeTextChanged(float Value) {
    if(LargeTextValue) LargeTextValue->SetText(FText::FromString(FString::Printf(TEXT("%.0f%%"),Value*100.f)));
    if(MenuWorld) MenuWorld->SetLargeTextScale(Value);
}
