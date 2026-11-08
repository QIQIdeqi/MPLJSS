#pragma once

#include "Kismet/BlueprintFunctionLibrary.h"
#include "AlchemyFurnaceFX.generated.h"

class UNiagaraComponent;
class UWidget;
class UWidgetTree;

UCLASS()
class ALCHEMYHD2D_API UAlchemyFurnaceFXLibrary : public UBlueprintFunctionLibrary
{
    GENERATED_BODY()

public:
    static UWidget* Create(UWidgetTree* Tree, FName Name=TEXT("FurnaceNiagara"));
    static UNiagaraComponent* GetComponent(const UWidget* Widget);
    static void SetPaused(UWidget* Widget, bool bPaused);
    static void Release(UWidget* Widget);

    UFUNCTION(BlueprintCallable, Category="Alchemy|Niagara UI")
    static bool BuildAssets();
};
