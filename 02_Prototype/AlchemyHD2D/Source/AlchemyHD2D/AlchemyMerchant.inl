// Run-local stock and currency; uses the existing world pause and inventory rules.
int32 AAlchemyWorld::MerchantBuyPrice(int32 Kind) const {
    static const int MaterialPrices[]={8,8,10,24,30,28};return Kind>=0 && Kind<6?MaterialPrices[Kind]:0;
}
int32 AAlchemyWorld::MerchantSellPrice(int32 Kind) const {return Kind>=0 && Kind<6?(Kind<3?2:8):0;}
int32 AAlchemyWorld::MerchantRefreshPrice() const {return 5+5*FMath::Min(MerchantRerolls,4);}
bool AAlchemyWorld::CanTrade() const {
    return bCombat && !bRunEnded && !bBossSpawned && RunTime<300 && bMerchantActive && MerchantRemaining>0 && FVector::Dist2D(PlayerPos,MerchantPos)<=260;
}
void AAlchemyWorld::CloseMerchant() {
    bMerchantActive=false;MerchantRemaining=0;MerchantSellKind=-1;MerchantSellCount=0;
    for(auto* A:{MerchantBody.Get(),MerchantShadow.Get(),MerchantMarker.Get()}) if(IsValid(A)) A->Destroy();
    MerchantBody=MerchantShadow=MerchantMarker=nullptr;
    for(auto& A:MerchantArrivalParts) if(IsValid(A)) A->Destroy();
    MerchantArrivalParts.Empty();MerchantArrivalAge=0;
    if(IsValid(MerchantArrivalFX)) MerchantArrivalFX->DestroyComponent();MerchantArrivalFX=nullptr;
    if(Panel==TEXT("merchant") || Panel==TEXT("merchantconfirm")) Panel.Empty();
}
void AAlchemyWorld::ResetMerchant() {
    CloseMerchant();MerchantVisit=MerchantRerolls=0;
    for(bool& B:MerchantEliteUnlocked) B=false;
    MerchantRandom.GenerateNewSeed();NextMerchantTime=MerchantRandom.FRandRange(70,90);
}
void AAlchemyWorld::RollMerchantStock() {
    TArray<int32> Pool;
    for(int I=0;I<3;I++) for(int N=0;N<4;N++) Pool.Add(I);
    for(int I=0;I<3;I++) if(MerchantEliteUnlocked[I]) Pool.Add(3+I);
    for(int I=0;I<3;I++) {MerchantStock[I]=Pool[MerchantRandom.RandRange(0,Pool.Num()-1)];MerchantSoldOut[I]=false;}
    if(MerchantStock[0]==MerchantStock[1] && MerchantStock[1]==MerchantStock[2]) {
        Pool.Remove(MerchantStock[0]);MerchantStock[MerchantRandom.RandRange(0,2)]=Pool[MerchantRandom.RandRange(0,Pool.Num()-1)];
    }
}
bool AAlchemyWorld::SpawnMerchant() {
    if(!bCombat || bRunEnded || bBossSpawned || RunTime>=300 || bMerchantActive || TutorialActive() || !Panel.IsEmpty() || MerchantVisit>=3 || PendingLevelUps>0 || PendingResultSkill>=0 || PendingIsNuclear) return false;
    bool Found=false;
    for(int I=0;I<32;I++) {
        const float Angle=MerchantRandom.FRandRange(0,2*PI),Distance=MerchantRandom.FRandRange(500,900);
        FVector P=PlayerPos+FVector(FMath::Cos(Angle),FMath::Sin(Angle),0)*Distance;
        if(!Walkable(P,60)) continue;
        if(Enemies.ContainsByPredicate([&](const FAlchemyEnemy& E){return E.HP>0 && FVector::DistSquared2D(E.Pos,P)<FMath::Square(220.f);})) continue;
        TArray<FVector> Path;if(!SegmentClear(PlayerPos,P,45) && !FindPath(PlayerPos,P,45,Path)) continue;
        MerchantPos=P;Found=true;break;
    }
    if(!Found) {NextMerchantTime=RunTime+5;return false;}
    MerchantVisit++;MerchantRerolls=0;MerchantRemaining=35;bMerchantActive=true;RollMerchantStock();
    MerchantBody=Sprite(TEXT("MerchantWanderer"),MerchantPos,223,260);
    MerchantShadow=Mesh(TEXT("Plane"),MerchantPos+FVector(0,0,6),FVector(1.5f,1,1),FLinearColor::White);
    MerchantShadow->GetStaticMeshComponent()->SetMaterial(0,Material(TEXT("M_SoftShadow")));
    MerchantMarker=Mesh(TEXT("Plane"),MerchantPos+FVector(0,0,12),FVector(2.6f,2.6f,1),Gold);
    MerchantMarker->GetStaticMeshComponent()->SetMaterial(0,Material(TEXT("M_ArenaRing")));
    MerchantArrivalAge=0;
    for(int I=0;I<14;I++) {
        auto* A=Mesh(TEXT("Plane"),MerchantPos+FVector(0,0,15),FVector(.01f),FLinearColor::White);
        auto* M=UMaterialInstanceDynamic::Create(Material(I<2?TEXT("M_MerchantArrival"):TEXT("M_MerchantSpark")),this);
        M->SetVectorParameterValue(TEXT("Tint"),I%2?FLinearColor(.2f,1,.8f):Gold);
        A->GetStaticMeshComponent()->SetMaterial(0,M);MerchantArrivalParts.Add(A);
    }
    MerchantArrivalFX=SpawnVFX(ImpactFX,MerchantPos+FVector(0,0,45),FLinearColor(.25f,1,.75f),.9f,1.4f);
    UpdateMerchantVisual(0);
    static const float Times[]={80,175,265},Jitter[]={10,15,10};
    NextMerchantTime=MerchantVisit<3?FMath::Max(RunTime+60,Times[MerchantVisit]+MerchantRandom.FRandRange(-Jitter[MerchantVisit],Jitter[MerchantVisit])):300;
    Message(TEXT("流浪商人出现 · 靠近金色标记按 F 交易，停留35秒"));
    UE_LOG(LogTemp,Display,TEXT("MERCHANT_SPAWN visit=%d time=%.2f pos=(%.0f,%.0f) stock=%d,%d,%d"),MerchantVisit,RunTime,MerchantPos.X,MerchantPos.Y,MerchantStock[0],MerchantStock[1],MerchantStock[2]);
    return true;
}
bool AAlchemyWorld::OpenMerchant() {
    if(!CanTrade() || !Panel.IsEmpty() || PendingLevelUps>0 || PendingResultSkill>=0 || PendingIsNuclear) return false;
    Selected={0,0,0,0,0,0};MerchantSellKind=-1;MerchantSellCount=0;Panel=TEXT("merchant");UpdateFeedback(0);return true;
}
bool AAlchemyWorld::BuyMerchant(int32 Slot) {
    if(!CanTrade() || Panel!=TEXT("merchant") || Slot<0 || Slot>=3 || MerchantSoldOut[Slot]) return false;
    const int Kind=MerchantStock[Slot],Price=MerchantBuyPrice(Kind);
    if(Kind<0 || Kind>=6 || Inventory[Kind]>=10 || RunCoins<Price) return false;
    RunCoins-=Price;Inventory[Kind]++;MerchantSoldOut[Slot]=true;
    UE_LOG(LogTemp,Display,TEXT("MERCHANT_BUY visit=%d slot=%d kind=%d cost=%d balance=%d"),MerchantVisit,Slot,Kind,Price,RunCoins);
    Message(FString::Printf(TEXT("购入 %s ×1，花费%d金币"),MaterialNames[Kind],Price));return true;
}
bool AAlchemyWorld::RefreshMerchant() {
    if(!CanTrade() || Panel!=TEXT("merchant") || RunCoins<MerchantRefreshPrice()) return false;
    const int Cost=MerchantRefreshPrice();RunCoins-=Cost;MerchantRerolls++;RollMerchantStock();
    UE_LOG(LogTemp,Display,TEXT("MERCHANT_REFRESH visit=%d count=%d cost=%d balance=%d"),MerchantVisit,MerchantRerolls,Cost,RunCoins);
    Message(FString::Printf(TEXT("货位已刷新，花费%d金币；下次%d金币"),Cost,MerchantRefreshPrice()));return true;
}
bool AAlchemyWorld::SellMerchant(int32 Kind,bool All) {
    if(!CanTrade() || Panel!=TEXT("merchant") || Kind<0 || Kind>=6 || Inventory[Kind]<=0) return false;
    if(All) {MerchantSellKind=Kind;MerchantSellCount=Inventory[Kind];Panel=TEXT("merchantconfirm");return true;}
    Inventory[Kind]--;RunCoins+=MerchantSellPrice(Kind);
    UE_LOG(LogTemp,Display,TEXT("MERCHANT_SELL visit=%d kind=%d count=1 balance=%d"),MerchantVisit,Kind,RunCoins);return true;
}
bool AAlchemyWorld::ConfirmMerchantSale() {
    if(!CanTrade() || Panel!=TEXT("merchantconfirm")) return false;
    const int Kind=MerchantSellKind,Count=MerchantSellCount;
    MerchantSellKind=-1;MerchantSellCount=0;Panel=TEXT("merchant");
    if(Kind<0 || Kind>=6 || Count<=0 || Inventory[Kind]!=Count) {Message(TEXT("库存已变化，请重新确认出售。"));return false;}
    Inventory[Kind]-=Count;RunCoins+=Count*MerchantSellPrice(Kind);
    UE_LOG(LogTemp,Display,TEXT("MERCHANT_SELL visit=%d kind=%d count=%d balance=%d"),MerchantVisit,Kind,Count,RunCoins);return true;
}
void AAlchemyWorld::UpdateMerchant(float Dt) {
    if(!bCombat || bRunEnded || bBossSpawned || RunTime>=300) {CloseMerchant();return;}
    if(!Panel.IsEmpty()) return;
    if(bMerchantActive) {
        UpdateMerchantVisual(Dt);
        MerchantRemaining=FMath::Max(0.f,MerchantRemaining-Dt);
        if(MerchantRemaining<=0) {UE_LOG(LogTemp,Display,TEXT("MERCHANT_LEAVE visit=%d"),MerchantVisit);CloseMerchant();Message(TEXT("流浪商人已经离开"));}
    } else if(RunTime>=NextMerchantTime && MerchantVisit<3 && !TutorialActive()) SpawnMerchant();
}

void AAlchemyWorld::UpdateMerchantVisual(float Dt) {
    if(!bMerchantActive || !IsValid(MerchantBody)) return;
    if(!Panel.IsEmpty()) Dt=0;
    MerchantArrivalAge=FMath::Min(1.4f,MerchantArrivalAge+Dt);
    const float T=MerchantArrivalAge/1.4f,Ease=1-FMath::Square(1-T);
    const float Height=260*(.82f+.18f*Ease);
    UpdateSprite(MerchantBody,TEXT("MerchantWanderer"),MerchantPos,Height*384/448,Height,false);
    MerchantBody->SetActorLocation(MerchantPos+Camera->GetActorUpVector()*(208.f/448*Height+18*(1-Ease)));
    for(int I=0;I<MerchantArrivalParts.Num();I++) {
        auto* A=MerchantArrivalParts[I].Get();
        if(I<2) {
            const float Radius=I==0?45+150*Ease:145-95*Ease;
            A->SetActorScale3D(FVector(Radius/50,Radius/50,1));
        } else {
            const float Angle=(I-2)*2*PI/12+T*1.6f,Radius=170*(1-Ease)+35;
            A->SetActorLocation(MerchantPos+FVector(FMath::Cos(Angle)*Radius,FMath::Sin(Angle)*Radius,20+90*FMath::Sin(PI*T)));
            A->SetActorRotation(FRotationMatrix::MakeFromXZ(Camera->GetActorRightVector(),-Camera->GetActorForwardVector()).Rotator());
            const float Size=7+9*FMath::Sin(PI*T);A->SetActorScale3D(FVector(Size/100,Size/100,1));
        }
        CastChecked<UMaterialInstanceDynamic>(A->GetStaticMeshComponent()->GetMaterial(0))->SetScalarParameterValue(TEXT("Fade"),1-T);
    }
    if(T>=1) {
        for(auto& A:MerchantArrivalParts) if(IsValid(A)) A->Destroy();
        MerchantArrivalParts.Empty();
        if(IsValid(MerchantArrivalFX)) MerchantArrivalFX->DestroyComponent();MerchantArrivalFX=nullptr;
    }
}
