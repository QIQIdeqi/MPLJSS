#include "AlchemyBrewWidget.h"
#include "AlchemyWorld.h"
#include "AlchemyFurnaceFX.h"
#include "Animation/WidgetAnimation.h"
#include "MovieScene.h"
#include "Tracks/MovieSceneFloatTrack.h"
#include "Sections/MovieSceneFloatSection.h"
#include "Blueprint/WidgetTree.h"
#include "Blueprint/DragDropOperation.h"
#include "Components/ButtonSlot.h"
#include "Framework/Application/SlateApplication.h"
#include "Components/CanvasPanel.h"
#include "Components/CanvasPanelSlot.h"
#include "Components/Image.h"
#include "Components/HorizontalBox.h"
#include "Components/HorizontalBoxSlot.h"
#include "Components/Overlay.h"
#include "Components/OverlaySlot.h"
#include "Components/ScaleBox.h"
#include "Components/SizeBox.h"
#include "Components/TextBlock.h"
#include "Components/WidgetSwitcher.h"
#include "Components/WidgetSwitcherSlot.h"
#include "Engine/Texture2D.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "NiagaraComponent.h"
#if WITH_EDITOR
#include "WidgetBlueprint.h"
#include "Engine/Font.h"
#include "Engine/FontFace.h"
#include "Blueprint/WidgetBlueprintGeneratedClass.h"
#include "Kismet2/KismetEditorUtilities.h"
#include "Kismet2/BlueprintEditorUtils.h"
#include "AssetRegistry/AssetRegistryModule.h"
#include "Misc/PackageName.h"
#include "UObject/SavePackage.h"
#endif
#include "Styling/CoreStyle.h"

namespace {
const FLinearColor Gold(.93f,.75f,.46f), Parchment(.93f,.86f,.73f);
const TCHAR* Names[]={TEXT("火粉"),TEXT("露水"),TEXT("魔法碎片")};
const FName Icons[]={TEXT("T_IconFirePowder"),TEXT("T_IconDew"),TEXT("T_IconMagicShard")};
constexpr float BagX=706, BagStride=162, BagWidth=154;
constexpr float MainY=189, SubY=321, BagHeight=63;

FSlateBrush ButtonBrush(UTexture2D* Texture) {
    FSlateBrush B;B.SetResourceObject(Texture);B.DrawAs=ESlateBrushDrawType::Box;
    B.Margin=FMargin(.14f,0,.14f,0);B.ImageSize=FVector2f(118,42);return B;
}
}

void UAlchemyBrewButton::Invoke() { if(Owner) Owner->Invoke(Action); }

void UAlchemyBrewControl::NativePreConstruct() {
    Super::NativePreConstruct();
    if(auto* Text=Cast<UTextBlock>(GetWidgetFromName(TEXT("CaptionText")))) {
        Text->SetText(Caption);
        FSlateFontInfo Font=Text->GetFont();
        Font.Size=CaptionSize;
        Text->SetFont(Font);
    }
    if(auto* Image=Cast<UImage>(GetWidgetFromName(TEXT("MaterialIcon")))) {
        if(Icon) Image->SetBrushFromTexture(Icon);
        Image->SetRenderOpacity(Icon?1.f:0.f);
        if(auto* IconBox=GetWidgetFromName(TEXT("ButtonIconSize")))
            IconBox->SetVisibility(Icon?ESlateVisibility::HitTestInvisible:ESlateVisibility::Collapsed);
    }
}

void UAlchemyBrewControl::NativeConstruct() {
    Super::NativeConstruct();
    if(auto* Button=Cast<UButton>(GetWidgetFromName(TEXT("ActionButton"))))
        Button->OnClicked.AddUniqueDynamic(this,&UAlchemyBrewControl::ForwardClick);
}

void UAlchemyBrewControl::ForwardClick() { OnClicked.Broadcast(); }

void UAlchemyBrewWidget::Setup(AAlchemyWorld* InWorld) {
    World=InWorld;
    Board=Cast<UCanvasPanel>(GetWidgetFromName(TEXT("BrewCanvas")));
    if(!Board)return;
    WidgetTree->ForEachWidget([this](UWidget* Widget) {
        const FString Name=Widget->GetName();
        if(auto* Control=Cast<UAlchemyBrewControl>(Widget)) {
            if(Name.StartsWith(TEXT("Btn_"))) {
                const FString Id=Name.Mid(4);
                auto* Btn=CastChecked<UAlchemyBrewButton>(Control->GetWidgetFromName(TEXT("ActionButton")));
                Btn->Owner=this;
                Btn->Action=Id;
                Btn->Label=CastChecked<UTextBlock>(Control->GetWidgetFromName(TEXT("CaptionText")));
                Btn->OnClicked.AddUniqueDynamic(Btn,&UAlchemyBrewButton::Invoke);
                NormalBrushes.Add(Id,Btn->GetStyle().Normal);
                Buttons.Add(Id,Btn);
                Controls.Add(Id,Control);
                if(Id.StartsWith(TEXT("bag")))Labels.Add(FName(*Id),Btn->Label);
            } else if(Name.StartsWith(TEXT("Slot"))) {
                Slots.Add(Widget->GetFName(),CastChecked<UImage>(Control->GetWidgetFromName(TEXT("MaterialIcon"))));
                Labels.Add(Widget->GetFName(),CastChecked<UTextBlock>(Control->GetWidgetFromName(TEXT("CaptionText"))));
            }
        } else if(auto* Label=Cast<UTextBlock>(Widget); Label && Name.StartsWith(TEXT("Data_"))) {
            Labels.Add(FName(*Name.Mid(5)),Label);
        }
    });
    Board->SetVisibility(ESlateVisibility::Collapsed);
    GetWidgetFromName(TEXT("BrewBackdrop"))->SetVisibility(ESlateVisibility::Collapsed);
    SetVisibility(ESlateVisibility::SelfHitTestInvisible);
    UE_LOG(LogTemp,Display,TEXT("ALCHEMY_WBP_RUNTIME class=%s buttons=%d slots=%d result_animation=%d flight_animation=%d"),
        *GetClass()->GetPathName(),Buttons.Num(),Slots.Num(),ResultReveal!=nullptr,MaterialFlight!=nullptr);
}

bool UAlchemyBrewWidget::OwnsPanel() const {
    return Board && World && !World->TutorialActive() &&
        (World->Panel==TEXT("alchemy") || (World->Panel==TEXT("result") && World->bV02Pending));
}

UTexture2D* UAlchemyBrewWidget::Texture(FName Name) {
    if(Name.IsNone()) return nullptr;
    if(auto* Found=Textures.Find(Name)) return *Found;
    const FString Path=FString::Printf(TEXT("/Game/UI/Alchemy/%s.%s"),*Name.ToString(),*Name.ToString());
    return Textures.Add(Name,LoadObject<UTexture2D>(nullptr,*Path));
}

#if WITH_EDITOR
void UAlchemyBrewWidget::BuildDesignerTree(UWidgetTree* Tree) {
    WidgetTree=Tree;
    auto* Scale=WidgetTree->ConstructWidget<UScaleBox>();
    Scale->SetStretch(EStretch::ScaleToFit);
    Scale->SetVisibility(ESlateVisibility::SelfHitTestInvisible);

    auto* Size=WidgetTree->ConstructWidget<USizeBox>();
    Size->SetWidthOverride(1280);Size->SetHeightOverride(720);
    Size->SetVisibility(ESlateVisibility::SelfHitTestInvisible);
    Board=WidgetTree->ConstructWidget<UCanvasPanel>(UCanvasPanel::StaticClass(),TEXT("BrewCanvas"));
    auto* Overlay=WidgetTree->ConstructWidget<UOverlay>();
    Overlay->SetVisibility(ESlateVisibility::SelfHitTestInvisible);
    auto* Backdrop=WidgetTree->ConstructWidget<UImage>(UImage::StaticClass(),TEXT("BrewBackdrop"));
    Backdrop->SetColorAndOpacity(FLinearColor(0,0,0,.72f));
    Backdrop->SetVisibility(ESlateVisibility::HitTestInvisible);
    WidgetTree->RootWidget=Overlay;
    for(UWidget* Layer : {static_cast<UWidget*>(Backdrop),static_cast<UWidget*>(Scale)}) {
        auto* Layout=Overlay->AddChildToOverlay(Layer);
        Layout->SetHorizontalAlignment(HAlign_Fill);Layout->SetVerticalAlignment(VAlign_Fill);
    }
    Scale->AddChild(Size);Size->AddChild(Board);
    auto* Root=Board.Get();
    auto* Pages=Tree->ConstructWidget<UWidgetSwitcher>(UWidgetSwitcher::StaticClass(),TEXT("BrewPages"));
    Pages->SetVisibility(ESlateVisibility::SelfHitTestInvisible);
    auto* PagesLayout=Root->AddChildToCanvas(Pages);
    PagesLayout->SetAnchors(FAnchors(0,0,1,1));
    PagesLayout->SetOffsets(FMargin(0));
    for(const TCHAR* View:{TEXT("alchemy"),TEXT("brewing"),TEXT("result")}) {
        const FName ViewName(*FString::Printf(TEXT("%sCanvas"),View));
        Board=Tree->ConstructWidget<UCanvasPanel>(UCanvasPanel::StaticClass(),ViewName);
        auto* Layout=CastChecked<UWidgetSwitcherSlot>(Pages->AddChild(Board));
        Layout->SetHorizontalAlignment(HAlign_Fill);Layout->SetVerticalAlignment(VAlign_Fill);
        AuthorView(View);
        Board->SetVisibility(FCString::Strcmp(View,TEXT("brewing"))==0?ESlateVisibility::SelfHitTestInvisible:ESlateVisibility::Visible);
    }
    Board=Root;
}

void UAlchemyBrewWidget::Place(UWidget* Child,float X,float Y,float W,float H) {
    auto* Layout=Board->AddChildToCanvas(Child);
    Layout->SetPosition({X,Y});Layout->SetSize({W,H});
}

UImage* UAlchemyBrewWidget::Image(FName Art,float X,float Y,float W,float H,bool bSlice) {
    auto* Img=WidgetTree->ConstructWidget<UImage>();
    FSlateBrush Brush;
    Brush.SetResourceObject(Texture(Art));
    if(bSlice) { Brush.DrawAs=ESlateBrushDrawType::Box;Brush.Margin=FMargin(.14f,.24f,.14f,.24f);Brush.ImageSize=FVector2f(175,90); }
    Img->SetBrush(Brush);
    Img->SetVisibility(ESlateVisibility::HitTestInvisible);
    Place(Img,X,Y,W,H);
    return Img;
}

UTextBlock* UAlchemyBrewWidget::Label(FName Name,const FString& Value,float X,float Y,float W,float H,int Size,bool Center) {
    auto* Item=WidgetTree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass(),Name.IsNone()?NAME_None:FName(*FString::Printf(TEXT("Data_%s"),*Name.ToString())));
    Item->SetText(FText::FromString(Value));Item->SetFont(FCoreStyle::GetDefaultFontStyle(TEXT("Regular"),Size));
    Item->SetColorAndOpacity(FSlateColor(Parchment));
    Item->SetShadowOffset({1,2});Item->SetShadowColorAndOpacity(FLinearColor::Black);
    if(Center)Item->SetJustification(ETextJustify::Center);
    Item->SetVisibility(ESlateVisibility::HitTestInvisible);
    Place(Item,X,Y,W,H);
    return Item;
}

void UAlchemyBrewWidget::Button(const FString& Id,const FString& Value,float X,float Y,float W,float H) {
    const FName Name(*FString::Printf(TEXT("Btn_%s"),*Id));
    auto* Control=CastChecked<UAlchemyBrewControl>(WidgetTree->ConstructWidget<UWidget>(ButtonClass.Get(),Name));
    Control->Caption=FText::FromString(Value);
    Control->FocusBrush=ButtonBrush(Texture(TEXT("T_ButtonFocus")));
    Control->CaptionSize=H<37?14:17;
    Place(Control,X,Y,W,H);
}

void UAlchemyBrewWidget::AuthorView(const FString& View) {
    if(View!=TEXT("brewing")) {
        Image(TEXT("T_PanelOrnate"),61,43,1158,626,true);
        Image(TEXT("T_TitlePlaque"),83,31,208,64);
        Label(NAME_None,View==TEXT("result")?TEXT("炼制结果"):TEXT("炼金"),83,View==TEXT("result")?47:43,208,41,View==TEXT("result")?23:29,true)->SetColorAndOpacity(FSlateColor(Gold));
    }
    if(View==TEXT("alchemy")) {
        Image(TEXT("T_PanelSecondary"),91,109,565,486,true);
        Image(TEXT("T_PanelSecondary"),680,109,507,486,true);
        Button(TEXT("close"),TEXT("返回  Esc"),1067,57,107,36);
        const TCHAR* Operations[]={TEXT("新制"),TEXT("同方强化"),TEXT("换主材"),TEXT("换辅材")};
        for(int I=0;I<4;++I) Button(FString::Printf(TEXT("brewop%d"),I),Operations[I],112+I*131,121,120,36);
        Label(NAME_None,TEXT("主材料"),119,173,124,28,18,true); Label(NAME_None,TEXT("副材料"),502,173,124,28,18,true);
        Image(TEXT("T_ArtCauldron"),228,327,292,246)->Rename(TEXT("DropCauldron"));
        Label(NAME_None,TEXT("＋"),349,244,46,39,27,true)->SetColorAndOpacity(FSlateColor(Gold));
        for(int I=0;I<3;++I) for(int Side=0;Side<2;++Side) {
            const int X=Side?535:134,Y=209+I*70;
            const FName Key(*FString::Printf(TEXT("Slot%d%d"),Side,I));
            auto* Control=CastChecked<UAlchemyBrewControl>(WidgetTree->ConstructWidget<UWidget>(SlotClass.Get(),Key));
            Control->Icon=Texture(Icons[I]);
            Control->CaptionSize=14;
            Place(Control,X,Y,55,55);
        }
        Button(TEXT("brewmainminus"),TEXT("-"),115,427,42,32);Button(TEXT("brewmainplus"),TEXT("+"),169,427,42,32);
        Button(TEXT("brewsupportminus"),TEXT("-"),511,427,42,32);Button(TEXT("brewsupportplus"),TEXT("+"),565,427,42,32);
        Button(TEXT("brewtargetprev"),TEXT("<"),117,557,42,30);Button(TEXT("brewtargetnext"),TEXT(">"),582,557,42,30);
        Label(TEXT("Target"),TEXT(""),162,568,414,23,16,true);
        Label(NAME_None,TEXT("主材料背包"),706,150,400,30,22);
        Label(NAME_None,TEXT("副材料背包"),706,282,400,30,22);
        for(int I=0;I<3;++I)for(int Side=0;Side<2;++Side) {
            const FString Key=FString::Printf(TEXT("%s%d"),Side?TEXT("bagsub"):TEXT("bagmain"),I);
            const float X=BagX+I*BagStride,Y=Side?SubY:MainY;
            Button(Key,Names[I],X,Y,BagWidth,BagHeight);
            auto* Control=CastChecked<UAlchemyBrewControl>(WidgetTree->FindWidget(FName(*FString::Printf(TEXT("Btn_%s"),*Key))));
            Control->Icon=Texture(Icons[I]);
            Control->CaptionSize=15;
        }
        Label(NAME_None,TEXT("同方强化"),706,407,300,30,21);
        Label(TEXT("Recipe"),TEXT(""),706,447,446,29,17);
        Button(TEXT("fill"),TEXT("填入原方"),705,485,149,40);
        Button(TEXT("brewconvert"),TEXT("虚空晶转换"),872,485,181,40);
        Button(TEXT("clear"),TEXT("清空材料"),698,603,212,45);
        Button(TEXT("brewstart"),TEXT("确认炼丹"),933,603,221,45);
        Label(TEXT("Hint"),TEXT(""),110,609,555,45,16);
        auto* FlightIcon=Image(Icons[0],0,0,42,42);
        FlightIcon->Rename(TEXT("FlightIcon"));
        FlightIcon->SetRenderOpacity(0);
    } else if(View==TEXT("brewing")) {
        Board->SetVisibility(ESlateVisibility::SelfHitTestInvisible);
        Image(TEXT("T_ArtCauldron"),1056,444,108,92);
        Label(TEXT("Progress"),TEXT(""),1005,540,210,32,17,true);
        auto* Host=WidgetTree->ConstructWidget<UOverlay>(UOverlay::StaticClass(),TEXT("FurnaceHost"));
        Host->SetVisibility(ESlateVisibility::HitTestInvisible);
        Place(Host,1000,264,220,200);
    } else {
        Image(TEXT("T_PanelSecondary"),116,198,493,348,true);Image(TEXT("T_PanelSecondary"),671,198,493,348,true);
        Label(NAME_None,TEXT("原有丹药"),140,220,443,38,23,true);
        Label(NAME_None,TEXT("本炉成品"),695,220,443,38,23,true);
        for(int I=0;I<2;++I) for(int Row=0;Row<6;++Row)
            Label(FName(*FString::Printf(TEXT("Result%d%d"),I,Row)),TEXT(""),(I?699:144),277+Row*40,440,34,Row==0?22:16,true);
        Label(NAME_None,TEXT("材料已消耗。保留旧丹也不会返还本炉材料。"),246,554,788,31,17,true);
        Button(TEXT("rejectresult"),TEXT("保留原有状态"),166,600,387,45);
        Button(TEXT("acceptresult"),TEXT("接受本炉成品"),725,600,387,45);
    }
    const auto Effect=[&](const TCHAR* Name,float X,float Y,float W,float H) {
        auto* ImageWidget=Image(NAME_None,X,Y,W,H);
        ImageWidget->Rename(Name);
        ImageWidget->SetRenderOpacity(0);
    };
    if(View==TEXT("alchemy"))Effect(TEXT("AlchemyFlash"),233,318,285,201);
    if(View==TEXT("brewing"))Effect(TEXT("FurnaceSwirl"),1043,392,134,132);
    if(View==TEXT("result"))Effect(TEXT("ResultFlash"),825,83,185,153);
}
#endif

bool UAlchemyBrewWidget::BuildDesignerAssets() {
#if WITH_EDITOR
    constexpr auto FontPath=TEXT("/Game/UI/Alchemy/F_AlchemyUI");
    auto* Font=FindObject<UFont>(nullptr,TEXT("/Game/UI/Alchemy/F_AlchemyUI.F_AlchemyUI"));
    if(!Font && FPackageName::DoesPackageExist(FontPath))
        Font=LoadObject<UFont>(nullptr,TEXT("/Game/UI/Alchemy/F_AlchemyUI.F_AlchemyUI"));
    if(!Font) {
        auto* Face=LoadObject<UFontFace>(nullptr,TEXT("/Game/UI/Alchemy/FF_AlchemyUI.FF_AlchemyUI"));
        if(!Face)return false;
        auto* Package=CreatePackage(FontPath);
        Font=NewObject<UFont>(Package,TEXT("F_AlchemyUI"),RF_Public|RF_Standalone);
        Font->FontCacheType=EFontCacheType::Runtime;
        FTypefaceEntry Entry;
        Entry.Name=TEXT("Regular");
        Entry.Font=FFontData(Face);
        Font->GetMutableInternalCompositeFont().DefaultTypeface.Fonts.Add(Entry);
        FAssetRegistryModule::AssetCreated(Font);
        FSavePackageArgs Save;
        Save.TopLevelFlags=RF_Public|RF_Standalone;
        if(!UPackage::SavePackage(Package,Font,*FPackageName::LongPackageNameToFilename(FontPath,FPackageName::GetAssetPackageExtension()),Save))
            return false;
    }
    auto* Author=NewObject<UAlchemyBrewWidget>();
    const auto Create=[Font](const TCHAR* Name,UClass* Parent,TFunctionRef<void(UWidgetBlueprint*)> Populate) -> UWidgetBlueprint* {
        const FString Path=FString(TEXT("/Game/UI/Alchemy/"))+Name;
        const bool bExisting=FPackageName::DoesPackageExist(Path);
        auto* Package=CreatePackage(*Path);
        auto* Blueprint=bExisting?LoadObject<UWidgetBlueprint>(nullptr,*(Path+TEXT(".")+Name)):
            Cast<UWidgetBlueprint>(FKismetEditorUtilities::CreateBlueprint(Parent,Package,FName(Name),
            BPTYPE_Normal,UWidgetBlueprint::StaticClass(),UWidgetBlueprintGeneratedClass::StaticClass()));
        if(!Blueprint)return nullptr;
        if(!bExisting)Populate(Blueprint);
        bool bNeedsSave=!bExisting;
        Blueprint->WidgetTree->ForEachWidget([&](UWidget* Widget) {
            if(auto* Control=Cast<UAlchemyBrewControl>(Widget)) {
                const FString Caption=Control->Caption.ToString();
                const TCHAR* Symbol=Caption==TEXT("−")?TEXT("-"):Caption==TEXT("‹")?TEXT("<"):Caption==TEXT("›")?TEXT(">"):nullptr;
                if(Symbol) {
                    Control->Caption=FText::FromString(Symbol);
                    bNeedsSave=true;
                }
            }
            if(auto* Text=Cast<UTextBlock>(Widget)) {
                FSlateFontInfo Info=Text->GetFont();
                if(!Info.FontObject) {
                    Info.FontObject=Font;
                    Info.CompositeFont.Reset();
                    Info.TypefaceFontName=TEXT("Regular");
                    Text->SetFont(Info);
                    bNeedsSave=true;
                }
            }
            if(!bExisting && !Blueprint->WidgetVariableNameToGuidMap.Contains(Widget->GetFName()))
                Blueprint->OnVariableAdded(Widget->GetFName());
        });
        if(!bNeedsSave)return Blueprint;
        FBlueprintEditorUtils::MarkBlueprintAsStructurallyModified(Blueprint);
        FKismetEditorUtilities::CompileBlueprint(Blueprint);
        if(Blueprint->Status==BS_Error)return nullptr;
        UE_LOG(LogTemp,Display,TEXT("ALCHEMY_WBP_SAVING %s"),Name);
        if(!bExisting)FAssetRegistryModule::AssetCreated(Blueprint);
        Package->MarkPackageDirty();
        FSavePackageArgs Save;
        Save.TopLevelFlags=RF_Public|RF_Standalone;
        return UPackage::SavePackage(Package,Blueprint,*FPackageName::LongPackageNameToFilename(Path,FPackageName::GetAssetPackageExtension()),Save)?Blueprint:nullptr;
    };
    const auto Control=[&](UWidgetBlueprint* Blueprint,bool bButton) {
        auto* Tree=Blueprint->WidgetTree.Get();
        auto* Caption=Tree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass(),TEXT("CaptionText"));
        Caption->SetFont(FCoreStyle::GetDefaultFontStyle(TEXT("Regular"),17));
        Caption->SetColorAndOpacity(FSlateColor(Parchment));
        Caption->SetVisibility(ESlateVisibility::HitTestInvisible);
        auto* Icon=Tree->ConstructWidget<UImage>(UImage::StaticClass(),TEXT("MaterialIcon"));
        Icon->SetVisibility(ESlateVisibility::HitTestInvisible);
        if(bButton) {
            auto* Button=Tree->ConstructWidget<UAlchemyBrewButton>(UAlchemyBrewButton::StaticClass(),TEXT("ActionButton"));
            FButtonStyle Style;
            Style.SetNormal(ButtonBrush(Author->Texture(TEXT("T_ButtonNormal"))))
                .SetHovered(ButtonBrush(Author->Texture(TEXT("T_ButtonHover"))))
                .SetPressed(ButtonBrush(Author->Texture(TEXT("T_ButtonPressed"))))
                .SetDisabled(ButtonBrush(Author->Texture(TEXT("T_ButtonDisabled"))));
            Button->SetStyle(Style);
            Tree->RootWidget=Button;
            auto* Row=Tree->ConstructWidget<UHorizontalBox>();
            auto* Layout=CastChecked<UButtonSlot>(Button->AddChild(Row));
            Layout->SetHorizontalAlignment(HAlign_Center);Layout->SetVerticalAlignment(VAlign_Center);
            auto* Size=Tree->ConstructWidget<USizeBox>(USizeBox::StaticClass(),TEXT("ButtonIconSize"));
            Size->SetWidthOverride(34);Size->SetHeightOverride(34);Size->AddChild(Icon);
            Row->AddChildToHorizontalBox(Size)->SetPadding(FMargin(0,0,5,0));
            Row->AddChildToHorizontalBox(Caption)->SetVerticalAlignment(VAlign_Center);
        } else {
            auto* Canvas=Tree->ConstructWidget<UCanvasPanel>();
            Tree->RootWidget=Canvas;
            auto* Frame=Tree->ConstructWidget<UImage>(UImage::StaticClass(),TEXT("SlotFrame"));
            Frame->SetBrushFromTexture(Author->Texture(TEXT("T_SkillSlot")));
            for(UImage* Item:{Frame,Icon}) {
                const float Inset=Item==Frame?0.f:7.f;
                auto* Layout=Canvas->AddChildToCanvas(Item);
                Layout->SetAnchors(FAnchors(0,0,1,1));
                Layout->SetOffsets(FMargin(Inset));
            }
            auto* Count=Canvas->AddChildToCanvas(Caption);
            Count->SetAnchors(FAnchors(1,1));
            Count->SetPosition({-10,-25});
            Count->SetAutoSize(true);
        }
    };
    auto* Button=Create(TEXT("WBP_AlchemyButton"),UAlchemyBrewControl::StaticClass(),[&](UWidgetBlueprint* BP){Control(BP,true);});
    auto* Slot=Create(TEXT("WBP_AlchemyMaterialSlot"),UAlchemyBrewControl::StaticClass(),[&](UWidgetBlueprint* BP){Control(BP,false);});
    if(!Button || !Slot)return false;
    Author->ButtonClass=Button->GeneratedClass;
    Author->SlotClass=Slot->GeneratedClass;
    auto* Main=Create(TEXT("WBP_Alchemy"),StaticClass(),[&](UWidgetBlueprint* BP) {
        Author->BuildDesignerTree(BP->WidgetTree);
        const auto Animate=[&](const TCHAR* Name,const TCHAR* Target,int32 Milliseconds,float Start,float End) {
            auto* Widget=BP->WidgetTree->FindWidget(FName(Target));
            auto* Animation=NewObject<UWidgetAnimation>(BP,FName(Name),RF_Transactional);
            Animation->SetDisplayLabel(Name);
            auto* Scene=NewObject<UMovieScene>(Animation,FName(Name),RF_Transactional);
            Animation->MovieScene=Scene;
            Scene->SetTickResolutionDirectly(FFrameRate(1000,1));
            Scene->SetDisplayRate(FFrameRate(60,1));
            Scene->SetPlaybackRange(FFrameNumber(0),Milliseconds);
            Scene->GetEditorData().WorkStart=0;
            Scene->GetEditorData().WorkEnd=Milliseconds/1000.;
            const FGuid Id=Scene->AddPossessable(Widget->GetName(),Widget->GetClass());
            FWidgetAnimationBinding Binding;
            Binding.AnimationGuid=Id;
            Binding.WidgetName=Widget->GetFName();
            Animation->AnimationBindings.Add(Binding);
            auto* Track=Scene->AddTrack<UMovieSceneFloatTrack>(Id);
            Track->SetPropertyNameAndPath(TEXT("RenderOpacity"),TEXT("RenderOpacity"));
            auto* Section=CastChecked<UMovieSceneFloatSection>(Track->CreateNewSection());
            Section->SetRange(TRange<FFrameNumber>(FFrameNumber(0),FFrameNumber(Milliseconds)));
            Section->GetChannel().AddCubicKey(FFrameNumber(0),Start);
            Section->GetChannel().AddCubicKey(FFrameNumber(Milliseconds-1),End);
            Track->AddSection(*Section);
            BP->Animations.Add(Animation);
            if(!BP->WidgetVariableNameToGuidMap.Contains(FName(Name)))BP->OnVariableAdded(FName(Name));
        };
        Animate(TEXT("ResultReveal"),TEXT("resultCanvas"),360,.15f,1.f);
        Animate(TEXT("MaterialFlight"),TEXT("FlightIcon"),340,1.f,0.f);
    });
    if(Main)UE_LOG(LogTemp,Display,TEXT("ALCHEMY_WBP_ASSETS_READY"));
    return Main!=nullptr;
#else
    return false;
#endif
}

void UAlchemyBrewWidget::Build(const FString& View) {
    if(ResultReveal)StopAnimation(ResultReveal);
    if(MaterialFlight)StopAnimation(MaterialFlight);
    if(Furnace) UAlchemyFurnaceFXLibrary::Release(Furnace);
    Furnace=nullptr; Flight=nullptr; Heat=nullptr;Flash=nullptr;
    FlightTime=1.f;
    FlightIndex=-1;
    DragSource.Reset();
    Board->SetVisibility(View.IsEmpty()?ESlateVisibility::Collapsed:ESlateVisibility::SelfHitTestInvisible);
    auto* Pages=CastChecked<UWidgetSwitcher>(GetWidgetFromName(TEXT("BrewPages")));
    Pages->SetActiveWidgetIndex(View==TEXT("result")?2:View==TEXT("brewing")?1:0);
    GetWidgetFromName(TEXT("resultCanvas"))->SetRenderOpacity(1.f);
    GetWidgetFromName(TEXT("BrewBackdrop"))->SetVisibility(
        View.IsEmpty() || View==TEXT("brewing")?ESlateVisibility::Collapsed:ESlateVisibility::HitTestInvisible);
    if(View.IsEmpty())return;
    if(View==TEXT("alchemy")) {
        Flight=Cast<UImage>(GetWidgetFromName(TEXT("FlightIcon")));
        Flight->SetRenderOpacity(0);
    } else if(View==TEXT("brewing")) {
        auto* Host=CastChecked<UOverlay>(GetWidgetFromName(TEXT("FurnaceHost")));
        if((Furnace=UAlchemyFurnaceFXLibrary::Create(WidgetTree))) {
            auto* Layout=Host->AddChildToOverlay(Furnace);
            Layout->SetHorizontalAlignment(HAlign_Fill);Layout->SetVerticalAlignment(VAlign_Fill);
        }
    } else {
        RevealTime=0;
        if(ResultReveal) PlayAnimation(ResultReveal);
    }
    const auto Effect=[&](const TCHAR* Name,float Mode,FLinearColor Tint) -> UMaterialInstanceDynamic* {
        auto* Item=CastChecked<UImage>(GetWidgetFromName(Name));
        auto* Mat=LoadObject<UMaterialInterface>(nullptr,TEXT("/Game/UI/Alchemy/M_AlchemyUIFX.M_AlchemyUIFX"));
        if(!Mat)return nullptr;
        auto* MID=UMaterialInstanceDynamic::Create(Mat,this);
        Item->SetBrushFromMaterial(MID);
        Item->SetRenderOpacity(1.f);
        MID->SetScalarParameterValue(TEXT("EffectMode"),Mode);
        MID->SetScalarParameterValue(TEXT("Strength"),0);
        MID->SetVectorParameterValue(TEXT("Tint"),Tint);
        return MID;
    };
    if(View==TEXT("alchemy"))Flash=Effect(TEXT("AlchemyFlash"),1,Gold);
    if(View==TEXT("brewing"))Heat=Effect(TEXT("FurnaceSwirl"),2,FLinearColor(.64f,.35f,1));
    if(View==TEXT("result"))Flash=Effect(TEXT("ResultFlash"),1,Gold);
    Refresh();
    const TCHAR* Focus=View==TEXT("result")?TEXT("acceptresult"):TEXT("close");
    if(View!=TEXT("brewing")) if(auto* Btn=Buttons.Find(Focus))(*Btn)->SetUserFocus(GetOwningPlayer());
}

void UAlchemyBrewWidget::Refresh() {
    const auto Set=[&](FName Key,const FString& Value) {
        if(auto* T=Labels.Find(Key);T && (*T)->GetText().ToString()!=Value)(*T)->SetText(FText::FromString(Value));
    };
    const auto Enabled=[&](const FString& Key,bool b){Buttons[Key]->SetIsEnabled(b);};
    if(Display==TEXT("alchemy")) {
        const auto* W=World.Get();const int Op=W->BrewOperation;
        const bool HasTarget=W->BrewTarget>0 && W->PillStates.IsValidIndex(W->BrewTarget);
        for(int I=0;I<4;++I) Buttons[FString::Printf(TEXT("brewop%d"),I)]->SetColorAndOpacity(I==Op?Gold:FLinearColor::White);
        for(int Side=0;Side<2;++Side)for(int I=0;I<3;++I) {
            const FString Id=FString::Printf(TEXT("%s%d"),Side?TEXT("bagsub"):TEXT("bagmain"),I);
            const FName Key(*FString::Printf(TEXT("Slot%d%d"),Side,I));
            const int Choice=Side?W->BrewSupport:(Op==3&&HasTarget?W->PillStates[W->BrewTarget].Main:W->BrewMain);
            const int Count=Side?W->BrewSupportCount:(Op==3&&HasTarget?1:W->BrewMainCount);
            const bool Filled=I==Choice && Count>0;
            Slots[Key]->SetRenderOpacity(Filled?1.f:0.f);
            Set(Key,Filled?FString::Printf(TEXT("×%d"),Count):FString());
            Enabled(Id,W->Inventory[I]>0 && (Side?(Op==0||Op==3):(Op==0||Op==2)));
            Set(FName(*Id),FString::Printf(TEXT("%s  %d"),Names[I],W->Inventory[I]));
        }
        Enabled(TEXT("brewmainplus"),(Op==0||Op==2)&&W->BrewMain>=0&&W->BrewMainCount<3);
        Enabled(TEXT("brewmainminus"),(Op==0||Op==2)&&W->BrewMainCount>1);
        Enabled(TEXT("brewsupportplus"),(Op==0||Op==3)&&W->BrewSupport>=0&&W->BrewSupportCount<3&&!W->bBrewConvertTrait);
        Enabled(TEXT("brewsupportminus"),(Op==0||Op==3)&&W->BrewSupportCount>0);
        Enabled(TEXT("brewconvert"),(Op==0||Op==3)&&W->BrewSupportCount==1&&(W->Inventory[4]>0||W->bBrewConvertTrait));
        Buttons[TEXT("brewconvert")]->SetColorAndOpacity(W->bBrewConvertTrait?Gold:FLinearColor::White);
        const auto Valid=[&](int32 I){return I>0&&W->PillStates.IsValidIndex(I)&&W->PillStates[I].Main>=0;};
        const bool Any=W->Equipped.ContainsByPredicate(Valid)||W->Bag.ContainsByPredicate(Valid);
        Enabled(TEXT("brewtargetprev"),Any);Enabled(TEXT("brewtargetnext"),Any);Enabled(TEXT("fill"),Any);
        const FString Target=HasTarget?W->SkillName(W->BrewTarget):TEXT("未选丹药");
        Set(TEXT("Target"),Op==0?TEXT("选材后开始炼制"):Target);
        Set(TEXT("Recipe"),HasTarget?Target:Any?TEXT("用左右箭头选择携带的丹药"):TEXT("暂无可强化的丹药"));
        FString Reason;const bool Can=W->CanStartBrew(Reason);
        Enabled(TEXT("brewstart"),Can);
        const auto Caption=FText::FromString(W->bBrewConfirmPending?TEXT("再次确认炼丹"):TEXT("确认炼丹"));
        if(!Buttons[TEXT("brewstart")]->Label->GetText().EqualTo(Caption))Buttons[TEXT("brewstart")]->Label->SetText(Caption);
        Set(TEXT("Hint"),W->bBrewConfirmPending?TEXT("再次确认将消耗已选材料"):Can?TEXT("点击或拖动材料投料"):Reason);
    } else if(Display==TEXT("result")) {
        const TCHAR* Quality[]={TEXT("粗制"),TEXT("稳定"),TEXT("精良")};
        const TCHAR* Traits[]={TEXT("强击"),TEXT("延伸"),TEXT("迅捷")};
        const int Old=World->PendingOldSkill,New=World->PendingResultSkill;
        const FAlchemySkillStats Stats[]={Old>=0?World->CurrentSkillStats(Old):FAlchemySkillStats(),World->PendingBrewStats()};
        for(int I=0;I<2;++I) {
            const auto& S=Stats[I];
            const auto Row=[&](int N,const FString& Value){Set(FName(*FString::Printf(TEXT("Result%d%d"),I,N)),Value);};
            Row(0,S.bValid?World->SkillName(I?New:Old):TEXT("无"));
            if(!S.bValid) {
                for(int N=1;N<6;++N)Row(N,FString());
                continue;
            }
            Row(1,FString::Printf(TEXT("成长 Lv.%d  ·  品质 %s"),S.Level,Quality[FMath::Clamp(S.Pill.Quality,0,2)]));
            Row(2,FString::Printf(TEXT("单次非暴击 %.0f  ·  冷却 %.2f 秒"),S.Damage,S.Cooldown));
            Row(3,FString::Printf(TEXT("作用距离 %.1f 米  ·  范围 %.1f 米"),S.Range/100,S.Radius/100));
            Row(4,S.Pill.Trait<0?TEXT("无词条"):FString::Printf(TEXT("词条 %s  Lv.%d"),Traits[FMath::Clamp(S.Pill.Trait,0,2)],S.Pill.TraitLevel));
            Row(5,S.Slow>0?FString::Printf(TEXT("减速 %.0f%%  ·  %.1f 秒"),(1-S.Factor)*100,S.Slow):TEXT("无减速"));
        }
    } else if(Display==TEXT("brewing")) {
        const float Progress=FMath::Clamp(World->BrewProgress/FMath::Max(.01f,World->BrewDuration),0.f,1.f);
        Set(TEXT("Progress"),FString::Printf(TEXT("炼制中  %d%%"),FMath::RoundToInt(100*Progress)));
        if(Heat) {
            Heat->SetScalarParameterValue(TEXT("Progress"),Progress);
            Heat->SetScalarParameterValue(TEXT("Strength"),.65f+Progress*.55f);
        }
        UAlchemyFurnaceFXLibrary::SetPaused(Furnace,World->BrewCommittedMode==1 && FVector::Dist2D(World->PlayerPos,World->BrewOrigin)>120.f);
    }
}

void UAlchemyBrewWidget::Invoke(const FString& Id) {
    if(!OwnsPanel())return;
    if(Id==TEXT("fill")) {
        if(World->BrewTarget<0)World->Action(TEXT("brewtargetnext"));
        if(World->BrewTarget>0)World->Action(FString::Printf(TEXT("fillpill%d"),World->BrewTarget));
    } else if(Id==TEXT("brewsupportminus") && World->BrewSupportCount==1)World->Action(TEXT("brewsnone"));
    else {
        const bool Material=Id.StartsWith(TEXT("bagmain")) || Id.StartsWith(TEXT("bagsub"));
        const int OldMain=World->BrewMain,OldSub=World->BrewSupport;
        const int OldMainCount=World->BrewMainCount,OldSubCount=World->BrewSupportCount;
        World->Action(Id);
        if(Material && (OldMain!=World->BrewMain || OldSub!=World->BrewSupport || OldMainCount!=World->BrewMainCount || OldSubCount!=World->BrewSupportCount)) {
            FlightSupport=Id.StartsWith(TEXT("bagsub"));
            FlightIndex=FlightSupport?World->BrewSupport:World->BrewMain;FlightTime=0;
            if(Flight && FlightIndex>=0) {
                Flight->SetBrushFromTexture(Texture(Icons[FlightIndex]));
                if(MaterialFlight)PlayAnimation(MaterialFlight);
            }
        }
    }
    Refresh();
}

FReply UAlchemyBrewWidget::NativeOnPreviewMouseButtonDown(const FGeometry& Geometry,const FPointerEvent& Event) {
    if(Display==TEXT("alchemy") && Event.GetEffectingButton()==EKeys::LeftMouseButton) {
        DragStart=Board->GetCachedGeometry().AbsoluteToLocal(Event.GetScreenSpacePosition());
        DragSource.Reset();
        for(int Side=0;Side<2;++Side) for(int I=0;I<3;++I) {
            const FString Key=FString::Printf(TEXT("%s%d"),Side?TEXT("bagsub"):TEXT("bagmain"),I);
            if(!IsOver(Controls[Key],Event.GetScreenSpacePosition()))continue;
            if(!Buttons[Key]->GetIsEnabled())break;
            DragSource=Key;
            return FReply::Handled().DetectDrag(TakeWidget(),EKeys::LeftMouseButton).CaptureMouse(TakeWidget());
        }
    }
    return Super::NativeOnPreviewMouseButtonDown(Geometry,Event);
}

void UAlchemyBrewWidget::NativeOnDragDetected(const FGeometry&,const FPointerEvent&,UDragDropOperation*& Operation) {
    if(DragSource.IsEmpty())return;
    Operation=NewObject<UDragDropOperation>(this);Operation->Tag=DragSource;
    auto* Ghost=NewObject<UImage>(Operation);
    const int I=FCString::Atoi(*DragSource.Right(1));Ghost->SetBrushFromTexture(Texture(Icons[I]));
    auto* Box=NewObject<USizeBox>(Operation);Box->SetWidthOverride(44);Box->SetHeightOverride(44);Box->AddChild(Ghost);
    Operation->DefaultDragVisual=Box;Operation->Pivot=EDragPivot::CenterCenter;
    DragSource.Reset();
}

FReply UAlchemyBrewWidget::NativeOnMouseButtonUp(const FGeometry& Geometry,const FPointerEvent& Event) {
    if(!DragSource.IsEmpty() && Event.GetEffectingButton()==EKeys::LeftMouseButton) {
        const FString Key=DragSource;DragSource.Reset();
        const FVector2D End=Board->GetCachedGeometry().AbsoluteToLocal(Event.GetScreenSpacePosition());
        if(FVector2D::Distance(End,DragStart)<9.f)Invoke(Key);
        return FReply::Handled().ReleaseMouseCapture();
    }
    return Super::NativeOnMouseButtonUp(Geometry,Event);
}

bool UAlchemyBrewWidget::NativeOnDrop(const FGeometry&,const FDragDropEvent& Event,UDragDropOperation* Operation) {
    if(Display!=TEXT("alchemy") || !Operation || Operation->GetOuter()!=this)return false;
    const auto Screen=Event.GetScreenSpacePosition();
    const int Side=Operation->Tag.StartsWith(TEXT("bagsub"))?1:0;
    bool Valid=IsOver(GetWidgetFromName(TEXT("DropCauldron")),Screen);
    for(int I=0;I<3 && !Valid;++I)
        Valid=IsOver(GetWidgetFromName(FName(*FString::Printf(TEXT("Slot%d%d"),Side,I))),Screen);
    if(!Valid)return false;
    Invoke(Operation->Tag);return true;
}

bool UAlchemyBrewWidget::IsOver(const UWidget* Widget,const FVector2D& Screen) const {
    return Widget && Widget->GetCachedGeometry().IsUnderLocation(Screen);
}

void UAlchemyBrewWidget::NativeTick(const FGeometry& Geometry,float Dt) {
    Super::NativeTick(Geometry,Dt);
    if(!IsValid(World) || !Board)return;
    const FString View=OwnsPanel()?World->Panel:World->bBrewActive&&!World->TutorialActive()?TEXT("brewing"):TEXT("");
    if(Display!=View){Display=View;Build(View);}
    if(View==TEXT("brewing")) Refresh();
    for(const auto& Item:Buttons) {
        auto* Btn=Item.Value.Get();
        const auto& Focus=Controls[Item.Key]->FocusBrush;
        const auto& Brush=Btn->HasAnyUserFocus() && Focus.GetResourceObject()?Focus:NormalBrushes[Item.Key];
        if(Btn->GetStyle().Normal!=Brush) {
            FButtonStyle Style=Btn->GetStyle();
            Style.SetNormal(Brush);
            Btn->SetStyle(Style);
        }
    }
    const float FlightDuration=MaterialFlight?FMath::Max(.01f,MaterialFlight->GetEndTime()-MaterialFlight->GetStartTime()):.34f;
    if(Flight && FlightIndex>=0 && FlightTime<FlightDuration) {
        FlightTime+=Dt;
        const float T=FMath::Clamp(FlightTime/FlightDuration,0.f,1.f);
        const FString Source=FString::Printf(TEXT("%s%d"),FlightSupport?TEXT("bagsub"):TEXT("bagmain"),FlightIndex);
        const auto Center=[this](UWidget* Widget) {
            const auto& Geo=Widget->GetCachedGeometry();
            return Board->GetCachedGeometry().AbsoluteToLocal(Geo.LocalToAbsolute(Geo.GetLocalSize()*.5));
        };
        const FVector2D A=Center(Controls[Source]),B=Center(GetWidgetFromName(TEXT("DropCauldron")));
        const auto* FlightLayout=CastChecked<UCanvasPanelSlot>(Flight->Slot);
        FVector2D P=FMath::Lerp(A,B,T)-FlightLayout->GetSize()*.5-FlightLayout->GetPosition();
        P.Y-=FMath::Sin(T*PI)*FlightArcHeight;
        Flight->SetRenderTranslation(P);
        if(!MaterialFlight)Flight->SetRenderOpacity(1-T*T);
        if(Flash)Flash->SetScalarParameterValue(TEXT("Strength"),T*T*(1-T)*5);
    }
    if(Display==TEXT("result") && RevealTime<.45f) {
        RevealTime+=Dt;const float T=FMath::Clamp(RevealTime/.45f,0.f,1.f);
        if(Flash) {Flash->SetScalarParameterValue(TEXT("Progress"),T);Flash->SetScalarParameterValue(TEXT("Strength"),FMath::Sin(T*PI));}
        if(auto* B=Buttons.Find(TEXT("acceptresult"))) (*B)->SetRenderScale(FVector2D(.96f+.04f*T));
    }
    if(!DragSource.IsEmpty() && !FSlateApplication::Get().GetPressedMouseButtons().Contains(EKeys::LeftMouseButton)) {
        const auto Key=MoveTemp(DragSource);DragSource.Reset();
        const FVector2D End=Board->GetCachedGeometry().AbsoluteToLocal(FSlateApplication::Get().GetCursorPos());
        if(FVector2D::Distance(End,DragStart)<9.f)Invoke(Key);
    }
}

void UAlchemyBrewWidget::NativeDestruct() {
    if(Furnace) UAlchemyFurnaceFXLibrary::Release(Furnace);
    Super::NativeDestruct();
}
