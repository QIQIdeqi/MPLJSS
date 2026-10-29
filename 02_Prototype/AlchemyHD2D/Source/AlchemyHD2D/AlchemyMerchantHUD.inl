void AAlchemyHUD::DrawMerchant() {
    const FLinearColor White(.94f,.95f,.93f),Dim(.72f,.79f,.8f),Card(.055f,.105f,.12f);
    if(World->Panel==TEXT("merchantconfirm")) {
        const int Kind=World->MerchantSellKind,Count=World->MerchantSellCount;
        if(Kind<0 || Kind>=6 || Count<=0) return;
        Paragraph(FString::Printf(TEXT("出售全部 %s ×%d"),MaterialNames[Kind],Count),104,246,1000,28,White);
        Text(FString::Printf(TEXT("将获得 %d 本局金币"),Count*World->MerchantSellPrice(Kind)),104,320,28,Gold);
        Text(TEXT("确认后材料立即扣除；只使用本局钱包，不影响银行金币。"),104,376,18,Dim);
        Button(TEXT("merchantconfirm"),TEXT("确认出售"),104,460,524,World->CanTrade());
        Button(TEXT("close"),TEXT("取消，返回商店"),654,460,524);return;
    }
    Text(FString::Printf(TEXT("本局金币 %d   ·   交易中战斗与倒计时暂停"),World->RunCoins),104,184,20,Gold);
    Button(TEXT("merchantrefresh"),FString::Printf(TEXT("刷新三个货位 · %d金币"),World->MerchantRefreshPrice()),800,178,378,World->CanTrade() && World->RunCoins>=World->MerchantRefreshPrice(),44);
    for(int I=0;I<3;I++) {
        const int K=World->MerchantStock[I],Price=World->MerchantBuyPrice(K);const float X=104+I*364;
        Box(X,238,344,126,Card);Box(X,238,344,3,Teal);
        Text(FString::Printf(TEXT("%d  %s"),I+1,MaterialNames[K]),X+14,250,22,White);
        Text(FString::Printf(TEXT("单价 %d金币   ·   库存 %d"),Price,World->MerchantSoldOut[I]?0:1),X+14,283,18,Dim);
        const bool Enabled=World->CanTrade() && !World->MerchantSoldOut[I] && World->Inventory[K]<10 && World->RunCoins>=Price;
        const FString Label=World->MerchantSoldOut[I]?TEXT("已售罄"):World->Inventory[K]>=10?TEXT("材料已满"):World->RunCoins<Price?TEXT("金币不足"):TEXT("购买一个");
        Button(FString::Printf(TEXT("merchantbuy%d"),I),Label,X+14,312,316,Enabled,40);
    }
    Text(TEXT("随身材料 · 出售"),104,382,22,White);
    for(int K=0;K<6;K++) {
        const float X=104+(K%3)*364,Y=416+(K/3)*72;
        Box(X,Y,344,64,Card);
        Text(FString::Printf(TEXT("%s ×%d"),MaterialNames[K],World->Inventory[K]),X+10,Y+7,18,White);
        Text(FString::Printf(TEXT("回收价 %d金币/个"),World->MerchantSellPrice(K)),X+10,Y+35,14,Dim);
        const bool Enabled=World->CanTrade() && World->Inventory[K]>0;
        Button(FString::Printf(TEXT("merchantsell%d"),K),TEXT("卖1"),X+168,Y+12,72,Enabled,40);
        Button(FString::Printf(TEXT("merchantsellall%d"),K),TEXT("全卖"),X+250,Y+12,84,Enabled,40);
    }
    Paragraph(TEXT("三个随机货位至少两种材料；购买上限10个。关闭重开不会补货或重置刷新费。"),104,574,1074,16,Dim);
    Paragraph(FString::Printf(TEXT("本位商人已刷新%d次；离场剩余%.0f秒（交易中暂停）。出售全部需再次确认。"),World->MerchantRerolls,World->MerchantRemaining),104,605,1074,16,Gold);
}
