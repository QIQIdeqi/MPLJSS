#include "BattleReferenceWidget.h"
#include "AlchemyWorld.h"
#include "Blueprint/WidgetTree.h"
#include "Components/Button.h"
#include "Components/CanvasPanel.h"
#include "Components/CanvasPanelSlot.h"
#include "Components/Image.h"
#include "Components/ProgressBar.h"
#include "Components/ScaleBox.h"
#include "Components/ScaleBoxSlot.h"
#include "Components/SizeBox.h"
#include "Components/TextBlock.h"
#include "Engine/Texture2D.h"
#include "Engine/Font.h"
#include "Engine/FontFace.h"
#include "Camera/CameraActor.h"
#include "Rendering/DrawElements.h"
#include "Styling/CoreStyle.h"
#include "Misc/Paths.h"
#if WITH_EDITOR
#include "WidgetBlueprint.h"
#include "Blueprint/WidgetBlueprintGeneratedClass.h"
#include "Kismet2/KismetEditorUtilities.h"
#include "Kismet2/BlueprintEditorUtils.h"
#include "AssetRegistry/AssetRegistryModule.h"
#include "UObject/SavePackage.h"
#include "Misc/PackageName.h"
#endif

namespace BattleReference {
constexpr float Width=1672,Height=940;
UTexture2D* Texture(const TCHAR* Name){return LoadObject<UTexture2D>(nullptr,*FString::Printf(TEXT("/Game/UI/Reference/T_%s.T_%s"),Name,Name));}
FSlateBrush Brush(const TCHAR* Name){FSlateBrush Result;Result.SetResourceObject(Texture(Name));Result.DrawAs=ESlateBrushDrawType::Image;return Result;}
void Place(UCanvasPanel* Parent,UWidget* Child,FVector2D Position,FVector2D Size){auto Slot=Parent->AddChildToCanvas(Child);Slot->SetPosition(Position);Slot->SetSize(Size);}
UImage* Image(UWidgetTree* Tree,UCanvasPanel* Parent,const TCHAR* Name,const TCHAR* Asset,FVector2D Position,FVector2D Size){
    auto Result=Tree->ConstructWidget<UImage>(UImage::StaticClass(),Name);Result->SetBrush(Brush(Asset));Result->SetVisibility(ESlateVisibility::HitTestInvisible);Place(Parent,Result,Position,Size);return Result;
}
UTextBlock* Text(UWidgetTree* Tree,UCanvasPanel* Parent,const TCHAR* Name,FVector2D Position,FVector2D Size,int32 FontSize,FLinearColor Color=FLinearColor(.96f,.94f,.88f)){
    auto Result=Tree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass(),Name);
    auto Serif=FCString::Strcmp(Name,TEXT("DodgeText"))==0?nullptr:LoadObject<UFont>(nullptr,TEXT("/Game/UI/Reference/F_ReferenceSerif.F_ReferenceSerif"));
    Result->SetFont(Serif?FSlateFontInfo(Serif,FontSize,TEXT("Regular")):FSlateFontInfo(FPaths::EngineContentDir()/TEXT("Slate/Fonts/DroidSansFallback.ttf"),FontSize));
    Result->SetColorAndOpacity(FSlateColor(Color));Result->SetShadowOffset(FVector2D(1,2));Result->SetShadowColorAndOpacity(FLinearColor(0,0,0,.9f));
    Result->SetVisibility(ESlateVisibility::HitTestInvisible);Place(Parent,Result,Position,Size);return Result;
}
UProgressBar* Progress(UWidgetTree* Tree,UCanvasPanel* Parent,const TCHAR* Name,const TCHAR* Fill,FVector2D Position,FVector2D Size){
    auto Result=Tree->ConstructWidget<UProgressBar>(UProgressBar::StaticClass(),Name);
    FProgressBarStyle Style;Style.BackgroundImage=Brush(TEXT("BarDark"));Style.FillImage=Brush(Fill);Style.MarqueeImage=Style.FillImage;
    Result->SetWidgetStyle(Style);Result->SetBorderPadding(FVector2D::ZeroVector);Result->SetFillColorAndOpacity(FLinearColor::White);Result->SetPercent(1);
    Result->SetVisibility(ESlateVisibility::HitTestInvisible);Place(Parent,Result,Position,Size);return Result;
}
}

void UBattleReferenceWidget::BuildReferenceTree(UWidgetTree* Tree){
    using namespace BattleReference;
    auto Scale=Tree->ConstructWidget<UScaleBox>(UScaleBox::StaticClass(),TEXT("ReferenceScale"));Scale->SetStretch(EStretch::ScaleToFit);Scale->SetStretchDirection(EStretchDirection::Both);Tree->RootWidget=Scale;
    auto DesignSize=Tree->ConstructWidget<USizeBox>(USizeBox::StaticClass(),TEXT("ReferenceSize_1672x940"));DesignSize->SetWidthOverride(Width);DesignSize->SetHeightOverride(Height);
    auto ScaleSlot=Cast<UScaleBoxSlot>(Scale->AddChild(DesignSize));ScaleSlot->SetHorizontalAlignment(HAlign_Center);ScaleSlot->SetVerticalAlignment(VAlign_Center);
    auto Root=Tree->ConstructWidget<UCanvasPanel>(UCanvasPanel::StaticClass(),TEXT("ReferenceCanvas"));DesignSize->AddChild(Root);
    Root->SetVisibility(ESlateVisibility::SelfHitTestInvisible);
    Image(Tree,Root,TEXT("PortraitArtwork"),TEXT("Portrait"),{20,8},{99,105});Image(Tree,Root,TEXT("PortraitBadge"),TEXT("PortraitBadge"),{20,82},{29,31});
    Text(Tree,Root,TEXT("LevelText"),{126,20},{72,33},18)->SetText(FText::FromString(TEXT("Lv 1")));
    Progress(Tree,Root,TEXT("HPBar"),TEXT("HPFill"),{213,35},{270,16});Image(Tree,Root,TEXT("HPFrame"),TEXT("HPFrame"),{197,27},{306,32});
    auto Health=Text(Tree,Root,TEXT("HPText"),{322,29},{152,27},15);Health->SetJustification(ETextJustify::Right);Health->SetText(FText::FromString(TEXT("100 / 100")));
    Progress(Tree,Root,TEXT("DodgeBar"),TEXT("DodgeFill"),{130,62},{270,10});Image(Tree,Root,TEXT("DodgeFrame"),TEXT("DodgeFrame"),{118,55},{296,24});
    auto DodgeLabel=Text(Tree,Root,TEXT("DodgeText"),{128,78},{290,20},12);DodgeLabel->SetVisibility(ESlateVisibility::Collapsed);
    Image(Tree,Root,TEXT("TimerLeft"),TEXT("TimerLeft"),{735,22},{60,24});Image(Tree,Root,TEXT("TimerRight"),TEXT("TimerRight"),{891,22},{60,24});
    auto Time=Text(Tree,Root,TEXT("TimerText"),{791,16},{106,34},20);Time->SetJustification(ETextJustify::Center);Time->SetText(FText::FromString(TEXT("00 : 00")));
    Image(Tree,Root,TEXT("KillIcon"),TEXT("Skull"),{1332,11},{36,38});Text(Tree,Root,TEXT("KillText"),{1374,10},{105,43},18)->SetText(FText::FromString(TEXT("0")));
    Image(Tree,Root,TEXT("CoinIcon"),TEXT("Coin"),{1488,10},{39,40});Text(Tree,Root,TEXT("CoinText"),{1533,10},{118,43},18,FLinearColor(.99f,.8f,.3f))->SetText(FText::FromString(TEXT("0")));
    auto Map=Tree->ConstructWidget<UCanvasPanel>(UCanvasPanel::StaticClass(),TEXT("Minimap"));Place(Root,Map,{1405,52},{249,148});
    Image(Tree,Map,TEXT("MinimapBacking"),TEXT("MinimapDark"),{6,6},{237,136});Image(Tree,Map,TEXT("MinimapFrame"),TEXT("MinimapFrame"),{0,0},{249,148});
    auto Slots=Tree->ConstructWidget<UCanvasPanel>(UCanvasPanel::StaticClass(),TEXT("SkillGroup"));Place(Root,Slots,{624,804},{421,100});
    for(int I=0;I<6;I++){
        auto SlotPanel=Tree->ConstructWidget<UCanvasPanel>(UCanvasPanel::StaticClass(),*FString::Printf(TEXT("SkillSlot%d"),I));Place(Slots,SlotPanel,{float(I*88),0},{75,98});
        Image(Tree,SlotPanel,*FString::Printf(TEXT("SkillBackdrop%d"),I),TEXT("BarDark"),{4,4},{67,68});
        Image(Tree,SlotPanel,*FString::Printf(TEXT("SkillArt%d"),I),*FString::Printf(TEXT("SkillArt%d"),I%4),{9,10},{56,56});
        Image(Tree,SlotPanel,*FString::Printf(TEXT("SkillFrame%d"),I),TEXT("SkillFrame"),{0,0},{75,76});
        auto Label=Text(Tree,SlotPanel,*FString::Printf(TEXT("SkillLevel%d"),I),{0,75},{75,25},15);Label->SetJustification(ETextJustify::Center);Label->SetText(FText::FromString(TEXT("Lv 1")));
        if(I>=4)SlotPanel->SetVisibility(ESlateVisibility::Collapsed);
    }
    auto Add=Tree->ConstructWidget<UButton>(UButton::StaticClass(),TEXT("OpenSkillsButton"));FButtonStyle AddStyle;AddStyle.Normal=Brush(TEXT("AddSkill"));AddStyle.Hovered=AddStyle.Pressed=AddStyle.Normal;
    AddStyle.Hovered.TintColor=FSlateColor(FLinearColor(1.12f,1.12f,1.12f));Add->SetStyle(AddStyle);Add->SetToolTipText(FText::FromString(TEXT("管理装备与储备技能 · B")));Place(Slots,Add,{354,6},{67,69});
    Progress(Tree,Root,TEXT("XPBar"),TEXT("XPFill"),{392,912},{887,11});Image(Tree,Root,TEXT("XPFrame"),TEXT("XPFrame"),{373,902},{926,30});
}

void UBattleReferenceWidget::NativeOnInitialized(){Super::NativeOnInitialized();if(!WidgetTree->RootWidget)BuildReferenceTree(WidgetTree);BindControls();}
void UBattleReferenceWidget::BindControls(){
    HPBar=Cast<UProgressBar>(GetWidgetFromName(TEXT("HPBar")));DodgeBar=Cast<UProgressBar>(GetWidgetFromName(TEXT("DodgeBar")));XPBar=Cast<UProgressBar>(GetWidgetFromName(TEXT("XPBar")));
    LevelText=Cast<UTextBlock>(GetWidgetFromName(TEXT("LevelText")));HPText=Cast<UTextBlock>(GetWidgetFromName(TEXT("HPText")));TimerText=Cast<UTextBlock>(GetWidgetFromName(TEXT("TimerText")));KillText=Cast<UTextBlock>(GetWidgetFromName(TEXT("KillText")));CoinText=Cast<UTextBlock>(GetWidgetFromName(TEXT("CoinText")));DodgeText=Cast<UTextBlock>(GetWidgetFromName(TEXT("DodgeText")));
    SkillGroup=Cast<UCanvasPanel>(GetWidgetFromName(TEXT("SkillGroup")));Minimap=Cast<UCanvasPanel>(GetWidgetFromName(TEXT("Minimap")));
    if(auto Add=Cast<UButton>(GetWidgetFromName(TEXT("OpenSkillsButton")))){Add->IsFocusable=false;Add->OnClicked.AddUniqueDynamic(this,&UBattleReferenceWidget::OpenSkills);}
}
void UBattleReferenceWidget::InitializeForWorld(AAlchemyWorld* InWorld){BattleWorld=InWorld;BindControls();SetVisibility(ESlateVisibility::SelfHitTestInvisible);}
void UBattleReferenceWidget::OpenSkills(){if(BattleWorld)BattleWorld->Action(TEXT("skills"));}

void UBattleReferenceWidget::NativeTick(const FGeometry& MyGeometry,float InDeltaTime){
    Super::NativeTick(MyGeometry,InDeltaTime);
    if(!BattleWorld || !HPBar || !BattleWorld->Progress)return;
    // Hidden still ticks, so leaving a modal never strands the HUD in Collapsed visibility.
    const bool Show=BattleWorld->bCombat && BattleWorld->Panel.IsEmpty() && !BattleWorld->bRunEnded;
    SetRenderOpacity(Show?1:0);SetVisibility(Show?ESlateVisibility::SelfHitTestInvisible:ESlateVisibility::HitTestInvisible);
    if(!Show)return;
    HPBar->SetPercent(FMath::Clamp(BattleWorld->HP/FMath::Max(1.f,BattleWorld->MaxHP),0.f,1.f));DodgeBar->SetPercent(1-FMath::Clamp(BattleWorld->DodgeCD/2.f,0.f,1.f));
    XPBar->SetPercent(FMath::Clamp(BattleWorld->RunXP/FMath::Max(1,BattleWorld->RequiredXP(BattleWorld->RunLevel)),0.f,1.f));
    LevelText->SetText(FText::FromString(FString::Printf(TEXT("Lv %d"),BattleWorld->RunLevel)));HPText->SetText(FText::FromString(FString::Printf(TEXT("%.0f / %.0f"),BattleWorld->HP,BattleWorld->MaxHP)));
    TimerText->SetText(FText::FromString(FString::Printf(TEXT("%02d : %02d"),int(BattleWorld->RunTime)/60,int(BattleWorld->RunTime)%60)));
    KillText->SetText(FText::AsNumber(BattleWorld->Kills));CoinText->SetText(FText::AsNumber(BattleWorld->RunCoins));
    DodgeText->SetText(FText::FromString(BattleWorld->DodgeCD<=0?TEXT("Space · 闪避就绪"):FString::Printf(TEXT("Space · 闪避 %.1fs"),BattleWorld->DodgeCD)));
    DodgeBar->SetToolTipText(DodgeText->GetText());
    XPBar->SetToolTipText(FText::FromString(FString::Printf(TEXT("经验 %.0f / %d"),BattleWorld->RunXP,BattleWorld->RequiredXP(BattleWorld->RunLevel))));
    const int32 VisibleSlots=FMath::Clamp(BattleWorld->Equipped.Num(),4,6);const float GroupWidth=VisibleSlots*88+69;
    if(auto Layout=Cast<UCanvasPanelSlot>(SkillGroup->Slot)){Layout->SetPosition({(BattleReference::Width-GroupWidth)/2-1.5f,804});Layout->SetSize({GroupWidth,100});}
    for(int I=0;I<6;I++){
        auto Panel=Cast<UCanvasPanel>(GetWidgetFromName(*FString::Printf(TEXT("SkillSlot%d"),I)));Panel->SetVisibility(I<VisibleSlots?ESlateVisibility::SelfHitTestInvisible:ESlateVisibility::Collapsed);
        const bool Equipped=BattleWorld->Equipped.IsValidIndex(I);
        auto Art=Cast<UImage>(GetWidgetFromName(*FString::Printf(TEXT("SkillArt%d"),I)));Art->SetVisibility(Equipped?ESlateVisibility::Visible:ESlateVisibility::Hidden);
        auto Label=Cast<UTextBlock>(GetWidgetFromName(*FString::Printf(TEXT("SkillLevel%d"),I)));Label->SetText(Equipped?FText::FromString(FString::Printf(TEXT("Lv %d"),BattleWorld->Levels[BattleWorld->Equipped[I]])):FText::GetEmpty());
        if(Equipped){const int SkillId=BattleWorld->Equipped[I];Art->SetToolTipText(FText::FromString(FString::Printf(TEXT("%s · Lv %d · 自动释放（参考图标）"),BattleWorld->SkillName(SkillId),BattleWorld->Levels[SkillId])));}
    }
    if(auto Add=Cast<UCanvasPanelSlot>(GetWidgetFromName(TEXT("OpenSkillsButton"))->Slot))Add->SetPosition({float(VisibleSlots*88+2),6});
    const FVector Right=BattleWorld->Camera->GetActorRightVector().GetSafeNormal2D();
    if(MapStage!=BattleWorld->GreyfordStage || MapHalf!=BattleWorld->CombatHalfSize || !MapRight.Equals(Right,.001f)){
        MapStage=BattleWorld->GreyfordStage;MapHalf=BattleWorld->CombatHalfSize;MapRight=Right;MapUp=BattleWorld->Camera->GetActorForwardVector().GetSafeNormal2D();
        MapRX=FMath::Max(1.f,float(FMath::Abs(MapRight.X)*MapHalf.X+FMath::Abs(MapRight.Y)*MapHalf.Y));MapRY=FMath::Max(1.f,float(FMath::Abs(MapUp.X)*MapHalf.X+FMath::Abs(MapUp.Y)*MapHalf.Y));WalkCells.Empty();
        for(int Row=0;Row<18;Row++)for(int Col=0;Col<24;Col++)if(BattleWorld->Walkable(MapRight*((Col+.5f)/24*2-1)*MapRX+MapUp*(1-(Row+.5f)/18*2)*MapRY,0))WalkCells.Add({float(Col),float(Row)});
    }
}

int32 UBattleReferenceWidget::NativePaint(const FPaintArgs& Args,const FGeometry& Geometry,const FSlateRect& CullingRect,FSlateWindowElementList& Elements,int32 LayerId,const FWidgetStyle& Style,bool ParentEnabled) const {
    const int32 Base=Super::NativePaint(Args,Geometry,CullingRect,Elements,LayerId,Style,ParentEnabled);
    if(!BattleWorld || !Minimap || !BattleWorld->bCombat || !BattleWorld->Panel.IsEmpty())return Base;
    const FGeometry MapGeometry=Minimap->GetCachedGeometry();const FVector2D Origin=Geometry.AbsoluteToLocal(MapGeometry.LocalToAbsolute(FVector2D::ZeroVector));
    const float Scale=float(MapGeometry.GetAbsoluteSize().X/Geometry.GetAccumulatedLayoutTransform().GetScale()/249.f);
    const auto Draw=[&](FVector2D P,FVector2D Size,FLinearColor Color){FSlateDrawElement::MakeBox(Elements,Base+1,Geometry.ToPaintGeometry(FVector2f(Size*Scale),FSlateLayoutTransform(FVector2f(Origin+P*Scale))),FCoreStyle::Get().GetBrush(TEXT("WhiteBrush")),ESlateDrawEffect::None,Color);};
    for(const auto& Cell:WalkCells)Draw({6+Cell.X*237/24,6+Cell.Y*136/18},{237.f/24,136.f/18},FLinearColor(.08f,.1f,.1f,.3f));
    const auto Point=[&](FVector P){return FVector2D(6+(FMath::Clamp(float(FVector::DotProduct(P,MapRight)/MapRX),-1.f,1.f)+1)*118.5f,6+(1-FMath::Clamp(float(FVector::DotProduct(P,MapUp)/MapRY),-1.f,1.f))*68);};
    for(const auto& Enemy:BattleWorld->Enemies)if(Enemy.HP>0){const float D=Enemy.Type==10?6:Enemy.Type>=7?5:3;Draw(Point(Enemy.Pos)-FVector2D(D/2),FVector2D(D),FLinearColor(.95f,.25f,.18f));}
    if(BattleWorld->GreyfordPortalReady){const auto P=Point(BattleWorld->GreyfordPortalPos);Draw(P-FVector2D(4),{8,8},FLinearColor(.15f,.95f,.9f));Draw(P-FVector2D(2),{4,4},FLinearColor(.1f,.2f,.2f));}
    const auto Player=Point(BattleWorld->PlayerPos);Draw(Player-FVector2D(2,5),{4,10},FLinearColor(1,.86f,.4f));Draw(Player-FVector2D(5,2),{10,4},FLinearColor(1,.86f,.4f));return Base+1;
}

bool UBattleReferenceWidget::CreateEditableBlueprint(){
#if WITH_EDITOR
    // Import the face first, then store a real composite-font asset so cooked builds do not need a local TTF path.
    auto Face=LoadObject<UFontFace>(nullptr,TEXT("/Game/UI/Reference/FF_ReferenceSerif.FF_ReferenceSerif"));
    if(!Face)return false;
    const FString FontName=TEXT("/Game/UI/Reference/F_ReferenceSerif");auto FontPackage=CreatePackage(*FontName);
    auto Serif=LoadObject<UFont>(nullptr,*(FontName+TEXT(".F_ReferenceSerif")));
    if(!Serif){Serif=NewObject<UFont>(FontPackage,TEXT("F_ReferenceSerif"),RF_Public|RF_Standalone);FAssetRegistryModule::AssetCreated(Serif);}
    Serif->FontCacheType=EFontCacheType::Runtime;auto& Typeface=Serif->GetMutableInternalCompositeFont().DefaultTypeface;
    Typeface.Fonts.Empty();FTypefaceEntry Entry;Entry.Name=TEXT("Regular");Entry.Font=FFontData(Face);Typeface.Fonts.Add(Entry);FontPackage->MarkPackageDirty();
    FSavePackageArgs FontSave;FontSave.TopLevelFlags=RF_Public|RF_Standalone;FontSave.SaveFlags=SAVE_NoError;
    if(!UPackage::SavePackage(FontPackage,Serif,*FPackageName::LongPackageNameToFilename(FontName,FPackageName::GetAssetPackageExtension()),FontSave))return false;
    const FString Name=TEXT("/Game/UI/Reference/WBP_BattleReference");auto Package=CreatePackage(*Name);
    auto Blueprint=LoadObject<UWidgetBlueprint>(nullptr,*(Name+TEXT(".WBP_BattleReference")));
    if(!Blueprint){Blueprint=Cast<UWidgetBlueprint>(FKismetEditorUtilities::CreateBlueprint(StaticClass(),Package,TEXT("WBP_BattleReference"),BPTYPE_Normal,UWidgetBlueprint::StaticClass(),UWidgetBlueprintGeneratedClass::StaticClass()));if(Blueprint)FAssetRegistryModule::AssetCreated(Blueprint);}
    if(!Blueprint)return false;
    Blueprint->WidgetTree=NewObject<UWidgetTree>(Blueprint,TEXT("WidgetTree"),RF_Transactional);BuildReferenceTree(Blueprint->WidgetTree);
    FBlueprintEditorUtils::MarkBlueprintAsStructurallyModified(Blueprint);FKismetEditorUtilities::CompileBlueprint(Blueprint);Package->MarkPackageDirty();
    if(Blueprint->Status==BS_Error)return false;
    FSavePackageArgs Save;Save.TopLevelFlags=RF_Public|RF_Standalone;Save.SaveFlags=SAVE_NoError;
    return UPackage::SavePackage(Package,Blueprint,*FPackageName::LongPackageNameToFilename(Name,FPackageName::GetAssetPackageExtension()),Save);
#else
    return false;
#endif
}
