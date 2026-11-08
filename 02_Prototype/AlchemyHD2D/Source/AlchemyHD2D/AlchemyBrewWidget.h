#pragma once

#include "Blueprint/UserWidget.h"
#include "Components/Button.h"
#include "AlchemyBrewWidget.generated.h"

class AAlchemyWorld;
class UCanvasPanel;
class UImage;
class UMaterialInstanceDynamic;
class UTextBlock;
class UTexture2D;
class UAlchemyBrewWidget;

UCLASS()
class UAlchemyBrewButton : public UButton {
    GENERATED_BODY()
public:
    UPROPERTY() TObjectPtr<UAlchemyBrewWidget> Owner;
    UPROPERTY() TObjectPtr<UTextBlock> Label;
    FString Action;
    UFUNCTION() void Invoke();
};

UCLASS()
class UAlchemyBrewControl : public UUserWidget {
    GENERATED_BODY()
public:
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Alchemy") FText Caption;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Alchemy") TObjectPtr<UTexture2D> Icon;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Alchemy") int32 CaptionSize=17;
    UPROPERTY(EditAnywhere, Category="Alchemy") FSlateBrush FocusBrush;
    UPROPERTY(BlueprintAssignable, Category="Alchemy") FOnButtonClickedEvent OnClicked;
protected:
    void NativePreConstruct() override;
    void NativeConstruct() override;
private:
    UFUNCTION() void ForwardClick();
};

UCLASS()
class UAlchemyBrewWidget : public UUserWidget {
    GENERATED_BODY()
public:
    void Setup(AAlchemyWorld* InWorld);
    void Invoke(const FString& Action);
    bool OwnsPanel() const;
    UPROPERTY(EditDefaultsOnly, Category="Alchemy|Animation") float FlightArcHeight=95.f;
    UFUNCTION(BlueprintCallable, Category="Alchemy|Editor")
    static bool BuildDesignerAssets();
protected:
    void NativeTick(const FGeometry& Geometry,float Dt) override;
    void NativeDestruct() override;
    FReply NativeOnPreviewMouseButtonDown(const FGeometry& Geometry,const FPointerEvent& Event) override;
    FReply NativeOnMouseButtonUp(const FGeometry& Geometry,const FPointerEvent& Event) override;
    void NativeOnDragDetected(const FGeometry& Geometry,const FPointerEvent& Event,UDragDropOperation*& Operation) override;
    bool NativeOnDrop(const FGeometry& Geometry,const FDragDropEvent& Event,UDragDropOperation* Operation) override;
private:
    UPROPERTY() TObjectPtr<AAlchemyWorld> World;
    UPROPERTY() TObjectPtr<UCanvasPanel> Board;
    UPROPERTY(Transient, meta=(BindWidgetAnimOptional)) TObjectPtr<class UWidgetAnimation> ResultReveal;
    UPROPERTY(Transient, meta=(BindWidgetAnimOptional)) TObjectPtr<class UWidgetAnimation> MaterialFlight;
    UPROPERTY() TObjectPtr<UWidget> Furnace;
    UPROPERTY() TObjectPtr<UImage> Flight;
    UPROPERTY() TObjectPtr<UMaterialInstanceDynamic> Heat;
    UPROPERTY() TObjectPtr<UMaterialInstanceDynamic> Flash;
    UPROPERTY() TMap<FName,TObjectPtr<UTexture2D>> Textures;
    UPROPERTY() TMap<FString,TObjectPtr<UAlchemyBrewButton>> Buttons;
    UPROPERTY() TMap<FName,TObjectPtr<UTextBlock>> Labels;
    UPROPERTY() TMap<FName,TObjectPtr<UImage>> Slots;
    UPROPERTY() TMap<FString,TObjectPtr<UAlchemyBrewControl>> Controls;
    TMap<FString,FSlateBrush> NormalBrushes;
    bool IsOver(const UWidget* Widget,const FVector2D& Screen) const;
    FString Display,DragSource;
    FVector2D DragStart;
    int32 FlightIndex=-1;
    bool FlightSupport=false;
    float FlightTime=1.f, RevealTime=1.f;
    UTexture2D* Texture(FName Name);
#if WITH_EDITOR
    TSubclassOf<UAlchemyBrewControl> ButtonClass,SlotClass;
    void BuildDesignerTree(class UWidgetTree* Tree);
    void AuthorView(const FString& View);
    void Place(UWidget* Child,float X,float Y,float W,float H);
    UImage* Image(FName Art,float X,float Y,float W,float H,bool bSlice=false);
    UTextBlock* Label(FName Name,const FString& Value,float X,float Y,float W,float H,int Size,bool Center=false);
    void Button(const FString& Id,const FString& Value,float X,float Y,float W,float H);
#endif
    void Build(const FString& View);
    void Refresh();
};
