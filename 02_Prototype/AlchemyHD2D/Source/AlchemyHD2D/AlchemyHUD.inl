// Included by AlchemyWorld.cpp; keeps the immediate-mode PC HUD beside its private game tables.
float AAlchemyHUD::Measure(const FString& Value,float Size) const {
    FSlateFontInfo Font(World->UIFont,FMath::Max(1,FMath::RoundToInt(World->Progress->FontSize(Size)*S*.75f)));
    return FSlateApplication::Get().GetRenderer()->GetFontMeasureService()->Measure(Value,Font).X/S;
}
void AAlchemyHUD::Text(const FString& Value,float X,float Y,float Size,FLinearColor Color) {
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
    int Index=Enabled?FocusOrder.Add(Id):-1;bool Focus=Enabled && Index==FocusIndex && !World->Panel.IsEmpty();
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
    if(!World) for(TActorIterator<AAlchemyWorld> I(GetWorld());I;++I) {World=*I;break;}
    if(!World || !World->Progress || !Canvas) return;
    S=FMath::Min(Canvas->SizeX/1280.f,Canvas->SizeY/720.f);OX=(Canvas->SizeX-1280*S)/2;OY=(Canvas->SizeY-720*S)/2;
    auto PC=GetOwningPlayerController();
    if(LastPanel!=World->Panel) {FocusIndex=World->Panel==TEXT("merchant")?0:2;DetailPage=0;LastPanel=World->Panel;}
    else if(!World->Panel.IsEmpty() && !FocusOrder.IsEmpty()) {
        int Step=(PC->WasInputKeyJustPressed(EKeys::Down)||PC->WasInputKeyJustPressed(EKeys::Gamepad_DPad_Down)?1:0)-(PC->WasInputKeyJustPressed(EKeys::Up)||PC->WasInputKeyJustPressed(EKeys::Gamepad_DPad_Up)?1:0);
        FocusIndex=(FocusIndex+Step+FocusOrder.Num())%FocusOrder.Num();
        if(PC->WasInputKeyJustPressed(EKeys::Enter)||PC->WasInputKeyJustPressed(EKeys::Gamepad_FaceButton_Bottom)) Activate(FocusOrder[FocusIndex]);
    }
    if(DragMaterial>=0 && PC->WasInputKeyJustReleased(EKeys::LeftMouseButton)) {
        float X,Y;PC->GetMousePosition(X,Y);FVector2D Mouse((X-OX)/S,(Y-OY)/S);
        if(World->Panel==TEXT("alchemy") && (DragSource.IsInsideOrOn(Mouse)||Furnace.IsInsideOrOn(Mouse))) World->AddMaterial(DragMaterial);
        DragMaterial=-1;
    }
    if(World->Panel!=TEXT("alchemy")) DragMaterial=-1;
    FocusOrder.Empty();ButtonRects.Empty();
    const FLinearColor White(.94f,.95f,.93f),Dim(.72f,.79f,.8f),Surface(.035f,.06f,.075f,.97f);
    // Background bars cover the screen; content stays inside a centered 16:9 PC safe frame.
    Box(-OX/S,-OY/S,Canvas->SizeX/S,88+OY/S,Surface);
    Text(TEXT("冒牌炼金术士"),24,18,28,Gold);
    Text(World->bCombat?TEXT("腐化林地"):TEXT("烛苔村 · 据点"),315,25,22,White);
    if(World->bCombat) {
        Text(FString::Printf(TEXT("%02d:%02d"),int(World->RunTime)/60,int(World->RunTime)%60),610,14,34,White);
        Text(FString::Printf(TEXT("击败 %d   金币 %d"),World->Kills,World->RunCoins),790,28,20,Gold);
    } else Text(FString::Printf(TEXT("金币 %d"),World->Progress->Coins),720,27,22,Gold);
    if(World->Panel.IsEmpty()) Button(TEXT("research"),TEXT("F6 画面"),1070,20,185);
    Box(-OX/S,668,Canvas->SizeX/S,52+OY/S,Surface);
    Paragraph(TEXT("WASD 移动    Space 闪避    F 交互    Tab 炼金    C 图鉴    B 技能    Esc 返回"),24,680,1232,16,Dim);
    World->RenderedEliteBars=0;World->RenderedBossBarY=-1;
    if(World->bCombat && World->Panel.IsEmpty()) {
        for(const auto& E:World->Enemies) if(E.HP>0 && E.Type>=7 && E.Type!=10) {
            FVector2D Screen;
            if(!PC->ProjectWorldLocationToScreen(E.Pos+FVector(0,0,E.Type>=7?225:120),Screen)) continue;
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
        Box(24,108,300,160,Surface);Box(24,108,4,160,Teal);
        Text(FString::Printf(TEXT("生命 %.0f / %.0f"),World->HP,World->MaxHP),42,122,24,White);
        Box(42,164,264,18,Ink);Box(42,164,264*World->HP/World->MaxHP,18,Teal);
        Text(World->DodgeCD<=0?TEXT("Space 闪避就绪"):FString::Printf(TEXT("闪避冷却 %.1f秒"),World->DodgeCD),42,197,18,Dim);
        // EXP-001: run level and xp progress bar.
        int NeedXP=World->RequiredXP(World->RunLevel);
        Text(FString::Printf(TEXT("Lv.%d   经验 %.0f / %d"),World->RunLevel,World->RunXP,NeedXP),42,224,18,Gold);
        Box(42,248,264,10,Ink);Box(42,248,264*FMath::Clamp(World->RunXP/NeedXP,0.f,1.f),10,Gold);
        Box(24,280,300,142,Surface);Box(24,280,4,142,Gold);
        for(int I=0;I<3;I++) Text(FString::Printf(TEXT("%s    %d%s"),MaterialNames[I],World->Inventory[I],World->Inventory[I]>10?TEXT(" · 补给"):TEXT(" / 10")),42,296+I*38,20,I==0?Gold:White);
        float Start=(1280-World->Equipped.Num()*146)/2.f;
        for(int I=0;I<World->Equipped.Num();I++) {
            int K=World->Equipped[I];float X=Start+I*146;Box(X,578,138,76,Surface);
            Text(World->SkillName(K),X+10,587,17,White);Text(FString::Printf(TEXT("Lv.%d"),World->Levels[K]),X+10,621,18,Gold);
        }
        if(World->TutorialActive() && !World->bBossArenaActive) {
            bool Ready=World->Inventory[0]>0 && World->Inventory[1]>0 && World->Inventory[2]>0;
            const float TY=World->RunTime>=300?186:108;
            Box(350,TY,650,118,Surface);
            Paragraph(World->TutorialSkill>=0?TEXT("让新技能一次命中至少2个敌人，完成首次教学。"):Ready?TEXT("材料已齐！按 Tab，尝试第一次炼金。"):TEXT("战斗收集三类材料，准备第一次炼金。"),370,TY+14,610,20,Gold);
            if(Ready && World->TutorialSkill<0) Button(TEXT("alchemy"),TEXT("Tab 开始炼金"),370,TY+63,340);
        }
        if(World->RunTime>=300 && !World->bBossSpawned) {Box(340,102,600,68,Surface);Text(FString::Printf(TEXT("BOSS 即将出现：%.1f秒"),310-World->RunTime),360,120,26,Gold);}
        for(const auto& E:World->Enemies) if(E.Type==10) {
            World->RenderedBossBarY=102;
            Box(340,102,600,104,Surface);Box(340,102,600,3,Gold);
            Text(E.Phase2?TEXT("腐化之源 · 二阶段"):TEXT("腐化之源 · 封锁战场"),360,112,24,Gold);
            Box(360,150,560,12,Ink);Box(360,150,560*FMath::Max(0.f,E.HP/E.MaxHP),12,Gold);
            const TCHAR* Names[]={TEXT("冲刺 · 离开橙色直线"),TEXT("弹幕 · 从扇形间隙穿过"),TEXT("冲击波 · 向侧面闪避")};
            Text(E.Transition>0?TEXT("阶段转换 · 可以继续攻击"):E.BossActive>0?TEXT("冲刺中 · 注意侧移"):E.Windup>0?Names[E.BossAttack]:TEXT("保持移动 · 金色边界不可越过"),360,174,18,E.Windup>0?FLinearColor(1,.65f,.3f):Dim);break;
        }
        if(World->bMerchantActive && !World->bBossSpawned) {
            const FVector D=World->MerchantPos-World->PlayerPos;
            const float Right=FVector::DotProduct(D,World->Camera->GetActorRightVector()),Up=FVector::DotProduct(D,World->Camera->GetActorForwardVector().GetSafeNormal2D());
            const TCHAR* Way=FMath::Abs(Right)>FMath::Abs(Up)?(Right>0?TEXT("右方"):TEXT("左方")):(Up>0?TEXT("上方"):TEXT("下方"));
            Box(964,108,292,150,Surface);Box(964,108,4,150,Gold);
            Text(FString::Printf(TEXT("流浪商人 · %.0f秒"),World->MerchantRemaining),982,122,20,Gold);
            Text(FString::Printf(TEXT("%s %.1f米 · 金色标记"),Way,D.Size2D()/100),982,158,18,White);
            Button(TEXT("merchantopen"),World->CanTrade()?TEXT("F 打开交易"):TEXT("靠近商人后按 F"),982,199,256,World->CanTrade(),42);
        }
    } else if(!World->bCombat && World->Panel.IsEmpty()) {
        for(int I=0;I<3;I++) {
            FVector P=I==0?FVector(-600,100,180):I==1?FVector(600,100,180):FVector(0,1050,410);FVector2D Screen;
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
        Text(Title,104,118,28,Gold);
        Button(TEXT("close"),TEXT("Esc 返回"),1018,114,160);
        Button(TEXT("textsize"),TEXT("F7 字体调试"),778,114,220);
        if(P==TEXT("merchant") || P==TEXT("merchantconfirm")) DrawMerchant();
        else if(P==TEXT("alchemy")) {
            Text(TEXT("点击或拖入材料；点击炉内材料取回。"),104,181,18,Dim);
            Furnace=FBox2D(FVector2D(104,220),FVector2D(704,490));Box(104,220,600,270,FLinearColor(.055f,.105f,.12f));
            int Total=0;for(int N:World->Selected) Total+=N;Text(FString::Printf(TEXT("炼金炉    %d / 10"),Total),124,232,24,Gold);
            Text(TEXT("材料背包"),756,228,24,White);
            int Next=-1;if(World->TutorialActive() && World->TutorialSkill<0) for(int I=0;I<3;I++) if(!World->Selected[I]) {Next=I;break;}
            for(int I=0;I<3;I++) {
                Button(FString::Printf(TEXT("sub%d"),I),FString::Printf(TEXT("%s ×%d   取回"),MaterialNames[I],World->Selected[I]),124,282+I*58,558,World->Selected[I]>0);
                Button(FString::Printf(TEXT("material%d"),I),FString::Printf(TEXT("%s%s  %d"),Next==I?TEXT("→ "):TEXT(""),MaterialNames[I],World->Inventory[I]-World->Selected[I]),756,282+I*58,422,World->Inventory[I]>World->Selected[I] && (!World->TutorialActive() || (World->TutorialSkill<0 && World->Selected[I]<1)));
            }
            TArray<int32> Options;TArray<float> Chances;FString Reason;int Combination;bool Valid=World->CraftOptions(Options,Chances,Reason,Combination);FString Probability;
            if(Valid && Combination>=0) {
                Probability=FString::Printf(TEXT("特殊 %.2f%%   "),SpecialProcChance[FMath::Clamp(Total-3,0,7)]);
                for(int Q=0;Q<3;Q++) {int I=Options.Find(World->CombinationSkill(Combination,Q));Probability+=FString::Printf(TEXT("%s %.1f%%   "),Q==0?TEXT("低"):Q==1?TEXT("中"):TEXT("高"),I>=0?Chances[I]:0);}
            }
            else Probability=Valid?TEXT("精英专属配方 · 固定产出"):TEXT("满足投料条件后显示实际品质概率");
            Text(Probability,124,456,18,Teal);
            if(!World->TutorialActive()) for(int I=3;I<6;I++) {
                float X=104+(I-3)*366;Text(FString::Printf(TEXT("%s %d  炉中%d"),MaterialNames[I],World->Inventory[I]-World->Selected[I],World->Selected[I]),X,503,16,Dim);
                Button(FString::Printf(TEXT("add%d"),I),TEXT("+"),X+230,495,54,true,40);Button(FString::Printf(TEXT("sub%d"),I),TEXT("-"),X+290,495,54,World->Selected[I]>0,40);
            }
            if(Valid) Button(TEXT("craft"),TEXT("开始炼金"),104,550,330);
            Button(TEXT("clear"),TEXT("清空投料"),456,550,330);Button(TEXT("codex"),TEXT("查看图鉴"),808,550,370);
            Paragraph(Reason.IsEmpty()?(World->TutorialActive()?TEXT("首次三料各1个；合成后返回战斗，体验范围攻击。"):TEXT("材料种类决定组合，投入总量影响品质概率。")):Reason,104,609,1074,16,Gold);
            if(DragMaterial>=0) {float X,Y;PC->GetMousePosition(X,Y);Text(MaterialNames[DragMaterial],(X-OX)/S+16,(Y-OY)/S,22,Gold);}
        } else if(P==TEXT("codex")) {
            Button(TEXT("codexprev"),TEXT("上一类"),104,181,185);Button(TEXT("codexnext"),TEXT("下一类"),993,181,185);
            const TCHAR* Tabs[]={TEXT("材料组合"),TEXT("已发现技能"),TEXT("技能连锁"),TEXT("精英配方")};Text(Tabs[World->CodexPage],430,191,22,White);
            int Count=World->CodexPage==2?World->NumChains():World->CodexPage==3?World->RuntimeRecipes.Num()-7:7,PerPage=World->CodexPage==2?4:World->CodexPage==3?3:5;
            int Pages=(Count+PerPage-1)/PerPage;DetailPage=FMath::Clamp(DetailPage,0,Pages-1);
            for(int Row=0;Row<PerPage;Row++) {
                int I=DetailPage*PerPage+Row;if(I>=Count) break;float Y=248+Row*(World->CodexPage==2?72:World->CodexPage==3?96:58);
                Box(104,Y,1074,World->CodexPage==2?66:World->CodexPage==3?88:52,FLinearColor(.055f,.095f,.11f));
                if(World->CodexPage==0) {bool Known=World->Progress->Combinations.Contains(I);Text(Known?World->CombinationName(I):TEXT("未发现的组合"),120,Y+13,20,Known?Gold:Dim);Text(Known?TEXT("三种品质；材料比例不改变组合"):TEXT("尝试不同材料种类"),450,Y+15,18,Dim);if(Known) Button(FString::Printf(TEXT("fill%d"),I),TEXT("一键填充"),923,Y+8,235,World->bCombat&&!World->TutorialActive());}
                if(World->CodexPage==1) for(int Q=0;Q<3;Q++) {int K=World->CombinationSkill(I,Q);bool Known=World->Progress->Recipes.Contains(K);Text(Known?FString::Printf(TEXT("%s %s"),Q==0?TEXT("低"):Q==1?TEXT("中"):TEXT("高"),World->SkillName(K)):TEXT("未发现技能"),120+Q*352,Y+14,19,Known?Gold:Dim);}
                if(World->CodexPage==2) {
                    const auto& K=World->ChainConfig(I);bool Known=World->Progress->ChainsV2.Contains(I);Text(K.Name,120,Y+10,21,Gold);
                    Text(Known?FString::Printf(TEXT("%s + %s  /  冷却%.0f秒"),World->SkillName(K.A),World->SkillName(K.B),K.CD):TEXT("装备互补技能，实际触发后揭示条件"),370,Y+10,18,Known?White:Dim);
                    if(Known) Text(FString::Printf(TEXT("基础伤害%.0f  %s%.1f  减速%.0f%%，持续%.1f秒"),K.Damage,K.Targets?TEXT("目标数"):TEXT("半径"),K.Targets?float(K.Targets):K.Radius/100,(1-K.Factor)*100,K.Slow),370,Y+39,16,Dim);
                }
                if(World->CodexPage==3) {
                    int K=World->RuntimeRecipes[7+I].LowSkill;bool Known=World->Progress->Recipes.Contains(K);Text(Known?World->SkillName(K):TEXT("未发现的精英配方"),120,Y+10,21,Known?Gold:Dim);
                    if(Known) {FString Cost;for(int M=0;M<6;M++) if(World->RecipeCost(K,M)) Cost+=FString::Printf(TEXT("%s×%d "),MaterialNames[M],World->RecipeCost(K,M));Text(Cost,120,Y+48,18,Dim);Button(FString::Printf(TEXT("recipe%d"),K),TEXT("填入素材"),923,Y+18,235,World->bCombat&&!World->TutorialActive());}
                }
            }
            Button(TEXT("detailprev"),TEXT("上一页"),104,570,185,DetailPage>0);Button(TEXT("detailnext"),TEXT("下一页"),993,570,185,DetailPage<Pages-1);Text(FString::Printf(TEXT("%d / %d"),DetailPage+1,Pages),600,580,20,Dim);
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
            Button(TEXT("tune"),World->bTune001B?TEXT("战斗：测试配置"):TEXT("战斗：原始基线"),104,450,524,!World->bCombat);Button(TEXT("drop"),World->bDrop001?TEXT("材料掉落：15.4%"):TEXT("材料掉落：22%"),654,450,524,!World->bCombat);
            Paragraph(TEXT("[ / ] 调整视野宽度。战斗与掉落配置仅限据点切换。"),104,535,1074,20,Dim);
        } else if(P==TEXT("talents")) {
            Text(FString::Printf(TEXT("永久金币 %d；前一项完成解锁下一项。"),World->Progress->Coins),104,181,18,Dim);
            for(int I=0;I<TalentNodeCount;I++) {
                const auto& N=TalentSequence[I];
                bool Done=World->TalentNodeDone(I),Open=World->TalentNodeUnlocked(I);
                float Y=232+I*58;
                FString State,Label;
                if(N.AttrIndex>=0) {int L=World->Progress->Talents[N.AttrIndex];State=FString::Printf(TEXT("Lv.%d/5"),L);Label=Done?TEXT("已满级"):FString::Printf(TEXT("购买  %d金币"),Prices[N.AttrIndex][L]);}
                else {State=TEXT("一次性");Label=Done?TEXT("已解锁"):FString::Printf(TEXT("解锁  %d金币"),N.OneShotCost);}
                Text(FString::Printf(TEXT("%s  %s  %s"),N.Name,*State,Open?TEXT(""):TEXT("锁定")),120,Y+6,21,Open?White:Dim);
                if(Open && !Done) Button(FString::Printf(TEXT("buy%d"),I),Label,808,Y,370);
            }
        } else if(P==TEXT("level")) {
            Text(TEXT("腐化林地"),104,245,32,Gold);Text(TEXT("自动战斗 · 材料炼金 · 固定地图"),104,305,23,White);
            if(World->Progress->StartMaterialUnlocked) {
                Text(TEXT("开局高级材料（选择一种，本局获得1个）："),104,370,20,White);
                for(int I=0;I<3;I++) {
                    const TCHAR* Names[]={TEXT("兽核"),TEXT("虚空晶"),TEXT("根须心")};
                    Button(FString::Printf(TEXT("startmat%d"),I),FString::Printf(TEXT("%s%s"),World->StartMaterialChoice==I?TEXT("→ "):TEXT(""),Names[I]),104+I*366,410,340);
                }
            }
            Paragraph(TEXT("5:00预警，5:10出现最终BOSS。击败BOSS获得胜利。"),104,500,1000,20,Dim);Button(TEXT("start"),TEXT("进入关卡"),104,545,460);
        } else if(P==TEXT("confirmbuy") && World->PendingTalent>=0) {
            int I=World->PendingTalent;const auto& N=TalentSequence[I];
            FString Desc;
            if(N.AttrIndex>=0) {int L=World->Progress->Talents[N.AttrIndex];Desc=FString::Printf(TEXT("%s：Lv.%d → Lv.%d，花费%d金币。"),N.Name,L,L+1,Prices[N.AttrIndex][L]);}
            else Desc=FString::Printf(TEXT("%s：一次性解锁，花费%d金币。"),N.Name,N.OneShotCost);
            Paragraph(Desc,104,260,1000,25,White);Button(TEXT("confirmbuy"),TEXT("确认购买并保存"),104,460,524);Button(TEXT("talents"),TEXT("取消"),654,460,524);
        } else if(P==TEXT("result")) {
            if(World->PendingIsNuclear) {
                Text(TEXT("核弹炼金 · 特殊结果"),104,200,30,Gold);
                Paragraph(TEXT("已清除全部普通怪物，精英与BOSS不受影响。"),104,270,1000,24,White);
                Text(TEXT("特殊结果，不参与常规连锁。"),104,360,20,Dim);
                Button(TEXT("acceptresult"),TEXT("确认"),104,520,524);
            } else if(World->PendingResultSkill>=0) {
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
                if(World->Progress->RefreshUnlocked && !World->PendingRefreshed && World->PendingResultCombination>=0) Button(TEXT("reroll"),TEXT("刷新一次"),560,520,420);
            }
        } else if(P==TEXT("levelup")) {
            Text(FString::Printf(TEXT("升级 · Lv.%d"),World->RunLevel),104,180,30,Gold);
            Text(TEXT("选择一项强化"),104,240,22,White);
            const TCHAR* AttrNames[]={TEXT("生命值"),TEXT("伤害"),TEXT("移动速度"),TEXT("技能范围"),TEXT("伤害减少"),TEXT("经验增加"),TEXT("生命回复")};
            int MaxLayers[]={5,5,5,5,5,5,3};
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
            Text(FString::Printf(TEXT("生存 %02d:%02d"),int(World->RunTime)/60,int(World->RunTime)%60),104,240,36,White);Text(FString::Printf(TEXT("击败 %d   炼金 %d   连锁 %d"),World->Kills,World->CraftCount,World->ChainCount),104,315,25,White);Text(FString::Printf(TEXT("本局到账 %d 金币"),World->ResultCoins),104,385,28,Gold);Button(TEXT("village"),TEXT("返回据点"),104,520,524);
        } else if(P==TEXT("savefailed")) {
            Paragraph(TEXT("本局金币仍待保存。重试成功后才能离开。"),104,270,1000,25,Gold);Button(TEXT("retry"),TEXT("重试保存"),104,460,524);
        } else {
            Button(TEXT("close"),TEXT("继续游戏"),104,245,524);Button(TEXT("codex"),TEXT("发现图鉴"),654,245,524);
            Button(World->bCombat?TEXT("alchemy"):TEXT("talents"),World->bCombat?TEXT("炼金"):TEXT("永久强化"),104,325,524);Button(World->bCombat?TEXT("return"):TEXT("level"),World->bCombat?TEXT("返回据点"):TEXT("选择关卡"),654,325,524);
            Text(TEXT("↑ ↓ 选择    Enter 确认    Esc 返回"),104,480,22,Dim);
        }
    }
    if(World->ToastTime>0) {Box(-OX/S,-OY/S,Canvas->SizeX/S,88+OY/S,FLinearColor(.025f,.075f,.085f,.99f));Paragraph(World->Toast,24,16,1232,20,Gold);}
}
