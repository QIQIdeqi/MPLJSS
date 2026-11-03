// Included by AlchemyWorld.cpp; keeps the immediate-mode PC HUD beside its private game tables.
float AAlchemyHUD::Measure(const FString& Value,float Size) const {
    FSlateFontInfo Font(World->UIFont,FMath::Max(1,FMath::RoundToInt(World->Progress->FontSize(Size)*S*.75f)));
    return FSlateApplication::Get().GetRenderer()->GetFontMeasureService()->Measure(Value,Font).X/S;
}
void AAlchemyHUD::Text(const FString& Value,float X,float Y,float Size,FLinearColor Color) {
    if(FParse::Param(FCommandLine::Get(),TEXT("UIV02Test")) || FParse::Param(FCommandLine::Get(),TEXT("BrewV02Test")) || FParse::Param(FCommandLine::Get(),TEXT("EnemyCodexTest")) || FParse::Param(FCommandLine::Get(),TEXT("EliteSpawnTest")) || FParse::Param(FCommandLine::Get(),TEXT("TutorialPlacementTest")) || FParse::Param(FCommandLine::Get(),TEXT("TeachingJourneyTest")))UIV02DrawnText.Add(Value);
    // Font size is rasterized at the display size, rather than stretching UFont's default 9pt glyphs.
    FSlateFontInfo Font(World->UIFont,FMath::Max(1,FMath::RoundToInt(World->Progress->FontSize(Size)*S*.75f)));
    FCanvasTextItem Item(FVector2D(OX+X*S,OY+Y*S),FText::FromString(Value),Font,Color);
    Item.EnableShadow(FLinearColor(0,0,0,.6f),FVector2D(1,1));Canvas->DrawItem(Item);
    if(World->bCapture && FParse::Param(FCommandLine::Get(),TEXT("AlchemyPCCapture"))) {
        FVector2D Extent=FSlateApplication::Get().GetRenderer()->GetFontMeasureService()->Measure(Value,Font);
        if(OX+X*S<0 || OY+Y*S<0 || OX+X*S+Extent.X>Canvas->SizeX || OY+Y*S+Extent.Y>Canvas->SizeY) {
            UE_LOG(LogTemp,Error,TEXT("PC_UI_OVERFLOW text=%s"),*Value);FPlatformMisc::RequestExitWithStatus(false,1);
        }
    }
}
void AAlchemyHUD::Paragraph(const FString& Value,float X,float Y,float Width,float Size,FLinearColor Color) {
    FString Line;
    for(TCHAR Ch:Value) {
        FString Next=Line;Next.AppendChar(Ch);
        if(Ch==TEXT('\n') || (!Line.IsEmpty() && Measure(Next,Size)>Width)) {
            Text(Line,X,Y,Size,Color);Y+=World->Progress->FontSize(Size)+6;Line.Empty();
        }
        if(Ch!=TEXT('\n')) Line.AppendChar(Ch);
    }
    if(!Line.IsEmpty()) Text(Line,X,Y,Size,Color);
}
void AAlchemyHUD::Box(float X,float Y,float W,float H,FLinearColor Color) {DrawRect(Color,OX+X*S,OY+Y*S,W*S,H*S);}
void AAlchemyHUD::Button(const FString& Id,const FString& Label,float X,float Y,float W,bool Enabled,float H) {
    float MX=0,MY=0;GetOwningPlayerController()->GetMousePosition(MX,MY);MX=(MX-OX)/S;MY=(MY-OY)/S;
    bool Hover=MX>=X && MX<=X+W && MY>=Y && MY<=Y+H;
    int Index=Enabled?FocusOrder.Add(Id):-1;
    if(Enabled && Id==FocusId)FocusIndex=Index;
    bool Focus=Enabled && (FocusId.IsEmpty()?Index==FocusIndex:Id==FocusId) && !World->Panel.IsEmpty();
    Box(X,Y,W,H,Enabled?(Hover||Focus?FLinearColor(.14f,.27f,.28f):FLinearColor(.075f,.135f,.16f)):FLinearColor(.055f,.075f,.085f));
    Box(X,Y,4,H,Enabled?Gold:Muted);
    if(Focus) {Box(X,Y,W,2,Gold);Box(X,Y+H-2,W,2,Gold);}
    Text(Label,X+16,Y+(H-World->Progress->FontSize(20))/2,20,Enabled?FLinearColor(.95f,.95f,.9f):FLinearColor(.55f,.61f,.63f));
    if(World->bCapture && FParse::Param(FCommandLine::Get(),TEXT("AlchemyPCCapture")) && Measure(Label,20)>W-32) {
        UE_LOG(LogTemp,Error,TEXT("PC_UI_BUTTON_OVERFLOW id=%s"),*Id);FPlatformMisc::RequestExitWithStatus(false,1);
    }
    if(Enabled) {
        ButtonRects.Add(Id,FBox2D(FVector2D(X,Y),FVector2D(X+W,Y+H)));
        AddHitBox(FVector2D(OX+X*S,OY+Y*S),FVector2D(W*S,H*S),FName(*Id),true);
    }
}
void AAlchemyHUD::Activate(const FString& Id) {
    if(Id==TEXT("modalclose")){World->Action(World->bRunEnded && World->Panel==TEXT("savefailed")?TEXT("retry"):TEXT("close"));return;}
    if((Id==TEXT("noteprev") || Id==TEXT("notenext")) && World->Panel==TEXT("alchemy")) {
        DetailPage=FMath::Max(0,DetailPage+(Id==TEXT("notenext")?1:-1));FocusIndex=0;FocusOrder.Empty();return;
    }
    if(Id==TEXT("codexprev") || Id==TEXT("codexnext")){World->Action(Id);DetailPage=0;FocusIndex=0;FocusOrder.Empty();return;}
    if(Id==TEXT("detailprev")) {DetailPage=FMath::Max(0,DetailPage-1);return;}
    if(Id==TEXT("detailnext")) {DetailPage++;return;}
    if(Id.StartsWith(TEXT("material"))) {World->AddMaterial(FCString::Atoi(*Id.Mid(8)));return;}
    World->Action(Id);
}
void AAlchemyHUD::NotifyHitBoxClick(FName Name) {
    if(!World) return;
    FString Id=Name.ToString();FocusIndex=FMath::Max(0,FocusOrder.Find(Id));
    if(Id.StartsWith(TEXT("material"))) {
        DragMaterial=FCString::Atoi(*Id.Mid(8));if(auto R=ButtonRects.Find(Id)) DragSource=*R;
    } else Activate(Id);
}
void AAlchemyHUD::DrawHUD() {
    Super::DrawHUD();
    UIV02DrawnText.Empty();
    if(!World) for(TActorIterator<AAlchemyWorld> I(GetWorld());I;++I) {World=*I;break;}
    if(!World || !World->Progress || !Canvas) return;
    S=FMath::Min(Canvas->SizeX/1280.f,Canvas->SizeY/720.f);OX=(Canvas->SizeX-1280*S)/2;OY=(Canvas->SizeY-720*S)/2;
    auto PC=GetOwningPlayerController();
    FocusId.Empty();
    if(LastPanel!=World->Panel) {FocusIndex=World->Panel==TEXT("merchant")?0:2;DetailPage=0;LastPanel=World->Panel;}
    else if(!World->Panel.IsEmpty() && !FocusOrder.IsEmpty()) {
        int Step=(PC->WasInputKeyJustPressed(EKeys::Down)||PC->WasInputKeyJustPressed(EKeys::Gamepad_DPad_Down)?1:0)-(PC->WasInputKeyJustPressed(EKeys::Up)||PC->WasInputKeyJustPressed(EKeys::Gamepad_DPad_Up)?1:0);
        FocusIndex=(FocusIndex+Step+FocusOrder.Num())%FocusOrder.Num();
        FocusId=FocusOrder[FocusIndex];
        if(PC->WasInputKeyJustPressed(EKeys::Enter)||PC->WasInputKeyJustPressed(EKeys::Gamepad_FaceButton_Bottom)) Activate(FocusId);
        if(FocusOrder.IsEmpty() || LastPanel!=World->Panel)FocusId.Empty();
    }
    if(DragMaterial>=0 && PC->WasInputKeyJustReleased(EKeys::LeftMouseButton)) {
        float X,Y;PC->GetMousePosition(X,Y);FVector2D Mouse((X-OX)/S,(Y-OY)/S);
        if(World->Panel==TEXT("alchemy") && (World->TutorialActive() || FParse::Param(FCommandLine::Get(),TEXT("UIV02Test"))) && (DragSource.IsInsideOrOn(Mouse)||Furnace.IsInsideOrOn(Mouse))) World->AddMaterial(DragMaterial);
        DragMaterial=-1;
    }
    if(World->Panel!=TEXT("alchemy")) DragMaterial=-1;
    FocusOrder.Empty();ButtonRects.Empty();
    const FLinearColor White(.94f,.95f,.93f),Dim(.72f,.79f,.8f),Surface(.035f,.06f,.075f,.97f);
    const auto TraitName=[](int32 Trait)->const TCHAR* {
        switch(Trait){case 0:return TEXT("强击");case 1:return TEXT("延伸");case 2:return TEXT("迅捷");default:return TEXT("无");}
    };
    const auto QualityName=[](int32 Quality)->const TCHAR* {
        switch(Quality){case 0:return TEXT("粗制");case 1:return TEXT("稳定");case 2:return TEXT("精良");default:return TEXT("待结算");}
    };
    const auto BrewOperationName=[](int32 Operation)->const TCHAR* {
        switch(Operation){case 0:return TEXT("新制");case 1:return TEXT("同方强化");case 2:return TEXT("换主材");case 3:return TEXT("换辅材");default:return TEXT("炼制");}
    };
    const bool FlowBoss=World->bGreyfordFlow && World->GreyfordStage==2 && World->Panel.IsEmpty();
    const bool BattleHUD=World->bCombat && World->Panel.IsEmpty();
    const float HUDLeft=-OX/S,HUDTop=-OY/S,HUDBottom=(Canvas->SizeY-OY)/S;
    // 顶部/底部横幅与提示条已移除（用户要求，画面全屏纯净）。
    // Keep transient guidance away from the actual heroine/Boss sprite bounds.
    const auto ClearPanelY=[&](float X,float W,float H,float Preferred,bool IncludeBoss){
        TArray<FBox2D> Figures;
        const auto AddFigure=[&](AActor* Actor){if(!IsValid(Actor))return;const FBox B=Actor->GetComponentsBoundingBox(true);FBox2D Screen(ForceInit);
            for(int I=0;I<8;I++){const FVector P((I&1)?B.Max.X:B.Min.X,(I&2)?B.Max.Y:B.Min.Y,(I&4)?B.Max.Z:B.Min.Z);FVector2D V;if(PC->ProjectWorldLocationToScreen(P,V))Screen+=FVector2D((V.X-OX)/S,(V.Y-OY)/S);}
            if(Screen.bIsValid){Screen.Min-=FVector2D(12,12);Screen.Max+=FVector2D(12,12);Figures.Add(Screen);}};
        AddFigure(World->Player);if(IncludeBoss)for(const auto& E:World->Enemies)if(E.Type==10)AddFigure(E.Body);
        if(IncludeBoss && World->bCombat && World->RenderedBossBarY>=0)Figures.Add(FBox2D(FVector2D(400,World->RenderedBossBarY),FVector2D(880,World->RenderedBossBarY+70)));
        float Best=Preferred,Cost=TNumericLimits<float>::Max();
        for(float Y:{Preferred,520.f,280.f,410.f}){const FBox2D Panel(FVector2D(X,Y),FVector2D(X+W,Y+H));float Area=0;
            for(const auto& F:Figures)Area+=FMath::Max(0.,FMath::Min(Panel.Max.X,F.Max.X)-FMath::Max(Panel.Min.X,F.Min.X))*FMath::Max(0.,FMath::Min(Panel.Max.Y,F.Max.Y)-FMath::Max(Panel.Min.Y,F.Min.Y));
            if(Area<Cost){Cost=Area;Best=Y;}if(Area==0)break;}
        return Best;
    };
    const auto DrawToast=[&](){
        if(World->ToastTime<=0)return;
        const bool Modal=!World->Panel.IsEmpty();
        const float X=Modal?104:340,W=Modal?1074:600,H=64;
        const float Y=Modal?650:ClearPanelY(X,W,H,520,true);
        Box(X,Y,W,H,Surface);Box(X,Y,3,H,Gold);Paragraph(World->Toast,X+14,Y+8,W-28,16,Gold);
    };
    World->RenderedEliteBars=0;World->RenderedBossBarY=-1;
    if(World->bGreyfordReference && World->Panel.IsEmpty()){
        if(FParse::Param(FCommandLine::Get(),TEXT("GreyfordReferenceCapture")))return;
        Box(12,678,680,30,FLinearColor(0,0,0,.6f));Text(TEXT("WASD 移动 · Space 闪避 · 小屋强化 / 作坊图鉴 / 雾门出发：靠近按 F"),22,684,16,FLinearColor::White);
        for(int I=0;I<3;I++)if(FVector::Dist2D(World->PlayerPos,World->FacilityPosition(I))<(I==2?300:280))Text(I==0?TEXT("F · 小屋强化"):I==1?TEXT("F · 作坊图鉴"):TEXT("F · 雾门出发"),525,637,22,Gold);
        DrawToast();return;
    }
    if(World->bCombat && World->Panel.IsEmpty()) {
        // V0.2: the live brew advances with combat time; fragments collect into materials.
        // Keep this independent of the editable reference UMG so both battle presentations show it.
        if(!FParse::Param(FCommandLine::Get(),TEXT("UIV02Test"))) {
            const float X=HUDLeft+18,W=326,H=World->bBrewActive?108.f:52.f;
            const float Preferred=HUDTop+290;
            const float Y=FMath::Clamp(ClearPanelY(X,W,H,Preferred,true),HUDTop+116,HUDBottom-H-142);
            Box(X,Y,W,H,Surface);Box(X,Y,3,H,Gold);
            Text(FString::Printf(TEXT("碎片  火 %d  ·  露 %d  ·  魔 %d"),World->FragmentCount[0],World->FragmentCount[1],World->FragmentCount[2]),X+13,Y+9,17,Gold);
            if(World->bBrewActive) {
                Text(World->BrewMode==1?TEXT("驻留坩埚 · 120cm内推进（首测）"):TEXT("随身试剂 · 移动中推进（首测）"),X+13,Y+38,16,White);
                Box(X+13,Y+68,W-26,10,FLinearColor(.07f,.10f,.12f));
                const float Ratio=World->BrewDuration>0?FMath::Clamp(World->BrewProgress/World->BrewDuration,0.f,1.f):0.f;
                Box(X+13,Y+68,(W-26)*Ratio,10,Teal);
                Text(FString::Printf(TEXT("炼制 %.0f%% · %s"),Ratio*100,World->BrewMode==1?TEXT("离开驻留点暂停"):TEXT("可继续走位")),X+13,Y+84,16,Dim);
            } else Text(World->bBossSpawned?TEXT("Boss战无普通碎片补给，存量仍可炼制"):TEXT("普通怪少量掉落，碎片自动归集为材料"),X+13,Y+31,15,Dim);
        }
        for(const auto& E:World->Enemies) if(E.HP>0 && E.Type>=7 && E.Type!=10) {
            FVector2D Screen;
            if(!PC->ProjectWorldLocationToScreen(E.Pos+FVector(0,0,World->EnemyDefinition(E).VisualSize.Y+25),Screen)) continue;
            float X=(Screen.X-OX)/S,Y=(Screen.Y-OY)/S,W=E.Type>=7?100:72;
            if(X<W/2 || X>1280-W/2 || Y<100 || Y>560) continue;
            World->RenderedEliteBars++;
            Box(X-W/2-2,Y-2,W+4,11,Ink);Box(X-W/2,Y,W*FMath::Clamp(E.HP/E.MaxHP,0.f,1.f),7,E.Type>=7?Gold:Teal);
        }
        for(const auto& Number:World->DamageNumbers) {
            FVector2D Screen;if(!PC->ProjectWorldLocationToScreen(Number.Position,Screen)) continue;
            float Age=.85f-Number.Life;float X=(Screen.X-OX)/S+Number.Lane*18-12,Y=(Screen.Y-OY)/S-28-45*FMath::Sqrt(Age/.85f);
            if(X<24 || X>1200 || Y<100 || Y>560) continue;
            FLinearColor Color(1,.9f,.55f,FMath::Min(1.f,Number.Life/.2f));
            Text(FString::Printf(TEXT("%.0f"),Number.Value),X,Y,19+4*FMath::Max(0.f,1-Age/.12f),Color);
        }
        // Reference artwork, live bars, skill slots and minimap are owned by BattleReferenceWidget.
        if(!World->BattleWidget) {
        // 左上角：素材列表（系统 UI V0.2 §6.2）。
        Box(24,108,260,142,Surface);Box(24,108,4,142,Gold);
        for(int I=0;I<3;I++) Text(FString::Printf(TEXT("%s    %d / 10"),MaterialNames[I],World->Inventory[I]),42,120+I*40,20,I==0?Gold:White);
        // 脚底血条：跟随玩家世界坐标（§6.4）。
        {
            FVector2D HP;if(PC->ProjectWorldLocationToScreen(World->PlayerPos+FVector(0,0,40),HP)) {
                float HX=(HP.X-OX)/S-45, HY=(HP.Y-OY)/S-28;
                Box(HX-2,HY-2,94,12,Ink);Box(HX,HY,90*FMath::Clamp(World->HP/World->MaxHP,0.f,1.f),8,World->HP/World->MaxHP>.3f?Teal:FLinearColor(0.9f,0.2f,0.15f));
                Text(FString::Printf(TEXT("%.0f/%.0f"),World->HP,World->MaxHP),HX+10,HY-18,14,White);
            }
        }
        // No-widget fallback only; production status bars and timer belong to UMG.
        Text(FString::Printf(TEXT("击败 %d   金币 %d"),World->Kills,World->RunCoins),850,60,20,Gold);
        Button(TEXT("pausebtn"),TEXT("暂停"),1180,52,80,true,40);
        float Start=(1280-World->Equipped.Num()*146)/2.f;
        for(int I=0;I<World->Equipped.Num();I++) {
            int K=World->Equipped[I];float X=Start+I*146;Box(X,578,138,76,Surface);
            Text(World->SkillName(K),X+10,587,17,White);Text(FString::Printf(TEXT("Lv.%d"),World->Levels[K]),X+10,621,18,Gold);
        }
        // Q 炼金 / B 背包入口 + 经验条（§6.2/6.7）。
        Text(TEXT("Q 炼金"),60,648,18,Gold);Text(TEXT("B 背包"),1190,648,18,Gold);
        int NeedXP=World->RequiredXP(World->RunLevel);
        Text(FString::Printf(TEXT("Lv.%d  %.0f / %d"),World->RunLevel,World->RunXP,NeedXP),560,648,18,Gold);
        Box(500,666,280,8,Ink);Box(500,666,280*FMath::Clamp(World->RunXP/NeedXP,0.f,1.f),8,Gold);
        } else {
            const float HintX=HUDLeft+18,HintY=ClearPanelY(HintX,264,26,HUDBottom-36,true);
            const FString Prefix=TEXT("Q 炼金 · B 技能 · "),Pause=TEXT("Esc 暂停");
            const float PauseX=HintX+Measure(Prefix,16),PauseW=Measure(Pause,16);
            // Padding is above/below and to the right, never over the Q/B prefix.
            const FBox2D PauseRect(FVector2D(PauseX,HintY),FVector2D(PauseX+PauseW+4,HintY+26));
            ButtonRects.Add(TEXT("pausebtn"),PauseRect);
            AddHitBox(FVector2D(OX+PauseX*S,OY+HintY*S),FVector2D((PauseW+4)*S,26*S),FName(TEXT("pausebtn")),true);
            float MX=0,MY=0;PC->GetMousePosition(MX,MY);
            const bool Hover=PauseRect.IsInsideOrOn(FVector2D((MX-OX)/S,(MY-OY)/S));
            Text(Prefix,HintX,HintY+4,16,Dim);Text(Pause,PauseX,HintY+4,16,Hover?Gold:Dim);
        }
        if(World->TutorialActive() && !World->bBossArenaActive) {
            bool Ready=World->Inventory[0]>0 && World->Inventory[1]>0 && World->Inventory[2]>0;
            const float PanelH=Ready && World->TutorialSkill<0?82:48;
            const float TY=ClearPanelY(340,600,PanelH,102,false);
            Box(340,TY,600,PanelH,Surface);
            Paragraph(World->TutorialSkill>=0?TEXT("让新技能一次命中至少2个敌人，完成首次教学。"):Ready?TEXT("材料已齐！按 Q，尝试第一次炼金。"):TEXT("战斗收集三类材料，准备第一次炼金。"),360,TY+10,560,18,Gold);
            if(Ready && World->TutorialSkill<0) Button(TEXT("alchemy"),TEXT("Q 开始炼金"),370,TY+42,340,true,32);
        }
        if(!World->bGreyfordFlow && World->RunTime>=300 && !World->bBossSpawned) {Box(340,102,600,68,Surface);Text(FString::Printf(TEXT("BOSS 即将出现：%.1f秒"),310-World->RunTime),360,120,26,Gold);}
        for(const auto& E:World->Enemies) if(E.Type==10) {
            const float Y=FlowBoss?ClearPanelY(400,480,70,102,true):102;World->RenderedBossBarY=FMath::RoundToInt(Y);
            Box(400,Y,480,FlowBoss?70:104,Surface);Box(400,Y,480,3,Gold);
            Text(E.Phase2?TEXT("腐化之源 · 二阶段"):World->bGreyfordFlow?TEXT("腐化之源 · 雾界草甸"):TEXT("腐化之源 · 封锁战场"),416,Y+10,FlowBoss?20:24,Gold);
            Box(416,Y+(FlowBoss?36:48),448,12,Ink);Box(416,Y+(FlowBoss?36:48),448*FMath::Max(0.f,E.HP/E.MaxHP),12,Gold);
            const TCHAR* Names[]={TEXT("冲刺 · 离开橙色直线"),TEXT("弹幕 · 从扇形间隙穿过"),TEXT("冲击波 · 向侧面闪避")};
            const TCHAR* FlowHint=World->GreyfordBossPreparation>0?TEXT("准备阶段 · 观察站位，倒计时结束后开战"):E.PlannedState==1?TEXT("冲刺蓄力 · 方向锁定后向侧面躲开"):E.PlannedState==2?TEXT("冲刺中 · 避开橙色路线"):E.PlannedState==3?TEXT("收招停顿 · 调整站位并输出"):(E.PlannedState==4 || E.PlannedState==5)?TEXT("两波弹幕 · 观察青色弹道间隙"):TEXT("保持移动 · 等待Boss出招");
            Text(FlowBoss?FlowHint:E.Transition>0?TEXT("阶段转换 · 可以继续攻击"):E.BossActive>0?TEXT("冲刺中 · 注意侧移"):E.Windup>0?Names[E.BossAttack]:World->bGreyfordFlow?TEXT("保持移动 · 雾界边界不可越过"):TEXT("保持移动 · 金色边界不可越过"),416,Y+(FlowBoss?50:72),FlowBoss?16:18,E.Windup>0?FLinearColor(1,.65f,.3f):Dim);break;
        }
        if(World->TutorialEncounterMarker.IsValid()) {
            FVector2D Screen;
            if(PC->ProjectWorldLocationToScreen(World->TutorialEncounterMarker->GetActorLocation(),Screen)) {
                const FString Label=FString::Printf(TEXT("近战怪群将至 %.1f秒"),FMath::Max(0.f,World->TutorialEncounterRetry-World->RunTime));
                const float Size=18,W=Measure(Label,Size),H=World->Progress->FontSize(Size)+6;
                const float X=FMath::Clamp(float((Screen.X-OX)/S-W*.5f),24.f,1256.f-W);
                const float Preferred=FMath::Clamp(float((Screen.Y-OY)/S-H-12),104.f,580.f-H);
                const float Y=FMath::Clamp(ClearPanelY(X,W,H,Preferred,true),104.f,580.f-H);
                Text(Label,X,Y,Size,Gold);
            }
        }
        if(World->EliteWarning.Marker.IsValid()) {
            FVector2D Screen;
            if(PC->ProjectWorldLocationToScreen(World->EliteWarning.Position,Screen)) {
                const FString Label=FString::Printf(TEXT("精英将至 %.1f秒"),FMath::Max(0.f,World->EliteWarning.Remaining));
                const float Size=18,W=Measure(Label,Size),H=World->Progress->FontSize(Size)+6;
                const float X=FMath::Clamp(float((Screen.X-OX)/S-W*.5f),24.f,1256.f-W);
                const float Preferred=FMath::Clamp(float((Screen.Y-OY)/S-H-12),104.f,580.f-H);
                const float Y=FMath::Clamp(ClearPanelY(X,W,H,Preferred,true),104.f,580.f-H);
                Text(Label,X,Y,Size,Gold);
            }
        }
        if(World->bMerchantActive && !World->bBossSpawned) {
            const FVector D=World->MerchantPos-World->PlayerPos;
            const float Right=FVector::DotProduct(D,World->Camera->GetActorRightVector()),Up=FVector::DotProduct(D,World->Camera->GetActorForwardVector().GetSafeNormal2D());
            const TCHAR* Way=FMath::Abs(Right)>FMath::Abs(Up)?(Right>0?TEXT("右方"):TEXT("左方")):(Up>0?TEXT("上方"):TEXT("下方"));
            const float MerchantX=HUDLeft+18,MerchantY=HUDTop+142;
            Box(MerchantX,MerchantY,292,150,Surface);Box(MerchantX,MerchantY,4,150,Gold);
            Text(World->bMerchantLeaving?FString(TEXT("流浪商人 · 正在离场")):FString::Printf(TEXT("流浪商人 · %.0f秒"),World->MerchantRemaining),MerchantX+18,MerchantY+14,20,Gold);
            Text(FString::Printf(TEXT("%s %.1f米 · 金色标记"),Way,D.Size2D()/100),MerchantX+18,MerchantY+50,18,White);
            Button(TEXT("merchantopen"),World->bMerchantLeaving?TEXT("正在收摊，暂不交易"):World->CanTrade()?TEXT("F 打开交易"):TEXT("靠近商人后按 F"),MerchantX+18,MerchantY+91,256,World->CanTrade(),42);
        }
    } else if(!World->bCombat && World->Panel.IsEmpty() && !World->bGreyfordFlow) {
        for(int I=0;I<3;I++) {
            FVector P=World->FacilityPosition(I);if(World->bGreyfordFlow && FVector::Dist2D(P,World->PlayerPos)>2000)continue;P.Z+=I==2?410:180;FVector2D Screen;
            PC->ProjectWorldLocationToScreen(P,Screen);float X=(Screen.X-OX)/S-125,Y=(Screen.Y-OY)/S-42;
            X=FMath::Clamp(X,34.f,960.f);Y=FMath::Clamp(Y,110.f,540.f);
            Box(X-10,Y-6,280,48,Surface);Text(I==0?TEXT("[F] 强化台"):I==1?TEXT("[F] 配方图鉴"):TEXT("[F] 进入林地"),X,Y,22,Gold);
        }
    }
    if(!World->Panel.IsEmpty() && (!World->CharacterAnimation.Dead || World->CharacterAnimation.DeathFinished())) {
        Box(-OX/S,88,Canvas->SizeX/S,580,FLinearColor(.005f,.01f,.015f,.8f));Box(72,98,1136,550,Surface);Box(72,98,1136,4,Gold);
        const FString P=World->Panel;
        FString Title=P==TEXT("alchemy")?TEXT("炼金 · 战斗已暂停"):P==TEXT("codex")?TEXT("发现图鉴"):P==TEXT("skills")?TEXT("装备与储备"):P==TEXT("talents")?TEXT("永久强化"):P==TEXT("fonts")?TEXT("字体调试 · 即时预览"):P==TEXT("research")?TEXT("画面与可读性"):P==TEXT("level")?TEXT("选择关卡"):P==TEXT("result")?TEXT("炼金结果"):P==TEXT("levelup")?TEXT("升级强化"):P==TEXT("victory")?TEXT("胜利 · 已结算"):P==TEXT("defeat")?TEXT("本局结束"):P==TEXT("confirmbuy")?TEXT("确认购买"):P==TEXT("confirmreturn")?TEXT("返回据点？"):P==TEXT("savefailed")?TEXT("保存失败"):TEXT("暂停");
        if(P==TEXT("merchant")) Title=TEXT("流浪商人 · 战斗已暂停");
        if(P==TEXT("merchantconfirm")) Title=TEXT("确认出售全部材料");
        if(P==TEXT("bossportal"))Title=TEXT("进入雾界草甸？");
        Text(Title,104,118,28,Gold);
        Button(TEXT("modalclose"),P==TEXT("savefailed")?TEXT("Esc 重试"):TEXT("Esc 返回"),1018,114,160);
        Button(TEXT("textsize"),TEXT("F7 字体调试"),778,114,220,P!=TEXT("savefailed"));
        if(P==TEXT("bossportal")) {
            Paragraph(TEXT("保留当前生命、技能与冷却。自动回收已有地面材料，背包每种最多10个。未拾取的金币、经验球与精英宝箱不会带入，确认后消失。进入后至胜负结算前不能返回。"),104,220,1000,24,White);
            Text(FString::Printf(TEXT("当前生命 %.0f / %.0f"),World->HP,World->MaxHP),104,370,26,Gold);
            Button(TEXT("enterboss"),TEXT("确认挑战Boss"),104,500,524);Button(TEXT("bossportalstay"),TEXT("继续在草原成长"),654,500,524);
        }
        else if(P==TEXT("merchant") || P==TEXT("merchantconfirm")) DrawMerchant();
        else if(P==TEXT("alchemy") && !World->TutorialActive() && !FParse::Param(FCommandLine::Get(),TEXT("UIV02Test"))) {
            Text(TEXT("主材决定技能本体，辅材影响效果词条；模式决定炼制过程。首测未启用负面变异。"),104,179,17,Dim);
            const TCHAR* Operations[]={TEXT("新制丹药"),TEXT("同方强化"),TEXT("换主材重炼"),TEXT("换辅材重炼")};
            const float OperationX[]={104.f,374.f,644.f,914.f};
            for(int I=0;I<4;I++) {
                Button(FString::Printf(TEXT("brewop%d"),I),Operations[I],OperationX[I],211,248,!World->bBrewActive,44);
                if(World->BrewOperation==I)Box(OperationX[I],211,248,3,Gold);
            }
            Box(104,269,1074,61,FLinearColor(.055f,.095f,.11f));
            const bool HasTarget=World->BrewTarget>=0 && World->PillStates.IsValidIndex(World->BrewTarget)
                && World->PillStates[World->BrewTarget].Main>=0
                && World->Levels.IsValidIndex(World->BrewTarget) && World->Levels[World->BrewTarget]>0;
            const bool UsesMain=World->BrewOperation!=3;
            const bool ChoosesMain=World->BrewOperation==0 || World->BrewOperation==2;
            const bool UsesSupport=World->BrewOperation==0 || World->BrewOperation==3;
            if(World->BrewOperation==0) {
                Text(TEXT("目标：新丹药 · 当前已装备的丹药不会被替换"),122,286,20,White);
            } else {
                Button(TEXT("brewtargetprev"),TEXT("上一个"),114,277,126,!World->bBrewActive,44);
                Button(TEXT("brewtargetnext"),TEXT("下一个"),1042,277,126,!World->bBrewActive,44);
                Text(HasTarget?FString::Printf(TEXT("目标丹药：%s · Lv.%d"),World->SkillName(World->BrewTarget),World->Levels[World->BrewTarget]):TEXT("暂无可改造丹药，请先新制"),260,287,19,HasTarget?Gold:Dim);
            }
            Text(UsesMain?TEXT("必要主材 · 决定本体"):TEXT("原有主材 · 保留，不消耗"),104,343,19,Gold);
            Text(UsesSupport?TEXT("辅助材料 · 决定词条倾向"):TEXT("辅助材料 · 本次不参与"),650,343,19,Gold);
            for(int I=0;I<3;I++) {
                const float X=104+I*174;
                Button(FString::Printf(TEXT("brewm%d"),I),MaterialNames[I],X,370,166,!World->bBrewActive && ChoosesMain,44);
                const int32 DisplayMain=!UsesMain && HasTarget?World->PillStates[World->BrewTarget].Main:World->BrewMain;
                if(DisplayMain==I)Box(X,370,166,3,Gold);
            }
            const TCHAR* SupportNames[]={TEXT("不加辅材"),TEXT("火粉"),TEXT("露水"),TEXT("魔法碎片")};
            const TCHAR* SupportIds[]={TEXT("brewsnone"),TEXT("brews0"),TEXT("brews1"),TEXT("brews2")};
            for(int I=0;I<4;I++) {
                const float X=650+I*134;
                Button(SupportIds[I],SupportNames[I],X,370,126,!World->bBrewActive && UsesSupport,44);
                if(World->BrewSupport==I-1)Box(X,370,126,3,Gold);
            }
            TArray<int32> Candidates;TArray<float> Weights;
            if(ChoosesMain) {
                World->BuildBrewBodyOptions(World->BrewMain,World->BrewMainCount,World->BrewOperation==2?World->BrewTarget:-1,Candidates,Weights);
                const TCHAR* BodyCategory=World->BrewMain==0?TEXT("火焰"):World->BrewMain==1?TEXT("寒霜"):World->BrewMain==2?TEXT("魔法/混融"):TEXT("本体");
                if(Candidates.IsEmpty()) Text(FString::Printf(TEXT("%s候选：无可接收的新技能"),BodyCategory),104,416,15,Gold);
                else {
                    float Total=0;for(float Weight:Weights) Total+=Weight;
                    float UseWeights[5]={0,0,0,0,0};
                    for(int32 I=0;I<Candidates.Num();I++) {
                        const EAlchemyCast Cast=World->SkillConfig(Candidates[I]).Cast;
                        const int32 Use=(Cast==EAlchemyCast::Bolt || Cast==EAlchemyCast::Direct)?0:
                            Cast==EAlchemyCast::SelfArea?1:Cast==EAlchemyCast::TargetArea?2:Cast==EAlchemyCast::Bounce?3:4;
                        UseWeights[Use]+=Weights[I];
                    }
                    const TCHAR* UseNames[5]={TEXT("单体"),TEXT("近身范围"),TEXT("落点范围"),TEXT("弹跳"),TEXT("其他")};
                    const int32 UseOrder[3][5]={{0,2,1,3,4},{1,0,2,3,4},{3,2,0,1,4}};
                    FString UseLine=FString::Printf(TEXT("%s用途："),BodyCategory);
                    bool bFirstUse=true;
                    for(int32 Position=0;Position<5;Position++) {
                        const int32 Use=UseOrder[FMath::Clamp(World->BrewMain,0,2)][Position];
                        if(UseWeights[Use]<=0) continue;
                        if(!bFirstUse) UseLine+=TEXT(" · ");
                        UseLine+=FString::Printf(TEXT("%s %.1f%%"),UseNames[Use],UseWeights[Use]*100.f/Total);
                        bFirstUse=false;
                    }
                    Text(UseLine,104,416,14,Gold);
                    FString FirstLine(TEXT("本体：")),SecondLine;
                    for(int32 I=0;I<Candidates.Num();I++) {
                        const FString Name=World->Progress->Recipes.Contains(Candidates[I])?FString(World->SkillName(Candidates[I])):FString::Printf(TEXT("未知本体%d"),I+1);
                        const FString Entry=FString::Printf(TEXT("%s %.1f%%"),*Name,Weights[I]*100.f/Total);
                        FString& Line=I<3?FirstLine:SecondLine;
                        if(I!=0 && I!=3) Line+=TEXT(" · ");
                        Line+=Entry;
                    }
                    Text(FirstLine,104,435,14,Dim);
                    if(!SecondLine.IsEmpty()) Text(SecondLine,104,453,14,Dim);
                }
            } else Text(HasTarget?FString::Printf(TEXT("本体保留：%s"),World->SkillName(World->BrewTarget)):TEXT("本体保留：请先选择丹药"),104,416,15,Dim);
            if(!UsesSupport) Text(HasTarget?FString::Printf(TEXT("词条保留：%s"),TraitName(World->PillStates[World->BrewTarget].Trait)):TEXT("词条不重抽"),650,415,15,Dim);
            else if(World->BrewSupport<0 || World->BrewSupportCount<1) Text(TEXT("不加辅材：本炉不会生成词条"),650,415,15,Dim);
            else if(World->bBrewConvertTrait) Text(FString::Printf(TEXT("虚空晶定向：%s 100%%"),TraitName(World->BrewSupport)),650,415,15,Gold);
            else {
                float TraitWeights[3];World->BuildBrewTraitWeights(World->BrewSupport,World->BrewSupportCount,TraitWeights);
                const float Total=TraitWeights[0]+TraitWeights[1]+TraitWeights[2];
                Text(TEXT("词条实际概率："),650,415,15,Dim);
                Text(FString::Printf(TEXT("强击 %.1f%% · 延伸 %.1f%% · 迅捷 %.1f%%"),TraitWeights[0]*100.f/Total,TraitWeights[1]*100.f/Total,TraitWeights[2]*100.f/Total),650,435,14,Dim);
            }
            Text(UsesMain?(World->BrewOperation==1?FString(TEXT("强化固定消耗1份主材（首测）")):FString::Printf(TEXT("主材投入 %d / 3 份（首测）"),World->BrewMainCount)):TEXT("沿用原主材 · 本炉不扣"),104,486,18,White);
            Button(TEXT("brewmainminus"),TEXT("－"),369,474,84,!World->bBrewActive && UsesMain && World->BrewOperation!=1 && World->BrewMainCount>1,42);
            Button(TEXT("brewmainplus"),TEXT("＋"),465,474,84,!World->bBrewActive && ChoosesMain && Candidates.Num()>1 && World->BrewMainCount<3,42);
            Text(UsesSupport?FString::Printf(TEXT("辅材投入 %d / 3 份（首测）"),World->BrewSupportCount):TEXT("本炉不扣辅材"),650,486,18,White);
            Button(TEXT("brewsupportminus"),TEXT("－"),972,474,94,!World->bBrewActive && UsesSupport && World->BrewSupport>=0 && World->BrewSupportCount>1,42);
            Button(TEXT("brewsupportplus"),TEXT("＋"),1078,474,94,!World->bBrewActive && UsesSupport && !World->bBrewConvertTrait && World->BrewSupport>=0 && World->BrewSupportCount<3,42);
            const int32 Main=World->BrewMain,Support=World->BrewSupport;
            int32 Cost[6];World->BuildBrewCost(Cost);
            const auto CostLine=[&](int32 Kind) {
                const int32 Remaining=World->Inventory[Kind]-Cost[Kind];
                return FString::Printf(TEXT("%s 需%d / 现有%d · %s%d"),MaterialNames[Kind],Cost[Kind],World->Inventory[Kind],Remaining>=0?TEXT("余"):TEXT("缺"),FMath::Abs(Remaining));
            };
            const bool SameColor=UsesMain && UsesSupport && Main>=0 && Main<3 && Main==Support && World->BrewSupportCount>0;
            if(SameColor) {
                const int32 Remaining=World->Inventory[Main]-Cost[Main];
                Text(FString(TEXT("主辅同色合计："))+CostLine(Main),104,517,18,Remaining>=0?Teal:Gold);
                Text(TEXT("主辅材共用此库存"),650,517,16,Dim);
            } else {
                Text(!UsesMain?TEXT("原主材会随旧丹保留"):Main>=0 && Main<3?CostLine(Main):TEXT("请选择主材"),104,517,18,UsesMain && Main>=0 && Main<3 && Cost[Main]>World->Inventory[Main]?Gold:Dim);
                Text(!UsesSupport?TEXT("该操作不重抽词条"):Support>=0 && Support<3?CostLine(Support):TEXT("无辅材投入"),650,517,18,UsesSupport && Support>=0 && Support<3 && Cost[Support]>World->Inventory[Support]?Gold:Dim);
            }
            Text(FString::Printf(TEXT("碎片：火 %d · 露 %d · 魔 %d，自动归集成材料"),World->FragmentCount[0],World->FragmentCount[1],World->FragmentCount[2]),104,541,17,Teal);
            const bool CanConvert=UsesSupport && World->BrewSupport>=0 && World->BrewSupportCount==1;
            const FString ConvertLabel=World->BrewSupportCount>1 && !World->bBrewConvertTrait?FString(TEXT("先将辅材减至1份，再选虚空晶定向转换")):
                FString::Printf(TEXT("%s虚空晶 · 额外需1 / 现有%d%s"),World->bBrewConvertTrait?TEXT("已选 "):TEXT("选择 "),World->Inventory[4],Cost[4]>World->Inventory[4]?TEXT(" · 缺1"):TEXT(""));
            Button(TEXT("brewconvert"),ConvertLabel,650,539,528,!World->bBrewActive && (CanConvert || World->bBrewConvertTrait) && (World->Inventory[4]>0 || World->bBrewConvertTrait),42);
            if(World->bBrewConvertTrait && CanConvert)Box(650,539,528,3,Gold);
            Text(TEXT("起炼即扣，拒绝成品不返料。虚空晶仅定词条，本体仍随机。"),104,560,15,Dim);
            FString Reason;
            const bool CanStart=World->CanStartBrew(Reason);
            const TCHAR* OperationHint=World->BrewOperation==0?TEXT("新制一颗丹药；旧丹仍可使用。"):
                World->BrewOperation==1?TEXT("保留本体与词条，提升成长；暂用 Lv.5 上限。"):
                World->BrewOperation==2?TEXT("换主材重抽本体，保留兼容词条与成长。"):
                TEXT("换辅材重抽词条，保留本体与成长。");
            Paragraph(CanStart?FString(OperationHint):Reason,104,583,760,16,CanStart?Dim:Gold);
            Text(World->BrewMode==1?
                TEXT("驻留1.2秒，离点120cm暂停；新制稳定起25%升精良；强化至少稳定、25%尝试升档（精良封顶）"):
                TEXT("随身2.5秒可移动；新制粗制起25%升稳定；强化保留旧品质、25%尝试升档（精良封顶）"),104,610,16,Dim);
            Button(TEXT("brewstart"),World->bBrewActive?TEXT("正在炼制中"):TEXT("确认起炼 · 返回战场"),888,587,290,CanStart && !World->bBrewActive,46);
        }
        else if(P==TEXT("alchemy")) {
            Text(TEXT("点击或拖入材料；点击炉内材料取回。"),104,181,18,Dim);
            Furnace=FBox2D(FVector2D(104,220),FVector2D(704,490));
            int Total=0;for(int N:World->Selected) Total+=N;
            // 炼金锅：5 列 × 2 行，共 10 份投料位置（系统 UI V0.2 §5.2）。
            // 点击已投入的格子可直接放回材料背包。
            Box(104,220,600,260,FLinearColor(.055f,.105f,.12f));
            Text(FString::Printf(TEXT("炼金锅   已投入 %d / 10"),Total),124,232,22,Gold);
            int Slot=0;
            for(int Row=0;Row<2;Row++) for(int Col=0;Col<5;Col++) {
                float X=124+Col*112, Y=270+Row*92;
                if(Slot<Total) {
                    // 找到第 Slot 份投入的材料种类。
                    int M=-1,Acc=0;for(int I=0;I<6;I++){Acc+=World->Selected[I];if(Slot<Acc){M=I;break;}}
                    // Suffix makes each slot hitbox unique; the leading integer remains the material type for Action.
                    if(M>=0) Button(FString::Printf(TEXT("furnace%d_%d"),M,Slot),FString::Printf(TEXT("%s"),MaterialNames[M]),X,Y,100,true,80);
                    else Box(X,Y,100,80,FLinearColor(.08f,.14f,.16f));
                } else {
                    Box(X,Y,100,80,FLinearColor(.08f,.14f,.16f));
                }
                Slot++;
            }
            // 品质概率（不显示核弹概率）。
            TArray<int32> Options;TArray<float> Chances;FString Reason;int Combination;bool Valid=World->CraftOptions(Options,Chances,Reason,Combination);FString Probability;
            if(Valid && Combination>=0) {
                for(int Q=0;Q<3;Q++) {int I=Options.Find(World->CombinationSkill(Combination,Q));Probability+=FString::Printf(TEXT("%s %.2f%%   "),Q==0?TEXT("低"):Q==1?TEXT("中"):TEXT("高"),I>=0?Chances[I]:0);}
            } else Probability=Valid?TEXT("精英专属配方 · 固定产出"):TEXT("满足投料条件后显示实际品质概率");
            Text(Probability,124,480,17,Teal);
            // 普通炼金只开放前三种投料；精英材料掉落/商人/旧配方仍保留（1.5现行边界）。
            Text(TEXT("材料背包"),740,220,22,White);
            for(int I=0;I<6;I++) {
                float X=740+(I%3)*120, Y=240+(I/3)*92;
                bool Enabled=I<3;
                if(Enabled) {
                    Button(FString::Printf(TEXT("material%d"),I),FString::Printf(TEXT("%s  %d"),MaterialNames[I],World->Inventory[I]-World->Selected[I]),X,Y,110,World->Inventory[I]>World->Selected[I] && Total<10 && (!World->TutorialActive() || (World->TutorialSkill<0 && World->Selected[I]<1)),64);
                } else {
                    Box(X,Y,110,64,FLinearColor(.05f,.06f,.07f));Text(TEXT("暂未开放"),X+10,Y+22,14,Muted);
                }
            }
            // All discovered normal combinations, three per page; actions stay below the list.
            Text(TEXT("炼成笔记"),740,412,20,White);
            TArray<int32> KnownCombinations;
            for(int C=0;C<7;C++)if(World->Progress->Combinations.Contains(C))KnownCombinations.Add(C);
            const int PerPage=3,Pages=FMath::Max(1,(KnownCombinations.Num()+PerPage-1)/PerPage);
            DetailPage=FMath::Clamp(DetailPage,0,Pages-1);
            if(KnownCombinations.IsEmpty())Text(TEXT("发现材料组合后在此记录。"),752,450,16,Dim);
            for(int Row=0;Row<PerPage;Row++) {
                const int Index=DetailPage*PerPage+Row;if(!KnownCombinations.IsValidIndex(Index))break;
                const int C=KnownCombinations[Index];const float Y=440+Row*38;
                Text(World->CombinationName(C),752,Y+9,16,Gold);
                int Need[3]={0,0,0};int Mask=World->RuntimeRecipes[C].Mask;
                if(Mask==7){Need[0]=Need[1]=Need[2]=1;}else{int Cnt=0;if(Mask&1){Need[0]=1;Cnt++;}if(Mask&2){Need[1]=1;Cnt++;}if(Mask&4){Need[2]=1;Cnt++;}if(Cnt==1){for(int M=0;M<3;M++)if(Need[M])Need[M]=3;}else{int First=-1;for(int M=0;M<3;M++)if(Need[M]){if(First<0)First=M;}for(int M=0;M<3;M++)Need[M]=Need[M]*(M==First?2:1);}}
                bool Enough=true;for(int M=0;M<3;M++)if(World->Inventory[M]<Need[M])Enough=false;
                Button(FString::Printf(TEXT("fill%d"),C),TEXT("一键填入"),1002,Y+3,176,Enough && World->bCombat && !World->TutorialActive(),32);
            }
            Button(TEXT("noteprev"),TEXT("上一页"),740,554,120,DetailPage>0,30);
            Text(FString::Printf(TEXT("%d / %d"),DetailPage+1,Pages),902,561,16,Dim);
            Button(TEXT("notenext"),TEXT("下一页"),1058,554,120,DetailPage<Pages-1,30);
            if(Valid) Button(TEXT("craft"),TEXT("开始炼金"),740,594,240,true,42);
            Button(TEXT("clear"),TEXT("清空素材"),1000,594,180,true,42);
            Paragraph(Reason.IsEmpty()?(World->TutorialActive()?TEXT("首次三料各1个；合成后返回战斗，体验范围攻击。"):TEXT("材料种类决定组合，投入总量影响品质概率。")):Reason,104,530,600,16,Gold);
            if(DragMaterial>=0) {float X,Y;PC->GetMousePosition(X,Y);Text(MaterialNames[DragMaterial],(X-OX)/S+16,(Y-OY)/S,22,Gold);}
        } else if(P==TEXT("codex")) {
            // 图鉴三分类：技能 / 怪物 / 素材（系统 UI V0.2 §4）。
            Button(TEXT("codexprev"),TEXT("上一类"),104,181,185);Button(TEXT("codexnext"),TEXT("下一类"),993,181,185);
            const TCHAR* Tabs[]={TEXT("技能"),TEXT("怪物"),TEXT("素材")};Text(Tabs[World->CodexPage],430,191,22,White);
            if(World->CodexPage==0) {
                // 技能图鉴：21 普通技能，已发现显示名称/品质/组合，未发现显示 ???。
                int PerPage=6; int Count=21; int Pages=(Count+PerPage-1)/PerPage;DetailPage=FMath::Clamp(DetailPage,0,Pages-1);
                for(int Row=0;Row<PerPage;Row++) {
                    const int Index=DetailPage*PerPage+Row;if(Index>=Count)break;
                    const int Combo=Index/3,Quality=Index%3,K=World->CombinationSkill(Combo,Quality);float Y=238+Row*54;
                    bool Known=World->Progress->Recipes.Contains(K);
                    Box(104,Y,1074,48,FLinearColor(.055f,.095f,.11f));
                    Text(Known?World->SkillName(K):TEXT("??? 未发现"),120,Y+13,20,Known?Gold:Dim);
                    if(Known) {
                        const bool LegacyUI=FParse::Param(FCommandLine::Get(),TEXT("UIV02Test"));
                        const TCHAR* QualityLabel=Quality==0?TEXT("低"):Quality==1?TEXT("中"):TEXT("高");
                        const FString Detail=LegacyUI?FString::Printf(TEXT("%s · %s品质"),World->CombinationName(Combo),QualityLabel):
                            FString::Printf(TEXT("历史组合档案：%s · %s品质"),World->CombinationName(Combo),QualityLabel);
                        Text(Detail,360,Y+15,18,Dim);
                    }
                }
                Button(TEXT("detailprev"),TEXT("上一页"),104,580,185,DetailPage>0);Button(TEXT("detailnext"),TEXT("下一页"),993,580,185,DetailPage<Pages-1);Text(FString::Printf(TEXT("%d / %d"),DetailPage+1,Pages),600,590,20,Dim);
            } else if(World->CodexPage==1) {
                // Each row is a codex identity; Archetype only controls rewards and special behavior.
                const auto SingleLine=[&](FString Value,float Size,float Width){
                    Value.ReplaceInline(TEXT("\r"),TEXT(" "));Value.ReplaceInline(TEXT("\n"),TEXT(" "));Value.ReplaceInline(TEXT("\t"),TEXT(" "));
                    if(Measure(Value,Size)<=Width)return Value;
                    const FString Suffix=TEXT("…");
                    while(!Value.IsEmpty() && Measure(Value+Suffix,Size)>Width){
                        Value=Value.LeftChop(1);
                        if(!Value.IsEmpty() && Value[Value.Len()-1]>=0xD800 && Value[Value.Len()-1]<=0xDBFF)Value=Value.LeftChop(1);
                    }
                    return Value+Suffix;
                };
                const int PerPage=6,Count=World->RuntimeEnemies.Num(),Pages=FMath::Max(1,(Count+PerPage-1)/PerPage);
                DetailPage=FMath::Clamp(DetailPage,0,Pages-1);
                for(int Row=0;Row<PerPage;Row++) {
                    const int I=DetailPage*PerPage+Row;if(I>=Count)break;const float Y=238+Row*54;
                    const bool Known=World->Progress->Monsters.Contains(I);
                    Box(104,Y,1074,48,FLinearColor(.055f,.095f,.11f));
                    Text(Known?SingleLine(World->RuntimeEnemies[I].Name,20,224):TEXT("??? 未发现"),120,Y+13,20,Known?Gold:Dim);
                    if(Known)Text(SingleLine(World->EnemyCodexDescription(I),18,802),360,Y+15,18,Dim);
                }
                Button(TEXT("detailprev"),TEXT("上一页"),104,580,185,DetailPage>0);Button(TEXT("detailnext"),TEXT("下一页"),993,580,185,DetailPage<Pages-1);Text(FString::Printf(TEXT("%d / %d"),DetailPage+1,Pages),600,590,20,Dim);
            } else {
                // 素材图鉴：3 种普通材料，首次拾取解锁（精英材料禁用）。
                for(int I=0;I<3;I++) {
                    float Y=238+I*90; bool Known=World->Progress->Materials.Contains(I);
                    Box(104,Y,1074,80,FLinearColor(.055f,.095f,.11f));
                    Text(Known?MaterialCodexNames[I]:TEXT("??? 未发现"),120,Y+13,22,Known?Gold:Dim);
                    if(Known) Text(MaterialCodexDescriptions[I],120,Y+48,18,Dim);
                }
            }
        } else if(P==TEXT("skills")) {
            Text(TEXT("选储备，再选装备位交换。初始魔弹固定保留。"),104,181,18,Dim);
            Text(TEXT("装备 6"),104,220,22,Gold);Text(TEXT("储备 6"),654,220,22,Gold);
            for(int I=0;I<6;I++) {
                bool Has=World->Equipped.IsValidIndex(I),HasBag=World->Bag.IsValidIndex(I);int K=Has?World->Equipped[I]:0;
                Button(FString::Printf(TEXT("equip%d"),I),Has?FString::Printf(TEXT("%d  %s  Lv.%d"),I+1,World->SkillName(K),World->Levels[K]):TEXT("空装备位"),104,260+I*56,524,World->SelectedBag>=0&&I!=0);
                Button(FString::Printf(TEXT("bag%d"),I),HasBag?FString::Printf(TEXT("%s%s"),World->SelectedBag==I?TEXT("→ "):TEXT(""),World->SkillName(World->Bag[I])):TEXT("空储备位"),654,260+I*56,524,HasBag);
            }
        } else if(P==TEXT("fonts")) {
            Text(TEXT("小号固定100%（16–18）；中号19–25，大号26及以上。调节即时生效并保存。"),104,185,18,Dim);
            Text(FString::Printf(TEXT("中号 %.0f%%"),World->Progress->MediumTextScale*100),104,235,18,Gold);
            Text(FString::Printf(TEXT("大号 %.0f%%"),World->Progress->LargeTextScale*100),104,315,18,Gold);
            for(int I=0;I<4;I++) {
                const TCHAR* Labels[]={TEXT("-5%"),TEXT("-1%"),TEXT("+1%"),TEXT("+5%")};
                Button(FString::Printf(TEXT("fontm%d"),I),Labels[I],350+I*155,222,140);
                Button(FString::Printf(TEXT("fontl%d"),I),Labels[I],350+I*155,302,140);
            }
            Text(TEXT("小号：WASD 移动 · 材料说明"),104,395,18,White);
            Text(TEXT("中号：生命 120 / 120 · 炼金确认"),104,435,24,White);
            Text(TEXT("大号：冒牌炼金术士 · 05:00"),104,480,34,Gold);
            Button(TEXT("fontreset"),TEXT("恢复推荐值 90% / 72%"),104,555,510);
            Text(TEXT("告诉我：中号百分比、大号百分比、窗口分辨率。范围50%–120%。"),104,615,16,Dim);
        } else if(P==TEXT("research")) {
            Text(TEXT("F7 打开字体调试；画面选项即时预览。"),104,181,18,Dim);
            Button(TEXT("ortho"),World->bPerspective?TEXT("F1 透视镜头"):TEXT("F1 正交镜头"),104,235,524);Button(TEXT("lit"),World->bLitSprites?TEXT("F2 角色接受光照"):TEXT("F2 角色自发光"),654,235,524);
            Button(TEXT("upright"),World->bUprightSprites?TEXT("F3 角色竖直"):TEXT("F3 角色面向相机"),104,300,524);Button(TEXT("tilt"),FString::Printf(TEXT("F4 俯角 %.0f°"),World->CameraPitch),654,300,524);
            Button(TEXT("dof"),World->bDepthOfField?TEXT("F5 景深开启"):TEXT("F5 景深关闭"),104,365,524);
            Button(TEXT("tune"),World->bTune001B?TEXT("战斗：测试配置"):TEXT("战斗：原始基线"),104,450,524,!World->bCombat);
            Button(TEXT("drop"),World->bSmoke || World->bCapture?(World->bDrop001?TEXT("材料掉落：15.4%"):TEXT("材料掉落：22%")):(World->bDrop001?TEXT("碎片触发：15.4%"):TEXT("碎片触发：22%")),654,450,524,!World->bCombat);
            Paragraph(TEXT("[ / ] 调整视野宽度。战斗与掉落配置仅限据点切换。"),104,535,1074,20,Dim);
        } else if(P==TEXT("talents")) {
            Text(FString::Printf(TEXT("永久金币 %d；所有强化独立开放，金币足够即可购买。"),World->Progress->Coins),104,181,18,Dim);
            // Two columns, five rows, all ten upgrades inside the modal safe frame.
            for(int I=0;I<TalentNodeCount;I++) {
                const int L=World->Progress->Talents[I],MX=TalentMaxLevel[I];
                const bool Done=World->TalentNodeDone(I);
                const bool Available=World->TalentNodeUnlocked(I);
                const float X=104+(I%2)*550,Y=220+(I/2)*76;
                Box(X,Y,524,68,FLinearColor(.055f,.095f,.11f));
                Text(TalentNames[I],X+12,Y+8,20,Done?Dim:White);
                Text(FString::Printf(TEXT("Lv.%d/%d"),L,MX),X+12,Y+38,18,Gold);
                const FString Label=I==8 && Done && !Available?TEXT("旧权益保留 · 暂不生效"):Done?TEXT("已解锁／满级"):!Available?TEXT("V0.2 暂不可购买"):FString::Printf(TEXT("购买 %d金币"),TalentCosts[I][L]);
                Button(FString::Printf(TEXT("buy%d"),I),Label,X+264,Y+14,248,Available && !Done && World->Progress->Coins>=TalentCosts[I][L],44);
            }
        } else if(P==TEXT("level")) {
            Text(World->bGreyfordFlow?TEXT("村庄外围"):TEXT("腐化林地"),104,192,29,Gold);
            Text(TEXT("本局炼金模式 · 主辅材料决定成品，模式决定战场炼制方式"),104,251,20,White);
            Button(TEXT("mode0"),TEXT("随身试剂 · 可移动"),104,305,524,true,66);
            Button(TEXT("mode1"),TEXT("驻留坩埚 · 快速"),654,305,524,true,66);
            const int32 ChosenMode=FMath::Clamp(World->Progress->AlchemyMode,0,1);
            Box(ChosenMode==0?104:654,305,524,4,Gold);
            Paragraph(ChosenMode==0?TEXT("已选随身试剂：起炼后可走位，2.5秒完成；耗时为首测暂值。"):
                TEXT("已选驻留坩埚：起炼点120cm内推进，1.2秒完成；离开暂停进度。距离与耗时为首测暂值。"),104,398,1074,19,Gold);
            Paragraph(World->bGreyfordFlow?TEXT("5:00开放Boss传送阵。进入后保留当前生命、丹药技能和材料。"):
                TEXT("5:00预警，5:10出现最终BOSS。击败BOSS获得胜利。"),104,470,1074,18,Dim);
            Button(TEXT("start"),TEXT("按所选模式进入关卡"),104,554,524,true,58);
        } else if(P==TEXT("confirmbuy") && World->PendingTalent>=0) {
            int I=World->PendingTalent;
            int L=World->Progress->Talents[I];
            FString Desc=FString::Printf(TEXT("%s：Lv.%d → Lv.%d，花费%d金币。"),TalentNames[I],L,L+1,TalentCosts[I][L]);
            Paragraph(TalentDescriptions[I],104,320,1000,20,Dim);
            Paragraph(Desc,104,260,1000,25,White);Button(TEXT("confirmbuy"),TEXT("确认购买并保存"),104,460,524);Button(TEXT("talents"),TEXT("取消"),654,460,524);
        } else if(P==TEXT("result")) {
            if(World->bV02Pending) {
                const int32 Old=World->PendingOldSkill,New=World->PendingResultSkill;
                const bool HasOld=Old>=0 && World->PillStates.IsValidIndex(Old) && World->Levels.IsValidIndex(Old) && World->Levels[Old]>0;
                const int32 OldLevel=HasOld?World->Levels[Old]:0;
                const auto* OldPill=HasOld?&World->PillStates[Old]:nullptr;
                const int32 NewLevel=World->PendingBrewOperation==0?1:World->PendingBrewOperation==1?OldLevel+1:OldLevel;
                Text(FString::Printf(TEXT("%s结果 · 每炉只结算一次"),BrewOperationName(World->PendingBrewOperation)),104,178,22,Gold);
                Text(TEXT("材料已消耗；保留旧丹也不会返还本炉材料（首测）。"),104,211,17,Dim);
                if(World->bPendingTraitConverted)Text(TEXT("已用虚空晶定向转换词条 · 额外消耗1枚（首测暂定）"),104,230,16,Teal);
                else if((World->PendingBrewOperation==0 || World->PendingBrewOperation==3) && World->PendingTrait>=0)
                    Text(TEXT("普通辅材只增加词条倾向；本次按候选权重生成结果（首测）。"),104,230,16,Dim);
                Box(104,247,510,261,FLinearColor(.055f,.095f,.11f));
                Box(654,247,524,261,FLinearColor(.055f,.095f,.11f));
                Text(HasOld?TEXT("原有丹药 · 结果处理前继续生效"):TEXT("原有丹药 · 无"),121,259,21,HasOld?White:Dim);
                Text(TEXT("本炉成品 · 接受后生效"),671,259,21,Gold);
                if(HasOld) {
                    Text(FString::Printf(TEXT("本体  %s"),World->SkillName(Old)),121,304,20,White);
                    Text(OldPill->Main>=0 && OldPill->Main<3?FString::Printf(TEXT("主材  %s"),MaterialNames[OldPill->Main]):TEXT("主材  未记录"),121,343,18,Dim);
                    FString OldTrait=FString::Printf(TEXT("词条  %s"),TraitName(OldPill->Trait));
                    if(OldPill->Trait>=0)OldTrait+=FString::Printf(TEXT(" Lv.%d"),OldPill->TraitLevel);
                    Text(OldTrait,121,380,18,Dim);
                    Text(FString::Printf(TEXT("成长  Lv.%d"),OldLevel),121,417,18,White);
                    Text(FString::Printf(TEXT("品质  %s"),QualityName(OldPill->Quality)),121,454,18,Dim);
                } else {
                    Text(TEXT("首次制丹，没有旧丹会被覆盖。"),121,327,19,Dim);
                }
                Text(New>=0?FString::Printf(TEXT("本体  %s"),World->SkillName(New)):TEXT("本体  待结算"),671,304,20,White);
                Text(World->PendingMain>=0 && World->PendingMain<3?FString::Printf(TEXT("主材  %s"),MaterialNames[World->PendingMain]):TEXT("主材  未记录"),671,343,18,Dim);
                FString NewTrait=FString::Printf(TEXT("词条  %s"),TraitName(World->PendingTrait));
                if(World->PendingTrait>=0)NewTrait+=FString::Printf(TEXT(" Lv.%d"),World->PendingTraitLevel);
                Text(NewTrait,671,380,18,Dim);
                Text(FString::Printf(TEXT("成长  Lv.%d%s"),NewLevel,World->PendingBrewOperation==1?TEXT(" · 首测暂用 Lv.5 上限"):World->PendingBrewOperation>=2?TEXT(" · 保留旧成长"):TEXT("")),671,417,18,White);
                Text(FString::Printf(TEXT("品质  %s（首测暂值）"),QualityName(World->PendingQuality)),671,454,18,Dim);
                Button(TEXT("acceptresult"),TEXT("接受本炉成品"),104,536,510,true,54);
                Button(TEXT("rejectresult"),HasOld?TEXT("保留旧丹 · 本炉材料已消耗"):TEXT("放弃成品 · 本炉材料已消耗"),654,536,524,true,54);
                Text(TEXT("换材继承为本版原型规则；接受新丹不会免费重置技能冷却。"),104,608,16,Dim);
            } else {
            if(World->PendingIsNuclear) {
                Text(TEXT("核弹额外清场 · 中高品质权重减半，差额转低品质"),104,180,18,Gold);
                Text(TEXT("精英与Boss不受清场影响；技能仍可接收、正常参与连锁。"),104,453,16,Dim);
            }
            if(World->PendingResultSkill>=0) {
                int K=World->PendingResultSkill;
                const auto& SK=World->SkillConfig(K);
                Text(FString::Printf(TEXT("炼金成功 · %s"),World->SkillName(K)),104,200,30,Gold);
                Text(World->PendingResultCombination>=0?FString::Printf(TEXT("组合：%s · 投入%d个"),World->CombinationName(World->PendingResultCombination),World->PendingResultTotal):TEXT("精英专属配方"),104,260,22,White);
                FString Desc=FString::Printf(TEXT("伤害 %.0f · 冷却 %.1f秒"),SK.Damage,SK.CD);
                if(SK.Cast==EAlchemyCast::SelfArea||SK.Cast==EAlchemyCast::TargetArea) Desc+=FString::Printf(TEXT(" · 范围半径 %.0f"),SK.Radius/100);
                else if(SK.Cast==EAlchemyCast::Bounce) Desc+=FString::Printf(TEXT(" · 最多%d目标"),SK.Targets);
                else if(SK.Cast==EAlchemyCast::Bolt) Desc+=FString::Printf(TEXT(" · 射程 %.0f"),SK.Range/100);
                if(SK.Slow>0) Desc+=FString::Printf(TEXT(" · 减速%.0f%%/%.1f秒"),(1-SK.Factor)*100,SK.Slow);
                Text(Desc,104,315,20,Dim);
                Paragraph(World->ChainHintFor(K),104,360,1000,20,Dim);
                Button(TEXT("acceptresult"),TEXT("接收技能"),104,520,420);
                if(World->Progress->Talents[8]>0 && !World->PendingRefreshed && World->PendingResultCombination>=0) Button(TEXT("reroll"),TEXT("刷新一次"),560,520,420);
            }
            }
        } else if(P==TEXT("levelup")) {
            Text(FString::Printf(TEXT("升级 · Lv.%d"),World->RunLevel),104,180,30,Gold);
            Text(TEXT("选择一项强化"),104,240,22,White);
            const TCHAR* AttrNames[]={TEXT("生命值"),TEXT("伤害"),TEXT("移动速度"),TEXT("技能范围"),TEXT("伤害减少"),TEXT("经验增加"),TEXT("生命回复")};
            int MaxLayers[]={5,5,5,5,6,5,5};
            for(int I=0;I<3;I++) {
                int Attr=World->LevelupChoices[I];
                if(Attr<0) continue;
                float Y=300+I*90;
                Text(FString::Printf(TEXT("%s  %d/%d"),AttrNames[Attr],World->RunAttrs[Attr],MaxLayers[Attr]),120,Y+8,22,White);
                Button(FString::Printf(TEXT("pick%d"),Attr),TEXT("选择"),808,Y,370,World->RunAttrs[Attr]<MaxLayers[Attr]);
            }
        } else if(P==TEXT("confirmreturn")) {
            Paragraph(TEXT("已拾取金币会结算。本局材料与技能将清空。"),104,270,1000,25,White);Button(TEXT("village"),TEXT("确认返回"),104,460,524);Button(TEXT("close"),TEXT("继续战斗"),654,460,524);
        } else if(P==TEXT("victory")||P==TEXT("defeat")) {
            Text(FString::Printf(TEXT("生存 %02d:%02d"),int(World->RunTime)/60,int(World->RunTime)%60),104,240,36,White);
            Text(World->bSmoke || World->bCapture?FString::Printf(TEXT("击败 %d   炼金 %d   连锁 %d"),World->Kills,World->CraftCount,World->ChainCount):FString::Printf(TEXT("击败 %d   炼丹 %d"),World->Kills,World->CraftCount),104,315,25,White);
            Text(FString::Printf(TEXT("本局到账 %d 金币"),World->ResultCoins),104,385,28,Gold);Button(TEXT("village"),TEXT("返回据点"),104,520,524);
        } else if(P==TEXT("savefailed")) {
            Paragraph(TEXT("本局金币仍待保存。重试成功后才能离开。"),104,270,1000,25,Gold);Button(TEXT("retry"),TEXT("重试保存"),104,460,524);
        } else {
            if(World->bCombat) {
                // 暂停菜单（系统 UI V0.2 §9.2）：继续 / 设置 / 返回据点。
                Button(TEXT("close"),TEXT("继续游戏"),104,245,524);Button(TEXT("fonts"),TEXT("游戏设置"),654,245,524);
                Button(TEXT("return"),TEXT("返回据点"),104,345,524,!(World->bGreyfordFlow && World->GreyfordStage==2));
            } else {
                Button(TEXT("close"),TEXT("继续游戏"),104,245,524);Button(TEXT("codex"),TEXT("图鉴"),654,245,524);
                Button(TEXT("talents"),TEXT("能力强化"),104,325,524);Button(TEXT("level"),TEXT("选择关卡"),654,325,524);
            }
            Text(TEXT("↑ ↓ 选择    Enter 确认    Esc 返回"),104,480,22,Dim);
        }
    }
    // Restore transient feedback below the scene/modal without a top banner.
    DrawToast();
    DrawMerchantFeedback();
    if(World->bGreyfordFlow)DrawGreyfordFlow();
    FocusIndex=FMath::Clamp(FocusIndex,0,FMath::Max(0,FocusOrder.Num()-1));
}
