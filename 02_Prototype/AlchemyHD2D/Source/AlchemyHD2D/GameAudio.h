#pragma once

#include "CoreMinimal.h"

class AActor;
namespace AlchemyGameAudio {
    void ApplyVolume(UObject* Context,float Gain);
    void SetMusic(AActor* Owner,FName Track);
    void SetAmbience(AActor* Owner,FName Track);
    void Play(AActor* Owner,FName Cue,float Gain=1.f,float Pitch=1.f);
}
