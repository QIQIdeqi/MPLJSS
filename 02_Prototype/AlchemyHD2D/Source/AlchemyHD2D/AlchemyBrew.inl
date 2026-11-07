// V0.2 playable brewing slice. Candidate pools and timings are prototype tuning,
// kept separate from the confirmed material-role rules in the combat document.
namespace AlchemyBrewPrototype {
    constexpr int32 FragmentThreshold=3;
    constexpr int32 Pool[3][5]={{1,6,10,11,12},{2,13,14,15,21},{3,16,17,18,23}};
}

void AAlchemyWorld::SpendRunMaterial(int32 Kind,int32 Count) {
    check(Inventory.IsValidIndex(Kind) && Count>=0 && Inventory[Kind]>=Count);
    if(Kind<3) BrewOnlyStock[Kind]-=FMath::Min(BrewOnlyStock[Kind],Count);
    Inventory[Kind]-=Count;
}

void AAlchemyWorld::GrantFragment(int32 Index,FVector Position) {
    if(Index<0 || Index>=3) return;
    // Older capture checks still exercise collection of physical material drops.
    if((bSmoke || bCapture) && !FParse::Param(FCommandLine::Get(),TEXT("BrewV02Test"))) {
        Drop(Position,Index);
        return;
    }
    FragmentCount[Index]++;
    if(FragmentCount[Index]<AlchemyBrewPrototype::FragmentThreshold) {PlayCue(TEXT("Fragment"));return;}
    if(Inventory[Index]>=10) {FragmentCount[Index]=AlchemyBrewPrototype::FragmentThreshold-1;return;}
    FragmentCount[Index]=0;
    Inventory[Index]++;
    PlayCue(TEXT("Fragment"));
    if(Progress && !Progress->Materials.Contains(Index)) {Progress->Materials.Add(Index);SaveProgress();}
    Message(FString::Printf(TEXT("%s碎片归集为材料"),MaterialNames[Index]));
}

void AAlchemyWorld::TryGrantNormalFragment(FVector Position) {
    if(MaterialRandom.FRand()>=MaterialDropChance()) return;
    const float Roll=MaterialRandom.FRand();
    GrantFragment(Roll<.4f?0:Roll<.75f?1:2,Position);
}

void AAlchemyWorld::BuildBrewBodyOptions(int32 Main,int32 MainCount,int32 ExcludedSkill,TArray<int32>& Candidates,TArray<float>& Weights) const {
    Candidates.Empty();Weights.Empty();
    if(Main<0 || Main>=3 || MainCount<1 || MainCount>3) return;
    for(int32 I=0;I<5;I++) {
        const int32 Skill=AlchemyBrewPrototype::Pool[Main][I];
        if(!RuntimeSkills.IsValidIndex(Skill) || !Levels.IsValidIndex(Skill) || Levels[Skill]>0 || Skill==ExcludedSkill) continue;
        Candidates.Add(Skill);
        Weights.Add(float(6-I+(MainCount-1)*I));
    }
}

void AAlchemyWorld::BuildBrewTraitWeights(int32 Support,int32 SupportCount,float OutWeights[3]) const {
    OutWeights[0]=OutWeights[1]=OutWeights[2]=0;
    if(Support<0 || Support>=3 || SupportCount<1 || SupportCount>3) return;
    OutWeights[0]=OutWeights[1]=OutWeights[2]=20;
    OutWeights[Support]+=40+15*(SupportCount-1);
}

void AAlchemyWorld::BuildBrewCost(int32 OutCost[6]) const {
    for(int32 I=0;I<6;I++) OutCost[I]=0;
    if(BrewOperation!=3 && BrewMain>=0 && BrewMain<3) OutCost[BrewMain]+=FMath::Max(0,BrewMainCount);
    if(BrewSupportCount>0 && BrewSupport>=0 && BrewSupport<3) OutCost[BrewSupport]+=BrewSupportCount;
    if(bBrewConvertTrait) OutCost[4]=1;
}

bool AAlchemyWorld::CanStartBrew(FString& Reason) const {
    Reason.Empty();
    if(!bCombat || bRunEnded) {Reason=TEXT("仅能在战斗中炼制");return false;}
    if(TutorialActive()) {Reason=TEXT("先完成首次炼金教学");return false;}
    if(bBrewActive || bV02Pending || PendingResultSkill>=0) {Reason=TEXT("请先完成或处理当前丹药");return false;}
    if(BrewOperation<0 || BrewOperation>3) {Reason=TEXT("请选择炼制方式");return false;}
    if(BrewOperation!=0) {
        if(BrewTarget<=0 || !Levels.IsValidIndex(BrewTarget) || Levels[BrewTarget]<=0 ||
           !PillStates.IsValidIndex(BrewTarget) || PillStates[BrewTarget].Main<0 ||
           (!Equipped.Contains(BrewTarget) && !Bag.Contains(BrewTarget))) {
            Reason=TEXT("请选择已拥有的丹药技能");return false;
        }
    }
    if(BrewOperation!=3 && (BrewMain<0 || BrewMain>=3 || BrewMainCount<1 || BrewMainCount>3)) {
        Reason=TEXT("主材需投入1至3份");return false;
    }
    if(BrewSupportCount<0 || BrewSupportCount>3 ||
       (BrewSupportCount>0 && (BrewSupport<0 || BrewSupport>=3))) {
        Reason=TEXT("辅材配置无效");return false;
    }
    if(BrewOperation==3 && BrewSupportCount==0) {Reason=TEXT("换辅材至少投入1份辅材");return false;}
    if((BrewOperation==1 || BrewOperation==2) && BrewSupportCount>0) {
        Reason=TEXT("本轮强化／换主材不消耗辅材");return false;
    }
    if(bBrewConvertTrait && ((BrewOperation!=0 && BrewOperation!=3) || BrewSupportCount==0 || BrewSupport<0)) {
        Reason=TEXT("虚空晶转换只用于新制或换辅材，须先选辅材");return false;
    }
    if(bBrewConvertTrait && BrewSupportCount>1) {
        Reason=TEXT("虚空晶确定转换只需1份辅材，请先减料");return false;
    }
    if(BrewOperation==1 && BrewMain!=PillStates[BrewTarget].Main) {
        Reason=TEXT("同方强化需要原丹药的主材");return false;
    }
    if(BrewOperation==1 && BrewMainCount!=1) {Reason=TEXT("首测同方强化固定消耗1份主材");return false;}
    if(BrewOperation==1 && Levels[BrewTarget]>=5) {Reason=TEXT("首测强化等级上限为5");return false;}
    if(BrewOperation==2 && BrewMain==PillStates[BrewTarget].Main) {
        Reason=TEXT("换主材请选择不同的主材");return false;
    }
    if(BrewOperation==0 && Equipped.Num()>=6 && Bag.Num()>=6) {
        Reason=TEXT("首测丹药容量已满");return false;
    }
    int32 Cost[6];BuildBrewCost(Cost);
    if(Cost[4]>Inventory[4]) {Reason=TEXT("确定转换需要1份虚空晶");return false;}
    for(int32 I=0;I<3;I++) if(Cost[I]>Inventory[I]) {
        Reason=FString::Printf(TEXT("%s不足：需要%d，持有%d"),MaterialNames[I],Cost[I],Inventory[I]);return false;
    }
    if(BrewOperation==0 || BrewOperation==2) {
        TArray<int32> Candidates;TArray<float> Weights;
        BuildBrewBodyOptions(BrewMain,BrewMainCount,BrewOperation==2?BrewTarget:-1,Candidates,Weights);
        if(Candidates.IsEmpty()) {Reason=TEXT("该主材没有可接收的新本体，不扣料");return false;}
        if(Candidates.Num()==1 && BrewMainCount>1) {
            Reason=TEXT("仅剩1种本体候选，多投主材不会改变结果，请减至1份");return false;
        }
    }
    return true;
}

bool AAlchemyWorld::BeginBrew() {
    FString Reason;
    if(!CanStartBrew(Reason)) {Message(Reason);return false;}
    int32 Cost[6];BuildBrewCost(Cost);
    for(int32 I=0;I<6;I++) SpendRunMaterial(I,Cost[I]);
    BrewCommittedMode=BrewMode;
    BrewCommittedOperation=BrewOperation;
    BrewCommittedTarget=BrewOperation==0?-1:BrewTarget;
    BrewCommittedMain=BrewOperation==3?PillStates[BrewTarget].Main:BrewMain;
    BrewCommittedMainCount=BrewOperation==3?0:BrewMainCount;
    BrewCommittedSupport=BrewSupportCount>0?BrewSupport:-1;
    BrewCommittedSupportCount=BrewSupportCount;
    bBrewCommittedConvertTrait=bBrewConvertTrait;
    BrewOrigin=PlayerPos;
    BrewProgress=0;
    BrewDuration=BrewMode==1?1.2f:2.5f;
    bBrewActive=true;
    CraftCount++;
    Panel.Empty();
    PlayCue(TEXT("BrewStart"));
    Message(BrewMode==1?TEXT("驻留坩埚起炼：留在原地完成炼制"):TEXT("随身试剂起炼：可边移动边炼制"));
    return true;
}

void AAlchemyWorld::UpdateBrew(float Delta) {
    if(!bBrewActive || Delta<=0) return;
    if(BrewCommittedMode==1 && FVector::Dist2D(PlayerPos,BrewOrigin)>120.f) return;
    BrewProgress=FMath::Min(BrewDuration,BrewProgress+Delta);
    if(BrewProgress>=BrewDuration) CompleteBrew();
}

void AAlchemyWorld::CompleteBrew() {
    if(!bBrewActive || bV02Pending) return;
    // Clear the active flag before rolling, so a duplicate completion event cannot pay twice.
    bBrewActive=false;
    const int32 Operation=BrewCommittedOperation;
    const int32 Old=BrewCommittedTarget;
    int32 NewSkill=Old;
    if(Operation==0 || Operation==2) {
        TArray<int32> Candidates;
        TArray<float> Weights;
        BuildBrewBodyOptions(BrewCommittedMain,BrewCommittedMainCount,Old,Candidates,Weights);
        if(Candidates.IsEmpty()) {Message(TEXT("炼制候选失效，原丹药保留"));return;}
        float Sum=0;for(float Weight:Weights) Sum+=Weight;
        float Roll=BrewRandom.FRand()*Sum;NewSkill=Candidates.Last();
        for(int32 I=0;I<Candidates.Num();I++) {Roll-=Weights[I];if(Roll<0){NewSkill=Candidates[I];break;}}
    }
    int32 Trait=Old>=0?PillStates[Old].Trait:-1;
    int32 TraitLevel=Old>=0?PillStates[Old].TraitLevel:0;
    if(Operation==0 || Operation==3) {
        Trait=-1;TraitLevel=0;
        if(BrewCommittedSupport>=0) {
            if(bBrewCommittedConvertTrait) Trait=BrewCommittedSupport;
            else {
                float Weights[3];
                BuildBrewTraitWeights(BrewCommittedSupport,BrewCommittedSupportCount,Weights);
                float Sum=Weights[0]+Weights[1]+Weights[2],Roll=BrewRandom.FRand()*Sum;
                Trait=2;
                for(int32 I=0;I<3;I++) {Roll-=Weights[I];if(Roll<0){Trait=I;break;}}
            }
            TraitLevel=1; // all available normal materials are grade one in this slice
        }
    }
    PendingResultSkill=NewSkill;
    PendingOldSkill=Old;
    PendingTrait=Trait;
    PendingTraitLevel=TraitLevel;
    PendingMain=BrewCommittedMain;
    PendingBrewOperation=Operation;
    bPendingTraitConverted=bBrewCommittedConvertTrait;
    PendingQuality=Old>=0?PillStates[Old].Quality:0;
    if(Operation==0 || Operation==1) {
        PendingQuality=FMath::Max(PendingQuality,BrewCommittedMode==1?1:0);
        if(BrewRandom.FRand()<.25f) PendingQuality=FMath::Min(2,PendingQuality+1);
    }
    bV02Pending=true;
    Panel=TEXT("result");
    PlayCue(TEXT("BrewDone"));
    Message(TEXT("炼制完成：比较新旧丹药后决定是否接收"));
}

void AAlchemyWorld::RejectPendingResult() {
    if(!bV02Pending || PendingResultSkill<0) return;
    const bool HadOldPill=PendingOldSkill>=0;
    bV02Pending=false;PendingResultSkill=-1;PendingOldSkill=-1;
    bPendingTraitConverted=false;
    PendingBrewOperation=-1;PendingTrait=-1;PendingMain=-1;
    Panel.Empty();
    Message(HadOldPill?TEXT("保留旧丹；本炉材料已消耗"):TEXT("放弃成品；本炉材料已消耗"));
}

void AAlchemyWorld::AcceptBrewResult() {
    if(!bV02Pending || !Levels.IsValidIndex(PendingResultSkill) ||
       !PillStates.IsValidIndex(PendingResultSkill)) return;
    const int32 NewSkill=PendingResultSkill;
    const int32 Old=PendingOldSkill;
    const int32 Operation=PendingBrewOperation;
    FAlchemyPillState NewState;
    NewState.Main=PendingMain;
    NewState.Trait=PendingTrait;
    NewState.TraitLevel=PendingTraitLevel;
    NewState.Quality=PendingQuality;
    if(Operation==0) {
        if(Levels[NewSkill]>0 || (Equipped.Num()>=6 && Bag.Num()>=6)) {Message(TEXT("丹药容量或候选已变化，请保留原结果"));return;}
        if(Equipped.Num()<6) Equipped.Add(NewSkill);else Bag.Add(NewSkill);
        Levels[NewSkill]=1;
        PillStates[NewSkill]=NewState;
    } else if(Operation==1 && Levels.IsValidIndex(Old) && Levels[Old]>0) {
        Levels[Old]=FMath::Min(5,Levels[Old]+1);
        PillStates[Old].Quality=FMath::Max(PillStates[Old].Quality,NewState.Quality);
    } else if(Operation==2 && Levels.IsValidIndex(Old) && Levels[Old]>0 && Levels[NewSkill]==0) {
        const int32 EquippedIndex=Equipped.Find(Old),BagIndex=Bag.Find(Old);
        if(EquippedIndex==INDEX_NONE && BagIndex==INDEX_NONE) {Message(TEXT("旧丹药不在技能栏，无法替换"));return;}
        if(EquippedIndex!=INDEX_NONE) Equipped[EquippedIndex]=NewSkill;else Bag[BagIndex]=NewSkill;
        Levels[NewSkill]=Levels[Old];Levels[Old]=0;
        SkillCD[NewSkill]=SkillCD[Old];SkillCD[Old]=0; // reforge cannot refresh the attack cooldown
        PillStates[NewSkill]=NewState;PillStates[Old]=FAlchemyPillState();
    } else if(Operation==3 && Levels.IsValidIndex(Old) && Levels[Old]>0) {
        PillStates[Old].Trait=NewState.Trait;
        PillStates[Old].TraitLevel=NewState.TraitLevel;
    } else {Message(TEXT("炼制目标已失效，保留旧丹"));return;}
    Progress->Recipes.AddUnique(NewSkill);
    SaveProgress();
    bV02Pending=false;PendingResultSkill=-1;PendingOldSkill=-1;
    bPendingTraitConverted=false;
    PendingBrewOperation=-1;PendingTrait=-1;PendingMain=-1;
    Panel.Empty();
    Message(FString::Printf(TEXT("已接收丹药：%s"),SkillName(NewSkill)));
}
