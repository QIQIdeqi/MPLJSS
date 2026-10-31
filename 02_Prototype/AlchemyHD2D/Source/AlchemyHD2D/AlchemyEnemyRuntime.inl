// Definition IDs address editable rows; Type remains the stable reward/special-ability archetype.
const FAlchemyEnemyRow& AAlchemyWorld::EnemyDefinition(const FAlchemyEnemy& E) const {
    return EnemyDefinition(E.Definition>=0?E.Definition:E.Type);
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
