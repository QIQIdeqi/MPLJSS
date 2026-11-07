#include "GameAudio.h"
#include "Components/AudioComponent.h"
#include "GameFramework/Actor.h"
#include "Kismet/GameplayStatics.h"
#include "Misc/CommandLine.h"
#include "Misc/Parse.h"
#include "Sound/SoundClass.h"
#include "Sound/SoundMix.h"

namespace {
USoundBase* Sound(FName Name) {
    static TMap<FName,TWeakObjectPtr<USoundBase>> Cache;
    if(auto* Existing=Cache.Find(Name)) if(Existing->IsValid()) return Existing->Get();
    const FString Key=Name.ToString();
    auto* Wave=LoadObject<USoundBase>(nullptr,*FString::Printf(TEXT("/Game/Art/Audio/%s.%s"),*Key,*Key));
    Cache.Add(Name,Wave);
    return Wave;
}

void SetLoop(AActor* Owner,FName Group,FName Track) {
    USoundBase* Wave=Track.IsNone()?nullptr:Sound(Track);
    if(!Track.IsNone() && !Wave) return;
    TInlineComponentArray<UAudioComponent*> Components(Owner);
    for(auto* Existing:Components) {
        if(!Existing->ComponentTags.Contains(Group)) continue;
        if(Existing->Sound==Wave && Existing->IsPlaying()) return;
        Existing->ComponentTags.Remove(Group);
        Existing->FadeOut(.55f,0.f);
    }
    if(!Wave) return;
    auto* Audio=NewObject<UAudioComponent>(Owner);
    Owner->AddInstanceComponent(Audio);
    Audio->ComponentTags.Add(Group);
    Audio->bAutoActivate=false;
    Audio->bAutoDestroy=true;
    Audio->bAllowSpatialization=false;
    Audio->bIsUISound=true;
    Audio->SetSound(Wave);
    Audio->RegisterComponent();
    Audio->FadeIn(.55f);
    UE_LOG(LogTemp,Display,TEXT("GAME_AUDIO_LOOP %s"),*Track.ToString());
}
}

void AlchemyGameAudio::ApplyVolume(UObject* Context,float Gain) {
    auto* Master=LoadObject<USoundClass>(nullptr,TEXT("/Game/Audio/SC_Master.SC_Master"));
    auto* Mix=LoadObject<USoundMix>(nullptr,TEXT("/Game/Audio/SM_Master.SM_Master"));
    if(!Master || !Mix) return;
    UGameplayStatics::SetBaseSoundMix(Context,Mix);
    UGameplayStatics::SetSoundMixClassOverride(Context,Mix,Master,FMath::Clamp(Gain,0.f,1.f),1.f,.12f,true);
}

void AlchemyGameAudio::SetMusic(AActor* Owner,FName Track) {
    SetLoop(Owner,TEXT("AlchemyMusic"),Track);
}

void AlchemyGameAudio::SetAmbience(AActor* Owner,FName Track) {
    SetLoop(Owner,TEXT("AlchemyAmbience"),Track);
}

void AlchemyGameAudio::Play(AActor* Owner,FName Cue,float Gain,float Pitch) {
    if(auto* Wave=Sound(FName(*(FString(TEXT("S_"))+Cue.ToString())))) {
        if(Cue==TEXT("UIConfirm")) UGameplayStatics::SpawnSound2D(Owner,Wave,Gain,Pitch,0.f,nullptr,true);
        else UGameplayStatics::PlaySound2D(Owner,Wave,Gain,Pitch);
        if(FParse::Param(FCommandLine::Get(),TEXT("GameAudioAudit")))
            UE_LOG(LogTemp,Display,TEXT("GAME_AUDIO_CUE %s"),*Cue.ToString());
    }
}
