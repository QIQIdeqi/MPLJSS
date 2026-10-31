// Definition IDs address editable rows; Type remains the stable reward/special-ability archetype.
const FAlchemyEnemyRow& AAlchemyWorld::EnemyDefinition(const FAlchemyEnemy& E) const {
    return EnemyDefinition(E.Definition>=0?E.Definition:E.Type);
}
bool AAlchemyWorld::DiscoverEnemy(const FAlchemyEnemy& E) {
    const int32 ID=E.Definition>=0?E.Definition:E.Type;
    if(!Progress || !RuntimeEnemies.IsValidIndex(ID) || Progress->Monsters.Contains(ID))return false;
    Progress->Monsters.Add(ID);return true;
}
FString AAlchemyWorld::EnemyCodexDescription(int32 ID) const {
    const auto& K=EnemyDefinition(ID);
    if(!K.CodexDescription.TrimStartAndEnd().IsEmpty())return K.CodexDescription;
    switch(K.Behavior) {
    case EAlchemyEnemyBehavior::Contact:return TEXT("主动靠近，接触时造成伤害。");
    case EAlchemyEnemyBehavior::Ranged:return TEXT("保持距离，发射投射物攻击。");
    case EAlchemyEnemyBehavior::Area:return TEXT("蓄力后发动范围攻击，留意地面预警。");
    case EAlchemyEnemyBehavior::Hybrid:return TEXT("兼有远程与范围攻击，留意站位。");
    case EAlchemyEnemyBehavior::Boss:return TEXT("强大的敌人，会使用多种招式。");
    default:return TEXT("详细记录尚未补充。");
    }
}
float AAlchemyWorld::EnemyRadius(int32 DefinitionID) const {return EnemyDefinition(DefinitionID).CollisionRadius;}
float AAlchemyWorld::EnemyRadius(const FAlchemyEnemy& E) const {return EnemyDefinition(E).CollisionRadius;}
void AAlchemyWorld::UpdateEnemyVisual(FAlchemyEnemy& E,bool Mirror) {
    const auto& K=EnemyDefinition(E);
    UpdateSprite(E.Body,K.SpriteKey,E.Pos,K.VisualSize.X*(1+.08f*E.HitFlash/.1f),K.VisualSize.Y*(1-.04f*E.HitFlash/.1f),Mirror,K.MaterialOverride);
}
int32 AAlchemyWorld::ChooseEliteDefinition() {
    float Sum=0;bool OriginalCycle=true;
    for(int ID=0;ID<RuntimeEnemies.Num();ID++){
        const auto& K=RuntimeEnemies[ID];if(K.Archetype<7 || K.Archetype>9)continue;
        Sum+=K.EliteWeight;
        if((ID>=7 && ID<=9)?K.EliteWeight!=1:K.EliteWeight!=0)OriginalCycle=false;
    }
    if(OriginalCycle)return 7+EliteIndex%3;
    if(Sum<=0)return -1;
    float Roll=Random.FRand()*Sum;
    for(int ID=0;ID<RuntimeEnemies.Num();ID++){
        const auto& K=RuntimeEnemies[ID];if(K.Archetype<7 || K.Archetype>9 || K.EliteWeight<=0)continue;
        Roll-=K.EliteWeight;if(Roll<=0)return ID;
    }
    return -1;
}
